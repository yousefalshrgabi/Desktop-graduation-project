import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart'; // 👈 استدعاء قاعدة البيانات
import 'users_view_model.dart';
import 'user_model.dart';

class EditUserDialog extends StatefulWidget {
  final UserModel user;
  final UsersViewModel viewModel;
  const EditUserDialog(
      {super.key, required this.user, required this.viewModel});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  // متغيرات القوائم المنسدلة للكلية والقسم
  List<Map<String, dynamic>> _collegesList = [];
  List<Map<String, dynamic>> _allDepartmentsList = [];
  List<String> _filteredDepartmentNames = [];

  String? _selectedFaculty;
  String? _selectedDepartment;

  List<String> _selectedRoles = [];
  late String _selectedStatus;
  bool _isLoading = false;

  // الأدوار اليدوية فقط (الإدارية تعيين تلقائياً عبر صفحة الكليات/الأقسام)
  final List<String> _roles = [
    'Public Prosecution',
    'Faculty Member',
    'super_admin',
  ];

  // الأدوار الإدارية المحمية (لا يمكن تعديلها يدوياً)
  static const List<String> _adminRoles = [
    'Dean',
    'Vice Dean for Academic Affairs',
    'Vice Dean for Student Affairs',
    'Head of department',
  ];

  final List<String> _statuses = ['نشط', 'غير نشط', 'موقوف'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone);

    _selectedFaculty = widget.user.faculty;
    _selectedDepartment = widget.user.department;

    _selectedRoles = widget.user.rolesList;
    _selectedStatus =
        _statuses.contains(widget.user.status) ? widget.user.status! : 'نشط';

    _loadCollegesAndDepartments(); // 👈 جلب البيانات عند الفتح
  }

  // 🌟 دالة جلب الكليات والأقسام من قاعدة البيانات
  Future<void> _loadCollegesAndDepartments() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final colleges = await db.query('colleges');
      final departments = await db.query('departments');

      if (mounted) {
        setState(() {
          _collegesList = colleges;
          _allDepartmentsList = departments;

          // تهيئة تصفية الأقسام بناءً على كلية المستخدم الحالية
          if (_selectedFaculty != null) {
            final college = _collegesList.firstWhere(
              (c) => c['ar_name'].toString() == _selectedFaculty,
              orElse: () => {},
            );

            if (college.isNotEmpty) {
              final collegeId = college['id'];
              _filteredDepartmentNames = _allDepartmentsList
                  .where((d) => d['college_id'] == collegeId)
                  .map((d) => d['name'].toString())
                  .toList();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading DB data: $e');
    }
  }

  // 🌟 دالة تصفية الأقسام بناءً على الكلية المختارة
  void _onFacultyChanged(String? newFaculty) {
    setState(() {
      _selectedFaculty = newFaculty;
      _selectedDepartment = null; // تصفير القسم عند تغيير الكلية

      if (newFaculty != null) {
        final college = _collegesList.firstWhere(
          (c) => c['ar_name'].toString() == newFaculty,
          orElse: () => {},
        );

        if (college.isNotEmpty) {
          final collegeId = college['id'];
          _filteredDepartmentNames = _allDepartmentsList
              .where((d) => d['college_id'] == collegeId)
              .map((d) => d['name'].toString())
              .toList();
        } else {
          _filteredDepartmentNames = [];
        }
      } else {
        _filteredDepartmentNames = [];
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار دور واحد على الأقل')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.viewModel.updateUser(widget.user.id, {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': jsonEncode(_selectedRoles), // 👈 حفظ مصفوفة الصلاحيات
        'status': _selectedStatus,
        'faculty': _selectedFaculty, // 👈 إرسال الكلية المختارة
        'department': _selectedDepartment, // 👈 إرسال القسم المختار
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تحديث بيانات المستخدم بنجاح'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> collegeNames =
        _collegesList.map((c) => c['ar_name'].toString()).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.white,
            child: Container(
              width: 600,
              padding: const EdgeInsets.all(DesktopSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('تعديل بيانات المستخدم',
                            style: DesktopTextStyles.heading1),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesktopSpacing.md),

                    _buildLabel('الاسم الكامل'),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'أدخل اسم الموظف',
                      icon: Icons.person_outline,
                      validator: (val) =>
                          val!.isEmpty ? 'هذا الحقل مطلوب' : null,
                    ),
                    const SizedBox(height: DesktopSpacing.sm),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('البريد الإلكتروني'),
                              _buildTextField(
                                controller: _emailController,
                                hint: 'example@domain.com',
                                icon: Icons.email_outlined,
                                validator: (val) {
                                  if (val == null || val.isEmpty)
                                    return 'مطلوب';
                                  final emailRegex = RegExp(
                                      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                                  if (!emailRegex.hasMatch(val))
                                    return 'غير صالح';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: DesktopSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('رقم الجوال'),
                              _buildTextField(
                                controller: _phoneController,
                                hint: '77xxxxxxx',
                                icon: Icons.phone_outlined,
                                validator: (val) {
                                  if (val == null || val.isEmpty)
                                    return 'مطلوب';
                                  if (!RegExp(r'^[0-9]+$').hasMatch(val))
                                    return 'أرقام فقط';
                                  if (val.length != 9)
                                    return 'يجب أن يكون 9 أرقام';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesktopSpacing.sm),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('الكلية (اختياري)'),
                              _buildDynamicDropdown(
                                hintText: 'اختر الكلية',
                                value: _selectedFaculty,
                                items: collegeNames,
                                icon: Icons.account_balance_outlined,
                                onChanged: _onFacultyChanged,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: DesktopSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('القسم (اختياري)'),
                              _buildDynamicDropdown(
                                hintText: 'اختر القسم',
                                value: _selectedDepartment,
                                items: _filteredDepartmentNames,
                                icon: Icons.category_outlined,
                                onChanged: (val) =>
                                    setState(() => _selectedDepartment = val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesktopSpacing.md),
                    _buildLabel('الدور والصلاحية'),

                    // الأدوار اليدوية القابلة للتعديل
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _roles.map((role) {
                        final isSelected = _selectedRoles.contains(role);
                        return FilterChip(
                          label: Text(UsersViewModel.roleTranslations[role] ?? role),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedRoles.add(role);
                              } else {
                                _selectedRoles.remove(role);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    if (_selectedRoles.where((r) => !_adminRoles.contains(r)).isEmpty &&
                        _selectedRoles.every((r) => _adminRoles.contains(r)))
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'يجب اختيار دور يدوي واحد على الأقل',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),

                    // عرض الأدوار الإدارية المحمية (إن وجدت)
                    Builder(builder: (context) {
                      final lockedRoles = _selectedRoles
                          .where((r) => _adminRoles.contains(r))
                          .toList();
                      if (lockedRoles.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.lock_outline, size: 13, color: Colors.orange.shade700),
                                    const SizedBox(width: 5),
                                    Text(
                                      'أدوار إدارية (تُعيَّن تلقائياً - غير قابلة للتعديل يدوياً)',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: lockedRoles.map((role) => Chip(
                                    avatar: Icon(Icons.lock, size: 12, color: Colors.orange.shade700),
                                    label: Text(
                                      UsersViewModel.roleTranslations[role] ?? role,
                                      style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                                    ),
                                    backgroundColor: Colors.orange.shade100,
                                    side: BorderSide(color: Colors.orange.shade300),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                  )).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: DesktopSpacing.md),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('حالة الحساب'),
                              _buildDynamicDropdown(
                                hintText: 'اختر الحالة',
                                value: _selectedStatus,
                                items: _statuses,
                                icon: Icons.toggle_on_outlined,
                                onChanged: (val) =>
                                    setState(() => _selectedStatus = val!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: DesktopSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: DesktopSpacing.md,
                                vertical: DesktopSpacing.sm),
                          ),
                          child: const Text('إلغاء',
                              style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: DesktopSpacing.xs),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _updateUser,
                          style: DesktopButtonTheme.elevatedButtonTheme.style,
                          child: _isLoading
                              ? const SizedBox(
                                  width: DesktopSpacing.md,
                                  height: DesktopSpacing.md,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('حفظ التعديلات'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        enabledBorder: DesktopInputTheme.inputDecorationTheme.enabledBorder,
        focusedBorder: DesktopInputTheme.inputDecorationTheme.focusedBorder,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  // 🌟 دالة موحدة لإنشاء أي قائمة منسدلة بشكل أنيق وآمن
  Widget _buildDynamicDropdown({
    required String hintText,
    required String? value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    String? safeValue = value;
    if (safeValue != null && !items.contains(safeValue)) {
      safeValue = null;
    }

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: hintText,
        enabledBorder: DesktopInputTheme.inputDecorationTheme.enabledBorder,
        focusedBorder: DesktopInputTheme.inputDecorationTheme.focusedBorder,
        filled: true,
        fillColor: Colors.grey[50],
        prefixIcon: Icon(icon, color: Colors.grey),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(UsersViewModel.roleTranslations[item] ?? item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text,
          style: DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}
