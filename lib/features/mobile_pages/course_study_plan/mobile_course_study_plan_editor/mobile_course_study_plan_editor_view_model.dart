import 'package:flutter/material.dart';
import '../services/course_study_plan_service.dart';
import '../models/course_study_plan_model.dart';

class MobileCourseStudyPlanEditorViewModel extends ChangeNotifier {
  final _service = CourseStudyPlanService();

  final String facultyDocId;
  final String facultyName;
  final String courseId;
  final String courseName;
  final String collegeName;
  final String departmentName;
  final String studentSets;
  final bool isReadOnly;

  MobileCourseStudyPlanEditorViewModel({
    required this.facultyDocId,
    required this.facultyName,
    required this.courseId,
    required this.courseName,
    required this.collegeName,
    required this.departmentName,
    required this.studentSets,
    required this.isReadOnly,
  });

  final List<TextEditingController> topicControllers = [];
  final List<TextEditingController> theoryControllers = [];
  final List<TextEditingController> practicalControllers = [];
  final List<TextEditingController> notesControllers = [];
  final List<bool> isCompletedFlags = [];

  CourseStudyPlanTemplateSettings? _settings;
  CourseStudyPlanTemplateSettings? get settings => _settings;

  CourseStudyPlanSubmission? _submission;
  CourseStudyPlanSubmission? get submission => _submission;

  bool _loading = true;
  bool get loading => _loading;

  bool _saving = false;
  bool get saving => _saving;

  bool _submitting = false;
  bool get submitting => _submitting;

  bool _exporting = false;
  bool get exporting => _exporting;

  void disposeControllers() {
    for (final controller in [
      ...topicControllers,
      ...theoryControllers,
      ...practicalControllers,
      ...notesControllers,
    ]) {
      controller.dispose();
    }
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final futures = await Future.wait([
        _service.loadSettings('first'),
        _service.loadSubmission(
          facultyDocId: facultyDocId,
          courseId: courseId,
        ),
      ]);

      _settings = futures[0] as CourseStudyPlanTemplateSettings;
      _submission = futures[1] as CourseStudyPlanSubmission?;

      _resetControllers(
        weekCount: _settings!.weekRanges.length,
        entries: _submission?.entries ?? const [],
      );
    } catch (e) {
      debugPrint('Error loading editor data: $e');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _resetControllers({
    required int weekCount,
    required List<CourseStudyPlanEntry> entries,
  }) {
    for (final controller in [
      ...topicControllers,
      ...theoryControllers,
      ...practicalControllers,
      ...notesControllers,
    ]) {
      controller.dispose();
    }
    topicControllers.clear();
    theoryControllers.clear();
    practicalControllers.clear();
    notesControllers.clear();
    isCompletedFlags.clear();

    for (int i = 0; i < weekCount; i++) {
      topicControllers.add(TextEditingController(
        text: i < entries.length ? entries[i].topicDetails : '',
      ));
      theoryControllers.add(TextEditingController(
        text: i < entries.length ? entries[i].theoryHours : '',
      ));
      practicalControllers.add(TextEditingController(
        text: i < entries.length ? entries[i].practicalOrDiscussionHours : '',
      ));
      notesControllers.add(TextEditingController(
        text: i < entries.length ? entries[i].notes : '',
      ));
      isCompletedFlags.add(i < entries.length ? entries[i].isCompleted : false);
    }
  }

  List<CourseStudyPlanEntry> _collectEntries() {
    return List.generate(
      topicControllers.length,
      (index) => CourseStudyPlanEntry(
        topicDetails: topicControllers[index].text.trim(),
        theoryHours: theoryControllers[index].text.trim(),
        practicalOrDiscussionHours: practicalControllers[index].text.trim(),
        notes: notesControllers[index].text.trim(),
        isCompleted: isCompletedFlags[index],
      ),
    );
  }

  CourseStudyPlanSubmission _buildSubmission(String status) {
    final s = _settings ??
        const CourseStudyPlanTemplateSettings(
          term: 'first',
          academicYear: '',
          weekRanges: <String>[],
        );
    return CourseStudyPlanSubmission(
      id: '${facultyDocId}__$courseId',
      facultyDocId: facultyDocId,
      facultyName: facultyName,
      collegeName: collegeName,
      departmentName: departmentName,
      programName: studentSets,
      levelLabel: '',
      term: 'first',
      courseId: courseId,
      courseKey: courseId,
      courseName: courseName,
      courseCode: '',
      creditHoursText: '',
      status: status,
      entries: _collectEntries(),
      weekRanges: s.weekRanges,
      academicYear: s.academicYear,
      updatedAt: _submission?.updatedAt,
      submittedAt: _submission?.submittedAt,
    );
  }

  Future<void> saveDraft() async {
    _saving = true;
    notifyListeners();
    try {
      final statusToSave = _submission?.status ?? 'draft';
      final sub = _buildSubmission(statusToSave);
      await _service.saveSubmission(sub);
      _submission = sub;
    } catch (e) {
      debugPrint('Error saving draft: $e');
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> submit() async {
    _submitting = true;
    notifyListeners();
    try {
      final sub = _buildSubmission('pending_dept_head');
      await _service.saveSubmission(sub);
      _submission = sub;
    } catch (e) {
      debugPrint('Error submitting plan: $e');
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> export() async {
    _exporting = true;
    notifyListeners();
    try {
      await _service.exportSubmissionDocx(_buildSubmission('submitted'));
    } catch (e) {
      debugPrint('Error exporting plan: $e');
      rethrow;
    } finally {
      _exporting = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(String newStatus, {String? reason}) async {
    if (_submission == null) return;
    _submitting = true;
    notifyListeners();
    try {
      await _service.updateSubmissionStatus(_submission!.id, newStatus, rejectionReason: reason);
      _submission = await _service.loadSubmission(facultyDocId: facultyDocId, courseId: courseId);
    } catch (e) {
      debugPrint('Error updating status: $e');
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> revertToDraft() async {
    _submitting = true;
    notifyListeners();
    try {
      await _service.updateSubmissionStatus(_submission!.id, 'draft');
      _submission = await _service.loadSubmission(facultyDocId: facultyDocId, courseId: courseId);
    } catch (e) {
      debugPrint('Error reverting to draft: $e');
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  void toggleCompletedFlag(int index, bool val) {
    isCompletedFlags[index] = val;
    notifyListeners();
  }
}
