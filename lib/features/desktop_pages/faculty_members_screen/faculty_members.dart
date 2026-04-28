import 'package:academic_affairs_management/features/desktop_pages/SyncDialog.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'faculty_members_view_model.dart';
import 'add_faculty_member_dialog.dart';

class FacultyMembers extends StatefulWidget {
  const FacultyMembers({super.key});

  @override
  State<FacultyMembers> createState() => _FacultyMembersState();
}

class _FacultyMembersState extends State<FacultyMembers> {
  // تعريف الـ ViewModel
  final FacultyMembersViewModel _viewModel = FacultyMembersViewModel();

  String _searchQuery = '';
  String? _selectedDepartment;
  String? _selectedDegree;
  String? _selectedStatus;

  final List<String> _departments = [
    'علوم الحاسوب',
    'نظم المعلومات',
    'تقنية المعلومات',
    'هندسة البرمجيات'
  ];

  final List<String> _degrees = ['أستاذ', 'أستاذ مشارك', 'أستاذ مساعد', 'معيد'];

  final List<String> _statuses = ['نشط', 'متفرغ', 'منتدب', 'غير نشط'];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel.fetchFacultyMembers(); // 👈 تأكد من وجود هذا السطر
  }

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesktopSpacing.md),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: DesktopSpacing.lg),
            _buildFiltersAndActions(context),
            const SizedBox(height: DesktopSpacing.md),
            _buildFacultyMembersTableLocal(),
          ],
        ),
      ),
    );
  }

  // 1. دالة الـ AppBar
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

  // 2. دالة الـ Header
  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إدارة أعضاء هيئة التدريس',
                style: DesktopTextStyles.heading1),
            const SizedBox(height: DesktopSpacing.xs / 2),
            Text(
              'إضافة وتعديل وحذف أعضاء هيئة التدريس في الأقسام الأكاديمية',
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
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم، القسم، أو الدرجة العلمية...',
                  prefixIcon: const Icon(Icons.search),
                  enabledBorder:
                      DesktopInputTheme.inputDecorationTheme.enabledBorder,
                  focusedBorder:
                      DesktopInputTheme.inputDecorationTheme.focusedBorder,
                ),
              ),
            ),
            const SizedBox(width: DesktopSpacing.xs),
            ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) {
                  return ElevatedButton.icon(
                    onPressed: _viewModel.isLoading
                        ? null
                        : () =>
                            _viewModel.importFacultyMembersFromExcel(context),
                    icon: _viewModel.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.upload_file, color: Colors.white),
                    label: const Text('استيراد الإكسل',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700], // لون مميز للإكسل
                      padding: const EdgeInsets.symmetric(
                          horizontal: DesktopSpacing.md, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }),
            const SizedBox(width: DesktopSpacing.xs),
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      AddFacultyMemberDialog(viewModel: _viewModel),
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
                    'إضافة عضو جديد',
                  )
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: DesktopSpacing.sm),
        Row(
          children: [
            _buildDropdownFilter(
                'كل الأقسام',
                _selectedDepartment,
                _departments,
                (val) => setState(() => _selectedDepartment = val)),
            const SizedBox(width: 10),
            _buildDropdownFilter('الدرجة العلمية', _selectedDegree, _degrees,
                (val) => setState(() => _selectedDegree = val)),
            const SizedBox(width: 10),
            _buildDropdownFilter('الحالة', _selectedStatus, _statuses,
                (val) => setState(() => _selectedStatus = val)),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _selectedDepartment = null;
                  _selectedDegree = null;
                  _selectedStatus = null;
                });
              },
              child: const Text('مسح المرشحات',
                  style: TextStyle(color: DesktopColors.primary)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownFilter(String label, String? selectedValue,
      List<String> items, void Function(String?) onChanged) {
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
            hint: Text(label, style: DesktopTextStyles.caption),
            value: selectedValue,
            isExpanded: true,
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  // 4. جدول البيانات المحلي (بدون Stream)
  Widget _buildFacultyMembersTableLocal() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesktopColors.border),
      ),
      // 👈 استخدام ListenableBuilder لربط الواجهة بالـ ViewModel
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
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

          if (_viewModel.allMembers.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(DesktopSpacing.lg),
              child: Text('لا يوجد أعضاء هيئة تدريس مسجلين حالياً'),
            ));
          }

          final allMembers = _viewModel.allMembers;

          // تفعيل الفلاتر محلياً
          final members = allMembers.where((m) {
            final matchesSearch = _searchQuery.isEmpty ||
                m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                m.department
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                m.academicDegree
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());

            final matchesDept = _selectedDepartment == null ||
                m.department == _selectedDepartment;
            final matchesDegree =
                _selectedDegree == null || m.academicDegree == _selectedDegree;
            final matchesStatus =
                _selectedStatus == null || m.status == _selectedStatus;

            return matchesSearch &&
                matchesDept &&
                matchesDegree &&
                matchesStatus;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomDataTable(
                // نفس الجدول الذي صممته تماماً
                columns: const [
                  DataColumn(
                      label: Text('المعرف', style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('الاسم', style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('القسم', style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('الدرجة العلمية',
                          style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('تاريخ الإضافة',
                          style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('الحالة', style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('إجراءات', style: DesktopTextStyles.caption)),
                ],
                rows: members.map((member) {
                  return DataRow(cells: [
                    DataCell(Text('#${member.id.substring(0, 5)}...',
                        style: DesktopTextStyles.caption)),
                    DataCell(Text(member.name, style: DesktopTextStyles.body)),
                    DataCell(
                        Text(member.department, style: DesktopTextStyles.body)),
                    DataCell(Text(member.academicDegree,
                        style: DesktopTextStyles.body)),
                    DataCell(Text(member.createdAt,
                        style: DesktopTextStyles.caption)),
                    DataCell(_buildStatusBadge(member.status)),
                    DataCell(
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        onSelected: (value) {
                          if (value == 'edit') {
                            // 👈 استدعاء نافذة الإضافة وتمرير العضو ليتم التعديل عليه
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => AddFacultyMemberDialog(
                                viewModel: _viewModel,
                                memberToEdit: member, // هنا نمرر البيانات
                              ),
                            );
                          } else if (value == 'delete') {
                            _viewModel.deleteFacultyMember(member.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit, color: Colors.blue, size: 16),
                              SizedBox(width: 8),
                              Text('تعديل',
                                  style: TextStyle(color: Colors.blue))
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete, color: Colors.red, size: 16),
                              SizedBox(width: 8),
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

  // 5. دالة تلوين الشارة الخاصة بالحالة (نشط، غير نشط، متفرغ، الخ)
  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'نشط':
      case 'متفرغ':
        color = Colors.green;
        break;
      case 'غير نشط':
      case 'منتدب':
        color = Colors.orange;
        break;
      default:
        color = Colors.blue;
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
        status,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
