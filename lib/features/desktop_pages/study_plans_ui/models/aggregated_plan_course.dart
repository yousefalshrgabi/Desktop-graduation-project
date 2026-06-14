import '../utils/course_coverage.dart';
import 'study_plan.dart';

/// One course row aggregated from all programs for a given academic term.
class AggregatedPlanCourse {
  const AggregatedPlanCourse({
    required this.courseKey,
    required this.nameAr,
    required this.codeLocal,
    this.codeEn,
    required this.coverageScope,
    required this.creditTheory,
    required this.creditPractical,
    this.sourcePrograms = const [],
  });

  final String courseKey;
  final String nameAr;
  final String codeLocal;
  final String? codeEn;
  final CourseCoverageScope coverageScope;
  final int creditTheory;
  final int creditPractical;
  final List<String> sourcePrograms;

  bool get needsPractical => creditPractical > 0;
  bool get needsTheory => creditTheory > 0;

  static String keyFor(StudyPlanCourse course) {
    final code = course.codeLocal.trim();
    if (code.isNotEmpty) {
      return code.replaceAll(RegExp(r'[/\\[\]*\s]+'), '_').toLowerCase();
    }
    return course.nameAr
        .trim()
        .replaceAll(RegExp(r'[/\\[\]*\s]+'), '_')
        .toLowerCase();
  }

  AggregatedPlanCourse copyWith({
    int? creditTheory,
    int? creditPractical,
    List<String>? sourcePrograms,
  }) {
    return AggregatedPlanCourse(
      courseKey: courseKey,
      nameAr: nameAr,
      codeLocal: codeLocal,
      codeEn: codeEn,
      coverageScope: coverageScope,
      creditTheory: creditTheory ?? this.creditTheory,
      creditPractical: creditPractical ?? this.creditPractical,
      sourcePrograms: sourcePrograms ?? this.sourcePrograms,
    );
  }
}
