import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/desktop_theme.dart';
import '../models/course_study_plan_model.dart';
import '../mobile_course_study_plan_editor/mobile_course_study_plan_editor_view.dart';
import 'mobile_course_progress_tracking_view_model.dart';

class MobileCourseProgressTrackingView extends StatefulWidget {
  const MobileCourseProgressTrackingView({super.key});

  @override
  State<MobileCourseProgressTrackingView> createState() =>
      _MobileCourseProgressTrackingViewState();
}

class _MobileCourseProgressTrackingViewState
    extends State<MobileCourseProgressTrackingView> {
  late MobileCourseProgressTrackingViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = MobileCourseProgressTrackingViewModel();
  }

  Future<void> _exportReport() async {
    try {
      await _viewModel.exportReport();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير التقرير بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التصدير: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<MobileCourseProgressTrackingViewModel>(
        builder: (context, vm, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('متابعة إنجاز المقررات'),
                backgroundColor: DesktopColors.primary,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: vm.exporting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download),
                    tooltip: 'تصدير تقرير الإنجاز CSV',
                    onPressed: vm.exporting ? null : _exportReport,
                  ),
                ],
              ),
              body: StreamBuilder<List<CourseStudyPlanSubmission>>(
                stream: vm.stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                  }

                  var allData = snapshot.data ?? [];
                  vm.filterSubmissions(allData);

                  // استخراج الخيارات المتاحة للفلترة
                  final colleges = allData.map((e) => e.collegeName).toSet().toList()..sort();
                  var deptSource = allData;
                  if (vm.selectedCollege != null) {
                    deptSource = deptSource.where((e) => e.collegeName == vm.selectedCollege).toList();
                  }
                  final depts = deptSource.map((e) => e.departmentName).toSet().toList()..sort();

                  Widget content;
                  if (vm.submissions.isEmpty) {
                    content = const Center(
                        child: Text('لا توجد خطط مقررات مسجلة حتى الآن.'));
                  } else {
                    content = ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: vm.submissions.length,
                      itemBuilder: (context, index) {
                        final sub = vm.submissions[index];
                        final percent = sub.completionPercent;
                        final statusInfo = switch (sub.status) {
                          'draft' => (
                              icon: Icons.edit_document,
                              color: Colors.orange,
                              text: 'مسودة'
                            ),
                          'pending_dept_head' => (
                              icon: Icons.pending,
                              color: Colors.blue,
                              text: 'بانتظار رئيس القسم'
                            ),
                          'pending_vice_dean' => (
                              icon: Icons.pending,
                              color: Colors.blue,
                              text: 'بانتظار نائب العميد'
                            ),
                          'pending_dean' => (
                              icon: Icons.pending,
                              color: Colors.blue,
                              text: 'بانتظار العميد'
                            ),
                          'pending_academic_affairs' => (
                              icon: Icons.pending,
                              color: Colors.blue,
                              text: 'بانتظار النيابة'
                            ),
                          'approved' => (
                              icon: Icons.check_circle,
                              color: Colors.green,
                              text: 'معتمدة'
                            ),
                          'rejected' => (
                              icon: Icons.cancel,
                              color: Colors.red,
                              text: 'مرفوضة'
                            ),
                          _ => (
                              icon: Icons.help_outline,
                              color: Colors.grey,
                              text: 'غير معروف'
                            ),
                        };

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MobileCourseStudyPlanEditorView(
                                    facultyDocId: sub.facultyDocId,
                                    facultyName: sub.facultyName,
                                    courseId: sub.courseId,
                                    courseName: sub.courseName,
                                    collegeName: sub.collegeName,
                                    departmentName: sub.departmentName,
                                    studentSets: sub.programName,
                                    isReadOnly: true,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          sub.courseName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios,
                                          size: 14, color: Colors.grey),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      'الدكتور: ${sub.facultyName} | القسم: ${sub.departmentName}'),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: percent / 100,
                                          backgroundColor: Colors.grey.shade200,
                                          color: percent == 100
                                              ? Colors.green
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                          '%$percent (${sub.completedTopics}/${sub.totalTopics})'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        statusInfo.icon,
                                        size: 14,
                                        color: statusInfo.color,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        statusInfo.text,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: statusInfo.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }

                  return Column(
                    children: [
                      if (vm.canSeeAllDepartments)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              if (vm.isAdminOrDeanship) ...[
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: 'تصفية حسب الكلية',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.business),
                                    ),
                                    value: colleges.contains(vm.selectedCollege) ? vm.selectedCollege : null,
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text('الكل')),
                                      ...colleges.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                                    ],
                                    onChanged: vm.selectCollege,
                                  ),
                                ),
                                const SizedBox(width: 16),
                              ],
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'تصفية حسب القسم',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.account_tree),
                                  ),
                                  value: depts.contains(vm.selectedDepartment) ? vm.selectedDepartment : null,
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('الكل')),
                                    ...depts.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                                  ],
                                  onChanged: vm.selectDepartment,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(child: content),
                    ],
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
