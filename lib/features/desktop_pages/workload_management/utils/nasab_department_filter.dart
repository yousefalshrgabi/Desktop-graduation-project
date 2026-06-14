import '../models/faculty_option.dart';
import '../models/incentive_entry.dart';

/// Filters nasab rows by the teacher's academic department (not course specialization).
class NasabDepartmentFilter {
  /// teacher name → department from faculty_members.
  static Map<String, String> deptByTeacherName(Iterable<FacultyOption> faculty) {
    final map = <String, String>{};
    for (final f in faculty) {
      final name = f.name.trim();
      if (name.isEmpty) continue;
      map[name] = f.department.trim();
    }
    return map;
  }

  static String resolveTeacherDepartment(
    IncentiveEntry entry,
    Map<String, String> deptByName,
  ) {
    final fromFaculty = deptByName[entry.teacherName.trim()];
    if (fromFaculty != null && fromFaculty.isNotEmpty) return fromFaculty;
    return entry.sourceDepartment.trim();
  }

  /// All teacher names belonging to [department].
  static Set<String> teachersInDepartment({
    required List<IncentiveEntry> entries,
    required Map<String, String> deptByName,
    required String department,
  }) {
    final target = department.trim();
    final names = <String>{};
    for (final e in entries) {
      if (resolveTeacherDepartment(e, deptByName) == target) {
        names.add(e.teacherName.trim());
      }
    }
    return names;
  }

  /// When a department is selected, return every row for teachers in that department.
  static List<IncentiveEntry> filterEntries({
    required List<IncentiveEntry> all,
    required Map<String, String> deptByName,
    String? departmentFilter,
  }) {
    if (departmentFilter == null || departmentFilter.trim().isEmpty) {
      return all;
    }
    final teachers = teachersInDepartment(
      entries: all,
      deptByName: deptByName,
      department: departmentFilter,
    );
    if (teachers.isEmpty) return [];
    return all.where((e) => teachers.contains(e.teacherName.trim())).toList();
  }

  static List<String> uniqueDepartmentsFromFaculty(Iterable<FacultyOption> faculty) {
    return faculty
        .map((f) => f.department.trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}
