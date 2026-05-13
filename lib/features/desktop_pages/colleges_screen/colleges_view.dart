import 'package:academic_affairs_management/features/desktop_pages/SyncDialog.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'colleges_view_model.dart';
import 'add_college_dialog.dart';
import 'edit_college_dialog.dart';
import 'view_college_dialog.dart';

class Colleges extends StatefulWidget {
  const Colleges({super.key});

  @override
  State<Colleges> createState() => _CollegesState();
}

class _CollegesState extends State<Colleges> {
  final CollegesViewModel _viewModel = CollegesViewModel();
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
      appBar: _buildAppBar(),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(DesktopSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: DesktopSpacing.lg),
                _buildFiltersAndActions(context),
                const SizedBox(height: DesktopSpacing.md),
                _buildCollegesTable(),
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
              builder: (context) => SyncDialog(),
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('إدارة الكليات', style: DesktopTextStyles.heading1),
        const SizedBox(height: DesktopSpacing.xs / 2),
        Text(
          'عرض، إضافة، وتعديل بيانات الكليات في النظام',
          style: DesktopTextStyles.caption,
        ),
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
              hintText: 'ابحث باسم الكلية أو الرمز...',
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
          onPressed: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AddCollegeDialog(viewModel: _viewModel),
            );
          },
          style: DesktopButtonTheme.elevatedButtonTheme.style,
          child: Row(
            children: [
              const Icon(Icons.add, color: DesktopColors.surface),
              const SizedBox(width: 8),
              const Text('إضافة كلية جديدة'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollegesTable() {
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
                padding: EdgeInsets.all(DesktopSpacing.lg),
                child: Text('حدث خطأ: ${_viewModel.errorMessage}',
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }

          if (_viewModel.filteredColleges.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(DesktopSpacing.lg),
                child: Text('لا توجد كليات مسجلة حالياً بهذا الاسم'),
              ),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: CustomDataTable(
            columns: const [
              DataColumn(
                  label: Text('المعرف', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('اسم الكلية', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('اسم الكلية', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('الرمز', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('العميد', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('نائب الشؤون الأكاديمية', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('نائب شؤون الطلاب', style: DesktopTextStyles.caption)),
              DataColumn(
                  label:
                      Text('تاريخ الإنشاء', style: DesktopTextStyles.caption)),
              DataColumn(
                  label: Text('إجراءات', style: DesktopTextStyles.caption)),
            ],
            rows: _viewModel.filteredColleges.map((college) {
              final deanName =
                  _viewModel.userNames[college.deanId] ?? 'غير محدد';
              return DataRow(cells: [
                DataCell(Text('#${college.id.substring(0, 5)}...',
                    style: DesktopTextStyles.caption)),
                DataCell(Text(college.arName, style: DesktopTextStyles.body)),
                DataCell(Text(college.enName, style: DesktopTextStyles.body)),
                DataCell(Text(college.code, style: DesktopTextStyles.body)),
                DataCell(Text(deanName, style: DesktopTextStyles.body)),
                DataCell(Text(_viewModel.userNames[college.academicViceDeanId] ?? '-',
                    style: DesktopTextStyles.body)),
                DataCell(Text(_viewModel.userNames[college.studentViceDeanId] ?? '-',
                    style: DesktopTextStyles.body)),
                DataCell(
                    Text(college.createdAt, style: DesktopTextStyles.caption)),
                DataCell(
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'view') {
                        showDialog(
                          context: context,
                          builder: (context) => ViewCollegeDialog(
                              college: college, viewModel: _viewModel),
                        );
                      } else if (value == 'edit') {
                        showDialog(
                          context: context,
                          builder: (context) => EditCollegeDialog(
                              college: college, viewModel: _viewModel),
                        );
                      } else if (value == 'delete') {
                        _showDeleteConfirmDialog(context, college);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(children: [
                          Icon(Icons.visibility, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text('عرض', style: TextStyle(color: Colors.blue))
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Text('تعديل', style: TextStyle(color: Colors.orange))
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('حذف', style: TextStyle(color: Colors.red))
                        ]),
                      ),
                    ],
                  ),
                ),
              ]);
            }).toList(),
          ));
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, var college) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف كلية "${college.arName}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              _viewModel.deleteCollege(college.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('تم حذف الكلية بنجاح'),
                    backgroundColor: Colors.red),
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
