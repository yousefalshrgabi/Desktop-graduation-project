import 'package:flutter/material.dart';
import 'package:academic_affairs_management/features/desktop_pages/users_screen/add_user_dialog.dart';
import 'package:academic_affairs_management/features/desktop_pages/users_screen/edit_user_dialog.dart';
import 'package:academic_affairs_management/features/desktop_pages/users_screen/view_user_dialog.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart'; // تأكد من استدعاء ويدجت الجدول المخصص
import 'users_view_model.dart';

class Users extends StatefulWidget {
  const Users({super.key});

  @override
  State<Users> createState() => _UsersState();
}

class _UsersState extends State<Users> {
  // تعريف الـ ViewModel
  final UsersViewModel _viewModel = UsersViewModel();
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
                children: [
                  _buildHeader(),
                  const SizedBox(height: DesktopSpacing.lg),
                  _buildFiltersAndActions(context),
                  const SizedBox(height: DesktopSpacing.md),
                  _buildUsersTableStream(),
                ],
              ),
            );
          }),
    );
  }

  // 1. دالة الـ AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.school, color: DesktopColors.primary),
          const SizedBox(width: DesktopSpacing.xs),
          Text('النيابة العامة',
              style:
                  DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        TextButton(onPressed: () {}, child: const Text('العربية | EN')),
        IconButton(
            icon: const Icon(Icons.notifications_none), onPressed: () {}),
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: CircleAvatar(
              backgroundColor: Color.fromARGB(255, 219, 215, 220),
              child: Text('أ')),
        ),
      ],
    );
  }

  // 2. دالة الـ Header
  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إدارة المستخدمين والصلاحيات',
                style: DesktopTextStyles.heading1),
            const SizedBox(height: DesktopSpacing.xs / 2),
            Text(
              'إضافة المستخدمين وتعيين صلاحياتهم وأدوارهم في النظام',
              style: DesktopTextStyles.caption,
            ),
            const SizedBox(height: DesktopSpacing.xs),
          ],
        ),
      ],
    );
  }

  // 3. دالة الفلاتر وزر الإضافة
  Widget _buildFiltersAndActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => _viewModel.updateSearchQuery(val),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم، البريد، الجوال...',
                  prefixIcon: const Icon(Icons.search),
                  enabledBorder:
                      DesktopInputTheme.inputDecorationTheme.enabledBorder,
                  focusedBorder:
                      DesktopInputTheme.inputDecorationTheme.focusedBorder,
                ),
              ),
            ),
            const SizedBox(width: DesktopSpacing.xs),
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AddUserDialog(viewModel: _viewModel),
                );
              },
              style: DesktopButtonTheme.elevatedButtonTheme.style,
              child: Row(
                children: [
                  const Icon(
                    Icons.add,
                    color: DesktopColors.surface,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'إضافة مستخدم جديد',
                  )
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: DesktopSpacing.sm),
        Row(
          children: [
            _buildRoleDropdownFilter(),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () {
                _searchController.clear();
                _viewModel.clearFilters();
              },
              child: const Text('مسح المرشحات',
                  style: TextStyle(color: DesktopColors.primary)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleDropdownFilter() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DesktopSpacing.xs + 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DesktopColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _viewModel.selectedRole,
            hint: Text('كل الأدوار (الصلاحيات)', style: DesktopTextStyles.caption),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('الكل')),
              ..._viewModel.availableRoles.map((e) => DropdownMenuItem(value: e, child: Text(e))),
            ],
            onChanged: (val) => _viewModel.updateRoleFilter(val),
          ),
        ),
      ),
    );
  }

  // 4. جدول البيانات باستخدام ViewModel
  Widget _buildUsersTableStream() {
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
            ));
          }

          if (_viewModel.errorMessage.isNotEmpty) {
            return Center(child: Text('حدث خطأ: ${_viewModel.errorMessage}'));
          }

          if (_viewModel.filteredUsers.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(DesktopSpacing.lg),
              child: Text('لا يوجد مستخدمين مسجلين حالياً'),
            ));
          }

          final users = _viewModel.filteredUsers;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomDataTable(
                columns: const [
                  DataColumn(
                      label: Text('المعرف', style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('الاسم', style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('البريد الإلكتروني',
                          style: DesktopTextStyles.caption)),
                  DataColumn(
                      label:
                          Text('رقم الجوال', style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('الدور', style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('تاريخ الإنشاء',
                          style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('إجراءات', style: DesktopTextStyles.caption)),
                ],
                rows: users.map((user) {
                  return DataRow(cells: [
                    DataCell(Text('#${user.id.substring(0, 5)}...',
                        style: DesktopTextStyles.caption)),
                    DataCell(Text(user.name, style: DesktopTextStyles.body)),
                    DataCell(Text(user.email, style: DesktopTextStyles.body)),
                    DataCell(Text(user.phone, style: DesktopTextStyles.body)),
                    DataCell(_buildRoleBadge(user.role)),
                    DataCell(
                        Text(user.createdAt, style: DesktopTextStyles.caption)),
                    DataCell(
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        onSelected: (value) {
                          if (value == 'view') {
                            showDialog(
                              context: context,
                              barrierDismissible: true,
                              builder: (context) => ViewUserDialog(user: user),
                            );
                          } else if (value == 'edit') {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => EditUserDialog(user: user, viewModel: _viewModel),
                            );
                          } else if (value == 'delete') {
                            _viewModel.deleteUser(user.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(children: [
                              Icon(Icons.visibility, color: Colors.blue, size: DesktopSpacing.sm),
                              SizedBox(width: DesktopSpacing.xs),
                              Text('عرض', style: TextStyle(color: Colors.blue))
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit, color: Colors.orange, size: DesktopSpacing.sm),
                              SizedBox(width: DesktopSpacing.xs),
                              Text('تعديل', style: TextStyle(color: Colors.orange))
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete, color: Colors.red, size: DesktopSpacing.sm),
                              SizedBox(width: DesktopSpacing.xs),
                              Text('حذف', style: TextStyle(color: Colors.red))
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  // 5. دالة تلوين الشارة
  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role) {
      case 'super_admin':
        color = Colors.red;
        break;
      case 'Public Prosecution':
        color = Colors.blue;
        break;
      case 'Deputy Dean':
        color = Colors.green;
        break;
      case 'Head of department':
        color = Colors.yellow;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DesktopSpacing.xs, vertical: DesktopSpacing.xs / 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        role,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
