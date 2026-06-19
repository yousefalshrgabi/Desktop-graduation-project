import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/features/schedule_screen/services/timetable_firestore_service.dart';
import 'package:flutter/material.dart';
import '../models/college_overtime_submission.dart';
import '../services/college_overtime_submission_service.dart';
import '../services/overtime_hours_excel_export_service.dart';

class CollegeOvertimePreviewScreen extends StatefulWidget {
  const CollegeOvertimePreviewScreen({super.key, required this.submission});

  final CollegeOvertimeSubmission submission;

  @override
  State<CollegeOvertimePreviewScreen> createState() =>
      _CollegeOvertimePreviewScreenState();
}

class _CollegeOvertimePreviewScreenState
    extends State<CollegeOvertimePreviewScreen> {
  final _service = CollegeOvertimeSubmissionService();
  final _timetableService = TimetableFirestoreService();
  final _exportService = OvertimeHoursExcelExportService();

  bool _isProcessing = false;

  // تتبع أي معلم يجري تصديره حالياً
  final Set<String> _exportingTeachers = {};

  @override
  Widget build(BuildContext context) {
    final typeName = widget.submission.type == 'overtime'
        ? 'الساعات الزائدة'
        : 'الساعات الموازية';

    return Scaffold(
      appBar: AppBar(
        title: Text('معاينة كشوفات $typeName'),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeaderCard(),
                Expanded(child: _buildTeachersList()),
                _buildActionsBar(),
              ],
            ),
    );
  }

  Widget _buildHeaderCard() {
    final typeName = widget.submission.type == 'overtime'
        ? 'الساعات الزائدة'
        : 'الساعات الموازية';
    String statusText;
    Color statusColor;
    switch (widget.submission.status) {
      case 'pending_dean':
        statusText = 'بانتظار اعتماد العميد';
        statusColor = Colors.orange;
        break;
      case 'pending_vice_chancellor':
        statusText = 'بانتظار اعتماد النيابة';
        statusColor = Colors.blue;
        break;
      case 'approved':
        statusText = 'تم الاعتماد النهائي';
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusText = 'مرفوض';
        statusColor = Colors.red;
        break;
      default:
        statusText = widget.submission.status;
        statusColor = Colors.grey;
    }

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
                Text(
                  'تفاصيل طلب $typeName',
                  style: const TextStyle(
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
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _infoChip(
                    Icons.school_outlined, 'الكلية', widget.submission.collegeName),
                _infoChip(
                    Icons.calendar_today_outlined,
                    'الفصل',
                    widget.submission.term == 'first'
                        ? 'الفصل الأول'
                        : 'الفصل الثاني'),
                _infoChip(
                    Icons.people_outline,
                    'عدد المعلمين',
                    '${widget.submission.entries.length} معلم'),
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
        Text('$label: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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

    final isOvertime = widget.submission.type == 'overtime';
    final typeName = isOvertime ? 'الساعات الزائدة' : 'الساعات الموازية';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: DesktopSpacing.lg),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.people, color: DesktopColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    'قائمة المعلمين المشمولين في كشوفات $typeName',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Text(
                    'تصدير كشف Excel لكل معلم',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.submission.entries.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final entry = widget.submission.entries[index];
                final teacherName =
                    entry['teacherName'] as String? ?? 'غير معروف';
                final isExporting = _exportingTeachers.contains(teacherName);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        DesktopColors.primary.withOpacity(0.1),
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
                    entry['collegeName'] as String? ??
                        widget.submission.collegeName,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                  trailing: isExporting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ElevatedButton.icon(
                          onPressed: () =>
                              _exportTeacherExcel(teacherName, isOvertime),
                          icon: const Icon(Icons.file_download, size: 16),
                          label: const Text('تصدير Excel',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
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
    final session = AppSession();
    final isDean =
        session.isDean && widget.submission.status == 'pending_dean';
    final isDeanship = session.isAdminOrDeanship &&
        widget.submission.status == 'pending_vice_chancellor';

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
          if (isDean || isDeanship) ...[
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
        ],
      ),
    );
  }

  /// تصدير كشف Excel لمعلم واحد عبر جلب جدوله من Firestore
  Future<void> _exportTeacherExcel(
      String teacherName, bool isOvertime) async {
    setState(() => _exportingTeachers.add(teacherName));
    try {
      // جلب جميع إدخالات الجدول الخاص بالكلية
      final allEntries = await _timetableService.getByCollegeCachedFirst(
        widget.submission.collegeName,
      );

      if (isOvertime) {
        await _exportService.exportTeacherOvertimeForm(
          teacherName: teacherName,
          entries: allEntries,
          collegeName: widget.submission.collegeName,
          term: widget.submission.term,
          graduationProjectScheduleType: 'عام',
        );
      } else {
        // للساعات الموازية: نمرر نفس القائمة كـ parallelEntries
        await _exportService.exportTeacherParallelHoursForm(
          teacherName: teacherName,
          entries: allEntries,
          parallelEntries: allEntries,
          collegeName: widget.submission.collegeName,
          term: widget.submission.term,
        );
      }

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

  Future<void> _handleApprove(bool isDeanship) async {
    setState(() => _isProcessing = true);
    try {
      if (isDeanship) {
        await _service.approveByDeanship(widget.submission.id);
      } else {
        await _service.approveByDean(widget.submission.id);
      }
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

  Future<void> _handleReject(bool isDeanship) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(
          controller: reasonController,
          decoration:
              const InputDecoration(hintText: 'اكتب سبب الرفض هنا...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
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
        await _service.rejectByDeanship(
            widget.submission.id, reasonController.text.trim());
      } else {
        await _service.rejectByDean(
            widget.submission.id, reasonController.text.trim());
      }
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
