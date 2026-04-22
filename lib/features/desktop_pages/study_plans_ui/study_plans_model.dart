import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── ساعات المادة (نظري / عملي / إجمالي) ──────────────────────────────────
class CourseHours {
  int theoretical;
  int practical;
  int total;

  CourseHours({
    required this.theoretical,
    required this.practical,
    required this.total,
  });

  Map<String, dynamic> toMap() => {
        'theoretical': theoretical,
        'practical': practical,
        'total': total,
      };

  factory CourseHours.fromMap(Map<String, dynamic> map) => CourseHours(
        theoretical: (map['theoretical'] ?? 0) is int
            ? map['theoretical']
            : int.tryParse(map['theoretical'].toString()) ?? 0,
        practical: (map['practical'] ?? 0) is int
            ? map['practical']
            : int.tryParse(map['practical'].toString()) ?? 0,
        total: (map['total'] ?? 0) is int
            ? map['total']
            : int.tryParse(map['total'].toString()) ?? 0,
      );

  factory CourseHours.empty() =>
      CourseHours(theoretical: 0, practical: 0, total: 0);
}

// ─── تفاصيل الساعات لمادة واحدة (فعلية + معتمدة) ─────────────────────────
class CourseHoursDetail {
  CourseHours actual;
  CourseHours credit;

  CourseHoursDetail({required this.actual, required this.credit});

  Map<String, dynamic> toMap() => {
        'actual': actual.toMap(),
        'credit': credit.toMap(),
      };

  factory CourseHoursDetail.fromMap(Map<String, dynamic> map) =>
      CourseHoursDetail(
        actual: CourseHours.fromMap(
            Map<String, dynamic>.from(map['actual'] ?? {})),
        credit: CourseHours.fromMap(
            Map<String, dynamic>.from(map['credit'] ?? {})),
      );

  factory CourseHoursDetail.empty() =>
      CourseHoursDetail(actual: CourseHours.empty(), credit: CourseHours.empty());
}

// ─── مقرر دراسي واحد ──────────────────────────────────────────────────────
class StudyCourse {
  String courseId;
  int courseOrder;
  String arCourseType;
  String enCourseType;
  CourseHoursDetail courseHours;

  StudyCourse({
    required this.courseId,
    required this.courseOrder,
    required this.arCourseType,
    required this.enCourseType,
    required this.courseHours,
  });

  Map<String, dynamic> toMap() => {
        'course_id': courseId,
        'course_order': courseOrder,
        'ar_course_type': arCourseType,
        'en_course_type': enCourseType,
        'course_hours': courseHours.toMap(),
      };

  factory StudyCourse.fromMap(Map<String, dynamic> map) => StudyCourse(
        courseId: map['course_id'] ?? '',
        courseOrder: (map['course_order'] ?? 0) is int
            ? map['course_order']
            : int.tryParse(map['course_order'].toString()) ?? 0,
        arCourseType: map['ar_course_type'] ?? '',
        enCourseType: map['en_course_type'] ?? '',
        courseHours: CourseHoursDetail.fromMap(
            Map<String, dynamic>.from(map['course_hours'] ?? {})),
      );
}

// ─── إجماليات الفصل الدراسي ───────────────────────────────────────────────
class SemesterTotals {
  int totalActualHours;
  int totalCreditHours;

  SemesterTotals({
    required this.totalActualHours,
    required this.totalCreditHours,
  });

  Map<String, dynamic> toMap() => {
        'total_actual_hours': totalActualHours,
        'total_credit_hours': totalCreditHours,
      };

  factory SemesterTotals.fromMap(Map<String, dynamic> map) => SemesterTotals(
        totalActualHours: (map['total_actual_hours'] ?? 0) is int
            ? map['total_actual_hours']
            : int.tryParse(map['total_actual_hours'].toString()) ?? 0,
        totalCreditHours: (map['total_credit_hours'] ?? 0) is int
            ? map['total_credit_hours']
            : int.tryParse(map['total_credit_hours'].toString()) ?? 0,
      );

  factory SemesterTotals.empty() =>
      SemesterTotals(totalActualHours: 0, totalCreditHours: 0);
}

// ─── الموديل الرئيسي للخطة الدراسية ──────────────────────────────────────
class StudyPlanModel {
  String id;
  String programId;
  String? trackId;
  String arLevel;
  String enLevel;
  String arSemester;
  String enSemester;
  SemesterTotals semesterTotals;
  List<StudyCourse> courses;
  bool isSynced;
  DateTime createdAt;

  StudyPlanModel({
    required this.id,
    required this.programId,
    this.trackId,
    required this.arLevel,
    required this.enLevel,
    required this.arSemester,
    required this.enSemester,
    required this.semesterTotals,
    required this.courses,
    this.isSynced = false,
    required this.createdAt,
  });

  // ── To Firestore ──────────────────────────────────────────────────────────
  Map<String, dynamic> toFirestoreMap() => {
        'program_id': programId,
        'track_id': trackId,
        'ar_level': arLevel,
        'en_level': enLevel,
        'ar_semester': arSemester,
        'en_semester': enSemester,
        'semester_totals': semesterTotals.toMap(),
        'courses': courses.map((c) => c.toMap()).toList(),
        'created_at': Timestamp.fromDate(createdAt),
      };

  // ── From Firestore ─────────────────────────────────────────────────────────
  factory StudyPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final coursesRaw = data['courses'] as List<dynamic>? ?? [];
    return StudyPlanModel(
      id: doc.id,
      programId: data['program_id'] ?? '',
      trackId: data['track_id'],
      arLevel: data['ar_level'] ?? '',
      enLevel: data['en_level'] ?? '',
      arSemester: data['ar_semester'] ?? '',
      enSemester: data['en_semester'] ?? '',
      semesterTotals: SemesterTotals.fromMap(
          Map<String, dynamic>.from(data['semester_totals'] ?? {})),
      courses: coursesRaw
          .map((c) => StudyCourse.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
      isSynced: true,
      createdAt: data['created_at'] is Timestamp
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // ── To SQLite ─────────────────────────────────────────────────────────────
  Map<String, dynamic> toSQLiteMap() => {
        'id': id,
        'program_id': programId,
        'track_id': trackId,
        'ar_level': arLevel,
        'en_level': enLevel,
        'ar_semester': arSemester,
        'en_semester': enSemester,
        'semester_totals': jsonEncode(semesterTotals.toMap()),
        'courses': jsonEncode(courses.map((c) => c.toMap()).toList()),
        'is_synced': isSynced ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  // ── From SQLite ───────────────────────────────────────────────────────────
  factory StudyPlanModel.fromSQLiteMap(Map<String, dynamic> map) {
    List<dynamic> coursesRaw = [];
    Map<String, dynamic> totalsRaw = {};
    try {
      if (map['courses'] != null) {
        coursesRaw = jsonDecode(map['courses'].toString());
      }
      if (map['semester_totals'] != null) {
        totalsRaw =
            Map<String, dynamic>.from(jsonDecode(map['semester_totals'].toString()));
      }
    } catch (_) {}

    return StudyPlanModel(
      id: map['id'],
      programId: map['program_id'] ?? '',
      trackId: map['track_id'],
      arLevel: map['ar_level'] ?? '',
      enLevel: map['en_level'] ?? '',
      arSemester: map['ar_semester'] ?? '',
      enSemester: map['en_semester'] ?? '',
      semesterTotals: SemesterTotals.fromMap(totalsRaw),
      courses: coursesRaw
          .map((c) => StudyCourse.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
      isSynced: map['is_synced'] == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}
