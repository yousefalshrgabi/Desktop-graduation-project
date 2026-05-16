import 'package:flutter/material.dart';

import '../models/timetable_entry.dart';
import '../services/timetable_firestore_service.dart';
import '../services/excel_export_service.dart';
import '../utils/timetable_schedule_grid.dart';
import '../widgets/department_data_table.dart';

class DepartmentScheduleScreen extends StatefulWidget {
  const DepartmentScheduleScreen({super.key});

  @override
  State<DepartmentScheduleScreen> createState() => _DepartmentScheduleScreenState();
}

class _DepartmentScheduleScreenState extends State<DepartmentScheduleScreen> {
  final TimetableFirestoreService _firestore = TimetableFirestoreService();
  late final Future<List<TimetableEntry>> _dataFuture;
  String? _searchQuery;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _firestore.getAllCachedFirst();
  }

  List<String> _extractSpecializations(List<TimetableEntry> all) {
    final specs = <String>{};
    for (final e in all) {
      for (final g in e.studentSets) {
        if (g.trim().isNotEmpty) {
          final parts = g.split('-');
          specs.add(parts.first.trim());
        }
      }
    }
    return specs.toList()..sort((a, b) => a.compareTo(b));
  }

  int _levelRank(String groupName) {
    if (groupName.contains('اول')) return 1;
    if (groupName.contains('ثاني') || groupName.contains('تاني')) return 2;
    if (groupName.contains('ثالث')) return 3;
    if (groupName.contains('رابع')) return 4;
    if (groupName.contains('خامس')) return 5;
    return 99;
  }

  (List<TimetableEntry>, List<String>) _filteredData(String? specQuery, List<TimetableEntry> all) {
    if (specQuery == null || specQuery.isEmpty) return ([], []);

    final matchedSets = <String>{};
    final matchedEntries = <TimetableEntry>[];

    for (final e in all) {
      bool entryMatches = false;
      for (final s in e.studentSets) {
        if (s.trim().isNotEmpty) {
          final sSpec = s.split('-').first.trim();
          if (sSpec == specQuery) {
            matchedSets.add(s);
            entryMatches = true;
          }
        }
      }
      if (entryMatches) {
        matchedEntries.add(e);
      }
    }

    final sortedMatchedSets = matchedSets.toList()..sort((a, b) {
      final rankA = _levelRank(a);
      final rankB = _levelRank(b);
      if (rankA != rankB) return rankA.compareTo(rankB);
      return a.compareTo(b);
    });
    return (matchedEntries, sortedMatchedSets);
  }

  Future<void> _exportSchedule(List<TimetableEntry> all) async {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار التخصص أولاً')));
      return;
    }
    setState(() => _isExporting = true);
    try {
      final (filtered, matchedSets) = _filteredData(_searchQuery, all);
      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد بيانات لهذا التخصص')));
        return;
      }

      final days = TimetableScheduleGrid.sortedDays(filtered.map((e) => e.day));
      final hours = TimetableScheduleGrid.sortedHours(filtered.map((e) => e.hour));
      final headers = ['اليوم', 'المستوى/القسم', ...hours];
      final dataRows = <List<String>>[];

      for (final day in days) {
        for (int gIdx = 0; gIdx < matchedSets.length; gIdx++) {
          final group = matchedSets[gIdx];
          final row = <String>[];
          row.add(gIdx == 0 ? day : '');
          row.add(group);
          for (final hour in hours) {
            final cellEntries = filtered.where((e) => e.day == day && e.hour == hour && e.studentSets.contains(group)).toList();
            row.add(cellEntries.isEmpty ? '' : cellEntries.map((e) => '${e.subject}\n${e.teachers.join(", ")}\n${e.room}').join('\n---\n'));
          }
          dataRows.add(row);
        }
      }

      await ExcelExportService().exportTable(
        fileName: 'جدول_تخصص_$_searchQuery',
        title: 'جدول تخصص: $_searchQuery',
        headers: headers,
        dataRows: dataRows,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصدير الجدول بنجاح')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TimetableEntry>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('لا توجد بيانات. يرجى رفع ملف الجدول أولاً.'));
        }
        final all = snapshot.data!;
        final specializations = _extractSpecializations(all);
        final (filteredEntries, matchedSets) = _filteredData(_searchQuery, all);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _searchQuery != null && specializations.contains(_searchQuery) ? _searchQuery : null,
                      decoration: const InputDecoration(
                        labelText: 'اختر القسم / التخصص',
                        hintText: 'مثال: تقنية المعلومات',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: specializations.map((spec) => DropdownMenuItem(value: spec, child: Text(spec))).toList(),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: IconButton.filled(
                      onPressed: _isExporting || _searchQuery == null ? null : () => _exportSchedule(all),
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
                child: DepartmentDataTable(entries: filteredEntries, groups: matchedSets),
              ),
            ),
          ],
        );
      },
    );
  }
}
