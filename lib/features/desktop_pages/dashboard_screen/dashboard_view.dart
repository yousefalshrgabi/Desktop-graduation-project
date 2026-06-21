import 'package:academic_affairs_management/features/desktop_pages/SyncDialog.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/features/desktop_pages/dashboard_screen/dashboard_view_model.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';

class DashboardView extends StatefulWidget {
  /// Callback to navigate to a page in MainShell (0=dashboard,1=colleges,2=faculty,3=users)
  final void Function(int index)? onNavigate;

  const DashboardView({super.key, this.onNavigate});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final DashboardViewModel _viewModel = DashboardViewModel();

  // Quick-access module definitions matching sidebar elements
  List<_ModuleCard> get _modules {
    final list = [
      const _ModuleCard(
        index: 1,
        label: 'إدارة الكليات',
        subtitle: 'إضافة، تعديل وحذف بيانات الكليات',
        icon: Icons.business_rounded,
        gradient: [Color(0xFF0123C9), Color(0xFF4F6FFF)],
      ),
      const _ModuleCard(
        index: 2,
        label: 'الأقسام',
        subtitle: 'إدارة الأقسام الأكاديمية وربطها بالكليات',
        icon: Icons.account_tree_rounded,
        gradient: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
      ),
      const _ModuleCard(
        index: 3,
        label: 'هيئة التدريس',
        subtitle: 'إدارة أعضاء هيئة التدريس وبياناتهم',
        icon: Icons.people_alt_rounded,
        gradient: [Color(0xFF00897B), Color(0xFF4DB6AC)],
      ),
      const _ModuleCard(
        index: 4,
        label: 'المستخدمين',
        subtitle: 'إدارة حسابات وصلاحيات المستخدمين',
        icon: Icons.manage_accounts_rounded,
        gradient: [Color(0xFFE65100), Color(0xFFFF8F00)],
      ),
      const _ModuleCard(
        index: 5,
        label: 'الخطط الدراسية',
        subtitle: 'إدارة ومزامنة خطط المقررات بملفات CSV',
        icon: Icons.schema_outlined,
        gradient: [Color(0xFF00796B), Color(0xFF26A69A)],
      ),
      const _ModuleCard(
        index: 6,
        label: 'الطلبات',
        subtitle: 'مراجعة طلبات النقل والندب وغيرها',
        icon: Icons.request_page_outlined,
        gradient: [Color(0xFFD32F2F), Color(0xFFEF5350)],
      ),
      const _ModuleCard(
        index: 7,
        label: 'إنجاز المقررات',
        subtitle: 'متابعة وتتبع نسبة إنجاز المقررات الدراسية',
        icon: Icons.query_stats,
        gradient: [Color(0xFF1976D2), Color(0xFF42A5F5)],
      ),
      const _ModuleCard(
        index: 8,
        label: 'طلبات الاحتياج',
        subtitle: 'تقديم ومتابعة طلبات الاحتياج من الكليات',
        icon: Icons.forward_to_inbox,
        gradient: [Color(0xFF388E3C), Color(0xFF66BB6A)],
      ),
    ];

    if (AppSession().isAdminOrDeanship ||
        AppSession().isDean ||
        AppSession().isViceDean) {
      list.addAll([
        const _ModuleCard(
          index: 9,
          label: 'اعتمادات النِصاب',
          subtitle: 'مراجعة واعتماد أنصبة الهيئة التدريسية',
          icon: Icons.assignment_turned_in_outlined,
          gradient: [Color(0xFFF57C00), Color(0xFFFFB74D)],
        ),
        const _ModuleCard(
          index: 10,
          label: 'الساعات الزائدة والموازية',
          subtitle: 'احتساب الساعات الإضافية والموازية للمدرسين',
          icon: Icons.access_time_outlined,
          gradient: [Color(0xFF455A64), Color(0xFF78909C)],
        ),
      ]);
    }

    if (AppSession().isAdminOrDeanship) {
      list.add(
        const _ModuleCard(
          index: 11,
          label: 'محاضر الكليات',
          subtitle: 'إدارة وتوثيق محاضر اجتماعات مجلس الكليات',
          icon: Icons.meeting_room,
          gradient: [Color(0xFF5D4037), Color(0xFF8D6E63)],
        ),
      );
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SharedDesktopAppBar(),
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
        // 4 بطاقات في الصف الأول
        int crossAxisCount = 4;
        double spacing = DesktopSpacing.md;
        double itemWidth =
            ((constraints.maxWidth - (crossAxisCount - 1) * spacing) /
                    crossAxisCount) -
                0.1;

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
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
        double itemWidth =
            ((constraints.maxWidth - (crossAxisCount - 1) * spacing) /
                    crossAxisCount) -
                0.1;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _modules
              .map((m) => SizedBox(
                    width: itemWidth,
                    child: _buildModuleButton(m),
                  ))
              .toList(),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(module.icon, color: Colors.white, size: 24),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          module.subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
