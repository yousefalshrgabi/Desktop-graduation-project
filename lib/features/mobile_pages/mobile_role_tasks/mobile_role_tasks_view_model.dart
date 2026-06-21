import 'package:flutter/material.dart';
import 'package:academic_affairs_management/features/mobile_pages/meetings/meetings_list_view.dart';
import 'package:academic_affairs_management/features/college_management/screens/departments_management_screen.dart';
import 'package:academic_affairs_management/features/college_management/screens/college_faculty_screen.dart';
import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/screens/study_plan_list_screen.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/screens/course_assignment_view.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';

class TaskItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const TaskItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });
}

class MobileRoleTasksViewModel extends ChangeNotifier {
  final String role;
  final Function(int)? onTabChange;
  final void Function(Widget)? onNavigate;

  MobileRoleTasksViewModel({
    required this.role,
    this.onTabChange,
    this.onNavigate,
  });

  bool get isDean => role == 'dean' || role == 'عميد';
  bool get isViceDean => role == 'vice_dean' || role == 'نائب العميد';
  bool get isDeptHead => role == 'dept_head' || role == 'رئيس قسم';

  String get pageTitle {
    if (isDean) return 'مهام العميد';
    if (isViceDean) return 'مهام نائب العميد';
    if (isDeptHead) return 'مهام رئيس القسم';
    return 'المهام الإدارية';
  }

  List<TaskItem> get tasks {
    if (isDean) {
      return [
        TaskItem(
          title: 'الطلبات والأنصبة',
          subtitle: 'مراجعة طلبات الكلية وأنصبة الأعضاء والبت فيها',
          icon: Icons.inbox_outlined,
          color: const Color(0xFF3B5BDB),
          onTap: () => onTabChange?.call(2), // التوجيه لتبويب الطلبات
        ),
        TaskItem(
          title: 'الموافقة على الخطط الدراسية',
          subtitle: 'مراجعة وتعديل الخطط الدراسية للأقسام',
          icon: Icons.schema_outlined,
          color: const Color(0xFF0CA678),
          onTap: () => onNavigate?.call(
            StudyPlanListScreen(
              initialCollege: AppSession().userCollege.isNotEmpty
                  ? AppSession().userCollege
                  : null,
              lockCollege: true,
              canEdit: true,
            ),
          ),
        ),
        TaskItem(
          title: 'اعتماد محاضر الاجتماعات',
          subtitle: 'مراجعة واعتماد محاضر اجتماعات مجالس الأقسام',
          icon: Icons.rate_review_outlined,
          color: const Color(0xFFE03131),
          onTap: () => onNavigate?.call(const MeetingsListView(forceRole: 'dean')),
        ),
        TaskItem(
          title: 'أعضاء هيئة التدريس بالكلية',
          subtitle: 'استعراض بيانات الأعضاء وإدارتها',
          icon: Icons.supervised_user_circle_outlined,
          color: const Color(0xFF7048E8),
          onTap: () => onNavigate?.call(const CollegeFacultyScreen()),
        ),
      ];
    } else if (isViceDean) {
      return [
        TaskItem(
          title: 'الطلبات والاحتياج الأكاديمي',
          subtitle: 'مراجعة الطلبات ورفع الأنصبة والاحتياج للعميد',
          icon: Icons.request_page_outlined,
          color: const Color(0xFF3B5BDB),
          onTap: () => onTabChange?.call(2), // التوجيه لتبويب الطلبات
        ),
        TaskItem(
          title: 'الإشراف على الخطط الدراسية',
          subtitle: 'متابعة جودة البرامج والمقررات الدراسية',
          icon: Icons.school_outlined,
          color: const Color(0xFF0CA678),
          onTap: () => onNavigate?.call(
            StudyPlanListScreen(
              initialCollege: AppSession().userCollege.isNotEmpty
                  ? AppSession().userCollege
                  : null,
              lockCollege: true,
              canEdit: true,
            ),
          ),
        ),
        TaskItem(
          title: 'ربط المقررات والأنصبة',
          subtitle: 'إسناد المقررات لمدرسي النظري والعملي',
          icon: Icons.assignment_ind_outlined,
          color: const Color(0xFF099268),
          onTap: () => onNavigate?.call(
            CourseAssignmentView(
              initialCollege: AppSession().userCollege.isNotEmpty
                  ? AppSession().userCollege
                  : 'كلية الحاسبات',
              lockCollege: true,
              canEdit: true,
            ),
          ),
        ),
        TaskItem(
          title: 'مراجعة محاضر الاجتماعات',
          subtitle: 'مراجعة وتمرير محاضر اجتماعات الأقسام للعميد',
          icon: Icons.rate_review_outlined,
          color: const Color(0xFF7048E8),
          onTap: () => onNavigate?.call(const MeetingsListView(forceRole: 'vice_dean')),
        ),
        TaskItem(
          title: 'جداول المحاضرات',
          subtitle: 'مراجعة وتنسيق الجداول الدراسية للكلية',
          icon: Icons.calendar_month_outlined,
          color: const Color(0xFFF59F00),
          onTap: () => onTabChange?.call(3), // تبويب الجداول
        ),
        TaskItem(
          title: 'إدارة الأقسام العلمية',
          subtitle: 'عرض وإدارة أقسام الكلية وتعيين رؤسائها',
          icon: Icons.account_tree_outlined,
          color: const Color(0xFF099268),
          onTap: () => onNavigate?.call(const DepartmentsManagementScreen()),
        ),
        TaskItem(
          title: 'أعضاء هيئة التدريس بالكلية',
          subtitle: 'استعراض بيانات الأعضاء وطلب تحديثها',
          icon: Icons.people_alt_outlined,
          color: const Color(0xFFE03131),
          onTap: () => onNavigate?.call(const CollegeFacultyScreen()),
        ),
      ];
    } else if (isDeptHead) {
      return [
        TaskItem(
          title: 'الطلبات',
          subtitle: 'رفع ومراجعة طلبات أعضاء القسم',
          icon: Icons.request_page_outlined,
          color: const Color(0xFF3B5BDB),
          onTap: () => onTabChange?.call(2), // التوجيه لتبويب الطلبات
        ),
        TaskItem(
          title: 'جدول القسم',
          subtitle: 'تنظيم ومتابعة الجداول الدراسية للقسم',
          icon: Icons.table_chart_outlined,
          color: const Color(0xFF0CA678),
          onTap: () => onTabChange?.call(3),
        ),
        TaskItem(
          title: 'اجتماعات القسم',
          subtitle: 'تنظيم وتوثيق اجتماعات مجلس القسم',
          icon: Icons.meeting_room_outlined,
          color: const Color(0xFFF59F00),
          onTap: () => onNavigate?.call(const MeetingsListView(forceRole: 'dept_head')),
        ),
        TaskItem(
          title: 'الخطة الدراسية للقسم',
          subtitle: 'مراجعة وتطوير الخطة الدراسية',
          icon: Icons.auto_stories_outlined,
          color: const Color(0xFFE03131),
          onTap: () async {
            String? deptName;
            if (AppSession().userDepartment.isNotEmpty) {
              final db = await DatabaseHelper.instance.database;
              final res = await db.query(
                'departments',
                where: 'id = ?',
                whereArgs: [AppSession().userDepartment],
              );
              if (res.isNotEmpty) {
                deptName = res.first['name'].toString();
              } else {
                deptName = AppSession().userDepartment;
              }
            }

            onNavigate?.call(
              StudyPlanListScreen(
                initialCollege: AppSession().userCollege.isNotEmpty
                    ? AppSession().userCollege
                    : null,
                lockCollege: true,
                initialProgram: deptName,
                lockProgram: true,
                canEdit: false,
              ),
            );
          },
        ),
      ];
    }
    return [];
  }
}
