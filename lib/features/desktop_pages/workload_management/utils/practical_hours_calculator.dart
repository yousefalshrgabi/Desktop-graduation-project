/// Practical workload: each session weighs [lectureHours] (default 2).
class PracticalHoursCalculator {
  PracticalHoursCalculator._();

  static const int lectureHours = 2;

  /// Sessions per group for one course (from plan actual/credit practical hours).
  static int sessionsPerGroup(int practicalHoursPerGroup) {
    if (practicalHoursPerGroup <= 0) return 0;
    return (practicalHoursPerGroup / lectureHours).ceil();
  }

  /// Total practical hours in nasab for one course = groups × hours per group.
  static int nasabHoursForCourse({
    required int practicalHoursPerGroup,
    required int groupCount,
  }) {
    if (practicalHoursPerGroup <= 0 || groupCount <= 0) return 0;
    return practicalHoursPerGroup * groupCount;
  }

  /// Total sessions a practical instructor teaches for one course.
  static int totalSessionsForCourse({
    required int practicalHoursPerGroup,
    required int groupCount,
  }) {
    return sessionsPerGroup(practicalHoursPerGroup) * groupCount;
  }

  /// Sum across all practical courses at a level for one instructor load estimate.
  static int totalNasabHoursForLevel({
    required Iterable<int> practicalHoursPerGroupList,
    required int groupCount,
  }) {
    var sum = 0;
    for (final h in practicalHoursPerGroupList) {
      sum += nasabHoursForCourse(
        practicalHoursPerGroup: h,
        groupCount: groupCount,
      );
    }
    return sum;
  }

  /// Infer group count from a sample nasab practical cell (e.g. 6 → 3 when per-group is 2).
  static int? inferGroupCount({
    required int nasabPracticalHours,
    required int practicalHoursPerGroup,
  }) {
    if (nasabPracticalHours <= 0 || practicalHoursPerGroup <= 0) return null;
    if (nasabPracticalHours % practicalHoursPerGroup != 0) return null;
    return nasabPracticalHours ~/ practicalHoursPerGroup;
  }
}
