import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'models/course_assignment_model.dart';
import '../study_plans_ui/study_plans_model.dart';

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
  List<StudyPlanModel> studyPlans = [];
  List<Map<String, dynamic>> facultyMembers = [];

  // Data for report
  Map<String, TeacherWorkloadData> workloadReports = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

    calculateWorkloads();

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
      final snapshot = await _firestore.collection('studyPlans').get();
      studyPlans = snapshot.docs.map((doc) => StudyPlanModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint("Error fetching study plans: $e");
    }
  }

  Future<void> fetchAssignments() async {
    try {
      // Offline-first: fetch from SQLite
      final db = await DatabaseHelper.instance.database;
      final localData = await db.query('course_assignments');
      
      assignments = localData.map((e) => CourseAssignmentModel.fromSQLiteMap(e)).toList();

      // Sync from Firebase
      final snapshot = await _firestore.collection('course_assignments').get();
      for (var doc in snapshot.docs) {
        final model = CourseAssignmentModel.fromFirestore(doc);
        // Save to SQLite if not exists
        await db.insert('course_assignments', model.toSQLiteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Refresh assignments list after sync
      final updatedLocalData = await db.query('course_assignments');
      assignments = updatedLocalData.map((e) => CourseAssignmentModel.fromSQLiteMap(e)).toList();
    } catch (e) {
      debugPrint("Error fetching assignments: $e");
    }
  }

  Future<void> assignCourse({
    required StudyPlanModel plan,
    required StudyCourse course,
    required String facultyMemberId,
    required String facultyMemberName,
    required int theoreticalGroups,
    required int practicalGroups,
  }) async {
    final assignment = CourseAssignmentModel(
      id: _uuid.v4(),
      planId: plan.id,
      courseId: course.courseId,
      courseNameAr: course.arCourseType,
      courseNameEn: course.enCourseType,
      facultyMemberId: facultyMemberId,
      facultyMemberName: facultyMemberName,
      theoreticalGroups: theoreticalGroups,
      practicalGroups: practicalGroups,
      createdAt: DateTime.now(),
    );

    assignments.add(assignment);
    calculateWorkloads();
    notifyListeners();

    try {
      // Save locally
      final db = await DatabaseHelper.instance.database;
      await db.insert('course_assignments', assignment.toSQLiteMap());

      // Save to Firebase
      await _firestore.collection('course_assignments').doc(assignment.id).set(assignment.toFirestoreMap());
      
      // Update sync status locally
      assignment.isSynced = true;
      await db.update('course_assignments', assignment.toSQLiteMap(), where: 'id = ?', whereArgs: [assignment.id]);
    } catch (e) {
      debugPrint("Error saving assignment: $e");
    }
  }

  Future<void> removeAssignment(String id) async {
    assignments.removeWhere((a) => a.id == id);
    calculateWorkloads();
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('course_assignments', where: 'id = ?', whereArgs: [id]);
      await _firestore.collection('course_assignments').doc(id).delete();
    } catch (e) {
      debugPrint("Error deleting assignment: $e");
    }
  }

  void calculateWorkloads() {
    workloadReports.clear();

    for (var assignment in assignments) {
      // Find the course hours from study plans
      StudyCourse? targetCourse;
      for (var plan in studyPlans) {
        if (plan.id == assignment.planId) {
          try {
            targetCourse = plan.courses.firstWhere((c) => c.courseId == assignment.courseId);
          } catch (_) {}
          break;
        }
      }

      int thHours = targetCourse?.courseHours.actual.theoretical ?? 0;
      int prHours = targetCourse?.courseHours.actual.practical ?? 0;

      int totalTh = thHours * assignment.theoreticalGroups;
      int totalPr = prHours * assignment.practicalGroups;

      if (workloadReports.containsKey(assignment.facultyMemberId)) {
        workloadReports[assignment.facultyMemberId]!.theoreticalHours += totalTh;
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
  }

  void updateWorkloadLimit(String memberId, int limit) {
    if (workloadReports.containsKey(memberId)) {
      workloadReports[memberId]!.workloadLimit = limit;
      notifyListeners();
    }
  }
}
