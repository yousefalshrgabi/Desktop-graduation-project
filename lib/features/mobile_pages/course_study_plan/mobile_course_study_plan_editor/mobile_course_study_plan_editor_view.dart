import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_session.dart';
import '../../../../core/theme/desktop_theme.dart';
import 'mobile_course_study_plan_editor_view_model.dart';

class MobileCourseStudyPlanEditorView extends StatefulWidget {
  const MobileCourseStudyPlanEditorView({
    super.key,
    required this.facultyDocId,
    required this.facultyName,
    required this.courseId,
    required this.courseName,
    required this.collegeName,
    this.departmentName = '',
    this.studentSets = '',
    this.isReadOnly = false,
  });

  final String facultyDocId;
  final String facultyName;
  final String courseId;
  final String courseName;
  final String collegeName;
  final String departmentName;
  final String studentSets;
  final bool isReadOnly;

  @override
  State<MobileCourseStudyPlanEditorView> createState() =>
      _MobileCourseStudyPlanEditorViewState();
}

class _MobileCourseStudyPlanEditorViewState
    extends State<MobileCourseStudyPlanEditorView> {
  late MobileCourseStudyPlanEditorViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = MobileCourseStudyPlanEditorViewModel(
      facultyDocId: widget.facultyDocId,
      facultyName: widget.facultyName,
      courseId: widget.courseId,
      courseName: widget.courseName,
      collegeName: widget.collegeName,
      departmentName: widget.departmentName,
      studentSets: widget.studentSets,
      isReadOnly: widget.isReadOnly,
    );
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.disposeControllers();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    try {
      await _viewModel.saveDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الخطة التدريسية ومستوى الإنجاز بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر الحفظ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submit() async {
    try {
      await _viewModel.submit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع الخطة التدريسية لاعتماد رئيس القسم.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر الرفع: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _export() async {
    try {
      await _viewModel.export();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ ملف الخطة التدريسية بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ ملف الخطة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateStatus(String newStatus, {String? reason}) async {
    try {
      await _viewModel.updateStatus(newStatus, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason != null ? 'تم رفض الخطة.' : 'تم اعتماد الخطة وتحويلها بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الحالة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _revertToDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الاعتماد للتعديل'),
        content: const Text(
          'إرجاع الخطة للتعديل سيوقف صلاحية تسجيل الإنجاز الأسبوعي، '
          'وسيتطلب إرسال الخطة لاعتمادها من جديد من قِبل الإدارة.\n\nهل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، إرجاع كمسودة'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _viewModel.revertToDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرجاع الخطة إلى مسودة للتعديل بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرجاع الخطة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showRejectDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الخطة'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'سبب الرفض'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              _updateStatus('rejected', reason: ctrl.text.trim());
            },
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalButtons(MobileCourseStudyPlanEditorViewModel vm) {
    final status = vm.submission?.status;
    if (status == null || status == 'approved' || status == 'draft' || status == 'rejected') return const SizedBox.shrink();

    final session = AppSession();
    bool canApprove = false;
    String nextStatus = '';

    if (status == 'pending_dept_head' && session.isDeptHead) {
      canApprove = true;
      nextStatus = 'pending_vice_dean';
    } else if (status == 'pending_vice_dean' && session.isViceDean) {
      canApprove = true;
      nextStatus = 'pending_dean';
    } else if (status == 'pending_dean' && session.isDean) {
      canApprove = true;
      nextStatus = 'pending_academic_affairs';
    } else if (status == 'pending_academic_affairs' && session.isAdminOrDeanship) {
      canApprove = true;
      nextStatus = 'approved';
    }

    if (!canApprove) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
            onPressed: vm.submitting ? null : _showRejectDialog,
            icon: const Icon(Icons.close),
            label: const Text('رفض'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: vm.submitting ? null : () => _updateStatus(nextStatus),
            icon: const Icon(Icons.check),
            label: const Text('اعتماد'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<MobileCourseStudyPlanEditorViewModel>(
        builder: (context, vm, child) {
          final settings = vm.settings;
          final bool canEditText = !widget.isReadOnly &&
              (vm.submission == null || vm.submission!.status == 'draft' || vm.submission!.status == 'rejected');
          final bool canEditProgress = !widget.isReadOnly && (vm.submission != null && vm.submission!.status == 'approved');

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              appBar: AppBar(
                title: Text(widget.courseName),
                backgroundColor: DesktopColors.primary,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    tooltip: 'تحديث',
                    onPressed: vm.loading ? null : () => vm.load(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              body: vm.loading
                  ? const Center(child: CircularProgressIndicator())
                  : settings == null
                      ? const Center(child: Text('تعذر تحميل إعدادات الكليشة.'))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'تحديث إنجاز المقرر',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'قم بتعبئة مواضيع الخطة، ثم أسبوعياً ضع علامة (✅ تم الإنجاز) على الأسابيع التي انتهيت من تدريسها.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    if (vm.submission != null) ...[
                                      const SizedBox(height: 16),
                                      if (vm.submission?.status == 'rejected' && vm.submission?.rejectionReason != null)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 16),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.red.shade200),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.error_outline, color: Colors.red.shade700),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('تم رفض الخطة', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                                                    Text(vm.submission!.rejectionReason!, style: TextStyle(color: Colors.red.shade900)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Text(
                                        vm.submission!.status == 'submitted'
                                            ? 'الحالة: مرفوعة'
                                            : vm.submission!.status == 'pending_dept_head' ? 'الحالة: بانتظار رئيس القسم'
                                            : vm.submission!.status == 'pending_vice_dean' ? 'الحالة: بانتظار وكيل الكلية'
                                            : vm.submission!.status == 'pending_dean' ? 'الحالة: بانتظار العميد'
                                            : vm.submission!.status == 'pending_academic_affairs' ? 'الحالة: بانتظار الشؤون الأكاديمية'
                                            : vm.submission!.status == 'approved' ? 'الحالة: معتمدة'
                                            : vm.submission!.status == 'rejected' ? 'الحالة: مرفوضة'
                                            : 'الحالة: مسودة',
                                        style: TextStyle(
                                          color: vm.submission!.status == 'approved' ? Colors.green.shade700 : Colors.orange.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (var i = 0; i < settings.weekRanges.length; i++) ...[
                              Card(
                                color: vm.isCompletedFlags[i] ? Colors.green.shade50 : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'الأسبوع ${i + 1}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Row(
                                            children: [
                                              const Text('تم الإنجاز'),
                                              Checkbox(
                                                value: vm.isCompletedFlags[i],
                                                onChanged: canEditProgress
                                                    ? (val) => vm.toggleCompletedFlag(i, val ?? false)
                                                    : null,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          settings.weekRanges[i].trim().isEmpty
                                              ? 'لم يحدد مسؤول النظام تاريخ هذا الأسبوع بعد.'
                                              : settings.weekRanges[i],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: vm.topicControllers[i],
                                        readOnly: !canEditText,
                                        minLines: 2,
                                        maxLines: 4,
                                        decoration: const InputDecoration(
                                          labelText: 'موضوعات المنهاج التفصيلية',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: vm.theoryControllers[i],
                                              readOnly: !canEditText,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'الساعات (ن)',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextField(
                                              controller: vm.practicalControllers[i],
                                              readOnly: !canEditText,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'الساعات (م/ع)',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: vm.notesControllers[i],
                                        readOnly: !canEditText,
                                        minLines: 1,
                                        maxLines: 3,
                                        decoration: const InputDecoration(
                                          labelText: 'ملاحظات',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (!widget.isReadOnly) ...[
                        if (canEditText || canEditProgress)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: vm.saving || vm.submitting || vm.exporting ? null : _saveDraft,
                              icon: vm.saving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(canEditText ? 'حفظ مسودة الخطة' : 'حفظ الإنجاز الأسبوعي'),
                            ),
                          ),
                        if (canEditText)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: vm.saving || vm.submitting || vm.exporting ? null : _submit,
                              icon: vm.submitting
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.upload_file),
                              label: const Text('رفع الخطة التدريسية للاعتماد'),
                            ),
                          ),
                        if (canEditProgress)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange.shade800,
                                side: BorderSide(color: Colors.orange.shade800),
                              ),
                              onPressed: vm.saving || vm.submitting || vm.exporting ? null : _revertToDraft,
                              icon: vm.submitting
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.lock_open),
                              label: const Text('إلغاء الاعتماد للتعديل (إرجاع كمسودة)'),
                            ),
                          ),
                      ],
                      _buildApprovalButtons(vm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: vm.saving || vm.submitting || vm.exporting ? null : _export,
                          icon: vm.exporting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.print_rounded),
                          label: const Text('طباعة/تصدير كـ Word'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
