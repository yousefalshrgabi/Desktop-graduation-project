import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/features/desktop_pages/SyncDialog.dart';
import 'programs_viewmodel.dart';
import 'add_program_dialog.dart';
import 'edit_program_dialog.dart';
import 'view_program_dialog.dart';

class ProgramsView extends StatefulWidget {
  const ProgramsView({Key? key}) : super(key: key);

  @override
  State<ProgramsView> createState() => _ProgramsViewState();
}

class _ProgramsViewState extends State<ProgramsView> {
  final ProgramsViewModel _viewModel = ProgramsViewModel();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesktopColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesktopSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: DesktopSpacing.lg),
            _buildFiltersAndActions(context),
            const SizedBox(height: DesktopSpacing.md),
            _buildProgramsTable(),
          ],
        ),
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
              style: DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        TextButton(onPressed: () {}, child: const Text('العربية | EN')),
        IconButton(
          tooltip: 'مزامنة السحابة',
          icon: const Icon(Icons.cloud_sync_outlined, color: DesktopColors.primary),
          onPressed: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const SyncDialog(),
            );
          },
        ),
        IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('إدارة البرامج الأكاديمية', style: DesktopTextStyles.heading1),
        const SizedBox(height: DesktopSpacing.xs / 2),
        Text('عرض، إضافة، وتعديل البرامج ومساراتها المتخصصة', style: DesktopTextStyles.caption),
      ],
    );
  }

  Widget _buildFiltersAndActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            onChanged: (val) => _viewModel.updateSearchQuery(val),
            decoration: InputDecoration(
              hintText: 'ابحث باسم البرنامج...',
              prefixIcon: const Icon(Icons.search),
              enabledBorder: DesktopInputTheme.inputDecorationTheme.enabledBorder,
              focusedBorder: DesktopInputTheme.inputDecorationTheme.focusedBorder,
            ),
          ),
        ),
        const SizedBox(width: DesktopSpacing.md),
        ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AddProgramDialog(viewModel: _viewModel),
            );
          },
          style: DesktopButtonTheme.elevatedButtonTheme.style,
          child: Row(
            children: const [
              Icon(Icons.add, color: DesktopColors.surface),
              SizedBox(width: 8),
              Text('إضافة برنامج جديد'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgramsTable() {
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
              child: Padding(padding: EdgeInsets.all(DesktopSpacing.lg), child: CircularProgressIndicator()),
            );
          }

          if (_viewModel.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(DesktopSpacing.lg),
                child: Text('حدث خطأ: ${_viewModel.errorMessage}', style: const TextStyle(color: Colors.red)),
              ),
            );
          }

          if (_viewModel.filteredPrograms.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(DesktopSpacing.lg),
                child: Text('لا توجد برامج مسجلة حالياً بهذا الاسم'),
              ),
            );
          }

          return CustomDataTable(
            columns: const [
              DataColumn(label: Text('المعرف', style: DesktopTextStyles.caption)),
              DataColumn(label: Text('الاسم بالعربي', style: DesktopTextStyles.caption)),
              DataColumn(label: Text('الاسم بالإنجليزي', style: DesktopTextStyles.caption)),
              DataColumn(label: Text('المستويات', style: DesktopTextStyles.caption)),
              DataColumn(label: Text('عدد المسارات', style: DesktopTextStyles.caption)),
              DataColumn(label: Text('المزامنة', style: DesktopTextStyles.caption)),
              DataColumn(label: Text('إجراءات', style: DesktopTextStyles.caption)),
            ],
            rows: _viewModel.filteredPrograms.map((program) {
              return DataRow(cells: [
                DataCell(Text('#${program.id.substring(0, 5)}...', style: DesktopTextStyles.caption)),
                DataCell(Text(program.nameAr, style: DesktopTextStyles.body)),
                DataCell(Text(program.nameEn, style: DesktopTextStyles.body)),
                DataCell(Text(program.totalLevels.toString(), style: DesktopTextStyles.body)),
                DataCell(Text('${program.tracks.length} مسار', style: DesktopTextStyles.body.copyWith(color: DesktopColors.primary))),
                DataCell(
                  Tooltip(
                    message: program.isSynced ? 'متزامن' : 'غير متزامن محلياً',
                    child: Icon(
                      program.isSynced ? Icons.cloud_done : Icons.cloud_off,
                      color: program.isSynced ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                  ),
                ),
                DataCell(
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'view') {
                        showDialog(
                          context: context,
                          builder: (context) => ViewProgramDialog(program: program, viewModel: _viewModel),
                        );
                      } else if (value == 'edit') {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => EditProgramDialog(program: program, viewModel: _viewModel),
                        );
                      } else if (value == 'delete') {
                        _showDeleteConfirmDialog(context, program);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(children: [Icon(Icons.visibility, color: Colors.blue, size: 18), SizedBox(width: 8), Text('عرض', style: TextStyle(color: Colors.blue))]),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [Icon(Icons.edit, color: Colors.orange, size: 18), SizedBox(width: 8), Text('تعديل', style: TextStyle(color: Colors.orange))]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('حذف', style: TextStyle(color: Colors.red))]),
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

  void _showDeleteConfirmDialog(BuildContext context, var program) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف البرنامج "${program.nameAr}" وكل مساراته؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              _viewModel.deleteProgram(program.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حذف البرنامج بنجاح'), backgroundColor: Colors.red),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
