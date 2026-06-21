import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/study_plan.dart';
import '../utils/level_labels.dart';
import '../widgets/study_plan_delete_dialog.dart';
import '../study_plan_detail/study_plan_detail_view.dart';
import '../study_plan_upload/study_plan_upload_view.dart';
import 'study_plan_list_view_model.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';

class StudyPlanListView extends StatefulWidget {
  const StudyPlanListView({
    super.key,
    this.initialCollege,
    this.canEdit = false,
    this.lockCollege = false,
    this.initialProgram,
    this.lockProgram = false,
  });

  final String? initialCollege;
  final bool canEdit;
  final bool lockCollege;
  final String? initialProgram;
  final bool lockProgram;

  @override
  State<StudyPlanListView> createState() => _StudyPlanListViewState();
}

class _StudyPlanListViewState extends State<StudyPlanListView> {
  late StudyPlanListViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = StudyPlanListViewModel(
      initialCollege: widget.initialCollege,
      canEdit: widget.canEdit,
      lockCollege: widget.lockCollege,
      initialProgram: widget.initialProgram,
      lockProgram: widget.lockProgram,
    );
    _viewModel.init();
  }

  Future<void> _deletePlan(StudyPlanSummary plan) async {
    if (!widget.canEdit) return;
    final confirmed = await confirmDeleteStudyPlan(context, plan);
    if (!confirmed || !mounted) return;

    try {
      await _viewModel.deletePlan(plan.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف خطة «${plan.displayTitle}»')),
      );
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

  Future<void> _openPlan(StudyPlanSummary plan) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StudyPlanDetailView(
          planId: plan.id,
          canEdit: widget.canEdit,
        ),
      ),
    );
    if (deleted == true && mounted) {
      _viewModel.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<StudyPlanListViewModel>(
        builder: (context, vm, child) {
          return Scaffold(
            backgroundColor: DesktopColors.background,
            appBar: const SharedDesktopAppBar(),
            body: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        children: [
                          Material(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.offline_bolt_rounded,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'يظهر كل مسار كخطة دراسية كاملة مستقلة، مع تخزين المقررات المشتركة مرة واحدة.',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.lockCollege)
                            TextField(
                              controller: TextEditingController(text: widget.initialCollege),
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'تصفية حسب الكلية',
                                border: OutlineInputBorder(),
                              ),
                            )
                          else
                            DropdownButtonFormField<String?>(
                              decoration: const InputDecoration(
                                labelText: 'تصفية حسب الكلية',
                                border: OutlineInputBorder(),
                              ),
                              value: vm.colleges.contains(vm.collegeFilter) ? vm.collegeFilter : null,
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('الكل (عرض جميع الخطط)'),
                                ),
                                ...vm.colleges.map((c) {
                                  return DropdownMenuItem<String?>(value: c, child: Text(c));
                                }),
                              ],
                              onChanged: vm.deleting ? null : vm.setCollegeFilter,
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: vm.loading
                          ? const Center(child: CircularProgressIndicator())
                          : vm.plans.isEmpty
                              ? const Center(
                                  child: Text(
                                    'لا توجد خطط مرفوعة بعد.\nارفع خطة من شاشة «رفع خطة دراسية».',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : () {
                                  final byCollege = <String, List<StudyPlanSummary>>{};
                                  for (final plan in vm.plans) {
                                    byCollege.putIfAbsent(plan.collegeName, () => []).add(plan);
                                  }

                                  final colleges = byCollege.keys.toList()..sort();
                                  return ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: colleges.length,
                                    itemBuilder: (context, index) {
                                      final college = colleges[index];
                                      final collegePlans = byCollege[college]!
                                        ..sort(
                                          (a, b) => a.displayTitle.compareTo(b.displayTitle),
                                        );
                                      return _CollegePlansCard(
                                        collegeName: college,
                                        plans: collegePlans,
                                        deleting: vm.deleting,
                                        onDelete: _deletePlan,
                                        canEdit: widget.canEdit,
                                        onOpen: _openPlan,
                                      );
                                    },
                                  );
                                }(),
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
            floatingActionButton: widget.canEdit
                ? FloatingActionButton.extended(
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudyPlanUploadView(
                            canEdit: widget.canEdit,
                            lockCollege: widget.lockCollege,
                            initialCollege: widget.initialCollege ?? 'كلية الحاسبات',
                          ),
                        ),
                      );
                      if (result == true) {
                        vm.reload();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة خطة'),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _CollegePlansCard extends StatelessWidget {
  const _CollegePlansCard({
    required this.collegeName,
    required this.plans,
    required this.deleting,
    required this.onDelete,
    required this.onOpen,
    required this.canEdit,
  });

  final String collegeName;
  final List<StudyPlanSummary> plans;
  final bool deleting;
  final ValueChanged<StudyPlanSummary> onDelete;
  final ValueChanged<StudyPlanSummary> onOpen;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final byProgram = <String, List<StudyPlanSummary>>{};
    for (final plan in plans) {
      byProgram.putIfAbsent(plan.programName, () => []).add(plan);
    }
    final programs = byProgram.keys.toList()..sort();
    final visiblePlanCount = byProgram.values.fold<int>(0, (count, items) {
      final tracks = items.where((plan) => (plan.trackName ?? '').trim().isNotEmpty).length;
      return count + (tracks > 0 ? tracks : items.length);
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          collegeName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$visiblePlanCount خطة/مسار'),
        children: programs.map((program) {
          final allProgramPlans = byProgram[program]!;
          final trackPlans = allProgramPlans.where((plan) => (plan.trackName ?? '').trim().isNotEmpty).toList();
          final programPlans = (trackPlans.isNotEmpty ? trackPlans : allProgramPlans)..sort(_sortPlans);
          final trackCount = programPlans.where((plan) => (plan.trackName ?? '').trim().isNotEmpty).length;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: const Icon(Icons.account_tree_rounded),
                title: Text(program),
                subtitle: Text(
                  trackCount == 0 ? 'خطة واحدة' : '$trackCount خطة مسار كاملة',
                ),
                children: programPlans.map((plan) {
                  return _PlanTile(
                    plan: plan,
                    deleting: deleting,
                    onDelete: onDelete,
                    onOpen: onOpen,
                    canEdit: canEdit,
                  );
                }).toList(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static int _sortPlans(StudyPlanSummary a, StudyPlanSummary b) {
    final aTrack = (a.trackName ?? '').trim();
    final bTrack = (b.trackName ?? '').trim();
    if (aTrack.isEmpty && bTrack.isNotEmpty) return -1;
    if (aTrack.isNotEmpty && bTrack.isEmpty) return 1;
    return a.displayTitle.compareTo(b.displayTitle);
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.deleting,
    required this.onDelete,
    required this.onOpen,
    required this.canEdit,
  });

  final StudyPlanSummary plan;
  final bool deleting;
  final ValueChanged<StudyPlanSummary> onDelete;
  final ValueChanged<StudyPlanSummary> onOpen;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final isTrack = (plan.trackName ?? '').trim().isNotEmpty;
    return ListTile(
      leading: CircleAvatar(
        child: Text('${plan.courseCount}'),
      ),
      title: Text(
        isTrack ? 'مسار: ${plan.trackName}' : 'الخطة العامة',
      ),
      subtitle: Text(
        [
          plan.displayTitle,
          if (plan.trackStartSemester != null)
            'يبدأ اختلاف المسار من ${LevelLabels.semesterLabel(plan.trackStartSemester!)}',
          if (plan.planStartYear != null) 'بداية الخطة: ${plan.planStartYear}',
          '${plan.semesterCount} فصل/قسم - ${plan.totalCreditHours} ساعة',
          if (plan.sourceFileName != null) plan.sourceFileName!,
        ].join('\n'),
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canEdit)
            IconButton(
              tooltip: 'حذف الخطة بالكامل',
              icon: Icon(
                Icons.delete_forever_rounded,
                color: Colors.red.shade700,
              ),
              onPressed: deleting ? null : () => onDelete(plan),
            ),
          const Icon(Icons.chevron_left),
        ],
      ),
      onTap: deleting ? null : () => onOpen(plan),
    );
  }
}
