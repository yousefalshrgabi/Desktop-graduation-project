/// One scheduled activity from a FET timetable export.
class TimetableEntry {
  const TimetableEntry({
    required this.id,
    required this.day,
    required this.hour,
    required this.subject,
    required this.teachers,
    required this.studentSets,
    required this.room,
  });

  /// Stable identifier from the CSV (FET activity id) or a generated fallback.
  final String id;

  /// Full Arabic weekday name (e.g. الأحد) after mapping from FET day codes.
  final String day;

  /// Time slot label as in the CSV (e.g. hour index or time range).
  final String hour;

  final String subject;

  /// One or more teacher names from the CSV, split for filtering.
  final List<String> teachers;

  /// Student groups; the CSV cell is split on '+'.
  final List<String> studentSets;

  final String room;

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'day': day,
      'hour': hour,
      'subject': subject,
      'teachers': teachers,
      'studentSets': studentSets,
      'room': room,
    };
  }

  factory TimetableEntry.fromFirestoreMap(Map<String, dynamic> data) {
    return TimetableEntry(
      id: data['id'] as String? ?? '',
      day: data['day'] as String? ?? '',
      hour: data['hour'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      teachers: List<String>.from(data['teachers'] as List? ?? const []),
      studentSets: List<String>.from(data['studentSets'] as List? ?? const []),
      room: data['room'] as String? ?? '',
    );
  }

  @override
  String toString() =>
      'TimetableEntry(id: $id, day: $day, hour: $hour, subject: $subject)';
}
