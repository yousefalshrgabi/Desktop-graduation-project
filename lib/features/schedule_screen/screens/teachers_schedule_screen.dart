import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_session.dart';
import '../../desktop_pages/workload_management/models/graduation_project_group.dart';
import '../../desktop_pages/workload_management/services/graduation_project_firestore_service.dart';
import '../../desktop_pages/workload_management/services/overtime_hours_excel_export_service.dart';
import '../../desktop_pages/workload_management/services/college_overtime_submission_service.dart';
import '../models/timetable_entry.dart';
import '../services/timetable_firestore_service.dart';
import '../services/excel_export_service.dart';
import '../services/teacher_alias_service.dart';
import '../models/teacher_alias.dart';
import '../../desktop_pages/workload_management/models/faculty_option.dart';
import '../../desktop_pages/workload_management/services/faculty_firestore_service.dart';
import '../utils/timetable_schedule_grid.dart';
import '../widgets/timetable_data_table.dart';
import '../widgets/teacher_sync_dialog.dart';

class TeachersScheduleScreen extends StatefulWidget {
  const TeachersScheduleScreen({super.key, this.collegeName});

  final String? collegeName;

  @override
  State<TeachersScheduleScreen> createState() => _TeachersScheduleScreenState();
}

class _TeachersScheduleScreenState extends State<TeachersScheduleScreen> {
  final TimetableFirestoreService _firestore = TimetableFirestoreService();
  final GraduationProjectFirestoreService _gradProjectService =
      GraduationProjectFirestoreService();
  final FacultyFirestoreService _facultyService = FacultyFirestoreService();
  final TeacherAliasService _aliasService = TeacherAliasService();

  late final Future<void> _initFuture;
  List<TimetableEntry> _allEntries = [];
  List<FacultyOption> _facultyMembers = [];
  List<TeacherAlias> _aliases = [];
  List<String> _unmappedNames = [];

  String? _searchQuery;
  bool _isExporting = false;
  bool _isExportingOvertime = false;
  bool _isExportingParallelHours = false;
  List<GraduationProjectGroup> _graduationGroups = [];
  List<Map<String, dynamic>> _newGroups = [];
  bool _isLoadingGroups = false;
  bool _isGraduationSectionExpanded = true;

  @override
  void initState() {
    super.initState();
    _initFuture = _loadData();
  }

  Future<void> _loadData() async {
    final college = widget.collegeName ?? AppSession().userCollege;

    final futures = await Future.wait([
      college.isEmpty
          ? _firestore.getAllCachedFirst(forceRefresh: true)
          : _firestore.getByCollegeCachedFirst(college, forceRefresh: true),
      _facultyService.listUniversityWide(forceRefresh: true),
      college.isNotEmpty
          ? _aliasService.getAliasesForCollege(college)
          : Future.value(<TeacherAlias>[]),
    ]);

    _allEntries = futures[0] as List<TimetableEntry>;
    _facultyMembers = futures[1] as List<FacultyOption>;
    _aliases = futures[2] as List<TeacherAlias>;

    _computeUnmappedNames();
  }

  void _computeUnmappedNames() {
    final scheduleNames = _uniqueTeachers(_allEntries);
    final facultyNames = _facultyMembers.map((f) => f.name.trim()).toSet();
    final aliasMap = {for (var a in _aliases) a.aliasName: a.canonicalName};

    final unmapped = <String>[];
    for (final name in scheduleNames) {
      if (!facultyNames.contains(name) && !aliasMap.containsKey(name)) {
        unmapped.add(name);
      }
    }
    _unmappedNames = unmapped;
  }

  List<String> _uniqueTeachers(List<TimetableEntry> all) {
    final set = <String>{};
    for (final e in all) {
      for (final t in e.teachers) {
        if (t.trim().isNotEmpty) set.add(t.trim());
      }
    }
    return set.toList()..sort((a, b) => a.compareTo(b));
  }

  List<TimetableEntry> _filteredData(String? query, List<TimetableEntry> all) {
    if (query == null || query.isEmpty) return [];
    final q = query.trim().toLowerCase();

    // Find aliases for this canonical name
    final matchingAliases = _aliases
        .where((a) => a.canonicalName.toLowerCase() == q)
        .map((a) => a.aliasName.toLowerCase())
        .toSet();

    return all.where((e) {
      return e.teachers.any((t) {
        final teacherName = t.trim().toLowerCase();
        return teacherName == q ||
            matchingAliases.contains(teacherName) ||
            teacherName.contains(q);
      });
    }).toList();
  }

  Future<void> _exportSchedule(List<TimetableEntry> all) async {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار المعلم أولاً')));
      return;
    }

    setState(() => _isExporting = true);

    try {
      final filtered = _filteredData(_searchQuery, all);
      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد بيانات لهذا المعلم')));
        return;
      }

      final days = TimetableScheduleGrid.sortedDays(filtered.map((e) => e.day));
      final hours =
          TimetableScheduleGrid.sortedHours(filtered.map((e) => e.hour));

      final headers = ['اليوم', ...hours];
      final dataRows = <List<String>>[];

      for (final day in days) {
        final row = <String>[day];
        for (final hour in hours) {
          final entries =
              filtered.where((e) => e.day == day && e.hour == hour).toList();
          if (entries.isEmpty) {
            row.add('');
          } else {
            final cellText = entries
                .map((e) =>
                    '${e.subject}\n${e.studentSets.join(", ")}\n${e.room}')
                .join('\n---\n');
            row.add(cellText);
          }
        }
        dataRows.add(row);
      }

      final service = ExcelExportService();
      await service.exportTable(
        fileName: 'جدول_المعلم_$_searchQuery',
        title: 'الكلية - جدول المعلم: $_searchQuery',
        headers: headers,
        dataRows: dataRows,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تصدير الجدول بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _loadGraduationGroups(String teacherName) async {
    setState(() => _isLoadingGroups = true);
    try {
      final groups = await _gradProjectService.getGroupsForTeacher(teacherName);
      if (mounted) {
        setState(() {
          _graduationGroups = groups;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ في تحميل مجموعات التخرج: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGroups = false);
      }
    }
  }

  void _addNewGroup() {
    setState(() {
      _newGroups.add({
        'studentCount': 1,
        'scheduleType': 'عام',
      });
      _isGraduationSectionExpanded = true;
    });
  }

  void _removeGroup(int index) {
    setState(() {
      _newGroups.removeAt(index);
    });
  }

  void _updateGroupStudentCount(int index, int count) {
    setState(() {
      _newGroups[index]['studentCount'] = count;
    });
  }

  void _updateGroupScheduleType(int index, String type) {
    setState(() {
      _newGroups[index]['scheduleType'] = type;
    });
  }

  Future<void> _saveGraduationGroups() async {
    if (_searchQuery == null || _newGroups.isEmpty) return;

    setState(() => _isLoadingGroups = true);
    try {
      final nextGroupNumber =
          await _gradProjectService.getNextGroupNumber(_searchQuery!);

      for (int i = 0; i < _newGroups.length; i++) {
        final group = GraduationProjectGroup(
          id: '',
          teacherName: _searchQuery!,
          groupNumber: nextGroupNumber + i,
          studentCount: _newGroups[i]['studentCount'] as int,
          scheduleType: (_newGroups[i]['scheduleType'] ?? 'عام').toString(),
        );
        await _gradProjectService.saveGroup(group);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ المجموعات بنجاح')),
        );
        setState(() {
          _newGroups.clear();
        });
        await _loadGraduationGroups(_searchQuery!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGroups = false);
      }
    }
  }

  Widget _buildGraduationProjectSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(top: BorderSide(color: Colors.blue.shade200)),
      ),
      child: ExpansionTile(
        initiallyExpanded: _isGraduationSectionExpanded,
        onExpansionChanged: (expanded) {
          setState(() => _isGraduationSectionExpanded = expanded);
        },
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: Icon(Icons.school, color: Colors.blue.shade700),
        title: Text(
          'مجموعات مشروع التخرج',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
        children: [
          const SizedBox(height: 12),
          if (_isLoadingGroups)
            const Center(child: CircularProgressIndicator())
          else if (_graduationGroups.isNotEmpty) ...[
            Text(
              'المجموعات المسجلة: ${_graduationGroups.length}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _graduationGroups.map((group) {
                return Chip(
                  label: Text(
                    'مجموعة ${group.groupNumber} (${group.studentCount} طلاب) - ${group.scheduleType}',
                  ),
                  backgroundColor: group.isParallel
                      ? Colors.orange.shade100
                      : Colors.green.shade100,
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () async {
                    await _gradProjectService.deleteGroup(group.id);
                    await _loadGraduationGroups(_searchQuery!);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'إضافة مجموعات جديدة',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ..._newGroups.asMap().entries.map((entry) {
            final index = entry.key;
            final group = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('مجموعة رقم (${index + 1})'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: group['studentCount'] as int,
                      decoration: const InputDecoration(
                        labelText: 'عدد الطلاب',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: List.generate(4, (i) => i + 1).map((count) {
                        return DropdownMenuItem(
                          value: count,
                          child: Text('$count طلاب'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _updateGroupStudentCount(index, val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: (group['scheduleType'] ?? 'عام').toString(),
                      decoration: const InputDecoration(
                        labelText: 'النوع',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'عام',
                          child: Text('عام'),
                        ),
                        DropdownMenuItem(
                          value: 'موازي',
                          child: Text('موازي'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _updateGroupScheduleType(index, val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeGroup(index),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _addNewGroup,
                icon: const Icon(Icons.add),
                label: const Text('إضافة مجموعة'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saveGraduationGroups,
                icon: const Icon(Icons.save),
                label: const Text('حفظ'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<TimetableEntry>> _loadCustomScheduleEntries(
    List<TimetableEntry> all,
    String scheduleName, {
    bool isOvertime = false,
  }) async {
    final filtered = _filteredData(_searchQuery, all);
    if (filtered.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final prefKey = isOvertime
        ? 'overtime_courses_$_searchQuery'
        : 'parallel_courses_$_searchQuery';

    final savedJson = prefs.getString(prefKey);
    List<String> assignedCourses = [];
    if (savedJson != null) {
      try {
        final List<dynamic> list = jsonDecode(savedJson);
        assignedCourses = list.cast<String>();
      } catch (_) {}
    }

    if (assignedCourses.isEmpty) {
      return filtered;
    } else {
      return filtered.where((e) {
        final key = '${e.subject}_${e.day}_${e.hour}';
        return assignedCourses.contains(key);
      }).toList();
    }
  }

  Future<void> _exportOvertimeForm(List<TimetableEntry> all) async {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار المعلم أولاً')));
      return;
    }
    setState(() => _isExportingOvertime = true);
    try {
      final entries =
          await _loadCustomScheduleEntries(all, 'overtime', isOvertime: true);
      if (entries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('لا توجد ساعات زائدة محددة لهذا المعلم')),
          );
        }
        return;
      }

      final service = OvertimeHoursExcelExportService();
      await service.exportTeacherOvertimeForm(
        teacherName: _searchQuery!,
        entries: all,
        selectedEntries: entries,
        graduationProjectScheduleType: 'عام',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تصدير استمارة الساعات الزائدة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingOvertime = false);
    }
  }

  Future<void> _exportParallelHoursForm(List<TimetableEntry> all) async {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار المعلم أولاً')));
      return;
    }
    setState(() => _isExportingParallelHours = true);
    try {
      final entries =
          await _loadCustomScheduleEntries(all, 'parallel', isOvertime: false);
      if (entries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('لا توجد ساعات موازية محددة لهذا المعلم')),
          );
        }
        return;
      }

      final service = OvertimeHoursExcelExportService();
      await service.exportTeacherParallelHoursForm(
        teacherName: _searchQuery!,
        entries: all,
        parallelEntries: entries,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تصدير استمارة الساعات الموازية بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingParallelHours = false);
    }
  }

  Future<void> _submitCollegeOvertime(String type) async {
    final session = AppSession();
    final typeName =
        type == 'overtime' ? 'الساعات الزائدة' : 'الساعات الموازية';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('رفع كشوفات $typeName'),
        content: Text(
            'هل أنت متأكد من رغبتك في رفع كشوفات $typeName للكلية إلى العميد لاعتمادها؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الرفع'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final service = CollegeOvertimeSubmissionService();
      final exportService = OvertimeHoursExcelExportService();

      final entriesByTeacher = <String, List<TimetableEntry>>{};
      for (final entry in _allEntries) {
        for (final teacher in entry.teachers) {
          if (teacher.trim().isEmpty) continue;
          final mappedTeacher = teacher.trim();
          entriesByTeacher.putIfAbsent(mappedTeacher, () => []).add(entry);
        }
      }

      final summary = await exportService.calculateCollegeSummary(
        collegeName: session.userCollege,
        term: 'second', // يُفضل جلبه من الإعدادات لاحقاً
        entriesByTeacher: entriesByTeacher,
        halfWeightEntryIds: {},
        halfWeightSessionKeys: {},
        graduationProjectScheduleType: type == 'overtime' ? 'عام' : 'موازي',
      );

      await service.submitToDean(
        collegeName: session.userCollege,
        term: 'second',
        type: type,
        entries: summary,
      );

      if (mounted) {
        Navigator.pop(context); // إغلاق التحميل
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تم رفع كشوفات $typeName للعميد بنجاح!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // إغلاق التحميل
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('حدث خطأ أثناء الرفع: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSession();
    final isViceDean = session.isViceDean;

    return Scaffold(
      appBar: AppBar(
        title: const Text('جدول المعلمين'),
        actions: [
          if (isViceDean && _allEntries.isNotEmpty) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () => _submitCollegeOvertime('overtime'),
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('رفع الساعات الزائدة للعميد',
                  style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              onPressed: () => _submitCollegeOvertime('parallel'),
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('رفع الساعات الموازية للعميد',
                  style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 16),
          ]
        ],
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          if (_allEntries.isEmpty) {
            return Center(
              child: Text(
                widget.collegeName == null
                    ? 'لا توجد بيانات للعرض'
                    : 'عذراً، لم يتم رفع جداول ${widget.collegeName} من قبل النائب الأكاديمي بعد',
                textAlign: TextAlign.center,
              ),
            );
          }

          final all = _allEntries;

          // عرض المعلمين الموجودين في الجدول المرفوع فقط
          List<String> sortedOptions = _uniqueTeachers(all);

          final session = AppSession();
          final isAdmin =
              session.isAdminOrDeanship || session.isDean || session.isViceDean;

          if (!isAdmin) {
            sortedOptions = sortedOptions.where((t) {
              if (t.trim() == session.userName.trim()) return true;
              final hasAlias = _aliases.any((a) =>
                  a.aliasName.trim() == t.trim() &&
                  a.canonicalName.trim() == session.userName.trim());
              return hasAlias;
            }).toList();

            if (_searchQuery != null && !sortedOptions.contains(_searchQuery)) {
              _searchQuery = null;
            }
            if (_searchQuery == null && sortedOptions.length == 1) {
              _searchQuery = sortedOptions.first;
            }
          }

          final filtered = _filteredData(_searchQuery, all);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'اختر المعلم',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _searchQuery != null &&
                                          sortedOptions.contains(_searchQuery)
                                      ? _searchQuery
                                      : null,
                                  decoration: const InputDecoration(
                                    hintText: 'اختر معلماً من القائمة...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                  items: sortedOptions.map((t) {
                                    final isUnmapped =
                                        _unmappedNames.contains(t);
                                    return DropdownMenuItem(
                                      value: t,
                                      child: Text(
                                        t + (isUnmapped ? ' (غير مربوط)' : ''),
                                        style: TextStyle(
                                          color: isUnmapped
                                              ? Colors.redAccent
                                              : null,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _searchQuery = val;
                                      _newGroups = [];
                                    });
                                    if (val != null && val.isNotEmpty) {
                                      _loadGraduationGroups(val);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed:
                                  _isExportingOvertime || _searchQuery == null
                                      ? null
                                      : () => _exportOvertimeForm(all),
                              icon: _isExportingOvertime
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.table_chart_outlined,
                                      size: 20),
                              label: const Text('الساعات الزائدة'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _isExportingParallelHours ||
                                      _searchQuery == null
                                  ? null
                                  : () => _exportParallelHoursForm(all),
                              icon: _isExportingParallelHours
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.table_rows_outlined,
                                      size: 20),
                              label: const Text('الساعات الموازية'),
                            ),
                            IconButton.filled(
                              onPressed: _isExporting || _searchQuery == null
                                  ? null
                                  : () => _exportSchedule(all),
                              icon: _isExporting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.download),
                              tooltip: 'تصدير كملف إكسل',
                              padding: const EdgeInsets.all(12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: TimetableDataTable(
                    entries: filtered,
                    showTeachers: false,
                    showStudentSets: true,
                    showRoom: true,
                  ),
                ),
              ),
              if ((AppSession().isViceDean || AppSession().isAdminOrDeanship) &&
                  _searchQuery != null &&
                  _searchQuery!.isNotEmpty)
                _buildGraduationProjectSection(),
            ],
          );
        },
      ),
    );
  }
}
