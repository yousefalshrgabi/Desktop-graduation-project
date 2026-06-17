import 'package:flutter/material.dart';

import '../../../../core/services/app_session.dart';
import '../../../../core/theme/desktop_theme.dart';
import '../models/course_study_plan_model.dart';
import '../services/course_study_plan_service.dart';
import 'mobile_course_study_plan_editor_screen.dart';

class MobileCourseProgressTrackingScreen extends StatefulWidget {
  const MobileCourseProgressTrackingScreen({super.key});

  @override
  State<MobileCourseProgressTrackingScreen> createState() =>
      _MobileCourseProgressTrackingScreenState();
}

class _MobileCourseProgressTrackingScreenState
    extends State<MobileCourseProgressTrackingScreen> {
  final _session = AppSession();
  final _service = CourseStudyPlanService();

  String? _selectedCollege;
  String? _selectedDepartment;
  List<CourseStudyPlanSubmission> _submissions = [];
  bool _exporting = false;

  late final Stream<List<CourseStudyPlanSubmission>> _stream;
  late final bool _canSeeAllDepartments;

  @override
  void initState() {
    super.initState();
    _canSeeAllDepartments =
        _session.isAdminOrDeanship || _session.isViceDean || _session.isDean;
    final defaultDepartment =
        _canSeeAllDepartments ? null : _session.userDepartment;

    final String? defaultCollege = _session.isAdminOrDeanship ? null : _session.userCollege;

    _stream = _service.watchSubmissions(
      collegeName: defaultCollege,
      departmentName: defaultDepartment,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('متابعة إنجاز المقررات'),
          backgroundColor: DesktopColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download),
              tooltip: 'تصدير تقرير الإنجاز CSV',
              onPressed: _exporting ? null : _exportReport,
            ),
          ],
        ),
        body: StreamBuilder<List<CourseStudyPlanSubmission>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('حدث خطأ: ${snapshot.error}'));
            }

            var allData = snapshot.data ?? [];

            // استخراج الخيارات المتاحة للفلترة
            final colleges = allData.map((e) => e.collegeName).toSet().toList()..sort();
            var deptSource = allData;
            if (_selectedCollege != null) {
              deptSource = deptSource.where((e) => e.collegeName == _selectedCollege).toList();
            }
            final depts = deptSource.map((e) => e.departmentName).toSet().toList()..sort();

            var list = allData;
            if (_session.isAdminOrDeanship && _selectedCollege != null) {
              list = list.where((e) => e.collegeName == _selectedCollege).toList();
            }
            if (_canSeeAllDepartments && _selectedDepartment != null) {
              list = list.where((e) => e.departmentName == _selectedDepartment).toList();
            }

            // تصفية الحالات حسب مستوى الصلاحية لعدم إزعاج المسؤولين بمسودات وخطط لم تصلهم بعد
                  list = list.where((sub) {
                    final s = sub.status;
                    if (s == 'approved' || s == 'rejected') return true;

                    if (_session.isAdminOrDeanship) {
                      return s == 'pending_academic_affairs';
                    } else if (_session.isDean) {
                      return s == 'pending_dean' || s == 'pending_academic_affairs';
                    } else if (_session.isViceDean) {
                      return s == 'pending_vice_dean' || s == 'pending_dean' || s == 'pending_academic_affairs';
                    } else if (_session.isDeptHead) {
                      return s != 'draft';
                    }
                    return true;
                  }).toList();

                  _submissions = list;

                  Widget content;
                  if (_submissions.isEmpty) {
                    content = const Center(
                        child: Text('لا توجد خطط مقررات مسجلة حتى الآن.'));
                  } else {
                    content = ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _submissions.length,
                    itemBuilder: (context, index) {
                      final sub = _submissions[index];
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
                                    MobileCourseStudyPlanEditorScreen(
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
                      if (_canSeeAllDepartments)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              if (_session.isAdminOrDeanship) ...[
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: 'تصفية حسب الكلية',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.business),
                                    ),
                                    value: colleges.contains(_selectedCollege) ? _selectedCollege : null,
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text('الكل')),
                                      ...colleges.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedCollege = val;
                                        _selectedDepartment = null;
                                      });
                                    },
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
                                  value: depts.contains(_selectedDepartment) ? _selectedDepartment : null,
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('الكل')),
                                    ...depts.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedDepartment = val;
                                    });
                                  },
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
  }

  Future<void> _exportReport() async {
    if (_submissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات للتصدير')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      await _service.exportProgressSummaryTable(_submissions);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير التقرير بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التصدير: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
