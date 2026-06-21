import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/study_plan.dart';
import '../utils/level_labels.dart';
import '../widgets/study_plan_courses_editor.dart';
import '../widgets/study_plan_delete_dialog.dart';
import 'study_plan_detail_view_model.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';

class StudyPlanDetailView extends StatefulWidget {
  const StudyPlanDetailView({
    super.key,
    required this.planId,
    this.canEdit = false,
  });

  final String planId;
  final bool canEdit;

  @override
  State<StudyPlanDetailView> createState() => _StudyPlanDetailViewState();
}

class _StudyPlanDetailViewState extends State<StudyPlanDetailView> {
  late StudyPlanDetailViewModel _viewModel;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = StudyPlanDetailViewModel(
      planId: widget.planId,
      canEdit: widget.canEdit,
    );
    _viewModel.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteCurrentPlan(StudyPlanSummary summary) async {
    final confirmed = await confirmDeleteStudyPlan(context, summary);
    if (!confirmed || !mounted) return;

    try {
      await _viewModel.deletePlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف خطة «${summary.displayTitle}»')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر الحذف: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<StudyPlanDetailViewModel>(
        builder: (context, vm, child) {
          final summary = vm.summary;

          return Scaffold(
            appBar: SharedDesktopAppBar(
              customTitle: 'تفاصيل الخطة',
              extraActions: [
                IconButton(
                  onPressed: vm.deleting ? null : () => vm.load(),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'تحديث',
                ),
                if (summary != null && widget.canEdit)
                  IconButton(
                    tooltip: 'حذف الخطة بالكامل',
                    onPressed: vm.deleting ? null : () => _deleteCurrentPlan(summary),
                    icon: Icon(Icons.delete_forever_rounded, color: Colors.red.shade100),
                  ),
              ],
            ),
            body: Stack(
              children: [
                vm.loading
                    ? const Center(child: CircularProgressIndicator())
                    : summary == null
                        ? const Center(child: Text('الخطة غير موجودة'))
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      summary.displayTitle,
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    Text(summary.collegeName),
                                    if (summary.trackStartSemester != null)
                                      Text(
                                        'يبدأ اختلاف المسار من ${LevelLabels.semesterLabel(summary.trackStartSemester!)}',
                                      ),
                                    if (summary.planStartYear != null)
                                      Text('بداية الخطة: ${summary.planStartYear}'),
                                    Text(
                                      '${summary.courseCount} مقرر • ${summary.totalCreditHours} ساعة معتمدة',
                                    ),
                                    const SizedBox(height: 8),
                                    if (widget.canEdit)
                                      OutlinedButton.icon(
                                        onPressed: vm.deleting ? null : () => _deleteCurrentPlan(summary),
                                        icon: const Icon(Icons.delete_forever_rounded),
                                        label: const Text('حذف هذه الخطة بالكامل'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red.shade800,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        labelText: 'بحث في المقررات',
                                        border: const OutlineInputBorder(),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.clear_rounded),
                                          onPressed: () {
                                            _searchController.clear();
                                            vm.setSearchQuery('');
                                          },
                                        ),
                                      ),
                                      onChanged: vm.setSearchQuery,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: vm.getGroupedCourses().isEmpty
                                    ? const Center(child: Text('لا توجد مقررات مطابقة'))
                                    : StudyPlanCoursesEditor(
                                        planId: widget.planId,
                                        groupedCourses: vm.getGroupedCourses(),
                                        canEdit: widget.canEdit,
                                      ),
                              ),
                            ],
                          ),
                if (vm.deleting)
                  const ColoredBox(
                    color: Color(0x55000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
