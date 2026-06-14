import 'package:cloud_firestore/cloud_firestore.dart';

class CourseStudyPlanTemplateSettings {
  const CourseStudyPlanTemplateSettings({
    required this.term,
    required this.academicYear,
    required this.weekRanges,
    this.updatedAt,
    this.updatedBy = '',
  });

  final String term;
  final String academicYear;
  final List<String> weekRanges;
  final DateTime? updatedAt;
  final String updatedBy;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'term': term,
      'academicYear': academicYear,
      'weekRanges': weekRanges,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  factory CourseStudyPlanTemplateSettings.fromMap(Map<String, dynamic> map) {
    return CourseStudyPlanTemplateSettings(
      term: (map['term'] ?? '').toString(),
      academicYear: (map['academicYear'] ?? '').toString(),
      weekRanges: ((map['weekRanges'] as List?) ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: (map['updatedBy'] ?? '').toString(),
    );
  }
}

class CourseStudyPlanEntry {
  const CourseStudyPlanEntry({
    required this.topicDetails,
    required this.theoryHours,
    required this.practicalOrDiscussionHours,
    required this.notes,
    this.isCompleted = false,
  });

  final String topicDetails;
  final String theoryHours;
  final String practicalOrDiscussionHours;
  final String notes;
  final bool isCompleted;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'topicDetails': topicDetails,
      'theoryHours': theoryHours,
      'practicalOrDiscussionHours': practicalOrDiscussionHours,
      'notes': notes,
      'isCompleted': isCompleted,
    };
  }

  factory CourseStudyPlanEntry.fromMap(Map<String, dynamic> map) {
    return CourseStudyPlanEntry(
      topicDetails: (map['topicDetails'] ?? '').toString(),
      theoryHours: (map['theoryHours'] ?? '').toString(),
      practicalOrDiscussionHours:
          (map['practicalOrDiscussionHours'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      isCompleted: map['isCompleted'] == true,
    );
  }
}

class CourseStudyPlanSubmission {
  const CourseStudyPlanSubmission({
    required this.id,
    required this.facultyDocId,
    required this.facultyName,
    required this.collegeName,
    required this.departmentName,
    required this.programName,
    required this.levelLabel,
    required this.term,
    required this.courseId,
    required this.courseKey,
    required this.courseName,
    required this.courseCode,
    required this.creditHoursText,
    required this.status,
    required this.entries,
    required this.weekRanges,
    required this.academicYear,
    this.updatedAt,
    this.submittedAt,
  });

  final String id;
  final String facultyDocId;
  final String facultyName;
  final String collegeName;
  final String departmentName;
  final String programName;
  final String levelLabel;
  final String term;
  final String courseId;
  final String courseKey;
  final String courseName;
  final String courseCode;
  final String creditHoursText;
  final String status;
  final List<CourseStudyPlanEntry> entries;
  final List<String> weekRanges;
  final String academicYear;
  final DateTime? updatedAt;
  final DateTime? submittedAt;

  int get totalTopics =>
      entries.where((entry) => entry.topicDetails.trim().isNotEmpty).length;

  int get completedTopics => entries
      .where(
        (entry) => entry.topicDetails.trim().isNotEmpty && entry.isCompleted,
      )
      .length;

  double get completionRatio =>
      totalTopics == 0 ? 0 : completedTopics / totalTopics;

  int get completionPercent => (completionRatio * 100).round();

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'facultyDocId': facultyDocId,
      'facultyName': facultyName,
      'collegeName': collegeName,
      'departmentName': departmentName,
      'programName': programName,
      'levelLabel': levelLabel,
      'term': term,
      'courseId': courseId,
      'courseKey': courseKey,
      'courseName': courseName,
      'courseCode': courseCode,
      'creditHoursText': creditHoursText,
      'status': status,
      'entries': entries.map((e) => e.toMap()).toList(),
      'weekRanges': weekRanges,
      'academicYear': academicYear,
      'updatedAt': FieldValue.serverTimestamp(),
      'submittedAt':
          status == 'submitted' ? FieldValue.serverTimestamp() : submittedAt,
    };
  }

  factory CourseStudyPlanSubmission.fromFirestore(
    String id,
    Map<String, dynamic> map,
  ) {
    return CourseStudyPlanSubmission(
      id: id,
      facultyDocId: (map['facultyDocId'] ?? '').toString(),
      facultyName: (map['facultyName'] ?? '').toString(),
      collegeName: (map['collegeName'] ?? '').toString(),
      departmentName: (map['departmentName'] ?? '').toString(),
      programName: (map['programName'] ?? '').toString(),
      levelLabel: (map['levelLabel'] ?? '').toString(),
      term: (map['term'] ?? '').toString(),
      courseId: (map['courseId'] ?? '').toString(),
      courseKey: (map['courseKey'] ?? '').toString(),
      courseName: (map['courseName'] ?? '').toString(),
      courseCode: (map['courseCode'] ?? '').toString(),
      creditHoursText: (map['creditHoursText'] ?? '').toString(),
      status: (map['status'] ?? 'draft').toString(),
      entries: ((map['entries'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((e) => CourseStudyPlanEntry.fromMap(e.cast<String, dynamic>()))
          .toList(),
      weekRanges: ((map['weekRanges'] as List?) ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      academicYear: (map['academicYear'] ?? '').toString(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate(),
    );
  }
}
