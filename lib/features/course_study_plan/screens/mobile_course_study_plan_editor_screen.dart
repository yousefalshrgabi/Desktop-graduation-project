import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';

import '../services/course_study_plan_service.dart';
import '../models/course_study_plan_model.dart';

class MobileCourseStudyPlanEditorScreen extends StatefulWidget {
  const MobileCourseStudyPlanEditorScreen({
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
  State<MobileCourseStudyPlanEditorScreen> createState() =>
      _MobileCourseStudyPlanEditorScreenState();
}

class _MobileCourseStudyPlanEditorScreenState
    extends State<MobileCourseStudyPlanEditorScreen> {
  final _service = CourseStudyPlanService();

  final List<TextEditingController> _topicControllers = [];
  final List<TextEditingController> _theoryControllers = [];
  final List<TextEditingController> _practicalControllers = [];
  final List<TextEditingController> _notesControllers = [];
  final List<bool> _isCompletedFlags = [];

  CourseStudyPlanTemplateSettings? _settings;
  CourseStudyPlanSubmission? _submission;

  bool _loading = true;
  bool _saving = false;
  bool _submitting = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      ..._topicControllers,
      ..._theoryControllers,
      ..._practicalControllers,
      ..._notesControllers,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final futures = await Future.wait([
        _service.loadSettings('first'), // Default to first term for now, or check session
        _service.loadSubmission(
          facultyDocId: widget.facultyDocId,
          courseId: widget.courseId,
        ),
      ]);

      final settings = futures[0] as CourseStudyPlanTemplateSettings;
      final submission = futures[1] as CourseStudyPlanSubmission?;

      _settings = settings;
      _submission = submission;

      _resetControllers(
        weekCount: settings.weekRanges.length,
        entries: submission?.entries ?? const [],
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل بيانات الخطة الدراسية: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetControllers({
    required int weekCount,
    required List<CourseStudyPlanEntry> entries,
  }) {
    for (final controller in [
      ..._topicControllers,
      ..._theoryControllers,
      ..._practicalControllers,
      ..._notesControllers,
    ]) {
      controller.dispose();
    }
    _topicControllers.clear();
    _theoryControllers.clear();
    _practicalControllers.clear();
    _notesControllers.clear();
    _isCompletedFlags.clear();

    for (int i = 0; i < weekCount; i++) {
      _topicControllers.add(TextEditingController(
        text: i < entries.length ? entries[i].topicDetails : '',
      ));
      _theoryControllers.add(TextEditingController(
        text: i < entries.length ? entries[i].theoryHours : '',
      ));
      _practicalControllers.add(TextEditingController(
        text: i < entries.length ? entries[i].practicalOrDiscussionHours : '',
      ));
      _notesControllers.add(TextEditingController(
        text: i < entries.length ? entries[i].notes : '',
      ));
      _isCompletedFlags.add(i < entries.length ? entries[i].isCompleted : false);
    }
  }

  List<CourseStudyPlanEntry> _collectEntries() {
    return List.generate(
      _topicControllers.length,
      (index) => CourseStudyPlanEntry(
        topicDetails: _topicControllers[index].text.trim(),
        theoryHours: _theoryControllers[index].text.trim(),
        practicalOrDiscussionHours: _practicalControllers[index].text.trim(),
        notes: _notesControllers[index].text.trim(),
        isCompleted: _isCompletedFlags[index],
      ),
    );
  }

  CourseStudyPlanSubmission _buildSubmission(String status) {
    final settings = _settings ??
        const CourseStudyPlanTemplateSettings(
          term: 'first',
          academicYear: '',
          weekRanges: <String>[],
        );
    return CourseStudyPlanSubmission(
      id: '${widget.facultyDocId}__${widget.courseId}',
      facultyDocId: widget.facultyDocId,
      facultyName: widget.facultyName,
      collegeName: widget.collegeName,
      departmentName: widget.departmentName,
      programName: widget.studentSets,
      levelLabel: '',
      term: 'first', // Default to first term for now
      courseId: widget.courseId,
      courseKey: widget.courseId,
      courseName: widget.courseName,
      courseCode: '',
      creditHoursText: '',
      status: status,
      entries: _collectEntries(),
      weekRanges: settings.weekRanges,
      academicYear: settings.academicYear,
      updatedAt: _submission?.updatedAt,
      submittedAt: _submission?.submittedAt,
    );
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      final statusToSave = _submission?.status ?? 'draft';
      final submission = _buildSubmission(statusToSave);
      await _service.saveSubmission(submission);
      _submission = submission;
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final submission = _buildSubmission('pending_dept_head');
      await _service.saveSubmission(submission);
      _submission = submission;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفع الخطة التدريسية لاعتماد رئيس القسم.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر الرفع: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await _service.exportSubmissionDocx(_buildSubmission('submitted'));
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
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _updateStatus(String newStatus, {String? reason}) async {
    if (_submission == null) return;
    setState(() => _submitting = true);
    try {
      await _service.updateSubmissionStatus(_submission!.id, newStatus, rejectionReason: reason);
      _submission = await _service.loadSubmission(facultyDocId: widget.facultyDocId, courseId: widget.courseId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason != null ? 'تم رفض الخطة.' : 'تم اعتماد الخطة وتحويلها بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الحالة: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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

    setState(() => _submitting = true);
    try {
      await _service.updateSubmissionStatus(_submission!.id, 'draft');
      _submission = await _service.loadSubmission(
          facultyDocId: widget.facultyDocId, courseId: widget.courseId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم إرجاع الخطة إلى مسودة للتعديل بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تعذر إرجاع الخطة: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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

  Widget _buildApprovalButtons() {
    final status = _submission?.status;
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
            onPressed: _submitting ? null : _showRejectDialog,
            icon: const Icon(Icons.close),
            label: const Text('رفض'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: _submitting ? null : () => _updateStatus(nextStatus),
            icon: const Icon(Icons.check),
            label: const Text('اعتماد'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final bool canEditText = !widget.isReadOnly && (_submission == null || _submission!.status == 'draft' || _submission!.status == 'rejected');
    final bool canEditProgress = !widget.isReadOnly && (_submission != null && _submission!.status == 'approved');
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
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
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
                              if (_submission != null) ...[
                                const SizedBox(height: 16),
                                if (_submission?.status == 'rejected' && _submission?.rejectionReason != null)
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
                                              Text(_submission!.rejectionReason!, style: TextStyle(color: Colors.red.shade900)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Text(
                                  _submission!.status == 'submitted'
                                      ? 'الحالة: مرفوعة'
                                      : _submission!.status == 'pending_dept_head' ? 'الحالة: بانتظار رئيس القسم'
                                      : _submission!.status == 'pending_vice_dean' ? 'الحالة: بانتظار وكيل الكلية'
                                      : _submission!.status == 'pending_dean' ? 'الحالة: بانتظار العميد'
                                      : _submission!.status == 'pending_academic_affairs' ? 'الحالة: بانتظار الشؤون الأكاديمية'
                                      : _submission!.status == 'approved' ? 'الحالة: معتمدة'
                                      : _submission!.status == 'rejected' ? 'الحالة: مرفوضة'
                                      : 'الحالة: مسودة',
                                  style: TextStyle(
                                    color: _submission!.status == 'approved' ? Colors.green.shade700 : Colors.orange.shade700,
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
                          color: _isCompletedFlags[i]
                              ? Colors.green.shade50
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'الأسبوع ${i + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Text('تم الإنجاز'),
                                        Checkbox(
                                          value: _isCompletedFlags[i],
                                          onChanged: canEditProgress
                                              ? (val) {
                                                  setState(() {
                                                    _isCompletedFlags[i] =
                                                        val ?? false;
                                                  });
                                                }
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
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
                                  controller: _topicControllers[i],
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
                                        controller: _theoryControllers[i],
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
                                        controller: _practicalControllers[i],
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
                                  controller: _notesControllers[i],
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
                        onPressed: _saving || _submitting || _exporting
                            ? null
                            : _saveDraft,
                        icon: _saving
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
                        onPressed:
                            _saving || _submitting || _exporting ? null : _submit,
                        icon: _submitting
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
                        onPressed:
                            _saving || _submitting || _exporting ? null : _revertToDraft,
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.lock_open),
                        label: const Text('إلغاء الاعتماد للتعديل (إرجاع كمسودة)'),
                      ),
                    ),
                ],
                _buildApprovalButtons(),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        _saving || _submitting || _exporting ? null : _export,
                    icon: _exporting
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
  }
}
