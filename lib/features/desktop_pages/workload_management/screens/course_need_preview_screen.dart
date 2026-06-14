import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';

import '../services/course_need_letter_service.dart';

class CourseNeedPreviewScreen extends StatefulWidget {
  const CourseNeedPreviewScreen({
    super.key,
    required this.collegeName,
    required this.term,
    required this.data,
  });

  final String collegeName;
  final String term;
  final CourseNeedLetterData data;

  @override
  State<CourseNeedPreviewScreen> createState() =>
      _CourseNeedPreviewScreenState();
}

class _CourseNeedPreviewScreenState extends State<CourseNeedPreviewScreen> {
  final _letterService = CourseNeedLetterService();
  bool _exporting = false;
  bool _uploading = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await _letterService.exportLetter(
        collegeName: widget.collegeName,
        term: widget.term,
        data: widget.data,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ خطاب مقررات الاحتياج بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ خطاب مقررات الاحتياج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _uploadForDean() async {
    setState(() => _uploading = true);
    try {
      await _letterService.uploadForDean(
        collegeName: widget.collegeName,
        term: widget.term,
        data: widget.data,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع مقررات الاحتياج للعميد بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر رفع مقررات الاحتياج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalTheory =
        widget.data.theoryRows.fold<int>(0, (sum, row) => sum + row.hours);
    final totalPractical =
        widget.data.practicalRows.fold<int>(0, (sum, row) => sum + row.hours);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: SharedDesktopAppBar(
          customTitle: 'مقررات الاحتياج',
          extraActions: [
            FilledButton.tonalIcon(
              onPressed:
                  _uploading || widget.data.isEmpty ? null : _uploadForDean,
              icon: _uploading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: const Text('رفع للعميد'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.description_outlined),
              label: const Text('حفظ الخطاب'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: widget.data.isEmpty
            ? const Center(
                child: Text(
                  'لا توجد مقررات احتياج.\nكل المقررات المطلوبة لها مدرسون محددون.',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Summary(
                    theoryCount: widget.data.theoryRows.length,
                    practicalCount: widget.data.practicalRows.length,
                    theoryHours: totalTheory,
                    practicalHours: totalPractical,
                  ),
                  const SizedBox(height: 16),
                  _NeedTable(
                    title: 'كشف بالمقررات النظرية',
                    rows: widget.data.theoryRows,
                    totalHours: totalTheory,
                  ),
                  const SizedBox(height: 20),
                  _NeedTable(
                    title: 'كشف بالمقررات العملية',
                    rows: widget.data.practicalRows,
                    totalHours: totalPractical,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.theoryCount,
    required this.practicalCount,
    required this.theoryHours,
    required this.practicalHours,
  });

  final int theoryCount;
  final int practicalCount;
  final int theoryHours;
  final int practicalHours;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(label: Text('مقررات نظري: $theoryCount')),
        Chip(label: Text('ساعات نظري: $theoryHours')),
        Chip(label: Text('مقررات عملي: $practicalCount')),
        Chip(label: Text('ساعات عملي: $practicalHours')),
      ],
    );
  }
}

class _NeedTable extends StatelessWidget {
  const _NeedTable({
    required this.title,
    required this.rows,
    required this.totalHours,
  });

  final String title;
  final List<CourseNeedRow> rows;
  final int totalHours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('لا توجد بيانات')),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('المقرر')),
                DataColumn(label: Text('عدد ساعات الاحتياج')),
                DataColumn(label: Text('القسم العلمي')),
                DataColumn(label: Text('المستوى')),
              ],
              rows: [
                ...rows.map(
                  (row) => DataRow(
                    cells: [
                      DataCell(Text(row.courseName)),
                      DataCell(Text(row.hours.toString())),
                      DataCell(Text(row.department)),
                      DataCell(Text(_levelText(row.level))),
                    ],
                  ),
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('الإجمالي')),
                    DataCell(Text('$totalHours ساعة')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _levelText(int level) {
    switch (level) {
      case 1:
        return 'الأول';
      case 2:
        return 'الثاني';
      case 3:
        return 'الثالث';
      case 4:
        return 'الرابع';
      default:
        return level.toString();
    }
  }
}
