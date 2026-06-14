import 'package:cloud_firestore/cloud_firestore.dart';

/// Number of student lab groups per program and academic level.
class PracticalGroupSetting {
  const PracticalGroupSetting({
    required this.collegeName,
    required this.programName,
    required this.level,
    required this.groupCount,
    this.parallelGroupIndices = const [],
    this.updatedAt,
  });

  final String collegeName;
  final String programName;
  final int level;
  final int groupCount;
  final List<int> parallelGroupIndices; // Indices of groups that are parallel (1-based)
  final DateTime? updatedAt;

  static String docIdFor({
    required String collegeName,
    required String programName,
    required int level,
  }) {
    final college = _norm(collegeName);
    final program = _norm(programName);
    return '${college}__${program}__L$level';
  }

  static String _norm(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[/\\[\]*\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  Map<String, dynamic> toMap() {
    return {
      'collegeName': collegeName,
      'programName': programName,
      'level': level,
      'groupCount': groupCount,
      'parallelGroupIndices': parallelGroupIndices,
      'updatedAt': updatedAt,
    };
  }

  factory PracticalGroupSetting.fromMap(String id, Map<String, dynamic> data) {
    DateTime? updated;
    final ts = data['updatedAt'];
    if (ts is Timestamp) {
      updated = ts.toDate();
    } else if (ts is DateTime) {
      updated = ts;
    }

    List<int> parallelIndices = [];
    if (data['parallelGroupIndices'] is List) {
      parallelIndices = (data['parallelGroupIndices'] as List)
          .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()) ?? 0)
          .toList();
    }

    return PracticalGroupSetting(
      collegeName: (data['collegeName'] ?? '').toString(),
      programName: (data['programName'] ?? '').toString(),
      level: (data['level'] as num?)?.toInt() ?? 0,
      groupCount: (data['groupCount'] as num?)?.toInt() ?? 1,
      parallelGroupIndices: parallelIndices,
      updatedAt: updated,
    );
  }

  PracticalGroupSetting copyWith({int? groupCount, List<int>? parallelGroupIndices}) {
    return PracticalGroupSetting(
      collegeName: collegeName,
      programName: programName,
      level: level,
      groupCount: groupCount ?? this.groupCount,
      parallelGroupIndices: parallelGroupIndices ?? this.parallelGroupIndices,
    );
  }
}

/// Row discovered from uploaded study plans (before/after saved group count).
class ProgramLevelPracticalRow {
  const ProgramLevelPracticalRow({
    required this.programName,
    required this.level,
    required this.practicalCourseCount,
    required this.practicalHoursPerGroupSamples,
    this.trackNames = const [],
    this.groupCount = 1,
    this.parallelGroupIndices = const [],
  });

  final String programName;
  final int level;
  final int practicalCourseCount;
  final List<int> practicalHoursPerGroupSamples;
  final List<String> trackNames;
  final int groupCount;
  final List<int> parallelGroupIndices; // Indices of groups that are parallel (1-based)

  int get typicalHoursPerGroup {
    if (practicalHoursPerGroupSamples.isEmpty) return 2;
    return practicalHoursPerGroupSamples.reduce((a, b) => a > b ? a : b);
  }

  ProgramLevelPracticalRow copyWith({
    int? groupCount,
    List<String>? trackNames,
    List<int>? parallelGroupIndices,
  }) {
    return ProgramLevelPracticalRow(
      programName: programName,
      level: level,
      practicalCourseCount: practicalCourseCount,
      practicalHoursPerGroupSamples: practicalHoursPerGroupSamples,
      trackNames: trackNames ?? this.trackNames,
      groupCount: groupCount ?? this.groupCount,
      parallelGroupIndices: parallelGroupIndices ?? this.parallelGroupIndices,
    );
  }
}
