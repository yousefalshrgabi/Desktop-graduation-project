import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import '../services/college_workload_submission_service.dart';
import '../widgets/incentive_data_table.dart';

class CollegeWorkloadPreviewScreen extends StatefulWidget {
  const CollegeWorkloadPreviewScreen({
    super.key,
    required this.submission,
    required this.onStatusChanged,
    this.canApprove = false,
    this.isFinalApproval = false,
  });

  final CollegeWorkloadSubmission submission;
  final VoidCallback onStatusChanged;
  final bool canApprove;
  final bool isFinalApproval;

  @override
  State<CollegeWorkloadPreviewScreen> createState() => _CollegeWorkloadPreviewScreenState();
}

class _CollegeWorkloadPreviewScreenState extends State<CollegeWorkloadPreviewScreen> {
  final _service = CollegeWorkloadSubmissionService();
  bool _processing = false;

  String get statusText {
    switch (widget.submission.status) {
      case 'pending_dean': return 'قيد المراجعة (العميد)';
      case 'pending_vice_chancellor': return 'قيد المراجعة (النيابة)';
      case 'approved': return 'معتمد';
      case 'rejected': return 'مرفوض';
      default: return widget.submission.status;
    }
  }

  Color get statusColor {
    switch (widget.submission.status) {
      case 'pending_dean':
      case 'pending_vice_chancellor':
        return Colors.orange;
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _approve() async {
    setState(() => _processing = true);
    try {
      if (widget.isFinalApproval) {
        await _service.approveByDeanship(widget.submission.id);
      } else {
        await _service.approveByDean(widget.submission.id);
      }
      widget.onStatusChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _processing = true);
    try {
      if (widget.isFinalApproval) {
        await _service.rejectByDeanship(widget.submission.id, reason);
      } else {
        await _service.rejectByDean(widget.submission.id, reason);
      }
      widget.onStatusChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalTheory = widget.submission.entries.fold<double>(0, (s, e) => s + e.theoryHours);
    final totalPractical = widget.submission.entries.fold<double>(0, (s, e) => s + e.practicalHours);
    final totalSupervision = widget.submission.entries.fold<double>(0, (s, e) => s + e.supervisionHours);

    return Scaffold(
      appBar: AppBar(
        title: Text('اعتماد النصاب المحسوب - ${widget.submission.collegeName} (الفصل ${widget.submission.term == 'first' ? 'الأول' : 'الثاني'})'),
        backgroundColor: DesktopColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إجمالي السجلات: ${widget.submission.entries.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('ساعات (نظري: ${totalTheory.toStringAsFixed(1)} | عملي: ${totalPractical.toStringAsFixed(1)} | إشراف: ${totalSupervision.toStringAsFixed(1)})'),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor)),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                ),
                if (widget.canApprove) ...[
                  const SizedBox(width: 16),
                  if (_processing)
                    const CircularProgressIndicator()
                  else ...[
                    FilledButton.icon(
                      onPressed: _reject,
                      icon: const Icon(Icons.close),
                      label: const Text('رفض'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.check),
                      label: const Text('اعتماد'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (widget.submission.rejectionReason != null && widget.submission.rejectionReason!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Text('سبب الرفض: ${widget.submission.rejectionReason}', style: TextStyle(color: Colors.red.shade900)),
            ),
          Expanded(
            child: widget.submission.entries.isEmpty
                ? const Center(child: Text('لا توجد بيانات'))
                : IncentiveDataTable(
                    entries: widget.submission.entries,
                    sourceDepartmentHeader: 'قسم المدرس',
                  ),
          ),
        ],
      ),
    );
  }
}
