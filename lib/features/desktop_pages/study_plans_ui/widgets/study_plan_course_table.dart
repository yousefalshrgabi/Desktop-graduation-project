import 'package:flutter/material.dart';

import '../models/study_plan.dart';

class StudyPlanCourseTable extends StatelessWidget {
  const StudyPlanCourseTable({
    super.key,
    required this.courses,
    this.compact = false,
  });

  final List<StudyPlanCourse> courses;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('لا توجد مقررات في هذا القسم'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: compact ? 12 : 20,
        headingRowHeight: compact ? 36 : 44,
        dataRowMinHeight: compact ? 36 : 48,
        columns: const [
          DataColumn(label: Text('م')),
          DataColumn(label: Text('المقرر')),
          DataColumn(label: Text('الرمز')),
          DataColumn(label: Text('النوع')),
          DataColumn(label: Text('معتمدة')),
          DataColumn(label: Text('ن/ع/م')),
          DataColumn(label: Text('رمز EN')),
        ],
        rows: courses.map((c) {
          final hours = [
            if ((c.creditTheory ?? 0) > 0) 'ن${c.creditTheory}',
            if ((c.creditPractical ?? 0) > 0) 'ع${c.creditPractical}',
            if ((c.creditDiscussion ?? 0) > 0) 'م${c.creditDiscussion}',
          ].join(' ');
          return DataRow(cells: [
            DataCell(Text('${c.sequence}')),
            DataCell(
              SizedBox(
                width: compact ? 160 : 220,
                child: Text(c.nameAr, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ),
            DataCell(Text(c.codeLocal)),
            DataCell(Text(c.courseTypeAr)),
            DataCell(Text('${c.creditTotal ?? 0}')),
            DataCell(Text(hours)),
            DataCell(Text(c.codeEn ?? '')),
          ]);
        }).toList(),
      ),
    );
  }
}
