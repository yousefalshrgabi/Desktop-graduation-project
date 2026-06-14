import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'models/course_assignment_model.dart';
import '../study_plans_ui/models/study_plan.dart';
import '../study_plans_ui/services/study_plan_firestore_service.dart';

class TeacherWorkloadData {
  String facultyMemberId;
  String facultyMemberName;
  int theoreticalHours;
  int practicalHours;
  int get totalHours => theoreticalHours + practicalHours;
  int workloadLimit;

  TeacherWorkloadData({
    required this.facultyMemberId,
    required this.facultyMemberName,
    required this.theoreticalHours,
    required this.practicalHours,
    this.workloadLimit = 14, // Default adjustable limit
  });
}

class WorkloadViewModel extends ChangeNotifier {
  bool isLoading = false;
  List<CourseAssignmentModel> assignments = [];
  List<StudyPlanSummary> studyPlans = [];
  List<Map<String, dynamic>> facultyMembers = [];

  // Data for report
  Map<String, TeacherWorkloadData> workloadReports = {};

  // Cache for courses
  final Map<String, List<StudyPlanCourse>> courseCache = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StudyPlanFirestoreService _planService = StudyPlanFirestoreService();
  final Uuid _uuid = const Uuid();

  bool _isDisposed = false;

  WorkloadViewModel() {
    initData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  Future<void> initData() async {
    isLoading = true;
    notifyListeners();

    await Future.wait([
      fetchFacultyMembers(),
      fetchStudyPlans(),
      fetchAssignments(),
    ]);

    await calculateWorkloads();

    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchFacultyMembers() async {
    try {
      final snapshot = await _firestore.collection('faculty_members').get();
      facultyMembers = snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint("Error fetching faculty members: $e");
    }
  }

  Future<void> fetchStudyPlans() async {
    try {
      studyPlans = await _planService.listPlans();
    } catch (e) {
      debugPrint("Error fetching study plans: $e");
    }
  }

  Future<List<StudyPlanCourse>> loadCoursesForPlan(String planId) async {
    if (courseCache.containsKey(planId)) return courseCache[planId]!;
    try {
      final courses = await _planService.getPlanCourses(planId);
      courseCache[planId] = courses;
      return courses;
    } catch (e) {
      debugPrint("Error fetching courses for plan: $e");
      return [];
    }
  }

  Future<void> fetchAssignments() async {
    try {
      // Offline-first: fetch from SQLite
      final db = await DatabaseHelper.instance.database;
      final localData = await db.query('course_assignments');

      assignments =
          localData.map((e) => CourseAssignmentModel.fromSQLiteMap(e)).toList();

      // Sync from Firebase
      final snapshot = await _firestore.collection('course_assignments').get();
      for (var doc in snapshot.docs) {
        final model = CourseAssignmentModel.fromFirestore(doc);
        // Save to SQLite if not exists
        await db.insert('course_assignments', model.toSQLiteMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Refresh assignments list after sync
      final updatedLocalData = await db.query('course_assignments');
      assignments = updatedLocalData
          .map((e) => CourseAssignmentModel.fromSQLiteMap(e))
          .toList();
    } catch (e) {
      debugPrint("Error fetching assignments: $e");
    }
  }

  Future<void> assignCourse({
    required StudyPlanSummary plan,
    required StudyPlanCourse course,
    required String facultyMemberId,
    required String facultyMemberName,
    required int theoreticalGroups,
    required int practicalGroups,
  }) async {
    final assignment = CourseAssignmentModel(
      id: _uuid.v4(),
      planId: plan.id,
      courseId: course.codeLocal,
      courseNameAr: course.nameAr,
      courseNameEn: course.titleEn ?? '',
      facultyMemberId: facultyMemberId,
      facultyMemberName: facultyMemberName,
      theoreticalGroups: theoreticalGroups,
      practicalGroups: practicalGroups,
      createdAt: DateTime.now(),
    );

    assignments.add(assignment);
    await calculateWorkloads();
    notifyListeners();

    try {
      // Save locally
      final db = await DatabaseHelper.instance.database;
      await db.insert('course_assignments', assignment.toSQLiteMap());

      // Save to Firebase
      await _firestore
          .collection('course_assignments')
          .doc(assignment.id)
          .set(assignment.toFirestoreMap());

      // Update sync status locally
      assignment.isSynced = true;
      await db.update('course_assignments', assignment.toSQLiteMap(),
          where: 'id = ?', whereArgs: [assignment.id]);
    } catch (e) {
      debugPrint("Error saving assignment: $e");
    }
  }

  Future<void> removeAssignment(String id) async {
    assignments.removeWhere((a) => a.id == id);
    await calculateWorkloads();
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('course_assignments', where: 'id = ?', whereArgs: [id]);
      await _firestore.collection('course_assignments').doc(id).delete();
    } catch (e) {
      debugPrint("Error deleting assignment: $e");
    }
  }

  Future<void> calculateWorkloads() async {
    workloadReports.clear();

    for (var assignment in assignments) {
      // Find the course hours from study plans
      StudyPlanCourse? targetCourse;

      if (!courseCache.containsKey(assignment.planId)) {
        await loadCoursesForPlan(assignment.planId);
      }
      final courses = courseCache[assignment.planId] ?? [];

      try {
        targetCourse = courses.firstWhere((c) =>
            c.codeLocal == assignment.courseId ||
            c.nameAr == assignment.courseNameAr);
      } catch (_) {}

      int thHours = targetCourse?.creditTheory ?? 0;
      int prHours = targetCourse?.creditPractical ?? 0;

      int totalTh = thHours * assignment.theoreticalGroups;
      int totalPr = prHours * assignment.practicalGroups;

      if (workloadReports.containsKey(assignment.facultyMemberId)) {
        workloadReports[assignment.facultyMemberId]!.theoreticalHours +=
            totalTh;
        workloadReports[assignment.facultyMemberId]!.practicalHours += totalPr;
      } else {
        workloadReports[assignment.facultyMemberId] = TeacherWorkloadData(
          facultyMemberId: assignment.facultyMemberId,
          facultyMemberName: assignment.facultyMemberName,
          theoreticalHours: totalTh,
          practicalHours: totalPr,
        );
      }
    }
    notifyListeners();
  }

  void updateWorkloadLimit(String memberId, int limit) {
    if (workloadReports.containsKey(memberId)) {
      workloadReports[memberId]!.workloadLimit = limit;
      notifyListeners();
    }
  }
}
