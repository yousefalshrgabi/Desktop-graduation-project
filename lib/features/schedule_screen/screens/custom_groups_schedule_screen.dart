import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/timetable_entry.dart';
import '../services/timetable_firestore_service.dart';
import '../services/excel_export_service.dart';
import '../utils/timetable_schedule_grid.dart';
import '../widgets/department_data_table.dart';

class CustomGroupsScheduleScreen extends StatefulWidget {
  const CustomGroupsScheduleScreen({super.key});

  @override
  State<CustomGroupsScheduleScreen> createState() => _CustomGroupsScheduleScreenState();
}

class _CustomGroupsScheduleScreenState extends State<CustomGroupsScheduleScreen> {
  final TimetableFirestoreService _firestore = TimetableFirestoreService();
  late final Future<List<TimetableEntry>> _dataFuture;
  
  List<String> _selectedGroups = [];
  bool _isExporting = false;
  
  Map<String, List<String>> _savedCombinations = {};
  String? _selectedCombinationName;

  @override
  void initState() {
    super.initState();
    _dataFuture = _firestore.getAllCachedFirst();
    _loadSavedCombinations();
  }

  Future<void> _loadSavedCombinations() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('saved_custom_groups');
    if (data != null) {
      final decoded = json.decode(data) as Map<String, dynamic>;
      setState(() {
        _savedCombinations = decoded.map((key, value) => MapEntry(key, List<String>.from(value)));
      });
    }
  }

  Future<void> _saveCurrentCombination(String name) async {
    if (name.isEmpty || _selectedGroups.isEmpty) return;
    
    _savedCombinations[name] = List.from(_selectedGroups);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_custom_groups', json.encode(_savedCombinations));
    
    setState(() {
      _selectedCombinationName = name;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ التسمية "$name" بنجاح')));
    }
  }

  Future<void> _deleteCombination(String name) async {
    _savedCombinations.remove(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_custom_groups', json.encode(_savedCombinations));
    
    setState(() {
      if (_selectedCombinationName == name) {
        _selectedCombinationName = null;
        _selectedGroups.clear();
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف التسمية "$name" بنجاح')));
    }
  }

  Future<void> _showSaveDialog() async {
    if (_selectedGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار المجموعات أولاً')));
      return;
    }
    
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حفظ التسمية'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'اسم المجموعة المخصصة (مثال: جدول سنة أولى)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    ).then((result) {
      if (result != null && result is String && result.isNotEmpty) {
        _saveCurrentCombination(result);
      }
    });
  }

  List<String> _extractAllGroups(List<TimetableEntry> all) {
    final groups = <String>{};
    for (final e in all) {
      for (final g in e.studentSets) {
        if (g.trim().isNotEmpty) {
          groups.add(g.trim());
        }
      }
    }
    return groups.toList()..sort((a, b) => a.compareTo(b));
  }

  int _levelRank(String groupName) {
    if (groupName.contains('اول')) return 1;
    if (groupName.contains('ثاني') || groupName.contains('تاني')) return 2;
    if (groupName.contains('ثالث')) return 3;
    if (groupName.contains('رابع')) return 4;
    if (groupName.contains('خامس')) return 5;
    return 99;
  }

  (List<TimetableEntry>, List<String>) _filteredData(List<TimetableEntry> all) {
    if (_selectedGroups.isEmpty) return ([], []);

    final matchedEntries = <TimetableEntry>[];

    for (final e in all) {
      bool entryMatches = false;
      for (final s in e.studentSets) {
        if (s.trim().isNotEmpty) {
          if (_selectedGroups.contains(s.trim())) {
            entryMatches = true;
          }
        }
      }
      if (entryMatches) {
        matchedEntries.add(e);
      }
    }

    final sortedSelectedGroups = List<String>.from(_selectedGroups)..sort((a, b) {
      final rankA = _levelRank(a);
      final rankB = _levelRank(b);
      if (rankA != rankB) return rankA.compareTo(rankB);
      return a.compareTo(b);
    });
    
    return (matchedEntries, sortedSelectedGroups);
  }

  Future<void> _showMultiSelect(BuildContext context, List<String> allGroups) async {
    final List<String> tempSelected = List.from(_selectedGroups);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('اختيار المجموعات'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allGroups.length,
                  itemBuilder: (context, index) {
                    final group = allGroups[index];
                    return CheckboxListTile(
                      title: Text(group),
                      value: tempSelected.contains(group),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            tempSelected.add(group);
                          } else {
                            tempSelected.remove(group);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, tempSelected);
                  },
                  child: const Text('موافق'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result != null) {
        setState(() {
          _selectedGroups = result as List<String>;
          _selectedCombinationName = null;
        });
      }
    });
  }

  Future<void> _exportSchedule(List<TimetableEntry> all) async {
    if (_selectedGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار المجموعات أولاً')));
      return;
    }

    setState(() => _isExporting = true);

    try {
      final (filtered, matchedSets) = _filteredData(all);
      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد بيانات للمجموعات المحددة')));
        return;
      }

      final days = TimetableScheduleGrid.sortedDays(filtered.map((e) => e.day));
      final hours = TimetableScheduleGrid.sortedHours(filtered.map((e) => e.hour));

      final headers = ['اليوم', 'المجموعة', ...hours];
      final dataRows = <List<String>>[];

      for (final day in days) {
        for (int gIdx = 0; gIdx < matchedSets.length; gIdx++) {
          final group = matchedSets[gIdx];
          final row = <String>[];
          
          row.add(gIdx == 0 ? day : '');
          row.add(group);

          for (final hour in hours) {
            final cellEntries = filtered.where((e) => e.day == day && e.hour == hour && e.studentSets.contains(group)).toList();
            if (cellEntries.isEmpty) {
              row.add('');
            } else {
              final cellText = cellEntries.map((e) => '${e.subject}\n${e.teachers.join(", ")}\n${e.room}').join('\n---\n');
              row.add(cellText);
            }
          }
          dataRows.add(row);
        }
      }

      final service = ExcelExportService();
      await service.exportTable(
        fileName: _selectedCombinationName != null 
            ? 'جدول_${_selectedCombinationName!.replaceAll(' ', '_')}'
            : 'جدول_مخصص_مجموعات',
        title: _selectedCombinationName != null 
            ? 'الكلية - جدول مخصص: $_selectedCombinationName'
            : 'الكلية - جدول مخصص',
        headers: headers,
        dataRows: dataRows,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصدير الجدول بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الجداول المخصصة'),
      ),
      body: FutureBuilder<List<TimetableEntry>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا توجد بيانات للعرض'));
          }
          
          final all = snapshot.data!;
          final allGroups = _extractAllGroups(all);
          
          final (filteredEntries, matchedSets) = _filteredData(all);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'تحديد المجموعات لإنشاء الجدول',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showMultiSelect(context, allGroups),
                                  icon: const Icon(Icons.playlist_add_check),
                                  label: Text(
                                    _selectedGroups.isEmpty
                                        ? 'اختر المجموعات بشكل يدوي...'
                                        : 'تعديل الاختيار (${_selectedGroups.length})',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                onPressed: _selectedGroups.isEmpty ? null : _showSaveDialog,
                                icon: const Icon(Icons.save),
                                tooltip: 'حفظ المجموعات المحددة حالياً بتسمية جديدة',
                              ),
                            ],
                          ),
                          if (_savedCombinations.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text('أو اختر من التسميات المحفوظة سابقاً:'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _savedCombinations.keys.map((name) {
                                final isSelected = _selectedCombinationName == name;
                                return InputChip(
                                  label: Text(name),
                                  selected: isSelected,
                                  onSelected: (bool selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedCombinationName = name;
                                        _selectedGroups = List.from(_savedCombinations[name]!);
                                      } else {
                                        _selectedCombinationName = null;
                                        _selectedGroups.clear();
                                      }
                                    });
                                  },
                                  onDeleted: () => _deleteCombination(name),
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                  deleteButtonTooltipMessage: 'حذف هذه التسمية',
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 26),
                      child: IconButton.filled(
                        onPressed: _isExporting || _selectedGroups.isEmpty ? null : () => _exportSchedule(all),
                        icon: _isExporting 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.download),
                        tooltip: 'تصدير كملف إكسل',
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: filteredEntries.isEmpty
                      ? const Center(child: Text('اختر مجموعات لعرض الجدول'))
                      : DepartmentDataTable(
                          entries: filteredEntries,
                          groups: matchedSets,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
