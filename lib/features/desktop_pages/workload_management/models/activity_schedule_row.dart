/// One row in the «Activities» sheet (Students Sets, Subject, Teachers).
class ActivityScheduleRow {
  const ActivityScheduleRow({
    required this.studentSet,
    required this.subject,
    required this.teacher,
  });

  final String studentSet;
  final String subject;
  final String teacher;
}
