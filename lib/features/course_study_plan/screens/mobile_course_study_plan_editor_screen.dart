import 'package:flutter/material.dart';
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
      final submission = _buildSubmission('draft');
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
      final submission = _buildSubmission('submitted');
      await _service.saveSubmission(submission);
      _submission = submission;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفع الخطة التدريسية للرئيس والنائب الأكاديمي.'),
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

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
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
                                const SizedBox(height: 12),
                                Text(
                                  _submission!.status == 'submitted'
                                      ? 'الحالة: مرفوعة'
                                      : 'الحالة: مسودة',
                                  style: TextStyle(
                                    color: _submission!.status == 'submitted'
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
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
                                          onChanged: widget.isReadOnly
                                              ? null
                                              : (val) {
                                                  setState(() {
                                                    _isCompletedFlags[i] =
                                                        val ?? false;
                                                  });
                                                },
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
                                  readOnly: widget.isReadOnly,
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
                                        readOnly: widget.isReadOnly,
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
                                        readOnly: widget.isReadOnly,
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
                                  readOnly: widget.isReadOnly,
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
                      label: const Text('حفظ الإنجاز والخطة'),
                    ),
                  ),
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
                          : const Icon(Icons.send_rounded),
                      label: const Text('رفع الخطة النهائية للإدارة'),
                    ),
                  ),
                ],
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
