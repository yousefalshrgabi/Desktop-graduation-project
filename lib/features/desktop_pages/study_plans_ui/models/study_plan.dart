import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/course_coverage.dart';

/// Parsed academic study plan (خطة دراسية) for a college program/track.
class StudyPlan {
  const StudyPlan({
    required this.collegeName,
    required this.programName,
    this.trackName,
    this.trackStartSemester,
    this.degreeNameAr,
    this.degreeNameEn,
    this.planStartYear,
    required this.semesters,
    this.sourceFileName,
    this.isElectiveOnly = false,
  });

  final String collegeName;
  final String programName;
  final String? trackName;
  final int? trackStartSemester;
  final String? degreeNameAr;
  final String? degreeNameEn;
  final String? planStartYear;
  final List<StudyPlanSemester> semesters;
  final String? sourceFileName;
  final bool isElectiveOnly;

  int get totalCourses => semesters.fold(0, (sum, s) => sum + s.courses.length);

  int get totalCreditHours => semesters.fold(0, (sum, s) {
        return sum +
            s.courses.fold(0, (cSum, c) => cSum + (c.creditTotal ?? 0));
      });

  String get displayTitle {
    if (trackName != null && trackName!.trim().isNotEmpty) {
      return '$programName - $trackName';
    }
    return programName;
  }

  String get documentId {
    final parts = <String>[
      collegeName,
      programName,
      if (trackName != null && trackName!.trim().isNotEmpty) trackName!,
    ];
    return parts.map(_normalizeDocPart).where((p) => p.isNotEmpty).join('__');
  }

  Map<String, dynamic> toSummaryMap() {
    return {
      'collegeName': collegeName,
      'programName': programName,
      'trackName': trackName ?? '',
      'trackStartSemester': trackStartSemester,
      'degreeNameAr': degreeNameAr ?? '',
      'degreeNameEn': degreeNameEn ?? '',
      'planStartYear': planStartYear ?? '',
      'sourceFileName': sourceFileName ?? '',
      'semesterCount': semesters.length,
      'courseCount': totalCourses,
      'totalCreditHours': totalCreditHours,
    };
  }

  List<Map<String, dynamic>> coursesToFirestoreMaps() {
    final out = <Map<String, dynamic>>[];
    for (final semester in semesters) {
      for (final course in semester.courses) {
        out.add({
          ...course.toMap(),
          'semesterKey': semester.key,
          'semesterLabelAr': semester.labelAr,
          'semesterLabelEn': semester.labelEn,
          'level': semester.level,
          'term': semester.term,
          'isElectivePool': semester.isElectivePool,
        });
      }
    }
    return out;
  }

  static String _normalizeDocPart(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[/\\[\]*\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }
}

class StudyPlanSemester {
  const StudyPlanSemester({
    required this.key,
    required this.labelAr,
    this.labelEn,
    this.level,
    this.term,
    required this.courses,
    this.isElectivePool = false,
    this.sheetName,
  });

  final String key;
  final String labelAr;
  final String? labelEn;
  final int? level;
  final String? term;
  final List<StudyPlanCourse> courses;
  final bool isElectivePool;
  final String? sheetName;
}

class StudyPlanCourse {
  const StudyPlanCourse({
    required this.sequence,
    required this.courseTypeAr,
    required this.nameAr,
    required this.codeLocal,
    this.codeEn,
    this.titleEn,
    this.courseTypeEn,
    this.creditTotal,
    this.creditTheory,
    this.creditPractical,
    this.creditDiscussion,
    this.actualTheory,
    this.actualPractical,
    this.actualDiscussion,
    this.actualTraining,
    this.notes,
    this.coverageScope = CourseCoverageScope.college,
  });

  final int sequence;
  final String courseTypeAr;
  final String nameAr;
  final String codeLocal;
  final String? codeEn;
  final String? titleEn;
  final String? courseTypeEn;
  final int? creditTotal;
  final int? creditTheory;
  final int? creditPractical;
  final int? creditDiscussion;
  final int? actualTheory;
  final int? actualPractical;
  final int? actualDiscussion;
  final int? actualTraining;
  final String? notes;
  final CourseCoverageScope coverageScope;

  Map<String, dynamic> toMap() {
    return {
      'sequence': sequence,
      'courseTypeAr': courseTypeAr,
      'nameAr': nameAr,
      'codeLocal': codeLocal,
      'codeEn': codeEn ?? '',
      'titleEn': titleEn ?? '',
      'courseTypeEn': courseTypeEn ?? '',
      'creditTotal': creditTotal ?? 0,
      'creditTheory': creditTheory ?? 0,
      'creditPractical': creditPractical ?? 0,
      'creditDiscussion': creditDiscussion ?? 0,
      'actualTheory': actualTheory ?? 0,
      'actualPractical': actualPractical ?? 0,
      'actualDiscussion': actualDiscussion ?? 0,
      'actualTraining': actualTraining ?? 0,
      'notes': notes ?? '',
      'coverageScope': coverageScope.firestoreValue,
    };
  }

  factory StudyPlanCourse.fromMap(Map<String, dynamic> map) {
    return StudyPlanCourse(
      sequence: (map['sequence'] as num?)?.toInt() ?? 0,
      courseTypeAr: (map['courseTypeAr'] ?? '').toString(),
      nameAr: (map['nameAr'] ?? '').toString(),
      codeLocal: (map['codeLocal'] ?? '').toString(),
      codeEn: (map['codeEn'] ?? '').toString().isEmpty
          ? null
          : map['codeEn'].toString(),
      titleEn: (map['titleEn'] ?? '').toString().isEmpty
          ? null
          : map['titleEn'].toString(),
      courseTypeEn: (map['courseTypeEn'] ?? '').toString().isEmpty
          ? null
          : map['courseTypeEn'].toString(),
      creditTotal: (map['creditTotal'] as num?)?.toInt(),
      creditTheory: (map['creditTheory'] as num?)?.toInt(),
      creditPractical: (map['creditPractical'] as num?)?.toInt(),
      creditDiscussion: (map['creditDiscussion'] as num?)?.toInt(),
      actualTheory: (map['actualTheory'] as num?)?.toInt(),
      actualPractical: (map['actualPractical'] as num?)?.toInt(),
      actualDiscussion: (map['actualDiscussion'] as num?)?.toInt(),
      actualTraining: (map['actualTraining'] as num?)?.toInt(),
      notes: (map['notes'] ?? '').toString().isEmpty
          ? null
          : map['notes'].toString(),
      coverageScope: (map['coverageScope'] ?? '').toString().trim().isEmpty
          ? CourseCoverageScope.inferFromCourseType(
              (map['courseTypeAr'] ?? '').toString(),
            )
          : CourseCoverageScope.fromString(map['coverageScope'].toString()),
    );
  }
}

/// Firestore summary row for browsing plans list.
class StudyPlanSummary {
  const StudyPlanSummary({
    required this.id,
    required this.collegeName,
    required this.programName,
    this.trackName,
    this.trackStartSemester,
    this.planStartYear,
    this.courseCount = 0,
    this.semesterCount = 0,
    this.totalCreditHours = 0,
    this.sourceFileName,
    this.lastUploadAt,
  });

  final String id;
  final String collegeName;
  final String programName;
  final String? trackName;
  final int? trackStartSemester;
  final String? planStartYear;
  final int courseCount;
  final int semesterCount;
  final int totalCreditHours;
  final String? sourceFileName;
  final DateTime? lastUploadAt;

  String get displayTitle {
    if (trackName != null && trackName!.trim().isNotEmpty) {
      return '$programName - $trackName';
    }
    return programName;
  }

  factory StudyPlanSummary.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? uploaded;
    final ts = data['lastUploadAt'];
    if (ts is Timestamp) {
      uploaded = ts.toDate();
    }

    return StudyPlanSummary(
      id: id,
      collegeName: (data['collegeName'] ?? '').toString(),
      programName: (data['programName'] ?? '').toString(),
      trackName: (data['trackName'] ?? '').toString().trim().isEmpty
          ? null
          : data['trackName'].toString(),
      trackStartSemester: (data['trackStartSemester'] as num?)?.toInt() ??
          _semesterFromLegacyTrackLevel(data['trackStartLevel']),
      planStartYear: (data['planStartYear'] ?? '').toString().trim().isEmpty
          ? null
          : data['planStartYear'].toString(),
      courseCount: (data['courseCount'] as num?)?.toInt() ?? 0,
      semesterCount: (data['semesterCount'] as num?)?.toInt() ?? 0,
      totalCreditHours: (data['totalCreditHours'] as num?)?.toInt() ?? 0,
      sourceFileName: (data['sourceFileName'] ?? '').toString().trim().isEmpty
          ? null
          : data['sourceFileName'].toString(),
      lastUploadAt: uploaded,
    );
  }

  static int? _semesterFromLegacyTrackLevel(dynamic value) {
    final level = (value as num?)?.toInt();
    if (level == null || level < 1 || level > 4) return null;
    return ((level - 1) * 2) + 1;
  }
}
