import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'departments_view_model.dart';
import 'add_department_dialog.dart';
import 'edit_department_dialog.dart';
import 'view_department_dialog.dart';

class DepartmentsView extends StatefulWidget {
  const DepartmentsView({super.key});

  @override
  State<DepartmentsView> createState() => _DepartmentsViewState();
}

class _DepartmentsViewState extends State<DepartmentsView> {
  final DepartmentsViewModel _viewModel = DepartmentsViewModel();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesktopColors.background,
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(DesktopSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: DesktopSpacing.lg),
                _buildFiltersRow(context),
                const SizedBox(height: DesktopSpacing.md),
                _buildTable(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('إدارة الأقسام', style: DesktopTextStyles.heading1),
        const SizedBox(height: 4),
        Text(
          'عرض، إضافة، وتعديل بيانات الأقسام الأكاديمية',
          style: DesktopTextStyles.caption,
        ),
      ],
    );
  }

  // ── Search + Add button ───────────────────────────────────────────────────────
  Widget _buildFiltersRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            onChanged: _viewModel.updateSearchQuery,
            decoration: InputDecoration(
              hintText: 'ابحث باسم القسم، الكلية، أو رئيس القسم...',
              prefixIcon: const Icon(Icons.search),
              enabledBorder:
                  DesktopInputTheme.inputDecorationTheme.enabledBorder,
              focusedBorder:
                  DesktopInputTheme.inputDecorationTheme.focusedBorder,
            ),
          ),
        ),
        const SizedBox(width: DesktopSpacing.md),
        ElevatedButton(
          onPressed: () => showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AddDepartmentDialog(viewModel: _viewModel),
          ),
          style: DesktopButtonTheme.elevatedButtonTheme.style,
          child: Row(
            children: const [
              Icon(Icons.add, color: DesktopColors.surface),
              SizedBox(width: 8),
              Text('إضافة قسم جديد'),
            ],
          ),
        ),
      ],
    );
  }

  // ── Data Table ────────────────────────────────────────────────────────────────
  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesktopColors.border),
      ),
      child: Builder(
        builder: (context) {
          if (_viewModel.isLoading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(DesktopSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (_viewModel.errorMessage.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(DesktopSpacing.lg),
                child: Text(
                  'حدث خطأ: ${_viewModel.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (_viewModel.filteredDepartments.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(DesktopSpacing.lg),
                child: Text('لا توجد أقسام مسجلة حالياً'),
              ),
            );
          }

          return CustomDataTable(
            columns: const [
              DataColumn(
                  label: Text('المعرف', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('اسم القسم', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('الكلية', style: DesktopTextStyles.caption)),
              DataColumn(
                  label:
                      Text('رئيس القسم', style: DesktopTextStyles.caption)),
              DataColumn(
                  label:
                      Text('تاريخ الإنشاء', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('إجراءات', style: DesktopTextStyles.caption)),
            ],
            rows: _viewModel.filteredDepartments.map((dept) {
              final collegeName =
                  _viewModel.collegeNames[dept.collegeId] ?? 'غير محدد';
              final hodName =
                  _viewModel.hodNames[dept.hodId] ?? 'غير محدد';

              return DataRow(cells: [
                DataCell(Text(
                  '#${dept.id.substring(0, 5)}...',
                  style: DesktopTextStyles.caption,
                )),
                DataCell(Text(dept.name, style: DesktopTextStyles.body)),
                DataCell(Text(collegeName, style: DesktopTextStyles.body)),
                DataCell(Text(hodName, style: DesktopTextStyles.body)),
                DataCell(
                    Text(dept.createdAt, style: DesktopTextStyles.caption)),
                DataCell(
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'view') {
                        showDialog(
                          context: context,
                          builder: (_) => ViewDepartmentDialog(
                              department: dept, viewModel: _viewModel),
                        );
                      } else if (value == 'edit') {
                        showDialog(
                          context: context,
                          builder: (_) => EditDepartmentDialog(
                              department: dept, viewModel: _viewModel),
                        );
                      } else if (value == 'delete') {
                        _showDeleteDialog(context, dept);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(children: [
                          Icon(Icons.visibility, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text('عرض', style: TextStyle(color: Colors.blue)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Text('تعديل',
                              style: TextStyle(color: Colors.orange)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('حذف', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ]);
            }).toList(),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, dept) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف قسم "${dept.name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              _viewModel.deleteDepartment(dept.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('تم حذف القسم بنجاح'),
                    backgroundColor: Colors.red),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
