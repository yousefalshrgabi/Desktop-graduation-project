import 'package:flutter/material.dart';
import 'mobile_role_tasks_view_model.dart';

class MobileRoleTasksPage extends StatefulWidget {
  final String role;
  final Function(int)? onTabChange;

  const MobileRoleTasksPage({super.key, required this.role, this.onTabChange});

  @override
  State<MobileRoleTasksPage> createState() => _MobileRoleTasksPageState();
}

class _MobileRoleTasksPageState extends State<MobileRoleTasksPage> {
  late final MobileRoleTasksViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = MobileRoleTasksViewModel(
      role: widget.role,
      onTabChange: widget.onTabChange,
      onNavigate: (page) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        final tasks = _viewModel.tasks;

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
                      colors: _viewModel.isDean
                          ? [const Color(0xFF7048E8), const Color(0xFF9775FA)]
                          : _viewModel.isViceDean
                              ? [const Color(0xFF0CA678), const Color(0xFF20C997)]
                              : [const Color(0xFFF59F00), const Color(0xFFFFD43B)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_viewModel.isDean
                                ? const Color(0xFF7048E8)
                                : _viewModel.isViceDean
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
                          _viewModel.isDean
                              ? Icons.account_balance_outlined
                              : _viewModel.isViceDean
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
                              _viewModel.pageTitle,
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
      },
    );
  }

  Widget _buildTaskCard(BuildContext context, TaskItem task) {
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
            // تجاهل النقر إذا لم يكن هناك إجراء محدد
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
