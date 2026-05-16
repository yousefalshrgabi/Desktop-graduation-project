import 'package:flutter/material.dart';

import '../models/timetable_entry.dart';
import '../services/timetable_firestore_service.dart';
import '../services/excel_export_service.dart';
import '../utils/timetable_schedule_grid.dart';
import '../widgets/timetable_data_table.dart';

class TeachersScheduleScreen extends StatefulWidget {
  const TeachersScheduleScreen({super.key});

  @override
  State<TeachersScheduleScreen> createState() => _TeachersScheduleScreenState();
}

class _TeachersScheduleScreenState extends State<TeachersScheduleScreen> {
  final TimetableFirestoreService _firestore = TimetableFirestoreService();
  late final Future<List<TimetableEntry>> _dataFuture;
  String? _searchQuery;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _firestore.getAllCachedFirst();
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
    return all
        .where((e) => e.teachers
            .any((t) => t.toLowerCase().contains(query.trim().toLowerCase())))
        .toList();
  }

  Future<void> _exportSchedule(List<TimetableEntry> all) async {
    if (_searchQuery == null) return;
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
          row.add(entries.isEmpty
              ? ''
              : entries
                  .map((e) =>
                      '${e.subject}\n${e.studentSets.join(", ")}\n${e.room}')
                  .join('\n---\n'));
        }
        dataRows.add(row);
      }

      await ExcelExportService().exportTable(
        fileName: 'جدول_المعلم_$_searchQuery',
        title: 'جدول المعلم: $_searchQuery',
        headers: headers,
        dataRows: dataRows,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تصدير الجدول بنجاح')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TimetableEntry>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('خطأ: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const Center(
              child: Text('لا توجد بيانات. يرجى رفع ملف الجدول أولاً.'));

        final all = snapshot.data!;
        final teachers = _uniqueTeachers(all);
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
                    child: DropdownButtonFormField<String>(
                      value: _searchQuery != null &&
                              teachers.contains(_searchQuery)
                          ? _searchQuery
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'اختر المعلم',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: teachers
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) => setState(() => _searchQuery = val),
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
                    showTeachers: false,
                    showStudentSets: true,
                    showRoom: true),
              ),
            ),
          ],
        );
      },
    );
  }
}
