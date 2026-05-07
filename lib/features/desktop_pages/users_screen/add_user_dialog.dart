import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart'; // 👈 استدعاء قاعدة البيانات
import 'users_view_model.dart';

class AddUserDialog extends StatefulWidget {
  final UsersViewModel viewModel;
  const AddUserDialog({super.key, required this.viewModel});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // متغيرات القوائم المنسدلة للكلية والقسم
  List<Map<String, dynamic>> _collegesList = [];
  List<Map<String, dynamic>> _allDepartmentsList = [];
  List<String> _filteredDepartmentNames = [];

  String? _selectedFaculty;
  String? _selectedDepartment;

  String? _selectedRole;
  String _selectedStatus = 'نشط';
  bool _isLoading = false;

  final List<String> _roles = [
    'Public Prosecution',
    'Deputy Dean',
    'Head of department',
    'Faculty Member',
    'super_admin',
  ];

  final List<String> _statuses = ['نشط', 'غير نشط', 'موقوف'];

  @override
  void initState() {
    super.initState();
    _loadCollegesAndDepartments(); // 👈 جلب البيانات عند فتح النافذة
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

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار الدور والصلاحية')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.viewModel.addUser({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
        'faculty': _selectedFaculty, // 👈 إرسال الكلية المختارة
        'department': _selectedDepartment, // 👈 إرسال القسم المختار
        'status': _selectedStatus,
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إضافة المستخدم بنجاح'),
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
    // تجهيز قائمة أسماء الكليات
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
                        const Text('إضافة مستخدم جديد',
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
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) {
                                  if (val == null || val.isEmpty)
                                    return 'مطلوب';
                                  final emailRegex = RegExp(
                                      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                                  if (!emailRegex.hasMatch(val.trim())) {
                                    return 'بريد إلكتروني غير صالح';
                                  }
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
                                keyboardType: TextInputType.phone,
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

                    // 👈 قوائم الكلية والقسم
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
                    const SizedBox(height: DesktopSpacing.sm),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('الدور والصلاحية'),
                              _buildDynamicDropdown(
                                hintText: 'اختر الصلاحية',
                                value: _selectedRole,
                                items: _roles,
                                icon: Icons.security,
                                onChanged: (val) =>
                                    setState(() => _selectedRole = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: DesktopSpacing.md),
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
                          onPressed: _isLoading ? null : _saveUser,
                          style: DesktopButtonTheme.elevatedButtonTheme.style,
                          child: _isLoading
                              ? const SizedBox(
                                  width: DesktopSpacing.md,
                                  height: DesktopSpacing.md,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('حفظ البيانات'),
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

  // ================= الدوال المساعدة للواجهة =================

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
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
    // حماية ضد انهيار الواجهة إذا كانت القيمة غير موجودة في القائمة
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
