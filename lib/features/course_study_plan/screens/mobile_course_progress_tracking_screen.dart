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

  String _filterDepartment = '';
  List<CourseStudyPlanSubmission> _submissions = [];
  bool _exporting = false;

  late final Stream<List<CourseStudyPlanSubmission>> _stream;
  late final bool _canSeeAllDepartments;

  @override
  void initState() {
    super.initState();
    _canSeeAllDepartments = _session.isAdminOrDeanship ||
        _session.isViceDean ||
        _session.isDean;
    final defaultDepartment =
        _canSeeAllDepartments ? null : _session.userDepartment;

    _stream = _service.watchSubmissions(
      collegeName: _session.userCollege,
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
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download),
              tooltip: 'تصدير تقرير الإنجاز CSV',
              onPressed: _exporting ? null : _exportReport,
            ),
          ],
        ),
        body: Column(
          children: [
            if (_canSeeAllDepartments)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'تصفية حسب القسم (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _filterDepartment = value.trim();
                    });
                  },
                ),
              ),
            Expanded(
              child: StreamBuilder<List<CourseStudyPlanSubmission>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                  }

                  var list = snapshot.data ?? [];

                  if (_canSeeAllDepartments && _filterDepartment.isNotEmpty) {
                    final query = _filterDepartment.toLowerCase();
                    list = list.where((sub) {
                      return sub.departmentName.toLowerCase().contains(query);
                    }).toList();
                  }

                  _submissions = list;

                  if (_submissions.isEmpty) {
                    return const Center(child: Text('لا توجد خطط مقررات مسجلة حتى الآن.'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _submissions.length,
                    itemBuilder: (context, index) {
                      final sub = _submissions[index];
                      final percent = sub.completionPercent;
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('الدكتور: ${sub.facultyName} | القسم: ${sub.departmentName}'),
                                const SizedBox(height: 12),
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
                                    Text('%$percent (${sub.completedTopics}/${sub.totalTopics})'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      sub.status == 'submitted' ? Icons.check_circle : Icons.pending,
                                      size: 14,
                                      color: sub.status == 'submitted' ? Colors.green : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      sub.status == 'submitted' ? 'تم الرفع' : 'مسودة',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: sub.status == 'submitted' ? Colors.green : Colors.orange,
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
                },
              ),
            ),
          ],
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
