import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';

import '../services/course_need_letter_service.dart';

class CourseNeedPreviewScreen extends StatefulWidget {
  const CourseNeedPreviewScreen({
    super.key,
    required this.collegeName,
    required this.term,
    required this.data,
    this.savedLetter,
  });

  final String collegeName;
  final String term;
  final CourseNeedLetterData data;
  final SavedCourseNeedLetter? savedLetter;

  @override
  State<CourseNeedPreviewScreen> createState() =>
      _CourseNeedPreviewScreenState();
}

class _CourseNeedPreviewScreenState extends State<CourseNeedPreviewScreen> {
  final _letterService = CourseNeedLetterService();
  final _session = AppSession();
  bool _exporting = false;
  bool _uploading = false;

  Future<void> _updateStatus(String newStatus, {String? reason}) async {
    if (widget.savedLetter == null) return;
    setState(() => _uploading = true);
    try {
      await _letterService.updateStatus(widget.savedLetter!.id, newStatus, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason != null ? 'تم رفض الطلب.' : 'تمت الموافقة على الطلب بنجاح.')),
      );
      Navigator.pop(context); // العودة للشاشة السابقة بعد اتخاذ القرار
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الحالة: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showRejectDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'سبب الرفض (إلزامي)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى كتابة سبب الرفض')),
                );
                return;
              }
              Navigator.pop(ctx);
              _updateStatus(
                _session.isDean ? 'rejected_by_dean' : 'rejected_by_academic_affairs',
                reason: ctrl.text.trim(),
              );
            },
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
  }

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
      Navigator.pop(context); // إغلاق الشاشة بعد الرفع بنجاح
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
            if (widget.savedLetter == null) ...[
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
            ] else ...[
              if (_session.isDean && widget.savedLetter!.status == 'pending_dean') ...[
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade100, foregroundColor: Colors.green.shade900),
                  onPressed: _uploading ? null : () => _updateStatus('pending_academic_affairs'),
                  icon: const Icon(Icons.check),
                  label: const Text('موافقة ورفع للنيابة'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.red.shade900),
                  onPressed: _uploading ? null : _showRejectDialog,
                  icon: const Icon(Icons.close),
                  label: const Text('رفض الطلب'),
                ),
                const SizedBox(width: 8),
              ] else if (_session.isAdminOrDeanship && widget.savedLetter!.status == 'pending_academic_affairs') ...[
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade100, foregroundColor: Colors.green.shade900),
                  onPressed: _uploading ? null : () => _updateStatus('approved'),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('اعتماد نهائي'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.red.shade900),
                  onPressed: _uploading ? null : _showRejectDialog,
                  icon: const Icon(Icons.cancel),
                  label: const Text('رفض نهائي'),
                ),
                const SizedBox(width: 8),
              ],
            ],
            FilledButton.icon(
              onPressed: _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.description_outlined),
              label: const Text('حفظ/تصدير Word'),
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
                  if (widget.savedLetter?.rejectionReason != null && widget.savedLetter!.rejectionReason!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.red.shade900),
                              const SizedBox(width: 8),
                              Text(
                                'سبب الرفض:',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.savedLetter!.rejectionReason!,
                            style: TextStyle(color: Colors.red.shade900),
                          ),
                        ],
                      ),
                    ),
                  ],
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
