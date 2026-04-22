import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'study_plans_model.dart';
import 'study_plans_viewmodel.dart';

/// نافذة عرض تفاصيل الخطة الدراسية (قراءة فقط)
class ViewStudyPlanDialog extends StatelessWidget {
  final StudyPlanModel plan;
  final StudyPlansViewModel viewModel;
  const ViewStudyPlanDialog(
      {super.key, required this.plan, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final progName = viewModel.programName(plan.programId);
    final trackName = viewModel.trackName(plan.programId, plan.trackId);
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenW * 0.85,
          maxHeight: screenH * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(DesktopSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(children: [
                      const Icon(Icons.schema_outlined,
                          color: DesktopColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تفاصيل الخطة الدراسية',
                          style: DesktopTextStyles.heading2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              const SizedBox(height: DesktopSpacing.md),

              // ── Info cards ─────────────────────────────────────────────
              Wrap(
                spacing: DesktopSpacing.sm,
                runSpacing: DesktopSpacing.sm,
                children: [
                  _InfoCard(
                      icon: Icons.school_outlined,
                      label: 'البرنامج الأكاديمي',
                      value: progName,
                      color: DesktopColors.primary),
                  _InfoCard(
                      icon: Icons.alt_route,
                      label: 'المسار',
                      value: trackName,
                      color: Colors.purple),
                  _InfoCard(
                      icon: Icons.layers_outlined,
                      label: 'المستوى',
                      value: plan.arLevel,
                      color: Colors.teal),
                  _InfoCard(
                      icon: Icons.calendar_today_outlined,
                      label: 'الفصل الدراسي',
                      value: plan.arSemester,
                      color: Colors.orange),
                ],
              ),

              const SizedBox(height: DesktopSpacing.md),

              // ── Totals ──────────────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: _TotalCard(
                    label: 'ساعات فعلية',
                    value: plan.semesterTotals.totalActualHours.toString(),
                    icon: Icons.access_time,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: DesktopSpacing.sm),
                Expanded(
                  child: _TotalCard(
                    label: 'ساعات معتمدة',
                    value: plan.semesterTotals.totalCreditHours.toString(),
                    icon: Icons.verified_outlined,
                    color: DesktopColors.primary,
                  ),
                ),
                const SizedBox(width: DesktopSpacing.sm),
                Expanded(
                  child: _TotalCard(
                    label: 'عدد المقررات',
                    value: plan.courses.length.toString(),
                    icon: Icons.menu_book_outlined,
                    color: Colors.teal,
                  ),
                ),
              ]),

              const SizedBox(height: DesktopSpacing.md),
              const Text('المقررات الدراسية',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),

              // ── Courses table ────────────────────────────────────────────
              Flexible(
                child: plan.courses.isEmpty
                    ? const Center(
                        child: Text('لا توجد مقررات مسجلة في هذه الخطة',
                            style: TextStyle(color: Colors.grey)))
                    : SingleChildScrollView(
                        // تمرير عمودي
                        child: SingleChildScrollView(
                          // تمرير أفقي للجدول
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              // الحد الأدنى = عرض الـ dialog لتجنب collapse
                              minWidth: screenW * 0.55,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: DesktopColors.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Table(
                                defaultColumnWidth:
                                    const IntrinsicColumnWidth(),
                                columnWidths: const {
                                  0: FixedColumnWidth(38),
                                  1: FixedColumnWidth(110),
                                  2: FixedColumnWidth(200),
                                  3: FixedColumnWidth(62),
                                  4: FixedColumnWidth(62),
                                  5: FixedColumnWidth(72),
                                  6: FixedColumnWidth(62),
                                  7: FixedColumnWidth(62),
                                  8: FixedColumnWidth(72),
                                },
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius:
                                          const BorderRadius.vertical(
                                              top: Radius.circular(8)),
                                    ),
                                    children: const [
                                      _TH('#'),
                                      _TH('رمز المادة'),
                                      _TH('النوع'),
                                      _TH('ف.نظري'),
                                      _TH('ف.عملي'),
                                      _TH('ف.إجمالي'),
                                      _TH('م.نظري'),
                                      _TH('م.عملي'),
                                      _TH('م.إجمالي'),
                                    ],
                                  ),
                                  ...List.generate(plan.courses.length, (i) {
                                    final c = plan.courses[i];
                                    return TableRow(
                                      decoration: BoxDecoration(
                                          color: i.isOdd
                                              ? Colors.grey[50]
                                              : Colors.white),
                                      children: [
                                        _TD(Text('${i + 1}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey))),
                                        _TD(Text(c.courseId,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: DesktopColors.primary))),
                                        _TD(Text(c.arCourseType,
                                            style: const TextStyle(
                                                fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2)),
                                        _TD(_num(
                                            c.courseHours.actual.theoretical,
                                            Colors.blue)),
                                        _TD(_num(
                                            c.courseHours.actual.practical,
                                            Colors.blue)),
                                        _TD(_num(
                                            c.courseHours.actual.total,
                                            Colors.blue,
                                            bold: true)),
                                        _TD(_num(
                                            c.courseHours.credit.theoretical,
                                            DesktopColors.primary)),
                                        _TD(_num(
                                            c.courseHours.credit.practical,
                                            DesktopColors.primary)),
                                        _TD(_num(
                                            c.courseHours.credit.total,
                                            DesktopColors.primary,
                                            bold: true)),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: DesktopSpacing.md),

              // ── Footer ──────────────────────────────────────────────────
              Row(
                children: [
                  Icon(
                      plan.isSynced ? Icons.cloud_done : Icons.cloud_off,
                      size: 16,
                      color: plan.isSynced ? Colors.green : Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                      plan.isSynced
                          ? 'متزامن مع السحابة'
                          : 'غير متزامن (مخزن محلياً)',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              plan.isSynced ? Colors.green : Colors.grey)),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _num(int value, Color color, {bool bold = false}) => Text(
        value.toString(),
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal),
      );
}

// ── InfoCard ──────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ]),
    );
  }
}

// ── TotalCard ─────────────────────────────────────────────────────────────────
class _TotalCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _TotalCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: color.withOpacity(0.8)),
                    overflow: TextOverflow.ellipsis),
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ]),
        ),
      ]),
    );
  }
}

// ── Table helpers ─────────────────────────────────────────────────────────────
class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black54)),
      );
}

class _TD extends StatelessWidget {
  final Widget child;
  const _TD(this.child);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: child,
      );
}
