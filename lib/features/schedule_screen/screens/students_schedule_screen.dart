import 'package:flutter/material.dart';

import '../models/timetable_entry.dart';
import '../services/timetable_firestore_service.dart';
import '../services/excel_export_service.dart';
import '../utils/timetable_schedule_grid.dart';
import '../widgets/timetable_data_table.dart';

class StudentsScheduleScreen extends StatefulWidget {
  const StudentsScheduleScreen({super.key, this.collegeName});

  final String? collegeName;

  @override
  State<StudentsScheduleScreen> createState() => _StudentsScheduleScreenState();
}

class _StudentsScheduleScreenState extends State<StudentsScheduleScreen> {
  final TimetableFirestoreService _firestore = TimetableFirestoreService();
  late final Future<List<TimetableEntry>> _dataFuture;
  String? _searchQuery;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = widget.collegeName == null
        ? _firestore.getAllCachedFirst()
        : _firestore.getByCollegeCachedFirst(widget.collegeName!);
  }

  List<String> _uniqueGroups(List<TimetableEntry> all) {
    final set = <String>{};
    for (final e in all) {
      for (final s in e.studentSets) {
        if (s.trim().isNotEmpty) set.add(s.trim());
      }
    }
    return set.toList()..sort((a, b) => a.compareTo(b));
  }

  List<TimetableEntry> _filteredData(String? query, List<TimetableEntry> all) {
    if (query == null || query.isEmpty) return [];
    final q = query.trim().toLowerCase();
    return all.where((e) {
      return e.studentSets.any((s) => s.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _exportSchedule(List<TimetableEntry> all) async {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار المجموعة أولاً')));
      return;
    }

    setState(() => _isExporting = true);

    try {
      final filtered = _filteredData(_searchQuery, all);
      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد بيانات لهذه المجموعة')));
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
                .map((e) => '${e.subject}\n${e.teachers.join(", ")}\n${e.room}')
                .join('\n---\n');
            row.add(cellText);
          }
        }
        dataRows.add(row);
      }

      final service = ExcelExportService();
      await service.exportTable(
        fileName: 'جدول_الطلاب_$_searchQuery',
        title: 'الكلية - جدول الطلاب: $_searchQuery',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جدول الطلاب'),
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
            return Center(
              child: Text(
                widget.collegeName == null
                    ? 'لا توجد بيانات للعرض'
                    : 'عذراً، لم يتم رفع جداول ${widget.collegeName} من قبل النائب الأكاديمي بعد',
                textAlign: TextAlign.center,
              ),
            );
          }
          final all = snapshot.data!;
          final groups = _uniqueGroups(all);

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
                            'اختر المجموعة / الدفعة',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _searchQuery != null &&
                                    groups.contains(_searchQuery)
                                ? _searchQuery
                                : null,
                            decoration: const InputDecoration(
                              hintText: 'اختر مجموعة أو دفعة من القائمة...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            items: groups.map((t) {
                              return DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: IconButton.filled(
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
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: TimetableDataTable(
                    entries: filtered,
                    showTeachers: true,
                    showStudentSets: false,
                    showRoom: true,
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
