import 'package:academic_affairs_management/main.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'mobile_shell_view_model.dart';
import '../mobile_profile/mobile_profile_view.dart';
import '../mobile_requests/mobile_requests_view.dart';
import '../mobile_role_tasks/mobile_role_tasks_view.dart';
import '../mobile_schedule/mobile_schedule_view.dart';
import '../mobile_home/mobile_home_view.dart';

/// واجهة الموبايل الرئيسية الموحدة لجميع الأدوار (عضو، عميد، نائب عميد، رئيس قسم)
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  final MobileShellViewModel _viewModel = MobileShellViewModel();
  late final List<_NavItem> _navItems;

  @override
  void initState() {
    super.initState();
    _buildNavItems();
  }

  void _buildNavItems() {
    _navItems = [
      _NavItem(
        label: 'الرئيسية',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        page: MobileHomeView(
          onTabChange: (index) {
            _viewModel.changeTab(index);
          },
        ),
      ),
      _NavItem(
        label: 'ملفي',
        icon: Icons.person_outlined,
        activeIcon: Icons.person,
        page: const MobileProfilePage(),
      ),
      _NavItem(
        label: 'الطلبات',
        icon: Icons.request_page_outlined,
        activeIcon: Icons.request_page,
        page: const MobileRequestsView(),
      ),
      _NavItem(
        label: 'الجداول',
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month,
        page: const MobileScheduleView(),
      ),
    ];

    // إضافة تبويب لكل دور إضافي (قد يكون أكثر من دور)
    for (final roleKey in _viewModel.extraRoleKeys) {
      _navItems.add(
        _NavItem(
          label: _viewModel.roleKeyToLabel(roleKey),
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings,
          page: MobileRoleTasksPage(
            role: roleKey,
            onTabChange: (index) => _viewModel.changeTab(index),
          ),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('تسجيل الخروج'),
          ],
        ),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    // 1. إظهار مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري تسجيل الخروج ورفع البيانات...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 2. استدعاء تسجيل الخروج
      bool success = await _viewModel.logout();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // إغلاق الدايلوج
      }

      if (success && mounted) {
        MyApp.restartApp(context, loggedIn: false);
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_viewModel.logoutErrorMessage.isNotEmpty
                ? _viewModel.logoutErrorMessage
                : 'حدث خطأ أثناء تسجيل الخروج'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ غير متوقع: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F9),
          appBar: _buildAppBar(),
          body: IndexedStack(
            index: _viewModel.currentIndex,
            children: _navItems.map((item) => item.page).toList(),
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: DesktopColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          const Icon(Icons.school, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'نظام الشؤون الأكاديمية',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  _viewModel.roleDisplayName,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'الإشعارات',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('لا توجد إشعارات جديدة')),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'تسجيل الخروج',
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _viewModel.currentIndex,
          onTap: (i) => _viewModel.changeTab(i),
          backgroundColor: Colors.white,
          selectedItemColor: DesktopColors.primary,
          unselectedItemColor: const Color(0xFF6B7280),
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: _navItems
              .map(
                (item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });
}
