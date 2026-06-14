import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import '../../schedule_screen/screens/teachers_schedule_screen.dart';
import '../../course_study_plan/screens/mobile_study_plan_template_settings_screen.dart';
import '../../course_study_plan/screens/mobile_course_study_plan_list_screen.dart';
import '../../course_study_plan/screens/mobile_course_progress_tracking_screen.dart';

class QuickActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const QuickActionItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class MobileHomeViewModel extends ChangeNotifier {
  final AppSession _session = AppSession();

  AppSession get session => _session;

  String get userName => _session.userName;
  String get roleDisplayName => _session.roleDisplayName;
  String get userCollege => _session.userCollege;
  String get userDepartment => _session.userDepartment;

  List<QuickActionItem> buildQuickActions(BuildContext context, Function(int) onTabChange) {
    final List<QuickActionItem> actions = [
      QuickActionItem(
        label: 'ملفي الشخصي',
        icon: Icons.person_outlined,
        color: const Color(0xFF3B5BDB),
        onTap: () => onTabChange(1), // الانتقال لتبويب الملف الشخصي (Index 1)
      ),
      QuickActionItem(
        label: 'طلباتي',
        icon: Icons.request_page_outlined,
        color: const Color(0xFF0CA678),
        onTap: () => onTabChange(2), // الانتقال لتبويب الطلبات (Index 2)
      ),
      QuickActionItem(
        label: 'طلب تعديل',
        icon: Icons.edit_note_outlined,
        color: const Color(0xFFF59F00),
        onTap: () => onTabChange(1), // الانتقال لتبويب الملف الشخصي لطلب التعديل
      ),
      QuickActionItem(
        label: 'الجداول',
        icon: Icons.calendar_today_outlined,
        color: const Color(0xFF7048E8),
        onTap: () => onTabChange(3), // الانتقال لتبويب الجداول (Index 3)
      ),
      QuickActionItem(
        label: 'الساعات الزائدة',
        icon: Icons.more_time,
        color: const Color(0xFFE64980),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeachersScheduleScreen(
                  collegeName: _session.userCollege.isNotEmpty
                      ? _session.userCollege
                      : null),
            ),
          );
        },
      ),
      QuickActionItem(
        label: 'الساعات الموازية',
        icon: Icons.timer_outlined,
        color: const Color(0xFF15AABF),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeachersScheduleScreen(
                  collegeName: _session.userCollege.isNotEmpty
                      ? _session.userCollege
                      : null),
            ),
          );
        },
      ),
    ];

    if (_session.isMemberOnly || _session.hasMobileRoleWithExtras) {
      actions.add(QuickActionItem(
        label: 'خطط المقررات',
        icon: Icons.menu_book_outlined,
        color: const Color(0xFF228BE6),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MobileCourseStudyPlanListScreen(),
            ),
          );
        },
      ));
    }

    if (_session.hasMobileRoleWithExtras) {
      actions.add(QuickActionItem(
        label: 'متابعة الخطط',
        icon: Icons.analytics_outlined,
        color: const Color(0xFFF03E3E),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MobileCourseProgressTrackingScreen(),
            ),
          );
        },
      ));
    }

    if (_session.isViceDean) {
      actions.add(QuickActionItem(
        label: 'إعداد كليشة الخطط',
        icon: Icons.settings_applications_outlined,
        color: const Color(0xFF4C6EF5),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MobileStudyPlanTemplateSettingsScreen(),
            ),
          );
        },
      ));
    }

    // إضافة زر سريع لكل دور إضافي (قد يكون أكثر من دور)
    const roleColors = [
      Color(0xFF7048E8),
      Color(0xFF0CA678),
      Color(0xFFF59F00),
    ];
    final extraRoles = _session.extraRoleKeys;
    for (int i = 0; i < extraRoles.length; i++) {
      final roleKey = extraRoles[i];
      final color = roleColors[i % roleColors.length];
      final int tabIndex = 4 + i; // الاندكس يبدأ من 4 للأدوار الإضافية

      actions.add(
        QuickActionItem(
          label: _session.roleKeyToLabel(roleKey),
          icon: Icons.admin_panel_settings_outlined,
          color: color,
          onTap: () => onTabChange(tabIndex),
        ),
      );
    }

    return actions;
  }
}
