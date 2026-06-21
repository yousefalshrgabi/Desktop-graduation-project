import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/level_labels.dart';
import '../widgets/study_plan_course_table.dart';
import 'study_plan_upload_view_model.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';

class StudyPlanUploadView extends StatefulWidget {
  const StudyPlanUploadView({
    super.key,
    this.initialCollege = 'كلية الحاسبات',
    this.canEdit = false,
    this.lockCollege = false,
  });

  final String initialCollege;
  final bool canEdit;
  final bool lockCollege;

  @override
  State<StudyPlanUploadView> createState() => _StudyPlanUploadViewState();
}

class _StudyPlanUploadViewState extends State<StudyPlanUploadView> {
  late StudyPlanUploadViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = StudyPlanUploadViewModel(
      initialCollege: widget.initialCollege,
      canEdit: widget.canEdit,
      lockCollege: widget.lockCollege,
    );
    _viewModel.loadColleges();
  }

  @override
  void dispose() {
    _viewModel.disposeControllers();
    super.dispose();
  }

  Future<void> _uploadPreview() async {
    final previewPlan = _viewModel.preview;
    if (previewPlan == null) return;
    final plan = _viewModel.planWithCurrentFields(previewPlan);
    if (plan.collegeName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار أو إدخال اسم الكلية أولاً.'),
        ),
      );
      return;
    }

    if ((plan.trackName ?? '').trim().isNotEmpty && plan.trackStartSemester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدد المستوى الذي يبدأ منه اختلاف المسارات'),
        ),
      );
      return;
    }

    final hasReplacement = await _viewModel.confirmTrackReplacements(plan);
    if (hasReplacement) {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('المسار موجود مسبقًا'),
          content: Text(
            'سيؤدي الحفظ إلى استبدال بيانات المسار التالي:\n\n• ${plan.displayTitle}\n\n'
            'تأكد أن اسم المسار صحيح قبل المتابعة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('استبدال المسار'),
            ),
          ],
        ),
      );
      if (confirm != true) {
        return;
      }
    }

    try {
      await _viewModel.savePlan(plan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ الخطة كاملة، مع تخزين المقررات المشتركة مرة واحدة',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل الحفظ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importBundledCsPlans() async {
    try {
      await _viewModel.importBundledCsPlans();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم استيراد خطط دراسية')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الاستيراد: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<StudyPlanUploadViewModel>(
        builder: (context, vm, child) {
          final preview = vm.preview;
          return Scaffold(
            appBar: const SharedDesktopAppBar(customTitle: 'رفع خطة دراسية'),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بيانات الربط',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          if (widget.lockCollege)
                            TextField(
                              controller: vm.collegeController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'الكلية',
                                border: OutlineInputBorder(),
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'الكلية',
                                border: OutlineInputBorder(),
                              ),
                              value: vm.colleges.contains(vm.collegeController.text)
                                  ? vm.collegeController.text
                                  : null,
                              hint: const Text('اختر الكلية من القائمة...'),
                              items: vm.colleges.map((c) {
                                return DropdownMenuItem(value: c, child: Text(c));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  vm.setCollegeText(val);
                                }
                              },
                            ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: vm.programController,
                            decoration: const InputDecoration(
                              labelText: 'اسم البرنامج (يُستنتج من الملف إن تُرك فارغاً)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: vm.trackController,
                            decoration: const InputDecoration(
                              labelText: 'المسار (اختياري — مثل: الشبكات، تطوير البرمجيات)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: vm.onTrackChanged,
                          ),
                          if (vm.trackController.text.trim().isNotEmpty ||
                              (preview?.trackName ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: vm.trackStartSemester,
                              decoration: const InputDecoration(
                                labelText: 'الفصل الذي يبدأ منه اختلاف المسارات',
                                helperText: 'الفصول السابقة تُجمع للبرنامج، ومن هذا الفصل تُفصل حسب المسار',
                                border: OutlineInputBorder(),
                              ),
                              items: List.generate(8, (index) => index + 1)
                                  .map(
                                    (semester) => DropdownMenuItem<int>(
                                      value: semester,
                                      child: Text(
                                        LevelLabels.semesterLabel(semester),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: vm.setTrackStartSemester,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'كل ملف مسار يُحفظ ويُعرض كخطة كاملة. مستوى بداية الاختلاف يحدد متى تُفصل المسارات في الجداول.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: vm.isLoading || !widget.canEdit ? null : vm.pickAndParse,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('اختيار ملف Excel وتحليله'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading || !widget.canEdit ? null : _importBundledCsPlans,
                    icon: const Icon(Icons.cloud_download_rounded),
                    label: const Text('استيراد خطط كلية الحاسبات (من assets)'),
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: vm.isLoading || !widget.canEdit ? null : _uploadPreview,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('حفظ الخطة (محلياً)'),
                    ),
                    const SizedBox(height: 12),
                    ...preview.semesters.map(
                      (s) => Card(
                        child: ExpansionTile(
                          title: Text(s.labelAr),
                          subtitle: Text('${s.courses.length} مقرر'),
                          children: [
                            StudyPlanCourseTable(courses: s.courses, compact: true),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (vm.isLoading) const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(vm.statusMessage, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
