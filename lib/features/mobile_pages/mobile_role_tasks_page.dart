import 'package:flutter/material.dart';

/// صفحة مهام الدور الوظيفي (عميد / نائب عميد / رئيس قسم)
class MobileRoleTasksPage extends StatelessWidget {
  final String role;
  final Function(int)? onTabChange;

  const MobileRoleTasksPage({super.key, required this.role, this.onTabChange});

  bool get _isDean => role == 'dean' || role == 'عميد';
  bool get _isViceDean => role == 'vice_dean' || role == 'نائب العميد';
  bool get _isDeptHead => role == 'dept_head' || role == 'رئيس قسم';

  String get _pageTitle {
    if (_isDean) return 'مهام العميد';
    if (_isViceDean) return 'مهام نائب العميد';
    if (_isDeptHead) return 'مهام رئيس القسم';
    return 'المهام الإدارية';
  }

  List<_TaskItem> get _tasks {
    if (_isDean) {
      return [
        _TaskItem(
          title: 'مراجعة الطلبات الواردة',
          subtitle: 'مراجعة طلبات أعضاء الكلية والبت فيها',
          icon: Icons.inbox_outlined,
          color: const Color(0xFF3B5BDB),
        ),
        _TaskItem(
          title: 'الموافقة على الخطط الدراسية',
          subtitle: 'مراجعة وتعديل الخطط الدراسية للأقسام',
          icon: Icons.schema_outlined,
          color: const Color(0xFF0CA678),
        ),
        _TaskItem(
          title: 'إصدار القرارات الإدارية',
          subtitle: 'إنشاء وإصدار القرارات على مستوى الكلية',
          icon: Icons.gavel_outlined,
          color: const Color(0xFFF59F00),
        ),
        _TaskItem(
          title: 'الإشراف على أعضاء الكلية',
          subtitle: 'متابعة شؤون أعضاء هيئة التدريس',
          icon: Icons.supervised_user_circle_outlined,
          color: const Color(0xFF7048E8),
        ),
        _TaskItem(
          title: 'تقارير الكلية',
          subtitle: 'مراجعة تقارير الأداء والإنجاز الدورية',
          icon: Icons.bar_chart_outlined,
          color: const Color(0xFFE03131),
        ),
        _TaskItem(
          title: 'التنسيق مع الجامعة',
          subtitle: 'التواصل مع إدارة الجامعة والنيابة الأكاديمية',
          icon: Icons.link_outlined,
          color: const Color(0xFF099268),
        ),
      ];
    } else if (_isViceDean) {
      return [
        _TaskItem(
          title: 'الإشراف على البرامج الأكاديمية',
          subtitle: 'متابعة جودة البرامج والمقررات الدراسية',
          icon: Icons.school_outlined,
          color: const Color(0xFF3B5BDB),
        ),
        _TaskItem(
          title: 'جداول المحاضرات',
          subtitle: 'مراجعة وتنسيق الجداول الدراسية للكلية',
          icon: Icons.calendar_month_outlined,
          color: const Color(0xFF0CA678),
          onTap: () => onTabChange?.call(3), // تبويب الجداول
        ),
        _TaskItem(
          title: 'الشؤون الأكاديمية للطلاب',
          subtitle: 'متابعة الشؤون الأكاديمية وحالات الطلاب',
          icon: Icons.people_outline,
          color: const Color(0xFFF59F00),
        ),
        _TaskItem(
          title: 'تقارير الأداء الأكاديمي',
          subtitle: 'إعداد ومراجعة تقارير الأداء الأكاديمي',
          icon: Icons.analytics_outlined,
          color: const Color(0xFF7048E8),
        ),
        _TaskItem(
          title: 'الاعتراضات الأكاديمية',
          subtitle: 'دراسة ومعالجة اعتراضات الطلاب والأعضاء',
          icon: Icons.balance_outlined,
          color: const Color(0xFFE03131),
        ),
      ];
    } else if (_isDeptHead) {
      return [
        _TaskItem(
          title: 'إدارة أعضاء القسم',
          subtitle: 'متابعة شؤون أعضاء هيئة التدريس في القسم',
          icon: Icons.people_outline,
          color: const Color(0xFF3B5BDB),
        ),
        _TaskItem(
          title: 'جدول القسم',
          subtitle: 'تنظيم ومتابعة الجداول الدراسية للقسم',
          icon: Icons.table_chart_outlined,
          color: const Color(0xFF0CA678),
        ),
        _TaskItem(
          title: 'اجتماعات القسم',
          subtitle: 'تنظيم وتوثيق اجتماعات مجلس القسم',
          icon: Icons.meeting_room_outlined,
          color: const Color(0xFFF59F00),
        ),
        _TaskItem(
          title: 'طلبات القسم',
          subtitle: 'مراجعة والبت في طلبات أعضاء القسم',
          icon: Icons.request_page_outlined,
          color: const Color(0xFF7048E8),
        ),
        _TaskItem(
          title: 'الخطة الدراسية للقسم',
          subtitle: 'مراجعة وتطوير الخطة الدراسية',
          icon: Icons.auto_stories_outlined,
          color: const Color(0xFFE03131),
        ),
        _TaskItem(
          title: 'تقرير القسم',
          subtitle: 'إعداد التقارير الدورية للقسم',
          icon: Icons.summarize_outlined,
          color: const Color(0xFF099268),
        ),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isDean
                      ? [const Color(0xFF7048E8), const Color(0xFF9775FA)]
                      : _isViceDean
                          ? [const Color(0xFF0CA678), const Color(0xFF20C997)]
                          : [const Color(0xFFF59F00), const Color(0xFFFFD43B)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (_isDean
                            ? const Color(0xFF7048E8)
                            : _isViceDean
                                ? const Color(0xFF0CA678)
                                : const Color(0xFFF59F00))
                        .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isDean
                          ? Icons.account_balance_outlined
                          : _isViceDean
                              ? Icons.school_outlined
                              : Icons.account_tree_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pageTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'إجمالي المهام: ${tasks.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // قسم الإشعار
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.construction_outlined,
                        color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'هذه المهام قيد التطوير. سيتم تفعيلها في الإصدارات القادمة.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // قائمة المهام
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildTaskCard(context, tasks[index]),
                childCount: tasks.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, _TaskItem task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: task.color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: task.color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: task.onTap ?? () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(task.icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('${task.title} - قيد التطوير'),
                  ],
                ),
                backgroundColor: task.color,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: task.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(task.icon, color: task.color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 14, color: task.color.withOpacity(0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _TaskItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });
}
