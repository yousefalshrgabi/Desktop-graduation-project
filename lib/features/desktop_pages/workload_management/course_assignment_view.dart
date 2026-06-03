import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'workload_viewmodel.dart';
import '../study_plans_ui/study_plans_model.dart';

class CourseAssignmentView extends StatelessWidget {
  const CourseAssignmentView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WorkloadViewModel(),
      child: const _CourseAssignmentContent(),
    );
  }
}

class _CourseAssignmentContent extends StatefulWidget {
  const _CourseAssignmentContent({Key? key}) : super(key: key);

  @override
  _CourseAssignmentContentState createState() => _CourseAssignmentContentState();
}

class _CourseAssignmentContentState extends State<_CourseAssignmentContent> {
  StudyPlanModel? selectedPlan;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WorkloadViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ربط المقررات بأعضاء هيئة التدريس'),
        centerTitle: true,
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlanSelector(viewModel),
                  const SizedBox(height: 20),
                  Expanded(
                    child: selectedPlan == null
                        ? const Center(child: Text('الرجاء اختيار الخطة الدراسية أولاً'))
                        : _buildCoursesList(viewModel),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanSelector(WorkloadViewModel viewModel) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Text('الخطة الدراسية:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<StudyPlanModel>(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: const Text('اختر الخطة...'),
                value: selectedPlan,
                items: viewModel.studyPlans.map((plan) {
                  return DropdownMenuItem(
                    value: plan,
                    child: Text('${plan.arLevel} - ${plan.arSemester}'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedPlan = val;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesList(WorkloadViewModel viewModel) {
    final courses = selectedPlan!.courses;

    if (courses.isEmpty) {
      return const Center(child: Text('لا توجد مقررات في هذه الخطة.'));
    }

    return ListView.builder(
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        // Check if already assigned
        final assignment = viewModel.assignments.where((a) => a.planId == selectedPlan!.id && a.courseId == course.courseId).firstOrNull;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(course.arCourseType),
            subtitle: Text('نظري: ${course.courseHours.actual.theoretical} | عملي: ${course.courseHours.actual.practical}'),
            trailing: assignment != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('مكلف إلى: ${assignment.facultyMemberName}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => viewModel.removeAssignment(assignment.id),
                      )
                    ],
                  )
                : ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('تكليف'),
                    onPressed: () => _showAssignDialog(context, viewModel, course),
                  ),
          ),
        );
      },
    );
  }

  void _showAssignDialog(BuildContext context, WorkloadViewModel viewModel, StudyCourse course) {
    String? selectedFacultyId;
    String? selectedFacultyName;
    int thGroups = 1;
    int prGroups = course.courseHours.actual.practical > 0 ? 1 : 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: Text('تكليف بمقرر: ${course.arCourseType}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'اختر عضو هيئة التدريس', border: OutlineInputBorder()),
                      items: viewModel.facultyMembers.map((member) {
                        return DropdownMenuItem<String>(
                          value: member['id'],
                          child: Text(member['name'] ?? 'بدون اسم'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setStateSB(() {
                          selectedFacultyId = val;
                          selectedFacultyName = viewModel.facultyMembers.firstWhere((m) => m['id'] == val)['name'];
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: thGroups.toString(),
                      decoration: const InputDecoration(labelText: 'عدد المجموعات (النظري)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => thGroups = int.tryParse(val) ?? 1,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: prGroups.toString(),
                      decoration: const InputDecoration(labelText: 'عدد المجموعات (العملي)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      enabled: course.courseHours.actual.practical > 0,
                      onChanged: (val) => prGroups = int.tryParse(val) ?? 0,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () {
                    if (selectedFacultyId != null) {
                      viewModel.assignCourse(
                        plan: selectedPlan!,
                        course: course,
                        facultyMemberId: selectedFacultyId!,
                        facultyMemberName: selectedFacultyName ?? 'Unknown',
                        theoreticalGroups: thGroups,
                        practicalGroups: prGroups,
                      );
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('حفظ التكليف'),
                )
              ],
            );
          }
        );
      },
    );
  }
}
