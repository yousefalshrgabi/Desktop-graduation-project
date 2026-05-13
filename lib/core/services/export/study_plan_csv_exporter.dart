// dart.library.js = true على الويب (JavaScript) فقط، false على Android/Desktop
export 'csv_download_io.dart'
    if (dart.library.js) 'csv_download_web.dart';

import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/study_plans_model.dart';

// ─── بناء محتوى CSV من خطة دراسية ─────────────────────────────────────────
String buildStudyPlanCsv(
  StudyPlanModel plan, {
  String programName = '',
  String trackName = '',
}) {
  final buf = StringBuffer();
  buf.writeln('الخطة الدراسية - تقرير المقررات');
  buf.writeln('');
  buf.writeln('البرنامج الأكاديمي,$programName');
  buf.writeln('المسار,${trackName.isEmpty ? "الخطة العامة" : trackName}');
  buf.writeln('المستوى,${plan.arLevel} / ${plan.enLevel}');
  buf.writeln('الفصل الدراسي,${plan.arSemester} / ${plan.enSemester}');
  buf.writeln('');
  buf.writeln('إجماليات الفصل');
  buf.writeln('إجمالي الساعات الفعلية,${plan.semesterTotals.totalActualHours}');
  buf.writeln('إجمالي الساعات المعتمدة,${plan.semesterTotals.totalCreditHours}');
  buf.writeln('عدد المقررات,${plan.courses.length}');
  buf.writeln('');
  buf.writeln(
    '#,رمز المادة,نوع المقرر,'
    'ساعات فعلية-نظري,ساعات فعلية-عملي,ساعات فعلية-إجمالي,'
    'ساعات معتمدة-نظري,ساعات معتمدة-عملي,ساعات معتمدة-إجمالي',
  );
  for (int i = 0; i < plan.courses.length; i++) {
    final c = plan.courses[i];
    buf.writeln(
      '${i + 1},'
      '${_esc(c.courseId)},'
      '${_esc(c.arCourseType)},'
      '${c.courseHours.actual.theoretical},'
      '${c.courseHours.actual.practical},'
      '${c.courseHours.actual.total},'
      '${c.courseHours.credit.theoretical},'
      '${c.courseHours.credit.practical},'
      '${c.courseHours.credit.total}',
    );
  }
  return buf.toString();
}

String _esc(String v) =>
    (v.contains(',') || v.contains('"') || v.contains('\n'))
        ? '"${v.replaceAll('"', '""')}"'
        : v;

String buildCsvFileName(StudyPlanModel plan) {
  final level = plan.arLevel.replaceAll(' ', '_');
  final sem = plan.arSemester.replaceAll(' ', '_');
  final now = DateTime.now();
  final d = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  return 'plan_${level}_${sem}_$d.csv';
}
