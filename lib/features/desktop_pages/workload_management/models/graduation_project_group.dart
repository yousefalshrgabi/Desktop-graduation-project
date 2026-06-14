class GraduationProjectGroup {
  final String id;
  final String teacherName;
  final int groupNumber;
  final int studentCount;
  final String scheduleType;

  GraduationProjectGroup({
    required this.id,
    required this.teacherName,
    required this.groupNumber,
    required this.studentCount,
    this.scheduleType = 'عام',
  });

  factory GraduationProjectGroup.fromMap(String id, Map<String, dynamic> data) {
    return GraduationProjectGroup(
      id: id,
      teacherName: data['teacherName'] ?? '',
      groupNumber: (data['groupNumber'] as num?)?.toInt() ?? 1,
      studentCount: (data['studentCount'] as num?)?.toInt() ?? 1,
      scheduleType: (data['scheduleType'] ?? 'عام').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherName': teacherName,
      'groupNumber': groupNumber,
      'studentCount': studentCount,
      'scheduleType': scheduleType,
    };
  }

  double get overtimeHours => studentCount * 0.5;

  bool get isParallel => scheduleType.trim() == 'موازي';
}
