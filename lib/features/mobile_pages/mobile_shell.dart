import 'package:academic_affairs_management/main.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/features/authentiction/login_view.dart';
import 'package:academic_affairs_management/features/authentiction/login_view_model.dart';
import 'package:academic_affairs_management/features/mobile_pages/mobile_profile_page.dart';
import 'package:academic_affairs_management/features/mobile_pages/mobile_requests_view.dart';
import 'package:academic_affairs_management/features/mobile_pages/mobile_role_tasks_page.dart';
import 'package:academic_affairs_management/features/mobile_pages/mobile_schedule_view.dart';

/// واجهة الموبايل الرئيسية الموحدة لجميع الأدوار (عضو، عميد، نائب عميد، رئيس قسم)
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _currentIndex = 0;
  final _session = AppSession();
  final _loginViewModel = LoginViewModel();

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
        page: _HomeTab(
          onTabChange: (index) {
            setState(() => _currentIndex = index);
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
    for (final roleKey in _session.extraRoleKeys) {
      _navItems.add(
        _NavItem(
          label: _session.roleKeyToLabel(roleKey),
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings,
          page: MobileRoleTasksPage(
            role: roleKey,
            onTabChange: (index) => setState(() => _currentIndex = index),
          ),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    // إظهار تأكيد الخروج
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
      // 2. استدعاء دالة تسجيل الخروج الموحدة
      bool success = await _loginViewModel.logout();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // إغلاق الدايلوج
      }

      if (success && mounted) {
        // 3. الحل النهائي: إعادة تشغيل حالة التطبيق بالكامل لتنظيف الذاكرة والمكدس
        MyApp.restartApp(context, loggedIn: false);
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_loginViewModel.errorMessage.isNotEmpty
                ? _loginViewModel.errorMessage
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: _navItems.map((item) => item.page).toList(),
      ),
      bottomNavigationBar: _buildBottomNav(),
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
                  _session.roleDisplayName,
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
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.white,
          selectedItemColor: DesktopColors.primary,
          unselectedItemColor: const Color(0xFF6B7280),
          selectedLabelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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

// =================== تبويب الرئيسية ===================
class _HomeTab extends StatelessWidget {
  final Function(int) onTabChange;
  const _HomeTab({required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final session = AppSession();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // بطاقة الترحيب
          _buildWelcomeCard(session),
          const SizedBox(height: 20),

          // إحصاءات سريعة
          const Text(
            'الإجراءات السريعة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActions(context, session),
          const SizedBox(height: 20),

          // معلومات الدور
          _buildRoleInfoCard(session),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(AppSession session) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0123C9), Color(0xFF3B5BDB)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0123C9).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            radius: 30,
            child: Text(
              session.userName.isNotEmpty
                  ? session.userName.substring(0, 1)
                  : 'م',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مرحباً،',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  session.userName.isNotEmpty ? session.userName : 'المستخدم',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    session.roleDisplayName,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AppSession session) {
    // نستخدم List صريحة قابلة للتعديل حتى نتمكن من .add() لاحقاً
    final List<_QuickAction> actions = [
      _QuickAction(
        label: 'ملفي الشخصي',
        icon: Icons.person_outlined,
        color: const Color(0xFF3B5BDB),
        onTap: () => onTabChange(1), // الانتقال لتبويب الملف الشخصي (Index 1)
      ),
      _QuickAction(
        label: 'طلباتي',
        icon: Icons.request_page_outlined,
        color: const Color(0xFF0CA678),
        onTap: () => onTabChange(2), // الانتقال لتبويب الطلبات (Index 2)
      ),
      _QuickAction(
        label: 'طلب تعديل',
        icon: Icons.edit_note_outlined,
        color: const Color(0xFFF59F00),
        onTap: () =>
            onTabChange(1), // الانتقال لتبويب الملف الشخصي لطلب التعديل
      ),
      _QuickAction(
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
    final extraRoles = session.extraRoleKeys;
    for (int i = 0; i < extraRoles.length; i++) {
      final roleKey = extraRoles[i];
      final color = roleColors[i % roleColors.length];
      final int tabIndex = 4 +
          i; // الاندكس يبدأ من 4 للأدوار الإضافية (بعد الرئيسية، ملفي، الطلبات، الجداول)

      actions.add(
        _QuickAction(
          label: session.roleKeyToLabel(roleKey),
          icon: Icons.admin_panel_settings_outlined,
          color: color,
          onTap: () => onTabChange(tabIndex),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: actions.map(_buildQuickActionCard).toList(),
    );
  }

  Widget _buildQuickActionCard(_QuickAction action) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: action.color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: action.color.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(action.icon, color: action.color, size: 28),
            const Spacer(),
            Text(
              action.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: action.color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleInfoCard(AppSession session) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: DesktopColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'معلومات الحساب',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow(Icons.badge_outlined, 'الدور', session.roleDisplayName),
          const SizedBox(height: 8),
          _buildInfoRow(
              Icons.business_outlined,
              'الكلية',
              session.userCollege.isNotEmpty
                  ? session.userCollege
                  : 'غير محدد'),
          if (session.userDepartment.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
                Icons.account_tree_outlined, 'القسم', session.userDepartment),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
