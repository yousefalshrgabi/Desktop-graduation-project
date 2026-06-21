import 'package:flutter/material.dart';
import '../../../../core/services/app_session.dart';
import '../../../schedule_screen/models/timetable_entry.dart';
import '../../../schedule_screen/services/timetable_firestore_service.dart';
import '../../../schedule_screen/services/teacher_alias_service.dart';
import '../models/course_study_plan_model.dart';
import '../services/course_study_plan_service.dart';

class MobileCourseStudyPlanListViewModel extends ChangeNotifier {
  final _session = AppSession();
  final _timetableService = TimetableFirestoreService();
  final _planService = CourseStudyPlanService();

  bool _loading = true;
  bool get loading => _loading;

  List<TimetableEntry> _courses = [];
  List<TimetableEntry> get courses => _courses;

  Map<String, CourseStudyPlanSubmission> _submissions = {};
  Map<String, CourseStudyPlanSubmission> get submissions => _submissions;

  String get userId => _session.userId;
  String get userName => _session.userName;
  String get userCollege => _session.userCollege;
  String get userDepartment => _session.userDepartment;

  Future<void> loadData() async {
    _loading = true;
    notifyListeners();
    try {
      final entries = await _timetableService.getByCollegeCachedFirst(
        _session.userCollege,
      );
      
      final aliases = await TeacherAliasService().getAliasesForCollege(_session.userCollege);
      final myName = _session.userName.trim().toLowerCase();

      final matchingAliases = aliases
          .where((a) => a.canonicalName.trim().toLowerCase() == myName)
          .map((a) => a.aliasName.trim().toLowerCase())
          .toSet();

      final myEntries = entries.where((e) {
        return e.teachers.any((t) {
          final teacherName = t.trim().toLowerCase();
          return teacherName == myName || matchingAliases.contains(teacherName);
        });
      }).toList();

      // Get unique courses
      final Map<String, TimetableEntry> uniqueCourses = {};
      for (final e in myEntries) {
        if (e.subject.isNotEmpty) {
          uniqueCourses[e.subject] = e;
        }
      }

      final coursesList = uniqueCourses.values.toList();
      coursesList.sort((a, b) => a.subject.compareTo(b.subject));

      // Load submissions for these courses
      final Map<String, CourseStudyPlanSubmission> submissionsMap = {};
      for (final course in coursesList) {
        final sub = await _planService.loadSubmission(
          facultyDocId: _session.userId,
          courseId: course.subject,
        );
        if (sub != null) {
          submissionsMap[course.subject] = sub;
        }
      }

      _courses = coursesList;
      _submissions = submissionsMap;
    } catch (e) {
      debugPrint('Error loading courses list data: $e');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
