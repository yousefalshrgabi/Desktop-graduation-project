import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/models/aggregated_plan_course.dart';
import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/models/study_plan.dart';
import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/services/study_plan_firestore_service.dart';
import '../models/incentive_entry.dart';
import '../utils/level_labels.dart';
import '../utils/practical_hours_calculator.dart';
import 'faculty_firestore_service.dart';
import 'graduation_project_firestore_service.dart';
import 'practical_group_firestore_service.dart';
import 'semester_nasab_firestore_service.dart';

/// One course instance in a program/level for nasab calculation.
class PlanCourseSlot {
  const PlanCourseSlot({
    required this.programName,
    required this.level,
    required this.term,
    required this.courseKey,
    required this.nameAr,
    required this.codeLocal,
    required this.creditTheory,
    required this.practicalPerGroup,
  });

  final String programName;
  final int level;
  final String term;
  final String courseKey;
  final String nameAr;
  final String codeLocal;
  final int creditTheory;
  final int practicalPerGroup;

  PlanCourseSlot copyWith({
    int? creditTheory,
    int? practicalPerGroup,
  }) {
    return PlanCourseSlot(
      programName: programName,
      level: level,
      term: term,
      courseKey: courseKey,
      nameAr: nameAr,
      codeLocal: codeLocal,
      creditTheory: creditTheory ?? this.creditTheory,
      practicalPerGroup: practicalPerGroup ?? this.practicalPerGroup,
    );
  }
}

/// Practical hours breakdown for one program/level.
class PracticalHoursBreakdown {
  const PracticalHoursBreakdown({
    required this.programName,
    required this.level,
    required this.groupCount,
    required this.practicalHours,
  });

  final String programName;
  final int level;
  final int groupCount;
  final int practicalHours;
}

/// Builds teacher workload rows from assignments, study plans, and group settings.
class ComputedNasabService {
  ComputedNasabService({
    StudyPlanFirestoreService? studyPlans,
    SemesterNasabFirestoreService? nasab,
    PracticalGroupFirestoreService? groups,
    FacultyFirestoreService? faculty,
    GraduationProjectFirestoreService? gradProjects,
  })  : _studyPlans = studyPlans ?? StudyPlanFirestoreService(),
        _nasab = nasab ?? SemesterNasabFirestoreService(),
        _groups = groups ?? PracticalGroupFirestoreService(),
        _faculty = faculty ?? FacultyFirestoreService(),
        _gradProjects = gradProjects ?? GraduationProjectFirestoreService();

  final StudyPlanFirestoreService _studyPlans;
  final SemesterNasabFirestoreService _nasab;
  final PracticalGroupFirestoreService _groups;
  final FacultyFirestoreService _faculty;
  final GraduationProjectFirestoreService _gradProjects;

  Future<List<PlanCourseSlot>> loadSlotsForTerm({
    required String collegeName,
    required String term,
    bool forceRefresh = false,
  }) async {
    final plans = await _studyPlans.listPlans(
      collegeFilter: collegeName,
      forceRefresh: forceRefresh,
    );
    final slots = <PlanCourseSlot>[];

    for (final plan in plans) {
      final rows = await _studyPlans.getPlanCoursesRaw(
        plan.id,
        forceRefresh: forceRefresh,
      );
      for (final row in rows) {
        if (row['isElectivePool'] == true) continue;
        final rowTerm = (row['term'] ?? '').toString();
        if (rowTerm != term) continue;

        final course = StudyPlanCourse.fromMap(row);
        if (course.nameAr.trim().isEmpty) continue;

        final level = (row['level'] as num?)?.toInt();
        if (level == null || level < 1) continue;

        final practical = course.actualPractical ?? course.creditPractical ?? 0;

        slots.add(
          PlanCourseSlot(
            programName: plan.programName.trim(),
            level: level,
            term: term,
            courseKey: AggregatedPlanCourse.keyFor(course),
            nameAr: course.nameAr,
            codeLocal: course.codeLocal,
            creditTheory: course.creditTheory ?? 0,
            practicalPerGroup: practical,
          ),
        );
      }
    }
    return slots;
  }

  Future<Map<String, int>> loadGroupCountMap({
    required String collegeName,
    bool forceRefresh = false,
  }) async {
    final saved = await _groups.loadSettingsMap(
      collegeName: collegeName,
      forceRefresh: forceRefresh,
    );
    final map = <String, int>{};
    for (final s in saved.values) {
      map[_groupKey(s.programName, s.level)] = s.groupCount;
    }
    return map;
  }

  static String _groupKey(String program, int level) =>
      '${program.trim()}|$level';

  static List<PlanCourseSlot> uniqueCourseSlots(
    List<PlanCourseSlot> slots,
  ) {
    final byKey = <String, PlanCourseSlot>{};

    for (final slot in slots) {
      final key = [
        slot.programName.trim(),
        slot.level,
        slot.term.trim(),
        slot.courseKey.trim(),
      ].join('|');
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = slot;
        continue;
      }

      byKey[key] = existing.copyWith(
        creditTheory: existing.creditTheory > slot.creditTheory
            ? existing.creditTheory
            : slot.creditTheory,
        practicalPerGroup: existing.practicalPerGroup > slot.practicalPerGroup
            ? existing.practicalPerGroup
            : slot.practicalPerGroup,
      );
    }

    return byKey.values.toList();
  }

  List<PracticalHoursBreakdown> practicalBreakdownsForCourse({
    required String courseKey,
    required String term,
    required List<PlanCourseSlot> slots,
    required Map<String, int> groupCounts,
  }) {
    final out = <PracticalHoursBreakdown>[];
    for (final slot in uniqueCourseSlots(slots)) {
      if (slot.courseKey != courseKey || slot.term != term) continue;
      if (slot.practicalPerGroup <= 0) continue;

      final groups = groupCounts[_groupKey(slot.programName, slot.level)] ?? 1;
      final hours = PracticalHoursCalculator.nasabHoursForCourse(
        practicalHoursPerGroup: slot.practicalPerGroup,
        groupCount: groups,
      );
      out.add(
        PracticalHoursBreakdown(
          programName: slot.programName,
          level: slot.level,
          groupCount: groups,
          practicalHours: hours,
        ),
      );
    }
    out.sort((a, b) {
      final p = a.programName.compareTo(b.programName);
      if (p != 0) return p;
      return a.level.compareTo(b.level);
    });
    return out;
  }

  static String formatBreakdowns(List<PracticalHoursBreakdown> list) {
    if (list.isEmpty) return '—';
    return list
        .map(
          (b) =>
              '${b.programName} (${LevelLabels.nasabShort(b.level)}): ${b.practicalHours}',
        )
        .join(' • ');
  }

  Future<List<IncentiveEntry>> buildEntries({
    required String collegeName,
    required String term,
    List<SemesterNasabRow>? assignmentRows,
    bool forceRefresh = false,
  }) async {
    final rows = assignmentRows ??
        await _nasab.loadSheet(
          collegeName: collegeName,
          term: term,
          forceRefresh: forceRefresh,
        );
    final slots = await loadSlotsForTerm(
      collegeName: collegeName,
      term: term,
      forceRefresh: forceRefresh,
    );
    final groupCounts = await loadGroupCountMap(
      collegeName: collegeName,
      forceRefresh: forceRefresh,
    );

    final gradGroupsAll = await _gradProjects.getAllGroups();

    final faculty =
        await _faculty.listUniversityWide(forceRefresh: forceRefresh);
    final deptById = {for (final f in faculty) f.id: f.department};
    final deptByName = {for (final f in faculty) f.name.trim(): f.department};

    final assignmentByKey = {
      for (final r in rows) r.course.courseKey: r.assignment,
    };

    final entries = <IncentiveEntry>[];

    for (final slot in uniqueCourseSlots(slots)) {
      final assignment = assignmentByKey[slot.courseKey];
      if (assignment == null) continue;

      final groups = groupCounts[_groupKey(slot.programName, slot.level)] ?? 1;
      final practicalHours = slot.practicalPerGroup > 0
          ? PracticalHoursCalculator.nasabHoursForCourse(
              practicalHoursPerGroup: slot.practicalPerGroup,
              groupCount: groups,
            ).toDouble()
          : 0.0;
      final theoryHours =
          slot.creditTheory > 0 ? slot.creditTheory.toDouble() : 0.0;
      final supervisionHours = practicalHours > 0 ? 1.0 : 0.0;
      final levelLabel = LevelLabels.nasabShort(slot.level);

      String resolveDept(String? teacherId, String teacherName) {
        if (teacherId != null && deptById[teacherId]?.isNotEmpty == true) {
          return deptById[teacherId]!;
        }
        return deptByName[teacherName.trim()] ?? '';
      }

      void addEntry({
        required String? teacherId,
        required String teacherName,
        required double theory,
        required double practical,
        required double supervision,
      }) {
        if (teacherName.trim().isEmpty) return;
        if (theory == 0 && practical == 0 && supervision == 0) return;

        entries.add(
          IncentiveEntry(
            teacherName: teacherName.trim(),
            subject: slot.nameAr,
            theoryHours: theory,
            practicalHours: practical,
            supervisionHours: supervision,
            courseDepartment: slot.programName,
            level: levelLabel,
            sourceDepartment: resolveDept(teacherId, teacherName),
          ),
        );
      }

      final theoryName = assignment.theoryTeacherName.trim();
      final practicalName = assignment.practicalTeacherName.trim();
      final sameTeacher = theoryName.isNotEmpty &&
          practicalName.isNotEmpty &&
          theoryName == practicalName;

      if (sameTeacher) {
        addEntry(
          teacherId: assignment.theoryTeacherId,
          teacherName: theoryName,
          theory: theoryHours,
          practical: practicalHours,
          supervision: supervisionHours,
        );
      } else {
        if (theoryName.isNotEmpty) {
          addEntry(
            teacherId: assignment.theoryTeacherId,
            teacherName: theoryName,
            theory: theoryHours,
            practical: 0,
            supervision: slot.practicalPerGroup > 0 ? 1.0 : 0.0,
          );
        }
        if (practicalName.isNotEmpty && practicalHours > 0) {
          addEntry(
            teacherId: assignment.practicalTeacherId,
            teacherName: practicalName,
            theory: 0,
            practical: practicalHours,
            supervision: 0,
          );
        }
      }
    }

    // Add graduation projects
    for (final gradGroup in gradGroupsAll) {
      if (gradGroup.isParallel) continue; // Usually, we only include 'عام' (regular) in the main nasab? Wait... The template might include both, but usually graduation projects are supervision hours.
      final teacherName = gradGroup.teacherName.trim();
      if (teacherName.isEmpty) continue;
      
      final supervisionHours = gradGroup.overtimeHours; // studentCount * 0.5
      
      // Determine the teacher's department
      final sourceDept = deptByName[teacherName] ?? '';

      entries.add(
        IncentiveEntry(
          teacherName: teacherName,
          subject: 'مشروع تخرج - مجموعة ${gradGroup.groupNumber}',
          theoryHours: 0,
          practicalHours: 0,
          supervisionHours: supervisionHours,
          courseDepartment: 'مشاريع التخرج',
          level: 'عام',
          sourceDepartment: sourceDept,
        ),
      );
    }

    entries.sort((a, b) {
      final t = a.teacherName.compareTo(b.teacherName);
      if (t != 0) return t;
      final s = a.subject.compareTo(b.subject);
      if (s != 0) return s;
      return a.courseDepartment.compareTo(b.courseDepartment);
    });

    return entries;
  }
}
