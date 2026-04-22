import 'package:academic_affairs_management/features/desktop_pages/SyncDialog.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/features/desktop_pages/dashboard_screen/dashboard_view_model.dart';

class DashboardView extends StatefulWidget {
  /// Callback to navigate to a page in MainShell (0=dashboard,1=colleges,2=faculty,3=users)
  final void Function(int index)? onNavigate;

  const DashboardView({super.key, this.onNavigate});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final DashboardViewModel _viewModel = DashboardViewModel();

  // Quick-access module definitions
  static const _modules = [
    _ModuleCard(
      index: 1,
      label: 'إدارة الكليات',
      subtitle: 'إضافة، تعديل وحذف بيانات الكليات',
      icon: Icons.business_rounded,
      gradient: [Color(0xFF0123C9), Color(0xFF4F6FFF)],
    ),
    _ModuleCard(
      index: 2,
      label: 'الأقسام',
      subtitle: 'إدارة الأقسام الأكاديمية وربطها بالكليات',
      icon: Icons.account_tree_rounded,
      gradient: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    ),
    _ModuleCard(
      index: 3,
      label: 'هيئة التدريس',
      subtitle: 'إدارة أعضاء هيئة التدريس وبياناتهم',
      icon: Icons.people_alt_rounded,
      gradient: [Color(0xFF00897B), Color(0xFF4DB6AC)],
    ),
    _ModuleCard(
      index: 4,
      label: 'المستخدمين',
      subtitle: 'إدارة حسابات وصلاحيات المستخدمين',
      icon: Icons.manage_accounts_rounded,
      gradient: [Color(0xFFE65100), Color(0xFFFF8F00)],
    ),
    _ModuleCard(
      index: 5,
      label: 'البرامج الأكاديمية',
      subtitle: 'إدارة البرامج وتخصيص المسارات',
      icon: Icons.school_rounded,
      gradient: [Color(0xFFC2185B), Color(0xFFE91E63)],
    ),
    _ModuleCard(
      index: 6,
      label: 'المقررات',
      subtitle: 'إدارة المقررات الدراسية',
      icon: Icons.menu_book_rounded,
      gradient: [Color(0xFF512DA8), Color(0xFF7E57C2)],
    ),
    _ModuleCard(
      index: 7,
      label: 'الخطط الدراسية',
      subtitle: 'إدارة ومزامنة خطط المقررات بملفات CSV',
      icon: Icons.schema_outlined,
      gradient: [Color(0xFF00796B), Color(0xFF26A69A)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: DesktopColors.background,
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_viewModel.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_viewModel.errorMessage!,
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: DesktopSpacing.md),
                  ElevatedButton(
                    onPressed: _viewModel.refreshStats,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(DesktopSpacing.lg,
                DesktopSpacing.lg, DesktopSpacing.lg + 56, DesktopSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: DesktopSpacing.xl),
                _buildStatsRow(),
                const SizedBox(height: DesktopSpacing.xl),
                const Text('الوصول السريع', style: DesktopTextStyles.heading2),
                const SizedBox(height: DesktopSpacing.md),
                _buildQuickAccessGrid(),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.school, color: DesktopColors.primary),
          const SizedBox(width: DesktopSpacing.xs),
          Text('نظام الشؤون الأكاديمية',
              style:
                  DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        TextButton(onPressed: () {}, child: const Text('العربية | EN')),

        // 👈 إضافة زر المزامنة هنا
        IconButton(
          tooltip: 'مزامنة السحابة', // يظهر كنص توضيحي عند تمرير الماوس
          icon: const Icon(Icons.cloud_sync_outlined,
              color: DesktopColors.primary),
          onPressed: () {
            showDialog(
              context: context,
              barrierDismissible: false, // لمنع الإغلاق بالخطأ أثناء المزامنة
              builder: (context) => const SyncDialog(),
            );
          },
        ),

        IconButton(
            icon: const Icon(Icons.notifications_none), onPressed: () {}),
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: CircleAvatar(
            backgroundColor: Color.fromARGB(255, 219, 215, 220),
            child: Text('أ'),
          ),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('لوحة التحكم', style: DesktopTextStyles.heading1),
        const SizedBox(height: 4),
        Text(
          'نظرة عامة على إحصائيات النظام',
          style: DesktopTextStyles.caption,
        ),
      ],
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 5 بطاقات: 4 في الصف الأول وواحدة في الثاني (أو تلقائياً حسب المساحة)
        int crossAxisCount = 4;
        double spacing = DesktopSpacing.md;
        double itemWidth = ((constraints.maxWidth - (crossAxisCount - 1) * spacing) / crossAxisCount) - 0.1;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: itemWidth,
              child: _buildStatCard(
                title: 'إجمالي الكليات',
                value: _viewModel.stats.totalColleges.toString(),
                icon: Icons.business_rounded,
                color: const Color(0xFF0123C9),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildStatCard(
                title: 'أعضاء هيئة التدريس',
                value: _viewModel.stats.totalFacultyMembers.toString(),
                icon: Icons.people_alt_rounded,
                color: const Color(0xFF00897B),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildStatCard(
                title: 'المستخدمين',
                value: _viewModel.stats.totalUsers.toString(),
                icon: Icons.manage_accounts_rounded,
                color: const Color(0xFFE65100),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildStatCard(
                title: 'البرامج الأكاديمية',
                value: _viewModel.stats.totalPrograms.toString(),
                icon: Icons.school_rounded,
                color: const Color(0xFFC2185B),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildStatCard(
                title: 'الخطط الدراسية',
                value: _viewModel.stats.totalStudyPlans.toString(),
                icon: Icons.schema_outlined,
                color: const Color(0xFF00796B),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Access Grid ─────────────────────────────────────────────────────
  Widget _buildQuickAccessGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // بناءً على طلبك، 4 بطاقات للمسار السريع وينزل للسطر
        int crossAxisCount = 4;
        double spacing = DesktopSpacing.md;
        double itemWidth = ((constraints.maxWidth - (crossAxisCount - 1) * spacing) / crossAxisCount) - 0.1;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _modules.map((m) => SizedBox(
            width: itemWidth,
            child: _buildModuleButton(m),
          )).toList(),
        );
      },
    );
  }

  Widget _buildModuleButton(_ModuleCard module) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onNavigate?.call(module.index),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: module.gradient,
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: module.gradient.first.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -20,
                left: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                right: -10,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(module.icon, color: Colors.white, size: 30),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          module.subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_forward_ios,
                      color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────
class _ModuleCard {
  final int index;
  final String label;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;

  const _ModuleCard({
    required this.index,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });
}

