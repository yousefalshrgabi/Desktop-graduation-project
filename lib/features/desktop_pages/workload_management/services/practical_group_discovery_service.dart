import '../models/practical_group_setting.dart';
import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/models/study_plan.dart';
import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/services/study_plan_firestore_service.dart';

/// Builds program/level rows from uploaded study plans in Firestore.
class PracticalGroupDiscoveryService {
  PracticalGroupDiscoveryService({StudyPlanFirestoreService? studyPlans})
      : _studyPlans = studyPlans ?? StudyPlanFirestoreService();

  final StudyPlanFirestoreService _studyPlans;

  Future<List<ProgramLevelPracticalRow>> discoverRows({
    required String collegeName,
    Map<String, PracticalGroupSetting> savedByDocId = const {},
    bool forceRefresh = false,
  }) async {
    final plans = await _studyPlans.listPlans(
      collegeFilter: collegeName,
      forceRefresh: forceRefresh,
    );

    final acc = <String, _Accumulator>{};

    for (final summary in plans) {
      final rows = await _studyPlans.getPlanCoursesRaw(
        summary.id,
        forceRefresh: forceRefresh,
      );
      final program = summary.programName.trim();
      if (program.isEmpty) continue;

      for (final row in rows) {
        if (row['isElectivePool'] == true) continue;
        final level = (row['level'] as num?)?.toInt();
        if (level == null || level < 1) continue;

        final course = StudyPlanCourse.fromMap(row);
        final practical = course.actualPractical ?? course.creditPractical ?? 0;
        if (practical <= 0) continue;

        final key = '$program|$level';
        acc.putIfAbsent(key, () => _Accumulator(programName: program, level: level));
        final bucket = acc[key]!;
        bucket.practicalCourseCount++;
        bucket.hoursSamples.add(practical);
        final track = summary.trackName?.trim();
        if (track != null && track.isNotEmpty) {
          bucket.tracks.add(track);
        }
      }
    }

    final list = acc.values.map((a) {
      final docId = PracticalGroupSetting.docIdFor(
        collegeName: collegeName,
        programName: a.programName,
        level: a.level,
      );
      final saved = savedByDocId[docId];
      return ProgramLevelPracticalRow(
        programName: a.programName,
        level: a.level,
        practicalCourseCount: a.practicalCourseCount,
        practicalHoursPerGroupSamples: a.hoursSamples.toList()..sort(),
        trackNames: a.tracks.toList()..sort(),
        groupCount: saved?.groupCount ?? 1,
      );
    }).toList();

    list.sort((a, b) {
      final p = a.programName.compareTo(b.programName);
      if (p != 0) return p;
      return a.level.compareTo(b.level);
    });
    return list;
  }
}

class _Accumulator {
  _Accumulator({required this.programName, required this.level});

  final String programName;
  final int level;
  int practicalCourseCount = 0;
  final Set<int> hoursSamples = {};
  final Set<String> tracks = {};
}
