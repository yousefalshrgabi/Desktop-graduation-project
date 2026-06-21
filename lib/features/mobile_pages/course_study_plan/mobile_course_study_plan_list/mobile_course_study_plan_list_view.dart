import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'mobile_course_study_plan_list_view_model.dart';
import '../../../../core/theme/desktop_theme.dart';
import '../mobile_course_study_plan_editor/mobile_course_study_plan_editor_view.dart';

class MobileCourseStudyPlanListView extends StatefulWidget {
  const MobileCourseStudyPlanListView({super.key});

  @override
  State<MobileCourseStudyPlanListView> createState() => _MobileCourseStudyPlanListViewState();
}

class _MobileCourseStudyPlanListViewState extends State<MobileCourseStudyPlanListView> {
  late MobileCourseStudyPlanListViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = MobileCourseStudyPlanListViewModel();
    _viewModel.loadData();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<MobileCourseStudyPlanListViewModel>(
        builder: (context, vm, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('مقرراتي وخطط السير'),
                backgroundColor: DesktopColors.primary,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => vm.loadData(),
                  ),
                ],
              ),
              body: vm.loading
                  ? const Center(child: CircularProgressIndicator())
                  : vm.courses.isEmpty
                      ? const Center(child: Text('لم يتم العثور على مقررات مسندة إليك.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: vm.courses.length,
                          itemBuilder: (context, index) {
                            final course = vm.courses[index];
                            final sub = vm.submissions[course.subject];
                            final percent = sub?.completionPercent ?? 0;

                            final statusInfo = switch (sub?.status) {
                              'draft' => (icon: Icons.edit_document, color: Colors.orange, text: 'مسودة'),
                              'pending_dept_head' => (icon: Icons.pending, color: Colors.blue, text: 'بانتظار رئيس القسم'),
                              'pending_vice_dean' => (icon: Icons.pending, color: Colors.blue, text: 'بانتظار نائب العميد'),
                              'pending_dean' => (icon: Icons.pending, color: Colors.blue, text: 'بانتظار العميد'),
                              'pending_academic_affairs' => (icon: Icons.pending, color: Colors.blue, text: 'بانتظار النيابة'),
                              'approved' => (icon: Icons.check_circle, color: Colors.green, text: 'معتمدة'),
                              'rejected' => (icon: Icons.cancel, color: Colors.red, text: 'مرفوضة'),
                              null => (icon: Icons.add_circle_outline, color: Colors.grey, text: 'جديد (لم يتم الإنشاء)'),
                              _ => (icon: Icons.help_outline, color: Colors.grey, text: 'غير معروف'),
                            };

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  course.subject,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(statusInfo.icon, size: 16, color: statusInfo.color),
                                        const SizedBox(width: 4),
                                        Text(
                                          statusInfo.text,
                                          style: TextStyle(
                                            color: statusInfo.color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: percent / 100,
                                            backgroundColor: Colors.grey.shade200,
                                            color: percent == 100
                                                ? Colors.green
                                                : Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text('%$percent إنجاز'),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MobileCourseStudyPlanEditorView(
                                        facultyDocId: vm.userId,
                                        facultyName: vm.userName,
                                        courseId: course.subject,
                                        courseName: course.subject,
                                        collegeName: vm.userCollege,
                                        departmentName: vm.userDepartment,
                                        studentSets: course.studentSets.join(', '),
                                      ),
                                    ),
                                  );
                                  vm.loadData();
                                },
                              ),
                            );
                          },
                        ),
            ),
          );
        },
      ),
    );
  }
}
