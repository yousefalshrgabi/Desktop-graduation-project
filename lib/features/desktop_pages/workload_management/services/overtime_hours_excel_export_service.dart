import 'dart:math';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/models/aggregated_plan_course.dart';
import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/models/study_plan.dart';
import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/services/study_plan_firestore_service.dart';
import 'package:academic_affairs_management/features/schedule_screen/models/timetable_entry.dart';
import 'package:academic_affairs_management/features/schedule_screen/utils/fet_day_mapping.dart';
import '../models/semester_nasab_assignment.dart';
import '../utils/app_file_saver.dart';
import '../utils/xlsx_template_helper.dart';
import 'faculty_firestore_service.dart';
import 'semester_nasab_firestore_service.dart';
import 'graduation_project_firestore_service.dart';

/// Fills «كليشة الساعات الزائدة» from a teacher timetable + study plans.
///
/// Session type: room name starting with `LAB` → practical; otherwise theory.
/// Theory row: D=2; + F=1 when the plan course has practical hours **and**
/// another instructor teaches the lab (نصاب فصل or LAB timetable).
/// If the same teacher teaches theory and lab for the course, F is omitted.
/// Lab row: E=2. Column H = D + E + F for the row.
class OvertimeHoursExcelExportService {
  static const _overtimeTemplateAsset = 'assets/templates/overtime_template.xlsx';
  static const _parallelTemplateAsset = 'assets/templates/parallel_template.xlsx';

  static const _defaultCollege = 'كلية الحاسبات';

  /// First data row for each weekday block (4 rows per day).
  static const Map<String, int> _dayFirstRow = {
    'الأحد': 8,
    'الاثنين': 12,
    'الإثنين': 12,
    'الثلاثاء': 16,
    'الأربعاء': 20,
    'الاربعاء': 20,
    'الخميس': 24,
  };

  OvertimeHoursExcelExportService({
    StudyPlanFirestoreService? studyPlans,
    FacultyFirestoreService? faculty,
    SemesterNasabFirestoreService? nasab,
    GraduationProjectFirestoreService? gradProject,
  })  : _studyPlans = studyPlans ?? StudyPlanFirestoreService(),
        _faculty = faculty ?? FacultyFirestoreService(),
        _nasab = nasab ?? SemesterNasabFirestoreService(),
        _gradProject = gradProject ?? GraduationProjectFirestoreService();

  final StudyPlanFirestoreService _studyPlans;
  final FacultyFirestoreService _faculty;
  final SemesterNasabFirestoreService _nasab;
  final GraduationProjectFirestoreService _gradProject;

  Future<void> exportTeacherOvertimeForm({
    required String teacherName,
    required List<TimetableEntry> entries,
    String collegeName = _defaultCollege,
    String term = 'second',
    List<TimetableEntry>? selectedEntries,
    Set<String> excludedEntryIds = const {},
    Set<String> halfWeightEntryIds = const {},
    Set<String> halfWeightSessionKeys = const {},
    String graduationProjectScheduleType = 'عام',
    String templateAsset = _overtimeTemplateAsset,
    String outputPrefix = 'ساعات_زائدة',
  }) async {
    final sourceEntries = selectedEntries ?? entries;
    final teacherEntries = sourceEntries
        .where((e) => e.teachers.any((t) => t.trim() == teacherName.trim()))
        .where((e) => !excludedEntryIds.contains(e.id))
        .toList();
    if (teacherEntries.isEmpty) {
      throw Exception('لا توجد بيانات لهذا المعلم');
    }

    final catalog = await _loadCourseCatalog(
      collegeName: collegeName,
      term: term,
    );
    final nasabRows = await _nasab.loadSheet(
      collegeName: collegeName,
      term: term,
    );
    final nasabByKey = {
      for (final row in nasabRows) row.course.courseKey: row.assignment,
    };
    final faculty = await _faculty.listUniversityWide();
    var department = '';
    for (final f in faculty) {
      if (f.name.trim() == teacherName.trim()) {
        department = f.department;
        if (f.college.trim().isNotEmpty) collegeName = f.college;
        break;
      }
    }

    final gradGroups = (await _gradProject.getGroupsForTeacher(teacherName))
        .where(
          (group) =>
              group.scheduleType.trim() == graduationProjectScheduleType.trim(),
        )
        .toList();

    final loaded = await XlsxTemplateHelper.loadTemplate(templateAsset);
    final sheet = loaded.sheet;

    sheet.setText('C2', collegeName);
    if (department.isNotEmpty) sheet.setText('G2', department);
    sheet.setText('C3', teacherName);

    final rowCursor = <String, int>{
      for (final e in _dayFirstRow.entries) e.key: e.value,
    };

    final sorted = List<TimetableEntry>.from(teacherEntries)
      ..sort((a, b) {
        final dayA = _dayOrder(mapFetDayToArabic(a.day));
        final dayB = _dayOrder(mapFetDayToArabic(b.day));
        if (dayA != dayB) return dayA.compareTo(dayB);
        return a.hour.compareTo(b.hour);
      });

    for (final entry in sorted) {
      final day = _normalizeDay(entry.day);
      if (day == null) continue;

      final firstRow = _dayFirstRow[day];
      if (firstRow == null) continue;

      var row = rowCursor[day] ?? firstRow;
      if (row > firstRow + 3) continue;
      rowCursor[day] = row + 1;

      final match = _findCourse(catalog, entry.subject);
      final isLab = _isLabSession(entry);
      final weight = halfWeightEntryIds.contains(entry.id) ||
              halfWeightSessionKeys.contains(sessionKeyFor(entry))
          ? 0.5
          : 1.0;

      num theoryHours = 0;
      num practicalHours = 0;
      num practicalSupervisionHours = 0;

      if (isLab) {
        practicalHours = 2 * weight;
      } else {
        theoryHours = 2 * weight;
        if (_shouldAddPracticalSupervision(
          teacherName: teacherName,
          subject: entry.subject,
          match: match,
          catalog: catalog,
          nasabByKey: nasabByKey,
          allEntries: entries,
        )) {
          practicalSupervisionHours = 1 * weight;
        }
      }

      if (theoryHours > 0) sheet.setNumber('D$row', theoryHours);
      if (practicalHours > 0) sheet.setNumber('E$row', practicalHours);
      if (practicalSupervisionHours > 0) {
        sheet.setNumber('F$row', practicalSupervisionHours);
      }

      final totalDue = theoryHours + practicalHours + practicalSupervisionHours;
      if (totalDue > 0) sheet.setNumber('H$row', totalDue);

      final courseLabel = match?.course.nameAr.trim().isNotEmpty == true
          ? match!.course.nameAr
          : entry.subject;
      sheet.setText('K$row', courseLabel);

      final deptLevels = _formatDeptLevels(entry.studentSets);
      if (deptLevels.isNotEmpty) sheet.setText('I$row', deptLevels);

      final mergedCount = _mergedGroupCount(entry.studentSets);
      if (mergedCount > 0) sheet.setNumber('J$row', mergedCount);

      final collegeLabel = match?.collegeName.trim().isNotEmpty == true
          ? match!.collegeName
          : collegeName;
      sheet.setText('L$row', collegeLabel);
    }

    // Add graduation project groups to the overtime form
    // Distribute groups in empty rows within the template, not at the end
    // Each group occupies one row with random day selection
    // Hours = studentCount * 0.5, added to supervision column (F)
    if (gradGroups.isNotEmpty) {
      final random = Random();
      final days = _dayFirstRow.keys.toList();

      for (final group in gradGroups) {
        // Find an empty row in a random day
        bool added = false;
        final shuffledDays = days.toList()..shuffle(random);

        for (final day in shuffledDays) {
          final firstRow = _dayFirstRow[day];
          if (firstRow == null) continue;

          var row = rowCursor[day] ?? firstRow;
          if (row <= firstRow + 3) {
            // This row is available
            final hours = group.studentCount * 0.5;

            sheet.setNumber('D$row', 0); // No theory hours
            sheet.setNumber('E$row', 0); // No practical hours
            sheet.setNumber(
                'F$row', hours); // Supervision hours = studentCount * 0.5
            sheet.setNumber('H$row', hours); // Total hours
            sheet.setText('K$row', 'مشروع تخرج - مجموعة ${group.groupNumber}');
            sheet.setText('I$row', department);
            sheet.setNumber('J$row', group.studentCount);
            sheet.setText('L$row', collegeName);

            rowCursor[day] = row + 1;
            added = true;
            break;
          }
        }

        // If no empty row found in any day, add to the first available day's last row
        if (!added && days.isNotEmpty) {
          final firstDay = days.first;
          final firstRow = _dayFirstRow[firstDay]!;
          final lastRow = firstRow + 3;
          final hours = group.studentCount * 0.5;

          sheet.setNumber('D$lastRow', 0);
          sheet.setNumber('E$lastRow', 0);
          sheet.setNumber('F$lastRow', hours);
          sheet.setNumber('H$lastRow', hours);
          sheet.setText(
              'K$lastRow', 'مشروع تخرج - مجموعة ${group.groupNumber}');
          sheet.setText('I$lastRow', department);
          sheet.setNumber('J$lastRow', group.studentCount);
          sheet.setText('L$lastRow', collegeName);
        }
      }
    }

    final bytes = XlsxTemplateHelper.repackXlsx(loaded.archive, sheet);
    final safeName = teacherName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    await AppFileSaver.saveExportedFile(
      name: '${outputPrefix}_$safeName',
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Future<void> exportTeacherParallelHoursForm({
    required String teacherName,
    required List<TimetableEntry> entries,
    required List<TimetableEntry> parallelEntries,
    Set<String> halfWeightEntryIds = const {},
    Set<String> halfWeightSessionKeys = const {},
    String collegeName = _defaultCollege,
    String term = 'second',
  }) async {
    await exportTeacherOvertimeForm(
      teacherName: teacherName,
      entries: entries,
      selectedEntries: parallelEntries,
      halfWeightEntryIds: halfWeightEntryIds,
      halfWeightSessionKeys: halfWeightSessionKeys,
      graduationProjectScheduleType: 'موازي',
      collegeName: collegeName,
      term: term,
      templateAsset: _parallelTemplateAsset,
      outputPrefix: 'ساعات_موازية',
    );
  }

  Future<List<_CatalogEntry>> _loadCourseCatalog({
    required String collegeName,
    required String term,
  }) async {
    final plans = await _studyPlans.listPlans(collegeFilter: collegeName);
    final catalog = <_CatalogEntry>[];

    for (final plan in plans) {
      final rows = await _studyPlans.getPlanCoursesRaw(plan.id);
      for (final row in rows) {
        if (row['isElectivePool'] == true) continue;
        final rowTerm = (row['term'] ?? '').toString();
        if (rowTerm.isNotEmpty && rowTerm != term) continue;

        final course = StudyPlanCourse.fromMap(row);
        if (course.nameAr.trim().isEmpty) continue;

        final level = (row['level'] as num?)?.toInt();
        catalog.add(
          _CatalogEntry(
            course: course,
            collegeName: plan.collegeName,
            programName: plan.programName,
            level: level,
          ),
        );
      }
    }
    return catalog;
  }

  /// F=1 only when the course has practical hours in a study plan and lab is
  /// taught by someone other than [teacherName] (نصاب فصل or LAB timetable).
  static bool _shouldAddPracticalSupervision({
    required String teacherName,
    required String subject,
    required _CatalogEntry? match,
    required List<_CatalogEntry> catalog,
    required Map<String, SemesterNasabAssignment> nasabByKey,
    required List<TimetableEntry> allEntries,
  }) {
    final teacher = teacherName.trim();
    final related = _findAllCourses(catalog, subject);
    if (match != null &&
        !related.any(
          (e) =>
              AggregatedPlanCourse.keyFor(e.course) ==
              AggregatedPlanCourse.keyFor(match.course),
        )) {
      related.add(match);
    }
    if (!related.any((e) => e.hasPracticalComponent)) return false;

    for (final entry in related) {
      final key = AggregatedPlanCourse.keyFor(entry.course);
      final assignment = nasabByKey[key];
      if (assignment == null) continue;

      final theory = assignment.theoryTeacherName.trim();
      final practical = assignment.practicalTeacherName.trim();

      if (theory.isNotEmpty && practical.isNotEmpty) {
        if (theory == practical) return false;
        if (theory == teacher && practical != teacher) return true;
        if (theory == teacher && practical == teacher) return false;
      } else if (theory == teacher &&
          practical.isNotEmpty &&
          practical != teacher) {
        return true;
      }
    }

    final labTeachers = _labTeachersForSubject(subject, allEntries);
    if (labTeachers.isEmpty) {
      for (final entry in related) {
        final key = AggregatedPlanCourse.keyFor(entry.course);
        final a = nasabByKey[key];
        if (a == null) continue;
        final theory = a.theoryTeacherName.trim();
        final practical = a.practicalTeacherName.trim();
        if (theory == teacher && practical.isNotEmpty && practical != teacher) {
          return true;
        }
      }
      return false;
    }

    if (labTeachers.every((t) => t == teacher)) return false;
    return labTeachers.any((t) => t != teacher);
  }

  static Set<String> _labTeachersForSubject(
    String subject,
    List<TimetableEntry> allEntries,
  ) {
    final teachers = <String>{};
    for (final e in allEntries) {
      if (!_isLabSession(e)) continue;
      if (!_subjectsMatch(e.subject, subject)) continue;
      for (final t in e.teachers) {
        final name = t.trim();
        if (name.isNotEmpty) teachers.add(name);
      }
    }
    return teachers;
  }

  static bool _subjectsMatch(String a, String b) {
    final na = _normalizeName(a);
    final nb = _normalizeName(b);
    if (na.isEmpty || nb.isEmpty) return false;
    return na == nb || na.contains(nb) || nb.contains(na);
  }

  static List<_CatalogEntry> _findAllCourses(
    List<_CatalogEntry> catalog,
    String subject,
  ) {
    final norm = _normalizeName(subject);
    if (norm.isEmpty) return [];

    final exact = <_CatalogEntry>[];
    final partial = <_CatalogEntry>[];

    for (final entry in catalog) {
      final name = _normalizeName(entry.course.nameAr);
      if (name == norm) {
        exact.add(entry);
        continue;
      }
      final code = entry.course.codeLocal.trim().toLowerCase();
      if (code.isNotEmpty &&
          (norm.contains(code) || subject.toLowerCase().contains(code))) {
        exact.add(entry);
        continue;
      }
      if (name.contains(norm) || norm.contains(name)) {
        partial.add(entry);
      }
    }
    return exact.isNotEmpty ? exact : partial;
  }

  _CatalogEntry? _findCourse(List<_CatalogEntry> catalog, String subject) {
    final all = _findAllCourses(catalog, subject);
    return all.isNotEmpty ? all.first : null;
  }

  static String _normalizeName(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static String sessionKeyFor(TimetableEntry entry) {
    final teachers = entry.teachers
        .map((teacher) => _normalizeName(teacher))
        .where((teacher) => teacher.isNotEmpty)
        .toList()
      ..sort();
    return [
      _normalizeDay(entry.day) ?? _normalizeName(entry.day),
      _normalizeName(entry.hour),
      _normalizeName(entry.subject),
      teachers.join('|'),
    ].join('::');
  }

  static String? _normalizeDay(String raw) {
    final arabic = mapFetDayToArabic(raw);
    if (arabic.isEmpty) return null;
    if (_dayFirstRow.containsKey(arabic)) return arabic;
    if (arabic == 'الأربعاء') return 'الاربعاء';
    return arabic;
  }

  static int _dayOrder(String day) {
    const order = [
      'الأحد',
      'الاثنين',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الاربعاء',
      'الخميس',
    ];
    final idx = order.indexOf(day);
    return idx >= 0 ? idx : 99;
  }

  /// Practical sessions are held in a lab room (name starts with LAB).
  static bool _isLabSession(TimetableEntry entry) {
    return entry.room.trim().toUpperCase().startsWith('LAB');
  }

  /// Count of practical groups (G1, G2, …) for merged-class column J.
  static int _mergedGroupCount(List<String> studentSets) {
    final groupPattern = RegExp(r'\bG\d+\b', caseSensitive: false);
    final gGroups = studentSets.where((s) => groupPattern.hasMatch(s)).length;
    if (gGroups > 0) return gGroups;
    return studentSets.length > 1 ? studentSets.length : 0;
  }

  /// Column I: unique dept/level labels from student sets, without G1/G2…
  static String _formatDeptLevels(List<String> studentSets) {
    final seen = <String>{};
    final ordered = <String>[];

    for (final set in studentSets) {
      final label = _deptLevelFromStudentSet(set);
      if (label.isEmpty) continue;
      if (seen.add(label)) ordered.add(label);
    }

    return ordered.join(' • ');
  }

  /// Strips practical group suffix (G1, G2, …) and keeps قسم/مستوى only.
  static String _deptLevelFromStudentSet(String raw) {
    var label = raw.trim();
    if (label.isEmpty) return '';

    label = label.replaceAll(RegExp(r'\s+G\d+\b', caseSensitive: false), '');
    return label.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<List<Map<String, dynamic>>> calculateCollegeSummary({
    required String collegeName,
    required String term,
    required Map<String, List<TimetableEntry>> entriesByTeacher,
    required Set<String> halfWeightEntryIds,
    required Set<String> halfWeightSessionKeys,
    required String graduationProjectScheduleType,
  }) async {
    final catalog = await _loadCourseCatalog(collegeName: collegeName, term: term);
    final nasabRows = await _nasab.loadSheet(collegeName: collegeName, term: term);
    final nasabByKey = {
      for (final row in nasabRows) row.course.courseKey: row.assignment,
    };
    final facultyList = await _faculty.listUniversityWide();

    final results = <Map<String, dynamic>>[];

    for (final mapEntry in entriesByTeacher.entries) {
      final teacherName = mapEntry.key;
      final teacherEntries = mapEntry.value;

      var teacherCollege = collegeName;
      for (final f in facultyList) {
        if (f.name.trim() == teacherName.trim()) {
          if (f.college.trim().isNotEmpty) teacherCollege = f.college;
          break;
        }
      }

      final gradGroups = (await _gradProject.getGroupsForTeacher(teacherName))
          .where((group) => group.scheduleType.trim() == graduationProjectScheduleType.trim())
          .toList();

      double totalHours = 0;

      for (final entry in teacherEntries) {
        final match = _findCourse(catalog, entry.subject);
        final isLab = _isLabSession(entry);
        final weight = halfWeightEntryIds.contains(entry.id) ||
                halfWeightSessionKeys.contains(sessionKeyFor(entry))
            ? 0.5
            : 1.0;

        num theoryHours = 0;
        num practicalHours = 0;
        num practicalSupervisionHours = 0;

        if (isLab) {
          practicalHours = 2 * weight;
        } else {
          theoryHours = 2 * weight;
          if (_shouldAddPracticalSupervision(
            teacherName: teacherName,
            subject: entry.subject,
            match: match,
            catalog: catalog,
            nasabByKey: nasabByKey,
            allEntries: teacherEntries,
          )) {
            practicalSupervisionHours = 1 * weight;
          }
        }

        totalHours += (theoryHours + practicalHours + practicalSupervisionHours);
      }

      for (final group in gradGroups) {
        totalHours += (group.studentCount * 0.5);
      }

      if (totalHours > 0) {
        results.add({
          'teacherName': teacherName,
          'totalHours': totalHours,
          'collegeName': teacherCollege,
        });
      }
    }

    return results;
  }
}

class _CatalogEntry {
  const _CatalogEntry({
    required this.course,
    required this.collegeName,
    required this.programName,
    this.level,
  });

  final StudyPlanCourse course;
  final String collegeName;
  final String programName;
  final int? level;

  bool get hasPracticalComponent {
    final practical = course.actualPractical ?? course.creditPractical ?? 0;
    return practical > 0;
  }
}
