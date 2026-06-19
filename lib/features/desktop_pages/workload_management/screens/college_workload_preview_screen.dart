import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:flutter/material.dart';

import '../services/college_workload_submission_service.dart';
import '../services/incentive_word_export_service.dart';

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
  State<CollegeWorkloadPreviewScreen> createState() =>
      _CollegeWorkloadPreviewScreenState();
}

class _CollegeWorkloadPreviewScreenState
    extends State<CollegeWorkloadPreviewScreen> {
  final _service = CollegeWorkloadSubmissionService();
  final _wordExport = IncentiveWordExportService();

  bool _isProcessing = false;
  final Set<String> _exportingTeachers = {};

  String get statusText {
    switch (widget.submission.status) {
      case 'pending_dean':
        return 'بانتظار اعتماد العميد';
      case 'pending_vice_chancellor':
        return 'بانتظار اعتماد النيابة';
      case 'approved':
        return 'تم الاعتماد النهائي';
      case 'rejected':
        return 'مرفوض';
      default:
        return widget.submission.status;
    }
  }

  Color get statusColor {
    switch (widget.submission.status) {
      case 'pending_dean':
      case 'pending_vice_chancellor':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة النصاب المحسوب'),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeaderCard(),
                Expanded(child: _buildTeachersList()),
                if (widget.canApprove) _buildActionsBar(),
              ],
            ),
    );
  }

  Widget _buildHeaderCard() {
    // Unique teachers list
    final teachers = widget.submission.entries
        .map((e) => e.teacherName.trim())
        .toSet()
        .toList();

    return Card(
      margin: const EdgeInsets.all(DesktopSpacing.lg),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(DesktopSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: DesktopColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'تفاصيل النصاب المحسوب',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(statusText,
                      style: TextStyle(
                          color: statusColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                _infoChip(
                    Icons.school_outlined, 'الكلية', widget.submission.collegeName),
                const SizedBox(width: 16),
                _infoChip(
                    Icons.calendar_today_outlined,
                    'الفصل',
                    widget.submission.term == 'first'
                        ? 'الفصل الأول'
                        : 'الفصل الثاني'),
                const SizedBox(width: 16),
                _infoChip(
                    Icons.people_outline,
                    'عدد المعلمين',
                    '${teachers.length} معلم'),
              ],
            ),
            if (widget.submission.rejectionReason != null &&
                widget.submission.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سبب الرفض: ${widget.submission.rejectionReason}',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text('$label: ',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildTeachersList() {
    if (widget.submission.entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('لا توجد بيانات معلمين في هذا الطلب',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // نستخرج المعلمين مع بياناتهم الأولية للعرض
    final teachersMap = <String, Map<String, dynamic>>{};
    for (final entry in widget.submission.entries) {
      final name = entry.teacherName.trim();
      if (!teachersMap.containsKey(name)) {
        teachersMap[name] = {
          'name': name,
          'totalTheory': 0.0,
          'totalPractical': 0.0,
          'totalSupervision': 0.0,
        };
      }
      teachersMap[name]!['totalTheory'] += entry.theoryHours;
      teachersMap[name]!['totalPractical'] += entry.practicalHours;
      teachersMap[name]!['totalSupervision'] += entry.supervisionHours;
    }

    final teachers = teachersMap.values.toList()
      ..sort((a, b) => a['name'].compareTo(b['name']));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: DesktopSpacing.lg),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.people, color: DesktopColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'قائمة المعلمين المشمولين في النصاب المحسوب',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  'اضغط على زر التصدير لتنزيل كشف Word لأي معلم',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: teachers.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final teacher = teachers[index];
                final teacherName = teacher['name'] as String;
                final isExporting = _exportingTeachers.contains(teacherName);
                
                final theory = (teacher['totalTheory'] as double).toStringAsFixed(1);
                final practical = (teacher['totalPractical'] as double).toStringAsFixed(1);
                final supervision = (teacher['totalSupervision'] as double).toStringAsFixed(1);
                final total = ((teacher['totalTheory'] as double) + 
                              (teacher['totalPractical'] as double) + 
                              (teacher['totalSupervision'] as double)).toStringAsFixed(1);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: DesktopColors.primary.withOpacity(0.1),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                          color: DesktopColors.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    teacherName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'نظري: $theory | عملي: $practical | إشراف: $supervision | الإجمالي: $total ساعة',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  trailing: isExporting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => _exportTeacherWord(teacherName),
                          icon: const Icon(Icons.file_download, size: 16),
                          label: const Text('تصدير Word',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsBar() {
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
            onPressed: _reject,
            icon: const Icon(Icons.close),
            label: const Text('رفض الطلب'),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: _approve,
            icon: const Icon(Icons.check),
            label: Text(widget.isFinalApproval ? 'اعتماد نهائي' : 'اعتماد ورفع للنيابة'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTeacherWord(String teacherName) async {
    setState(() => _exportingTeachers.add(teacherName));
    try {
      await _wordExport.exportTeacherNasab(
        teacherName: teacherName,
        entries: widget.submission.entries,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير كشف $teacherName بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التصدير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingTeachers.remove(teacherName));
    }
  }

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    try {
      if (widget.isFinalApproval) {
        await _service.approveByDeanship(widget.submission.id);
      } else {
        await _service.approveByDean(widget.submission.id);
      }
      widget.onStatusChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم اعتماد الطلب بنجاح')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'اكتب سبب الرفض هنا...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      if (widget.isFinalApproval) {
        await _service.rejectByDeanship(widget.submission.id, reason);
      } else {
        await _service.rejectByDean(widget.submission.id, reason);
      }
      widget.onStatusChanged();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم رفض الطلب')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
