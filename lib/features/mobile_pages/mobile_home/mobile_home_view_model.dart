import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';

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
    ];

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
