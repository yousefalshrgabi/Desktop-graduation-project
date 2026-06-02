import 'package:academic_affairs_management/main.dart';
import 'package:academic_affairs_management/features/authentiction/login_view.dart';
import 'package:academic_affairs_management/features/authentiction/login_view_model.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/features/desktop_pages/dashboard_screen/dashboard_view.dart';
import 'package:academic_affairs_management/features/desktop_pages/colleges_screen/colleges_view.dart';
import 'package:academic_affairs_management/features/desktop_pages/departments_screen/departments_view.dart';
import 'package:academic_affairs_management/features/desktop_pages/faculty_members_screen/faculty_members.dart';
import 'package:academic_affairs_management/features/desktop_pages/users_screen/users_view.dart';
import 'package:academic_affairs_management/features/desktop_pages/requests_screen/requests_view.dart';
import 'package:academic_affairs_management/features/desktop_pages/programs_screen/programs_view.dart';
import 'package:academic_affairs_management/features/desktop_pages/subjects_screen/subjects_view.dart';
import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/study_plans_view.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/widgets/change_password_dialog.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _dashboardKeyCount = 0;
  bool _sidebarVisible = true;

  late final AnimationController _animController;
  late final Animation<double> _widthAnimation;

  final LoginViewModel _loginViewModel = LoginViewModel();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0, // starts open
    );
    _widthAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() => _sidebarVisible = !_sidebarVisible);
    if (_sidebarVisible) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  /// Called from DashboardView quick-access buttons
  void _navigateTo(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) _dashboardKeyCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── Animated Sidebar ──────────────────────────────────────────
          SizeTransition(
            sizeFactor: _widthAnimation,
            axis: Axis.horizontal,
            child: SizedBox(
              width: 260,
              child: _buildSidebar(),
            ),
          ),

          // ── Main Content (with toggle button in top-left corner) ──────
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: _selectedIndex,
                  children: [
                    DashboardView(
                        key: ValueKey('dash_$_dashboardKeyCount'),
                        onNavigate: _navigateTo),
                    Colleges(key: ValueKey('colleges_$_selectedIndex')),
                    DepartmentsView(key: ValueKey('depts_$_selectedIndex')),
                    FacultyMembers(key: ValueKey('faculty_$_selectedIndex')),
                    Users(key: ValueKey('users_$_selectedIndex')),
                    ProgramsView(key: ValueKey('programs_$_selectedIndex')),
                    SubjectsView(key: ValueKey('subjects_$_selectedIndex')),
                    StudyPlansView(key: ValueKey('study_plans_$_selectedIndex')),
                    RequestsView(key: ValueKey('requests_$_selectedIndex')),
                  ],
                ),
                // Toggle button
                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildToggleButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    return Tooltip(
      message:
          _sidebarVisible ? 'إخفاء القائمة الجانبية' : 'إظهار القائمة الجانبية',
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _toggleSidebar,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _sidebarVisible ? Icons.menu_open : Icons.menu,
                key: ValueKey(_sidebarVisible),
                color: DesktopColors.primary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildSidebarHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: DesktopSpacing.md),
              children: [
                _buildSidebarItem(0, 'لوحة التحكم', Icons.dashboard_outlined),
                _buildSidebarItem(1, 'إدارة الكليات', Icons.business_outlined),
                _buildSidebarItem(2, 'الأقسام', Icons.account_tree_outlined),
                _buildSidebarItem(3, 'هيئة التدريس', Icons.people_outline),
                _buildSidebarItem(4, 'المستخدمين', Icons.manage_accounts_outlined),
                _buildSidebarItem(5, 'إدارة البرامج', Icons.school_outlined),
                _buildSidebarItem(6, 'المقررات', Icons.menu_book_outlined),
                _buildSidebarItem(7, 'الخطط الدراسية', Icons.schema_outlined),
                _buildSidebarItem(8, 'الطلبات', Icons.request_page_outlined),
              ],
            ),
          ),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.all(DesktopSpacing.md),
      child: Row(
        children: const [
          Icon(Icons.school, color: DesktopColors.primary, size: 32),
          SizedBox(width: DesktopSpacing.sm),
          Expanded(
            child: Text(
              'نظام الشؤون\nالأكاديمية',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: DesktopColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DesktopSpacing.sm, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            if (index == 0) _dashboardKeyCount++;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
              horizontal: DesktopSpacing.md, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? DesktopColors.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? DesktopColors.primary
                    : DesktopColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: DesktopSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? DesktopColors.primary
                        : DesktopColors.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: DesktopColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    final session = AppSession();
    final String initial = session.userName.isNotEmpty ? session.userName.trim().substring(0, 1) : 'أ';
    final String displayName = session.userName.isNotEmpty ? session.userName : 'المدير العام';
    final String displayEmail = session.userEmail.isNotEmpty ? session.userEmail : 'admin@univ.edu';

    return Padding(
      padding: const EdgeInsets.all(DesktopSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(DesktopSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: DesktopColors.primary,
              child: Text(initial, style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: DesktopSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    displayEmail,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.vpn_key_outlined, color: DesktopColors.primary, size: 20),
              tooltip: 'تغيير كلمة المرور',
              onPressed: () async {
                final success = await showDialog<bool>(
                  context: context,
                  builder: (context) => const ChangePasswordDialog(),
                );
                if (success == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تغيير كلمة المرور بنجاح.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              tooltip: 'تسجيل الخروج',
              onPressed: () async {
                // 1. إظهار مؤشر التحميل
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                // 2. استدعاء دالة تسجيل الخروج وانتظار النتيجة (true أو false)
                // لاحظ أننا لم نعد نمرر context للدالة
                bool success = await _loginViewModel.logout();

                // 3. إغلاق مؤشر التحميل بأمان (قبل أي توجيه آخر)
                if (context.mounted) {
                  Navigator.pop(context);
                }

                // 4. التحقق من النتيجة لتوجيه المستخدم
                if (success) {
                  // إذا نجح الخروج والرفع، نقوم بإعادة تشغيل التطبيق بالكامل
                  if (context.mounted) {
                    MyApp.restartApp(context, loggedIn: false);
                  }
                } else {
                  // إذا فشل (بسبب انقطاع النت)، نظهر رسالة الخطأ
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.wifi_off, color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _loginViewModel.errorMessage,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red[700],
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
            )
          ],
        ),
      ),
    );
  }
}
