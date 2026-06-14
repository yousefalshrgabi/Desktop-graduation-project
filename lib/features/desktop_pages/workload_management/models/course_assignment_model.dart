import 'package:cloud_firestore/cloud_firestore.dart';

class CourseAssignmentModel {
  String id;
  String planId;
  String courseId;
  String courseNameAr;
  String courseNameEn;
  String facultyMemberId;
  String facultyMemberName;
  int theoreticalGroups;
  int practicalGroups;
  bool isSynced;
  DateTime createdAt;

  CourseAssignmentModel({
    required this.id,
    required this.planId,
    required this.courseId,
    required this.courseNameAr,
    required this.courseNameEn,
    required this.facultyMemberId,
    required this.facultyMemberName,
    this.theoreticalGroups = 1,
    this.practicalGroups = 0,
    this.isSynced = false,
    required this.createdAt,
  });

  Map<String, dynamic> toSQLiteMap() => {
        'id': id,
        'plan_id': planId,
        'course_id': courseId,
        'course_name_ar': courseNameAr,
        'course_name_en': courseNameEn,
        'faculty_member_id': facultyMemberId,
        'faculty_member_name': facultyMemberName,
        'theoretical_groups': theoreticalGroups,
        'practical_groups': practicalGroups,
        'is_synced': isSynced ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory CourseAssignmentModel.fromSQLiteMap(Map<String, dynamic> map) =>
      CourseAssignmentModel(
        id: map['id'],
        planId: map['plan_id'] ?? '',
        courseId: map['course_id'] ?? '',
        courseNameAr: map['course_name_ar'] ?? '',
        courseNameEn: map['course_name_en'] ?? '',
        facultyMemberId: map['faculty_member_id'] ?? '',
        facultyMemberName: map['faculty_member_name'] ?? '',
        theoreticalGroups: map['theoretical_groups'] ?? 1,
        practicalGroups: map['practical_groups'] ?? 0,
        isSynced: map['is_synced'] == 1,
        createdAt:
            DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now(),
      );

  Map<String, dynamic> toFirestoreMap() => {
        'plan_id': planId,
        'course_id': courseId,
        'course_name_ar': courseNameAr,
        'course_name_en': courseNameEn,
        'faculty_member_id': facultyMemberId,
        'faculty_member_name': facultyMemberName,
        'theoretical_groups': theoreticalGroups,
        'practical_groups': practicalGroups,
        'created_at': Timestamp.fromDate(createdAt),
      };

  factory CourseAssignmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CourseAssignmentModel(
      id: doc.id,
      planId: data['plan_id'] ?? '',
      courseId: data['course_id'] ?? '',
      courseNameAr: data['course_name_ar'] ?? '',
      courseNameEn: data['course_name_en'] ?? '',
      facultyMemberId: data['faculty_member_id'] ?? '',
      facultyMemberName: data['faculty_member_name'] ?? '',
      theoreticalGroups: data['theoretical_groups'] ?? 1,
      practicalGroups: data['practical_groups'] ?? 0,
      isSynced: true,
      createdAt: data['created_at'] is Timestamp
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
