import 'package:flutter/material.dart';
import '../../../../core/services/app_session.dart';
import '../models/course_study_plan_model.dart';
import '../services/course_study_plan_service.dart';

class MobileCourseProgressTrackingViewModel extends ChangeNotifier {
  final _session = AppSession();
  final _service = CourseStudyPlanService();

  String? _selectedCollege;
  String? get selectedCollege => _selectedCollege;

  String? _selectedDepartment;
  String? get selectedDepartment => _selectedDepartment;

  List<CourseStudyPlanSubmission> _submissions = [];
  List<CourseStudyPlanSubmission> get submissions => _submissions;

  bool _exporting = false;
  bool get exporting => _exporting;

  late final Stream<List<CourseStudyPlanSubmission>> stream;
  late final bool canSeeAllDepartments;

  MobileCourseProgressTrackingViewModel() {
    canSeeAllDepartments = _session.isAdminOrDeanship || _session.isViceDean || _session.isDean;
    final defaultDepartment = canSeeAllDepartments ? null : _session.userDepartment;
    final String? defaultCollege = _session.isAdminOrDeanship ? null : _session.userCollege;

    stream = _service.watchSubmissions(
      collegeName: defaultCollege,
      departmentName: defaultDepartment,
    );
  }

  void filterSubmissions(List<CourseStudyPlanSubmission> allData) {
    var list = allData;
    if (_session.isAdminOrDeanship && _selectedCollege != null) {
      list = list.where((e) => e.collegeName == _selectedCollege).toList();
    }
    if (canSeeAllDepartments && _selectedDepartment != null) {
      list = list.where((e) => e.departmentName == _selectedDepartment).toList();
    }

    list = list.where((sub) {
      final s = sub.status;
      if (s == 'approved' || s == 'rejected') return true;

      if (_session.isAdminOrDeanship) {
        return s == 'pending_academic_affairs';
      } else if (_session.isDean) {
        return s == 'pending_dean' || s == 'pending_academic_affairs';
      } else if (_session.isViceDean) {
        return s == 'pending_vice_dean' || s == 'pending_dean' || s == 'pending_academic_affairs';
      } else if (_session.isDeptHead) {
        return s != 'draft';
      }
      return true;
    }).toList();

    _submissions = list;
  }

  void selectCollege(String? val) {
    _selectedCollege = val;
    _selectedDepartment = null;
    notifyListeners();
  }

  void selectDepartment(String? val) {
    _selectedDepartment = val;
    notifyListeners();
  }

  Future<void> exportReport() async {
    if (_submissions.isEmpty) {
      throw Exception('لا توجد بيانات للتصدير');
    }
    _exporting = true;
    notifyListeners();
    try {
      await _service.exportProgressSummaryTable(_submissions);
    } finally {
      _exporting = false;
      notifyListeners();
    }
  }

  bool get isAdminOrDeanship => _session.isAdminOrDeanship;
}
