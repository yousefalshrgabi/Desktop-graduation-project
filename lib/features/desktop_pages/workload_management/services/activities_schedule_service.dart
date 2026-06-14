import '../models/activity_schedule_row.dart';
import '../models/practical_group_setting.dart';
import '../models/semester_nasab_assignment.dart';
import 'computed_nasab_service.dart';
import 'semester_nasab_firestore_service.dart';
import 'excel_export_service.dart';
import 'practical_group_firestore_service.dart';
import '../utils/level_labels.dart';

/// Builds «Activities»-style schedule rows from assignments and study-plan slots.
class ActivitiesScheduleService {
  ActivitiesScheduleService({
    ExcelExportService? excel,
    PracticalGroupFirestoreService? groupService,
  })  : _excel = excel ?? ExcelExportService(),
        _groupService = groupService ?? PracticalGroupFirestoreService();

  final ExcelExportService _excel;
  final PracticalGroupFirestoreService _groupService;

  static String groupKey(String program, int level) =>
      '${program.trim()}|$level';

  /// Same layout as sheet «Activities» in انصبة كل الاقسام.xlsm.
  Future<List<ActivityScheduleRow>> build({
    required List<PlanCourseSlot> slots,
    required List<SemesterNasabRow> assignmentRows,
    required Map<String, int> groupCounts,
    required String collegeName,
  }) async {
    final assignmentByKey = <String, SemesterNasabAssignment>{};
    for (final row in assignmentRows) {
      assignmentByKey[row.course.courseKey] = row.assignment;
    }

    // Load parallel group settings for all programs/levels
    final parallelSettings = await _groupService.loadSettingsMap(
      collegeName: collegeName,
      forceRefresh: false,
    );

    final out = <ActivityScheduleRow>[];

    for (final slot in ComputedNasabService.uniqueCourseSlots(slots)) {
      final assignment = assignmentByKey[slot.courseKey];
      if (assignment == null) continue;

      final baseSet =
          '${slot.programName} - ${LevelLabels.nasabShort(slot.level)}';
      final groups = groupCounts[groupKey(slot.programName, slot.level)] ?? 1;

      // Get parallel group indices for this program/level
      final settingId = PracticalGroupSetting.docIdFor(
        collegeName: collegeName,
        programName: slot.programName,
        level: slot.level,
      );
      final parallelIndices =
          parallelSettings[settingId]?.parallelGroupIndices ?? [];

      final parallelGroups = <int>[];
      for (int i = 1; i <= groups; i++) {
        if (parallelIndices.contains(i)) {
          parallelGroups.add(i);
        }
      }

      final theory = assignment.theoryTeacherName.trim();
      if (theory.isNotEmpty && slot.creditTheory > 0) {
        out.add(
          ActivityScheduleRow(
            studentSet: baseSet,
            subject: slot.nameAr,
            teacher: theory,
          ),
        );

        if (parallelGroups.isNotEmpty) {
          out.add(
            ActivityScheduleRow(
              studentSet: '$baseSet موازي',
              subject: slot.nameAr,
              teacher: theory,
            ),
          );
        }
      }

      final practical = assignment.practicalTeacherName.trim();
      if (practical.isNotEmpty && slot.practicalPerGroup > 0) {
        // For practical, each group in its own activity (no merge at all)
        for (var g = 1; g <= groups; g++) {
          final isParallel = parallelIndices.contains(g);
          final suffix = isParallel ? ' موازي' : '';
          out.add(
            ActivityScheduleRow(
              studentSet: '$baseSet G$g$suffix',
              subject: slot.nameAr,
              teacher: practical,
            ),
          );
        }
      }
    }

    out.sort((a, b) {
      final setCmp = a.studentSet.compareTo(b.studentSet);
      if (setCmp != 0) return setCmp;
      final subCmp = a.subject.compareTo(b.subject);
      if (subCmp != 0) return subCmp;
      return a.teacher.compareTo(b.teacher);
    });

    return out;
  }

  Future<void> exportToExcel({
    required String collegeName,
    required String term,
    required List<ActivityScheduleRow> rows,
  }) async {
    if (rows.isEmpty) {
      throw Exception('لا توجد صفوف للتصدير. عيّن المدرسين واحفظ الربط أولاً.');
    }

    final termAr = term == 'first' ? 'الفصل_الأول' : 'الفصل_الثاني';
    final safeCollege = collegeName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    await _excel.exportTable(
      fileName: 'Activities_${safeCollege}_$termAr',
      title: 'Activities',
      headers: const ['Students Sets', 'Subject', 'Teachers'],
      dataRows: rows.map((r) => [r.studentSet, r.subject, r.teacher]).toList(),
    );
  }
}
