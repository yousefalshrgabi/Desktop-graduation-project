import 'package:academic_affairs_management/features/schedule_screen/models/timetable_entry.dart';
import 'package:academic_affairs_management/features/schedule_screen/services/timetable_firestore_service.dart';
import 'package:academic_affairs_management/features/schedule_screen/services/teacher_alias_service.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/app_session.dart';
import '../services/course_study_plan_service.dart';
import '../models/course_study_plan_model.dart';
import 'mobile_course_study_plan_editor_screen.dart';

class MobileCourseStudyPlanListScreen extends StatefulWidget {
  const MobileCourseStudyPlanListScreen({super.key});

  @override
  State<MobileCourseStudyPlanListScreen> createState() =>
      _MobileCourseStudyPlanListScreenState();
}

class _MobileCourseStudyPlanListScreenState
    extends State<MobileCourseStudyPlanListScreen> {
  final _session = AppSession();
  final _timetableService = TimetableFirestoreService();
  final _planService = CourseStudyPlanService();

  bool _loading = true;
  List<TimetableEntry> _courses = [];
  Map<String, CourseStudyPlanSubmission> _submissions = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final entries = await _timetableService.getByCollegeCachedFirst(
        _session.userCollege,
      );
      
      final aliases = await TeacherAliasService().getAliasesForCollege(_session.userCollege);
      final myName = _session.userName.trim().toLowerCase();

      final matchingAliases = aliases
          .where((a) => a.canonicalName.trim().toLowerCase() == myName)
          .map((a) => a.aliasName.trim().toLowerCase())
          .toSet();

      final myEntries = entries.where((e) {
        return e.teachers.any((t) {
          final teacherName = t.trim().toLowerCase();
          return teacherName == myName || matchingAliases.contains(teacherName);
        });
      }).toList();

      // Get unique courses
      final Map<String, TimetableEntry> uniqueCourses = {};
      for (final e in myEntries) {
        if (e.subject.isNotEmpty) {
          uniqueCourses[e.subject] = e;
        }
      }

      final coursesList = uniqueCourses.values.toList();
      coursesList.sort((a, b) => a.subject.compareTo(b.subject));

      // Load submissions for these courses
      final Map<String, CourseStudyPlanSubmission> submissionsMap = {};
      for (final course in coursesList) {
        final sub = await _planService.loadSubmission(
          facultyDocId: _session.userId,
          courseId: course.subject,
        );
        if (sub != null) {
          submissionsMap[course.subject] = sub;
        }
      }

      if (mounted) {
        setState(() {
          _courses = coursesList;
          _submissions = submissionsMap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء جلب المقررات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: _loadData,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _courses.isEmpty
                ? const Center(
                    child: Text('لم يتم العثور على مقررات مسندة إليك.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _courses.length,
                    itemBuilder: (context, index) {
                      final course = _courses[index];
                      final sub = _submissions[course.subject];
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
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    statusInfo.icon,
                                    size: 16,
                                    color: statusInfo.color,
                                  ),
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
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary,
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
                                builder: (context) =>
                                    MobileCourseStudyPlanEditorScreen(
                                  facultyDocId: _session.userId,
                                  facultyName: _session.userName,
                                  courseId: course.subject,
                                  courseName: course.subject,
                                  collegeName: _session.userCollege,
                                  departmentName: _session.userDepartment,
                                  studentSets: course.studentSets.join(', '),
                                ),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
