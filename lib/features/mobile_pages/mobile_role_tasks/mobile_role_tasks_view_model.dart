import 'package:flutter/material.dart';
import 'package:academic_affairs_management/features/mobile_pages/meetings/meetings_list_view.dart';
import 'package:academic_affairs_management/features/college_management/screens/departments_management_screen.dart';
import 'package:academic_affairs_management/features/college_management/screens/college_faculty_screen.dart';

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
          title: 'مراجعة الطلبات الواردة',
          subtitle: 'مراجعة طلبات أعضاء الكلية والبت فيها',
          icon: Icons.inbox_outlined,
          color: const Color(0xFF3B5BDB),
        ),
        TaskItem(
          title: 'الموافقة على الخطط الدراسية',
          subtitle: 'مراجعة وتعديل الخطط الدراسية للأقسام',
          icon: Icons.schema_outlined,
          color: const Color(0xFF0CA678),
        ),
        TaskItem(
          title: 'اعتماد محاضر الاجتماعات',
          subtitle: 'مراجعة واعتماد محاضر اجتماعات مجالس الأقسام',
          icon: Icons.rate_review_outlined,
          color: const Color(0xFFE03131),
          onTap: () => onNavigate?.call(const MeetingsListView()),
        ),
        TaskItem(
          title: 'إصدار القرارات الإدارية',
          subtitle: 'إنشاء وإصدار القرارات على مستوى الكلية',
          icon: Icons.gavel_outlined,
          color: const Color(0xFFF59F00),
        ),
        TaskItem(
          title: 'الإشراف على أعضاء الكلية',
          subtitle: 'متابعة شؤون أعضاء هيئة التدريس',
          icon: Icons.supervised_user_circle_outlined,
          color: const Color(0xFF7048E8),
        ),
        TaskItem(
          title: 'تقارير الكلية',
          subtitle: 'مراجعة تقارير الأداء والإنجاز الدورية',
          icon: Icons.bar_chart_outlined,
          color: const Color(0xFFE03131),
        ),
        TaskItem(
          title: 'التنسيق مع الجامعة',
          subtitle: 'التواصل مع إدارة الجامعة والنيابة الأكاديمية',
          icon: Icons.link_outlined,
          color: const Color(0xFF099268),
        ),
      ];
    } else if (isViceDean) {
      return [
        TaskItem(
          title: 'الإشراف على البرامج الأكاديمية',
          subtitle: 'متابعة جودة البرامج والمقررات الدراسية',
          icon: Icons.school_outlined,
          color: const Color(0xFF3B5BDB),
        ),
        TaskItem(
          title: 'مراجعة محاضر الاجتماعات',
          subtitle: 'مراجعة وتمرير محاضر اجتماعات الأقسام للعميد',
          icon: Icons.rate_review_outlined,
          color: const Color(0xFF7048E8),
          onTap: () => onNavigate?.call(const MeetingsListView()),
        ),
        TaskItem(
          title: 'جداول المحاضرات',
          subtitle: 'مراجعة وتنسيق الجداول الدراسية للكلية',
          icon: Icons.calendar_month_outlined,
          color: const Color(0xFF0CA678),
          onTap: () => onTabChange?.call(3), // تبويب الجداول
        ),
        TaskItem(
          title: 'الشؤون الأكاديمية للطلاب',
          subtitle: 'متابعة الشؤون الأكاديمية وحالات الطلاب',
          icon: Icons.people_outline,
          color: const Color(0xFFF59F00),
        ),
        TaskItem(
          title: 'تقارير الأداء الأكاديمي',
          subtitle: 'إعداد ومراجعة تقارير الأداء الأكاديمي',
          icon: Icons.analytics_outlined,
          color: const Color(0xFF7048E8),
        ),
        TaskItem(
          title: 'الاعتراضات الأكاديمية',
          subtitle: 'دراسة ومعالجة اعتراضات الطلاب والأعضاء',
          icon: Icons.balance_outlined,
          color: const Color(0xFFE03131),
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
          title: 'إدارة أعضاء القسم',
          subtitle: 'متابعة شؤون أعضاء هيئة التدريس في القسم',
          icon: Icons.people_outline,
          color: const Color(0xFF3B5BDB),
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
          onTap: () => onNavigate?.call(const MeetingsListView()),
        ),
        TaskItem(
          title: 'طلبات القسم',
          subtitle: 'مراجعة والبت في طلبات أعضاء القسم',
          icon: Icons.request_page_outlined,
          color: const Color(0xFF7048E8),
        ),
        TaskItem(
          title: 'الخطة الدراسية للقسم',
          subtitle: 'مراجعة وتطوير الخطة الدراسية',
          icon: Icons.auto_stories_outlined,
          color: const Color(0xFFE03131),
        ),
        TaskItem(
          title: 'تقرير القسم',
          subtitle: 'إعداد التقارير الدورية للقسم',
          icon: Icons.summarize_outlined,
          color: const Color(0xFF099268),
        ),
      ];
    }
    return [];
  }
}
