import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';


import '../models/faculty_option.dart';
import '../models/semester_nasab_assignment.dart';
import '../services/activities_schedule_service.dart';
import '../services/computed_nasab_service.dart';
import '../services/course_need_letter_service.dart';
import '../services/faculty_firestore_service.dart';
import '../services/semester_nasab_firestore_service.dart';
import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/utils/course_coverage.dart';
import '../utils/level_labels.dart';
import '../widgets/faculty_dropdown_field.dart';
import 'activities_preview_screen.dart';
import 'computed_nasab_view_screen.dart';
import 'course_need_preview_screen.dart';

/// Vice dean: assign theory (B) and practical (C) teachers per course (A).
class CourseAssignmentView extends StatefulWidget {
  const CourseAssignmentView({
    super.key,
    this.initialCollege = 'كلية الحاسبات',
    this.canEdit = false,
    this.lockCollege = false,
    this.restrictFacultyToCollege = false,
  });

  final String initialCollege;
  final bool canEdit;
  final bool lockCollege;
  final bool restrictFacultyToCollege;

  @override
  State<CourseAssignmentView> createState() => _CourseAssignmentViewState();
}

class _CourseAssignmentViewState extends State<CourseAssignmentView> {
  final _nasabService = SemesterNasabFirestoreService();
  final _facultyService = FacultyFirestoreService();
  final _computedNasab = ComputedNasabService();
  final _activitiesService = ActivitiesScheduleService();
  final _collegeController = TextEditingController();

  String _term = 'first';
  bool _loading = false;
  bool _saving = false;
  bool _importingFromExcel = false;

  List<SemesterNasabRow> _rows = [];
  List<FacultyOption> _collegeFaculty = [];
  List<FacultyOption> _universityFaculty = [];
  List<PlanCourseSlot> _slots = [];
  Map<String, int> _groupCounts = {};

  String? _filterProgram;
  int? _filterLevel;
  final Map<int, SemesterNasabAssignment> _localModifications = {};

  @override
  void initState() {
    super.initState();
    _collegeController.text = widget.initialCollege;
    _load();
  }

  @override
  void dispose() {
    _collegeController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    try {
      final college = _collegeController.text.trim();
      final results = await Future.wait([
        _nasabService.loadSheet(
          collegeName: college,
          term: _term,
          forceRefresh: forceRefresh,
        ),
        _facultyService.listByCollege(college, forceRefresh: true),
        _facultyService.listUniversityWide(forceRefresh: true),
        _computedNasab.loadSlotsForTerm(
          collegeName: college,
          term: _term,
          forceRefresh: forceRefresh,
        ),
        _computedNasab.loadGroupCountMap(
          collegeName: college,
          forceRefresh: forceRefresh,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _rows = results[0] as List<SemesterNasabRow>;
        _collegeFaculty = results[1] as List<FacultyOption>;
        _universityFaculty = results[2] as List<FacultyOption>;
        _slots = results[3] as List<PlanCourseSlot>;
        _groupCounts = results[4] as Map<String, int>;
        _localModifications.clear();
        _filterProgram = null;
        _filterLevel = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('تعذر تحميل بيانات الربط: $e', isError: true);
    }
  }

  List<SemesterNasabRow> _mergedRows() {
    return List<SemesterNasabRow>.generate(_rows.length, (index) {
      final base = _rows[index];
      final local = _localModifications[index];
      return SemesterNasabRow(
          course: base.course, assignment: local ?? base.assignment);
    });
  }

  List<SemesterNasabRow> get _visibleRows {
    final merged = _mergedRows();
    return [
      for (var i = 0; i < merged.length; i++)
        if (_rowVisible(i)) merged[i],
    ];
  }

  List<String> get _programOptions {
    final programs = _slots.map((slot) => slot.programName).toSet().toList();
    programs.sort();
    return programs;
  }

  List<int> get _levelOptions {
    final levels = _slots.map((slot) => slot.level).toSet().toList();
    levels.sort();
    return levels;
  }

  int get _assignedCount {
    return _mergedRows().where((row) {
      final a = row.assignment;
      final theoryOk =
          !row.course.needsTheory || a.theoryTeacherName.trim().isNotEmpty;
      final practicalOk = !row.course.needsPractical ||
          a.practicalTeacherName.trim().isNotEmpty;
      return theoryOk && practicalOk;
    }).length;
  }

  bool _rowVisible(int index) {
    final row = _rows[index];
    final matchingSlots = _slots.where(
      (slot) => slot.courseKey == row.course.courseKey && slot.term == _term,
    );

    if (_filterProgram != null &&
        !matchingSlots.any((slot) => slot.programName == _filterProgram)) {
      return false;
    }
    if (_filterLevel != null &&
        !matchingSlots.any((slot) => slot.level == _filterLevel)) {
      return false;
    }
    return true;
  }

  List<FacultyOption> _poolFor(CourseCoverageScope scope) {
    final source = widget.restrictFacultyToCollege
        ? _collegeFaculty
        : _universityFaculty;
    return _dedupeFaculty(source);
  }

  List<FacultyOption> _allFaculty() {
    if (widget.restrictFacultyToCollege) {
      return _dedupeFaculty(_collegeFaculty);
    }
    return _dedupeFaculty([..._collegeFaculty, ..._universityFaculty]);
  }

  List<FacultyOption> _dedupeFaculty(List<FacultyOption> faculty) {
    final byId = <String, FacultyOption>{};
    for (final item in faculty) {
      if (item.id.isNotEmpty && item.name.trim().isNotEmpty) {
        byId[item.id] = item;
      }
    }
    final out = byId.values.toList();
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  void _setTheory(int index, FacultyOption? teacher) {
    setState(() {
      final current = _localModifications[index] ?? _rows[index].assignment;
      _localModifications[index] = current.copyWith(
        theoryTeacherId: teacher?.id,
        theoryTeacherName: teacher?.name ?? '',
      );
    });
  }

  void _setPractical(int index, FacultyOption? teacher) {
    setState(() {
      final current = _localModifications[index] ?? _rows[index].assignment;
      _localModifications[index] = current.copyWith(
        practicalTeacherId: teacher?.id,
        practicalTeacherName: teacher?.name ?? '',
      );
    });
  }

  Future<void> _save() async {
    if (!widget.canEdit) return;
    setState(() => _saving = true);
    try {
      await _nasabService.saveAll(
        collegeName: _collegeController.text.trim(),
        term: _term,
        rows: _mergedRows(),
      );
      if (!mounted) return;
      setState(() => _localModifications.clear());
      _showSnack('تم حفظ ربط المدرسين بالمواد بنجاح');
    } catch (e) {
      if (!mounted) return;
      _showSnack('تعذر الحفظ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _importFromExcel() async {
    if (!widget.canEdit) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'xlsm'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      _showSnack('تعذر قراءة الملف المختار.', isError: true);
      return;
    }

    setState(() => _importingFromExcel = true);
    try {
      final excel = Excel.decodeBytes(bytes);
      final sheet = _findAssignmentSheet(excel);
      if (sheet == null) {
        _showSnack('لم يتم العثور على ورقة1 أو أي ورقة قابلة للقراءة.',
            isError: true);
        return;
      }

      final assignments = _parseExcelAssignments(sheet);
      if (assignments.isEmpty) {
        _showSnack('لم أجد صفوف مواد داخل الملف.', isError: true);
        return;
      }

      if (!mounted) return;
      final confirmed = await _showImportPreview(assignments);
      if (confirmed != true) return;

      await _applyImportedAssignments(assignments);
    } catch (e) {
      if (mounted) _showSnack('خطأ أثناء استيراد Excel: $e', isError: true);
    } finally {
      if (mounted) setState(() => _importingFromExcel = false);
    }
  }

  Sheet? _findAssignmentSheet(Excel excel) {
    const preferredNames = ['ورقة1', 'Sheet1', 'sheet1'];
    for (final name in preferredNames) {
      if (excel.sheets.containsKey(name)) return excel[name];
    }
    if (excel.tables.isEmpty) return null;
    return excel.tables.values.first;
  }

  List<_ExcelAssignment> _parseExcelAssignments(Sheet sheet) {
    final out = <_ExcelAssignment>[];
    for (var i = 0; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final course = _cellText(row, 0);
      if (course.isEmpty) continue;
      if (i == 0 && _looksLikeHeader(course)) continue;

      out.add(
        _ExcelAssignment(
          courseName: course,
          theoryTeacher: _cellText(row, 1),
          practicalTeacher: _cellText(row, 2),
          department: _cellText(row, 6),
          level: _cellText(row, 7),
        ),
      );
    }
    return out;
  }

  String _cellText(List<Data?> row, int index) {
    if (index >= row.length) return '';
    final value = row[index]?.value;
    if (value == null) return '';
    return value.toString().replaceAll('\u00a0', ' ').trim();
  }

  bool _looksLikeHeader(String value) {
    final normalized = _normalize(value);
    return normalized.contains('المادة') ||
        normalized.contains('المقرر') ||
        normalized.contains('course') ||
        normalized.contains('subject');
  }

  Future<bool?> _showImportPreview(List<_ExcelAssignment> assignments) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معاينة الاستيراد'),
        content: SizedBox(
          width: 720,
          height: 440,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('سيتم استيراد ${assignments.length} صفاً من ملف Excel.'),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: assignments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = assignments[index];
                    return ListTile(
                      dense: true,
                      title: Text(item.courseName),
                      subtitle: Text(
                        'نظري: ${_dash(item.theoryTeacher)} | عملي: ${_dash(item.practicalTeacher)}',
                      ),
                      trailing: Text(
                        [item.department, item.level]
                            .where((v) => v.isNotEmpty)
                            .join(' - '),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.done_rounded),
            label: const Text('تطبيق الاستيراد'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyImportedAssignments(
      List<_ExcelAssignment> assignments) async {
    final allFaculty = _allFaculty();
    final teacherNames = <String>{};
    for (final assignment in assignments) {
      if (assignment.theoryTeacher.isNotEmpty) {
        teacherNames.add(assignment.theoryTeacher);
      }
      if (assignment.practicalTeacher.isNotEmpty) {
        teacherNames.add(assignment.practicalTeacher);
      }
    }

    final matches = <String, FacultyOption?>{};
    final unmatched = <String>[];
    for (final name in teacherNames) {
      final match = _matchTeacher(name, allFaculty);
      matches[name] = match;
      if (match == null) unmatched.add(name);
    }

    if (unmatched.isNotEmpty && mounted) {
      final handled =
          await _handleUnmatchedTeachers(unmatched, matches, allFaculty);
      if (handled != true) return;
    }

    var applied = 0;
    var skippedCourses = 0;
    for (final imported in assignments) {
      final rowIndex = _findCourseRow(imported.courseName);
      if (rowIndex == -1) {
        skippedCourses++;
        continue;
      }

      final theory = imported.theoryTeacher.isEmpty
          ? null
          : matches[imported.theoryTeacher];
      final practical = imported.practicalTeacher.isEmpty
          ? null
          : matches[imported.practicalTeacher];
      if (theory == null && practical == null) continue;

      final current =
          _localModifications[rowIndex] ?? _rows[rowIndex].assignment;
      _localModifications[rowIndex] = current.copyWith(
        theoryTeacherId: theory?.id,
        theoryTeacherName: theory?.name ?? '',
        practicalTeacherId: practical?.id,
        practicalTeacherName: practical?.name ?? '',
      );
      applied++;
    }

    if (!mounted) return;
    setState(() {});
    _showSnack(
      skippedCourses == 0
          ? 'تم تطبيق $applied ربطاً من Excel. راجع النتائج ثم اضغط حفظ.'
          : 'تم تطبيق $applied ربطاً. لم تطابق $skippedCourses مادة مع الخطة.',
    );
  }

  Future<bool?> _handleUnmatchedTeachers(
    List<String> unmatched,
    Map<String, FacultyOption?> matches,
    List<FacultyOption> allFaculty,
  ) {
    final selections = <String, FacultyOption?>{};
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('مطابقة ${unmatched.length} مدرس غير موجود'),
            content: SizedBox(
              width: 680,
              height: 460,
              child: ListView.separated(
                itemCount: unmatched.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final name = unmatched[index];
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<FacultyOption>(
                            initialValue: selections[name],
                            decoration: const InputDecoration(
                              labelText: 'اختر المدرس المطابق',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            isExpanded: true,
                            items: allFaculty
                                .map(
                                  (faculty) => DropdownMenuItem(
                                    value: faculty,
                                    child: Text(
                                      '${faculty.name} - ${faculty.college} - ${faculty.department}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() => selections[name] = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء الاستيراد'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تجاهل غير المطابق'),
              ),
              FilledButton(
                onPressed: selections.isEmpty
                    ? null
                    : () {
                        for (final entry in selections.entries) {
                          matches[entry.key] = entry.value;
                        }
                        Navigator.pop(context, true);
                      },
                child: Text('تطبيق المطابقة (${selections.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  FacultyOption? _matchTeacher(String name, List<FacultyOption> allFaculty) {
    final target = _normalize(name);
    if (target.isEmpty) return null;

    for (final faculty in allFaculty) {
      if (_normalize(faculty.name) == target ||
          _normalize(faculty.shortName) == target) {
        return faculty;
      }
    }
    for (final faculty in allFaculty) {
      final normalizedName = _normalize(faculty.name);
      if (normalizedName.contains(target) || target.contains(normalizedName)) {
        return faculty;
      }
    }
    return null;
  }

  int _findCourseRow(String courseName) {
    final target = _normalize(courseName);
    for (var i = 0; i < _rows.length; i++) {
      final course = _rows[i].course;
      if (_normalize(course.nameAr) == target ||
          _normalize(course.codeLocal) == target ||
          _normalize(course.courseKey) == target) {
        return i;
      }
    }
    for (var i = 0; i < _rows.length; i++) {
      final course = _rows[i].course;
      final byName = _normalize(course.nameAr);
      final byCode = _normalize(course.codeLocal);
      if (byName.contains(target) ||
          target.contains(byName) ||
          (byCode.isNotEmpty && target.contains(byCode))) {
        return i;
      }
    }
    return -1;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064b-\u065f]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[\s_\-–—/\\()[\]{}،,.:;]+'), '')
        .trim();
  }

  Future<void> _openActivitiesExport() async {
    final activities = await _activitiesService.build(
      slots: _slots,
      assignmentRows: _mergedRows(),
      groupCounts: _groupCounts,
      collegeName: _collegeController.text.trim(),
    );

    if (!mounted) return;
    if (activities.isEmpty) {
      _showSnack(
        'لا توجد بيانات Activities. عيّن المدرسين وتأكد من الخطط ومجموعات العملي.',
        isError: true,
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivitiesPreviewScreen(
          collegeName: _collegeController.text.trim(),
          term: _term,
          rows: activities,
        ),
      ),
    );
  }

  void _openComputedNasab() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComputedNasabViewScreen(
          initialCollege: _collegeController.text.trim(),
          initialTerm: _term,
          lockCollege: widget.lockCollege,
        ),
      ),
    );
  }

  void _openCourseNeedPreview() {
    final data = CourseNeedLetterService.buildData(
      assignmentRows: _mergedRows(),
      slots: _slots,
      groupCounts: _groupCounts,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseNeedPreviewScreen(
          collegeName: _collegeController.text.trim(),
          term: _term,
          data: data,
        ),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  String _dash(String value) => value.trim().isEmpty ? '-' : value.trim();

  @override
  Widget build(BuildContext context) {
    final termLabel = _term == 'first' ? 'الفصل الأول' : 'الفصل الثاني';
    final visibleRows = _visibleRows;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'ربط المدرسين بالمواد',
            style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 20),
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          actions: [
            if (MediaQuery.of(context).size.width >= 600) ...[
              IconButton(
                tooltip: 'توليد Activities',
                onPressed: _loading ? null : _openActivitiesExport,
                icon: const Icon(Icons.event_note_rounded),
              ),
              IconButton(
                tooltip: 'عرض النصاب المحسوب',
                onPressed: _loading ? null : _openComputedNasab,
                icon: const Icon(Icons.table_view_rounded),
              ),
              IconButton(
                tooltip: 'مقررات الاحتياج',
                onPressed: _loading ? null : _openCourseNeedPreview,
                icon: const Icon(Icons.fact_check_outlined),
              ),
            ] else ...[
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'activities') _openActivitiesExport();
                  if (value == 'computed') _openComputedNasab();
                  if (value == 'need') _openCourseNeedPreview();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'activities',
                    child: Text('توليد Activities'),
                  ),
                  const PopupMenuItem(
                    value: 'computed',
                    child: Text('النصاب المحسوب'),
                  ),
                  const PopupMenuItem(
                    value: 'need',
                    child: Text('مقررات الاحتياج'),
                  ),
                ],
              ),
            ],
            IconButton(
              tooltip: 'تحديث',
              onPressed:
                  _loading || _saving ? null : () => _load(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'حفظ',
              onPressed: _loading || _saving || _rows.isEmpty || !widget.canEdit
                  ? null
                  : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            _Header(
              collegeController: _collegeController,
              term: _term,
              loading: _loading,
              saving: _saving,
              importing: _importingFromExcel,
              canEdit: widget.canEdit,
              lockCollege: widget.lockCollege,
              programFilter: _filterProgram,
              levelFilter: _filterLevel,
              programs: _programOptions,
              levels: _levelOptions,
              totalRows: _rows.length,
              visibleRows: visibleRows.length,
              assignedRows: _assignedCount,
              termLabel: termLabel,
              onReload: () => _load(forceRefresh: true),
              onImport: _importFromExcel,
              onActivities: _openActivitiesExport,
              onComputedNasab: _openComputedNasab,
              onCourseNeed: _openCourseNeedPreview,
              onTermChanged: (value) {
                setState(() => _term = value);
                _load();
              },
              onProgramChanged: (value) =>
                  setState(() => _filterProgram = value),
              onLevelChanged: (value) => setState(() => _filterLevel = value),
              onCollegeSubmitted: () => _load(forceRefresh: true),
              onClearFilters: () {
                setState(() {
                  _filterProgram = null;
                  _filterLevel = null;
                });
              },
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                      ? const _EmptyMessage(
                          text:
                              'لا توجد مواد لهذا الفصل.\nارفع الخطط الدراسية أولاً ثم عد إلى هذه الصفحة.',
                        )
                      : visibleRows.isEmpty
                          ? const _EmptyMessage(
                              text: 'لا توجد مواد مطابقة للفلاتر الحالية.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                              itemCount: _rows.length,
                              itemBuilder: (context, index) {
                                if (!_rowVisible(index)) {
                                  return const SizedBox.shrink();
                                }
                                return _CourseAssignmentCard(
                                  row: _rows[index],
                                  current: _localModifications[index] ??
                                      _rows[index].assignment,
                                  pool: _poolFor(_rows[index].coverageScope),
                                  practicalText:
                                      _practicalTextFor(_rows[index]),
                                  canEdit: widget.canEdit,
                                  onTheoryChanged: (teacher) => widget.canEdit
                                      ? _setTheory(index, teacher)
                                      : null,
                                  onPracticalChanged: (teacher) =>
                                      widget.canEdit
                                          ? _setPractical(index, teacher)
                                          : null,
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  String _practicalTextFor(SemesterNasabRow row) {
    if (!row.course.needsPractical) return '-';
    final breakdowns = _computedNasab.practicalBreakdownsForCourse(
      courseKey: row.course.courseKey,
      term: _term,
      slots: _slots,
      groupCounts: _groupCounts,
    );
    return ComputedNasabService.formatBreakdowns(breakdowns);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.collegeController,
    required this.term,
    required this.loading,
    required this.saving,
    required this.importing,
    required this.canEdit,
    required this.lockCollege,
    required this.programFilter,
    required this.levelFilter,
    required this.programs,
    required this.levels,
    required this.totalRows,
    required this.visibleRows,
    required this.assignedRows,
    required this.termLabel,
    required this.onReload,
    required this.onImport,
    required this.onActivities,
    required this.onComputedNasab,
    required this.onCourseNeed,
    required this.onTermChanged,
    required this.onProgramChanged,
    required this.onLevelChanged,
    required this.onCollegeSubmitted,
    required this.onClearFilters,
  });

  final TextEditingController collegeController;
  final String term;
  final bool loading;
  final bool saving;
  final bool importing;
  final bool canEdit;
  final bool lockCollege;
  final String? programFilter;
  final int? levelFilter;
  final List<String> programs;
  final List<int> levels;
  final int totalRows;
  final int visibleRows;
  final int assignedRows;
  final String termLabel;
  final VoidCallback onReload;
  final VoidCallback onImport;
  final VoidCallback onActivities;
  final VoidCallback onComputedNasab;
  final VoidCallback onCourseNeed;
  final ValueChanged<String> onTermChanged;
  final ValueChanged<String?> onProgramChanged;
  final ValueChanged<int?> onLevelChanged;
  final VoidCallback onCollegeSubmitted;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'مطابق لورقة1: العمود A للمادة، B للمدرس النظري، C للمدرس العملي. الحفظ يبني النصاب المحسوب وملف Activities من نفس الربط.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: collegeController,
              readOnly: lockCollege,
              decoration: const InputDecoration(
                labelText: 'الكلية',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school_outlined),
              ),
              onSubmitted: (_) => onCollegeSubmitted(),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'first', label: Text('الفصل الدراسي الأول')),
                ButtonSegment(
                    value: 'second', label: Text('الفصل الدراسي الثاني')),
              ],
              selected: {term},
              onSelectionChanged: loading || saving
                  ? null
                  : (selected) => onTermChanged(selected.first),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final filterFields = [
                  DropdownButtonFormField<String?>(
                    initialValue: programFilter,
                    decoration: const InputDecoration(
                      labelText: 'فلتر التخصص',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.filter_alt_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('كل التخصصات'),
                      ),
                      ...programs.map(
                        (program) => DropdownMenuItem(
                          value: program,
                          child: Text(program, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: loading ? null : onProgramChanged,
                  ),
                  DropdownButtonFormField<int?>(
                    initialValue: levelFilter,
                    decoration: const InputDecoration(
                      labelText: 'فلتر المستوى',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.filter_alt_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('كل المستويات'),
                      ),
                      ...levels.map(
                        (level) => DropdownMenuItem(
                          value: level,
                          child: Text(LevelLabels.forLevel(level)),
                        ),
                      ),
                    ],
                    onChanged: loading ? null : onLevelChanged,
                  ),
                ];

                if (compact) {
                  return Column(
                    children: [
                      filterFields[0],
                      const SizedBox(height: 8),
                      filterFields[1],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: filterFields[0]),
                    const SizedBox(width: 8),
                    Expanded(child: filterFields[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: const Icon(Icons.menu_book_rounded, size: 18),
                  label: Text('المواد: $visibleRows من $totalRows'),
                ),
                Chip(
                  avatar:
                      const Icon(Icons.assignment_turned_in_rounded, size: 18),
                  label: Text('المكتملة: $assignedRows'),
                ),
                Chip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(termLabel),
                ),
                OutlinedButton.icon(
                  onPressed: loading ? null : onClearFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('مسح الفلاتر'),
                ),
                FilledButton.icon(
                  onPressed: loading ? null : onReload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة تحميل'),
                ),
                FilledButton.tonalIcon(
                  onPressed: loading || importing || !canEdit ? null : onImport,
                  icon: importing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_rounded),
                  label: const Text('استيراد من Excel'),
                ),
                FilledButton.tonalIcon(
                  onPressed: loading ? null : onActivities,
                  icon: const Icon(Icons.event_note_rounded),
                  label: const Text('Activities'),
                ),
                FilledButton.tonalIcon(
                  onPressed: loading ? null : onCourseNeed,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('مقررات الاحتياج'),
                ),
                FilledButton.tonalIcon(
                  onPressed: loading ? null : onComputedNasab,
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('النصاب المحسوب'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseAssignmentCard extends StatelessWidget {
  const _CourseAssignmentCard({
    required this.row,
    required this.current,
    required this.pool,
    required this.practicalText,
    required this.canEdit,
    required this.onTheoryChanged,
    required this.onPracticalChanged,
  });

  final SemesterNasabRow row;
  final SemesterNasabAssignment current;
  final List<FacultyOption> pool;
  final String practicalText;
  final bool canEdit;
  final ValueChanged<FacultyOption?> onTheoryChanged;
  final ValueChanged<FacultyOption?> onPracticalChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      if (row.course.codeLocal.isNotEmpty) row.course.codeLocal,
      row.coverageScope.labelAr,
      if (row.course.needsPractical)
        'نظري ${row.course.creditTheory} / عملي ${row.course.creditPractical}'
      else
        'نظري ${row.course.creditTheory}',
    ].join(' - ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              row.course.nameAr,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(details, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.calculate_outlined,
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ساعات العملي المحسوبة: $practicalText',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            FacultyDropdownField(
              label: 'المدرس النظري (عمود B)',
              options: pool,
              selectedId: current.theoryTeacherId,
              enabled: canEdit && row.course.needsTheory,
              onChanged: onTheoryChanged,
            ),
            const SizedBox(height: 8),
            FacultyDropdownField(
              label: 'المدرس العملي (عمود C)',
              options: pool,
              selectedId: current.practicalTeacherId,
              enabled: canEdit && row.course.needsPractical,
              onChanged: onPracticalChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

class _ExcelAssignment {
  const _ExcelAssignment({
    required this.courseName,
    required this.theoryTeacher,
    required this.practicalTeacher,
    required this.department,
    required this.level,
  });

  final String courseName;
  final String theoryTeacher;
  final String practicalTeacher;
  final String department;
  final String level;
}
