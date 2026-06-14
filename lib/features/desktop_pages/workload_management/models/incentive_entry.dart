/// One teaching-assignment row from a «نتيجة_*» sheet (teacher incentives).
class IncentiveEntry {
  const IncentiveEntry({
    required this.teacherName,
    required this.subject,
    required this.theoryHours,
    required this.practicalHours,
    required this.supervisionHours,
    required this.courseDepartment,
    required this.level,
    required this.sourceDepartment,
  });

  final String teacherName;
  final String subject;
  final double theoryHours;
  final double practicalHours;
  final double supervisionHours;

  /// القسم — department where the course is delivered.
  final String courseDepartment;

  final String level;

  /// Department extracted from sheet name (نتيجة_قسم علمي).
  final String sourceDepartment;

  double get totalHours => theoryHours + practicalHours + supervisionHours;

  Map<String, dynamic> toFirestoreMap() {
    return {
      'teacherName': teacherName,
      'subject': subject,
      'theoryHours': theoryHours,
      'practicalHours': practicalHours,
      'supervisionHours': supervisionHours,
      'courseDepartment': courseDepartment,
      'level': level,
      'sourceDepartment': sourceDepartment,
    };
  }

  factory IncentiveEntry.fromFirestoreMap(Map<String, dynamic> data) {
    return IncentiveEntry(
      teacherName: data['teacherName'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      theoryHours: _toDouble(data['theoryHours']),
      practicalHours: _toDouble(data['practicalHours']),
      supervisionHours: _toDouble(data['supervisionHours']),
      courseDepartment: data['courseDepartment'] as String? ?? '',
      level: data['level'] as String? ?? '',
      sourceDepartment: data['sourceDepartment'] as String? ?? '',
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }
}
