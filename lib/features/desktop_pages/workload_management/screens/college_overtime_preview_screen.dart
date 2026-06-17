import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:flutter/material.dart';
import '../models/college_overtime_submission.dart';
import '../services/college_overtime_submission_service.dart';

class CollegeOvertimePreviewScreen extends StatefulWidget {
  const CollegeOvertimePreviewScreen({super.key, required this.submission});

  final CollegeOvertimeSubmission submission;

  @override
  State<CollegeOvertimePreviewScreen> createState() => _CollegeOvertimePreviewScreenState();
}

class _CollegeOvertimePreviewScreenState extends State<CollegeOvertimePreviewScreen> {
  final _service = CollegeOvertimeSubmissionService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final typeName = widget.submission.type == 'overtime' ? 'الساعات الزائدة' : 'الساعات الموازية';
    
    return Scaffold(
      appBar: AppBar(
        title: Text('معاينة كشوفات $typeName'),
        actions: [
          IconButton(
            tooltip: 'تصدير كشف مجمع (قيد التطوير)',
            icon: const Icon(Icons.file_download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ميزة التصدير قيد التطوير')));
            },
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeaderCard(),
                Expanded(child: _buildDetailsTable()),
                if (widget.submission.status == 'pending_dean') _buildDeanActions(),
              ],
            ),
    );
  }

  Widget _buildHeaderCard() {
    final typeName = widget.submission.type == 'overtime' ? 'الساعات الزائدة' : 'الساعات الموازية';
    return Card(
      margin: const EdgeInsets.all(DesktopSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(DesktopSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: DesktopColors.primary),
                const SizedBox(width: 8),
                Text('تفاصيل طلب $typeName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(child: Text('الكلية: ${widget.submission.collegeName}')),
                Expanded(child: Text('الفصل: ${widget.submission.term == 'first' ? 'الأول' : 'الثاني'}')),
                Expanded(
                  child: Text(
                    'إجمالي المعلمين: ${widget.submission.entries.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'إجمالي الساعات: ${widget.submission.entries.fold<double>(0, (sum, e) => sum + (e['totalHours'] as num).toDouble())}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTable() {
    if (widget.submission.entries.isEmpty) {
      return const Center(child: Text('لا توجد تفاصيل للمعلمين'));
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: DesktopSpacing.lg),
      child: ListView(
        padding: const EdgeInsets.all(DesktopSpacing.md),
        children: [
          DataTable(
            columns: const [
              DataColumn(label: Text('م', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('اسم المعلم', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('إجمالي الساعات المستحقة', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: List.generate(widget.submission.entries.length, (index) {
              final entry = widget.submission.entries[index];
              return DataRow(cells: [
                DataCell(Text('${index + 1}')),
                DataCell(Text(entry['teacherName'] ?? 'غير معروف')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '${entry['totalHours']}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ]);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDeanActions() {
    final session = AppSession();
    final isDean = session.isDean && widget.submission.status == 'pending_dean';
    final isDeanship = session.isAdminOrDeanship && widget.submission.status == 'pending_vice_chancellor';

    if (!isDean && !isDeanship) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(DesktopSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('رجوع'),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _handleReject(isDeanship),
            icon: const Icon(Icons.close),
            label: const Text('رفض الطلب'),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => _handleApprove(isDeanship),
            icon: const Icon(Icons.check),
            label: Text(isDeanship ? 'اعتماد نهائي' : 'اعتماد ورفع للنيابة'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(bool isDeanship) async {
    setState(() => _isProcessing = true);
    try {
      if (isDeanship) {
        await _service.approveByDeanship(widget.submission.id);
      } else {
        await _service.approveByDean(widget.submission.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اعتماد الطلب بنجاح')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject(bool isDeanship) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'اكتب سبب الرفض هنا...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );

    if (confirm != true || reasonController.text.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      if (isDeanship) {
        await _service.rejectByDeanship(widget.submission.id, reasonController.text.trim());
      } else {
        await _service.rejectByDean(widget.submission.id, reasonController.text.trim());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الطلب')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
