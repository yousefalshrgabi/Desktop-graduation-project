import 'package:flutter/material.dart';

import '../services/study_plan_firestore_service.dart';
import '../utils/course_coverage.dart';

/// Editable course list displayed as a rich data table matching Image 2.
class StudyPlanCoursesEditor extends StatefulWidget {
  const StudyPlanCoursesEditor({
    super.key,
    required this.planId,
    required this.groupedCourses,
    this.canEdit = false,
  });

  final String planId;
  final Map<String, List<Map<String, dynamic>>> groupedCourses;
  final bool canEdit;

  @override
  State<StudyPlanCoursesEditor> createState() => _StudyPlanCoursesEditorState();
}

class _StudyPlanCoursesEditorState extends State<StudyPlanCoursesEditor> {
  final _service = StudyPlanFirestoreService();

  Future<void> _updateScope(
    String docId,
    CourseCoverageScope scope,
  ) async {
    try {
      await _service.updateCourseCoverage(
        planId: widget.planId,
        courseDocId: docId,
        scope: scope,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث التغطية: ${scope.labelAr}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحديث التغطية: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: widget.groupedCourses.keys.map((semesterKey) {
        final rawList = widget.groupedCourses[semesterKey] ?? [];
        if (rawList.isEmpty) return const SizedBox.shrink();

        // جلب المسمى العربي للمستوى الدراسي
        final semesterLabel = rawList.first['semesterLabelAr'] ?? semesterKey;

        return Card(
          margin: const EdgeInsets.only(bottom: 24.0),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. ترويسة الفصل الدراسي باللون الكحلي الداكن المميز (الصورة 2)
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 12.0, horizontal: 16.0),
                color: const Color(0xFF1A237E),
                child: Text(
                  semesterLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // 2. الجدول التفصيلي مع التمرير الأفقي الآمن للشاشات
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    border: TableBorder.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    children: [
                      // صف العناوين الرئيسي (Header)
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey.shade100),
                        children: const [
                          _TableCell(text: 'م', isHeader: true),
                          _TableCell(text: 'نوع المقرر', isHeader: true),
                          _TableCell(text: 'اسم المقرر', isHeader: true),
                          _TableCell(text: 'رمز المقرر', isHeader: true),
                          _TableCell(text: 'ساعات معتمدة (ن)', isHeader: true),
                          _TableCell(text: 'ساعات معتمدة (ع)', isHeader: true),
                          _TableCell(text: 'ساعات معتمدة (م)', isHeader: true),
                          _TableCell(text: 'ساعات معتمدة (ت)', isHeader: true),
                          _TableCell(text: 'إجمالي المعتمدة', isHeader: true),
                          _TableCell(text: 'ساعات فعلية (ن)', isHeader: true),
                          _TableCell(text: 'ساعات فعلية (ع)', isHeader: true),
                          _TableCell(text: 'نطاق التغطية', isHeader: true),
                          _TableCell(text: 'الرمز الإنجليزي', isHeader: true),
                          _TableCell(text: 'الاسم الإنجليزي', isHeader: true),
                        ],
                      ),

                      // صفوف البيانات الفردية للمواد
                      ...rawList.map((map) {
                        final docId = map['id']?.toString() ?? '';

                        // مطابقة المسميات مع ملف الـ Model وقاعدة البيانات الفعليين:
                        final int creditTheory =
                            (map['creditTheory'] as num?)?.toInt() ?? 0;
                        // تم التعديل من 'creditPractical' إلى 'creditLab' ليتوافق مع الـ Model الخاص بك
                        final int creditLab =
                            (map['creditLab'] as num?)?.toInt() ?? 0;
                        final int creditDiscussion =
                            (map['creditDiscussion'] as num?)?.toInt() ?? 0;
                        final int creditTraining =
                            (map['creditTraining'] as num?)?.toInt() ?? 0;

                        // تم التعديل من 'creditTotal' إلى 'creditHours' لتطابق الحقل الفعلي المخزن في Firestore
                        final int creditHours =
                            (map['creditHours'] as num?)?.toInt() ??
                                (creditTheory +
                                    creditLab +
                                    creditDiscussion +
                                    creditTraining);

                        // الساعات الفعلية للنصاب
                        final int actualTheory =
                            (map['actualTheory'] as num?)?.toInt() ?? 0;
                        final int actualPractical =
                            (map['actualPractical'] as num?)?.toInt() ?? 0;

                        // جلب نطاق التغطية الحالي
                        final currentScopeName =
                            map['coverageScope']?.toString() ?? '';
                        final scope = CourseCoverageScope.values.firstWhere(
                          (s) => s.name == currentScopeName,
                          orElse: () => CourseCoverageScope.college,
                        );

                        return TableRow(
                          children: [
                            _TableCell(text: '${map['sequence'] ?? ''}'),
                            _TableCell(
                                text:
                                    '${map['courseTypeAr'] ?? map['courseTypeEn'] ?? ''}'),
                            _TableCell(
                                text: '${map['nameAr'] ?? ''}',
                                textAlign: TextAlign.right),
                            _TableCell(text: '${map['codeLocal'] ?? ''}'),
                            _TableCell(text: '$creditTheory'),
                            _TableCell(
                                text:
                                    '$creditLab'), // عرض ساعات العملي/المختبر الصحيحة
                            _TableCell(text: '$creditDiscussion'),
                            _TableCell(text: '$creditTraining'),
                            _TableCell(
                                text: '$creditHours',
                                isBold: true), // إجمالي الساعات الصحيح (2)
                            _TableCell(text: '$actualTheory'),
                            _TableCell(text: '$actualPractical'),

                            // قائمة التغطية التفاعلية (Dropdown) داخل الخلية
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0, vertical: 4.0),
                              child: DropdownButton<CourseCoverageScope>(
                                value: scope,
                                isDense: true,
                                underline: const SizedBox.shrink(),
                                items: CourseCoverageScope.values.map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(s.labelAr,
                                        style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: docId.isEmpty || !widget.canEdit
                                    ? null
                                    : (v) {
                                        if (v != null) _updateScope(docId, v);
                                      },
                              ),
                            ),

                            _TableCell(text: '${map['codeEn'] ?? ''}'),
                            _TableCell(
                                text: '${map['titleEn'] ?? ''}',
                                textAlign: TextAlign.left),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// وجت مساعد مخصص لتنسيق وضبط حجم وهيكل خلايا الجدول بانتظام
class _TableCell extends StatelessWidget {
  const _TableCell({
    required this.text,
    this.isHeader = false,
    this.isBold = false,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final bool isHeader;
  final bool isBold;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight:
              (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 13 : 14,
          color: isHeader ? Colors.blueGrey.shade900 : Colors.black87,
        ),
        textAlign: textAlign,
      ),
    );
  }
}
