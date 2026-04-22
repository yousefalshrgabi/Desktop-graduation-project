import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/features/desktop_pages/SyncDialog.dart';
import 'package:academic_affairs_management/core/services/export/study_plan_csv_exporter.dart';
import 'study_plans_viewmodel.dart';
import 'add_study_plan_dialog.dart';
import 'edit_study_plan_dialog.dart';
import 'view_study_plan_dialog.dart';

class StudyPlansView extends StatefulWidget {
  const StudyPlansView({Key? key}) : super(key: key);

  @override
  State<StudyPlansView> createState() => _StudyPlansViewState();
}

class _StudyPlansViewState extends State<StudyPlansView> {
  final StudyPlansViewModel _viewModel = StudyPlansViewModel();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesktopColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesktopSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: DesktopSpacing.lg),
            _buildFiltersAndActions(context),
            const SizedBox(height: DesktopSpacing.md),
            _buildTable(),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(children: [
        const Icon(Icons.schema_outlined, color: DesktopColors.primary),
        const SizedBox(width: DesktopSpacing.xs),
        Text('نظام الشؤون الأكاديمية',
            style:
                DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
      ]),
      actions: [
        TextButton(onPressed: () {}, child: const Text('العربية | EN')),
        IconButton(
          tooltip: 'مزامنة السحابة',
          icon: const Icon(Icons.cloud_sync_outlined,
              color: DesktopColors.primary),
          onPressed: () => showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const SyncDialog(),
          ),
        ),
        IconButton(
            icon: const Icon(Icons.notifications_none), onPressed: () {}),
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: CircleAvatar(
            backgroundColor: Color.fromARGB(255, 219, 215, 220),
            child: Text('أ'),
          ),
        ),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('إدارة الخطط الدراسية', style: DesktopTextStyles.heading1),
      const SizedBox(height: 4),
      Text('عرض، إضافة، وتعديل الخطط الدراسية لجميع البرامج الأكاديمية',
          style: DesktopTextStyles.caption),
    ]);
  }

  // ── Filters & Actions ───────────────────────────────────────────────────────
  Widget _buildFiltersAndActions(BuildContext context) {
    return Row(children: [
      Expanded(
        flex: 3,
        child: TextField(
          controller: _searchController,
          onChanged: _viewModel.updateSearchQuery,
          decoration: InputDecoration(
            hintText: 'ابحث بالمستوى أو الفصل أو البرنامج...',
            prefixIcon: const Icon(Icons.search),
            enabledBorder: DesktopInputTheme.inputDecorationTheme.enabledBorder,
            focusedBorder: DesktopInputTheme.inputDecorationTheme.focusedBorder,
          ),
        ),
      ),
      const SizedBox(width: DesktopSpacing.md),
      ElevatedButton(
        onPressed: () => showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AddStudyPlanDialog(viewModel: _viewModel),
        ),
        style: DesktopButtonTheme.elevatedButtonTheme.style,
        child: Row(children: const [
          Icon(Icons.add, color: DesktopColors.surface),
          SizedBox(width: 8),
          Text('إضافة خطة جديدة'),
        ]),
      ),
    ]);
  }

  // ── Table ───────────────────────────────────────────────────────────────────
  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesktopColors.border),
      ),
      child: Builder(builder: (context) {
        if (_viewModel.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(DesktopSpacing.lg),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_viewModel.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(DesktopSpacing.lg),
              child: Text('حدث خطأ: ${_viewModel.errorMessage}',
                  style: const TextStyle(color: Colors.red)),
            ),
          );
        }

        if (_viewModel.filteredPlans.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(DesktopSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schema_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('لا توجد خطط دراسية مسجلة حالياً',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: CustomDataTable(
            columns: const [
              DataColumn(
                  label: Text('البرنامج', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('المسار', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('المستوى', style: DesktopTextStyles.caption)),
              DataColumn(
                  label:
                      Text('الفصل الدراسي', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('ساعات فعلية', style: DesktopTextStyles.caption)),
              DataColumn(
                  label:
                      Text('ساعات معتمدة', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('المقررات', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('المزامنة', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('إجراءات', style: DesktopTextStyles.caption)),
            ],
            rows: _viewModel.filteredPlans.map((plan) {
              final progName = _viewModel.programName(plan.programId);
              final trackName =
                  _viewModel.trackName(plan.programId, plan.trackId);

              return DataRow(cells: [
                // البرنامج
                DataCell(Tooltip(
                  message: progName,
                  child: Text(
                    progName.length > 22
                        ? '${progName.substring(0, 22)}...'
                        : progName,
                    style: DesktopTextStyles.body,
                  ),
                )),
                // المسار
                DataCell(Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: plan.trackId == null || plan.trackId!.isEmpty
                        ? Colors.grey[100]
                        : DesktopColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(trackName,
                      style: TextStyle(
                          fontSize: 12,
                          color: plan.trackId == null || plan.trackId!.isEmpty
                              ? Colors.grey
                              : DesktopColors.primary)),
                )),
                // المستوى
                DataCell(Text(plan.arLevel, style: DesktopTextStyles.body)),
                // الفصل
                DataCell(Text(plan.arSemester, style: DesktopTextStyles.body)),
                // ساعات فعلية
                DataCell(Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(plan.semesterTotals.totalActualHours.toString(),
                      style: const TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold)),
                )),
                // ساعات معتمدة
                DataCell(Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: DesktopColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(plan.semesterTotals.totalCreditHours.toString(),
                      style: const TextStyle(
                          color: DesktopColors.primary,
                          fontWeight: FontWeight.bold)),
                )),
                // عدد المقررات
                DataCell(Text('${plan.courses.length} مقرر',
                    style:
                        DesktopTextStyles.body.copyWith(color: Colors.teal))),
                // المزامنة
                DataCell(Tooltip(
                  message: plan.isSynced ? 'متزامن' : 'غير متزامن',
                  child: Icon(
                      plan.isSynced ? Icons.cloud_done : Icons.cloud_off,
                      color: plan.isSynced ? Colors.green : Colors.grey,
                      size: 20),
                )),
                // إجراءات
                DataCell(PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'view') {
                      showDialog(
                        context: context,
                        builder: (_) => ViewStudyPlanDialog(
                            plan: plan, viewModel: _viewModel),
                      );
                    } else if (value == 'edit') {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => EditStudyPlanDialog(
                            plan: plan, viewModel: _viewModel),
                      );
                    } else if (value == 'delete') {
                      _showDeleteConfirm(context, plan);
                    } else if (value == 'export') {
                      try {
                        final csv = buildStudyPlanCsv(
                          plan,
                          programName: _viewModel.programName(plan.programId),
                          trackName: _viewModel.trackName(
                              plan.programId, plan.trackId),
                        );
                        final fileName = buildCsvFileName(plan);
                        downloadCsvFile(csv, fileName);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('✅ تم تصدير الخطة بصيغة CSV: $fileName'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      } catch (e) {
                        debugPrint('CSV Export Error: $e');
                        final msg = e.toString().contains('Read-only') ||
                                e.toString().contains('Permission')
                            ? '❌ تعذّر الحفظ: تأكد من منح التطبيق صلاحية الوصول للتخزين'
                            : '❌ فشل التصدير: $e';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(children: [
                        Icon(Icons.visibility, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text('عرض', style: TextStyle(color: Colors.blue)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Text('تعديل', style: TextStyle(color: Colors.orange)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'export',
                      child: Row(children: [
                        Icon(Icons.download_outlined,
                            color: Colors.teal, size: 18),
                        SizedBox(width: 8),
                        Text('تصدير CSV', style: TextStyle(color: Colors.teal)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('حذف', style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
        );
      }),
    );
  }

  void _showDeleteConfirm(BuildContext context, plan) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
            'هل أنت متأكد من حذف الخطة الدراسية "${plan.arLevel} - ${plan.arSemester}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              _viewModel.deletePlan(plan.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('تم حذف الخطة الدراسية بنجاح'),
                    backgroundColor: Colors.red),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
