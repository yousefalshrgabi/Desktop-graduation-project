import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'users_view_model.dart';
import 'user_model.dart';

class EditUserDialog extends StatefulWidget {
  final UserModel user;
  final UsersViewModel viewModel;
  const EditUserDialog({super.key, required this.user, required this.viewModel});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  String? _selectedRole;
  bool _isLoading = false;

  final List<String> _roles = [
    'Public Prosecution',
    'Deputy Dean',
    'Head of department',
    'super_admin',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone);
    _selectedRole = _roles.contains(widget.user.role) ? widget.user.role : null;
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
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار الدور والصلاحية')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.viewModel.updateUser(widget.user.id, {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
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
    return SingleChildScrollView(
      child: Column(
        children: [
          Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.white,
            child: Container(
              width: 500,
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
                        const Text('تعديل بيانات المستخدم', style: DesktopTextStyles.heading1),
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
                      validator: (val) => val!.isEmpty ? 'هذا الحقل مطلوب' : null,
                    ),
                    const SizedBox(height: DesktopSpacing.sm),

                    _buildLabel('البريد الإلكتروني'),
                    _buildTextField(
                      controller: _emailController,
                      hint: 'example@domain.com',
                      icon: Icons.email_outlined,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'هذا الحقل مطلوب';
                        final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                        if (!emailRegex.hasMatch(val)) return 'بريد إلكتروني غير صالح باللغة الإنجليزية';
                        return null;
                      },
                    ),
                    const SizedBox(height: DesktopSpacing.sm),

                    _buildLabel('رقم الجوال'),
                    _buildTextField(
                      controller: _phoneController,
                      hint: '77xxxxxxx',
                      icon: Icons.phone_outlined,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'هذا الحقل مطلوب';
                        if (!RegExp(r'^[0-9]+$').hasMatch(val)) return 'يجب إدخال أرقام فقط';
                        if (val.length != 9) return 'رقم الجوال يجب أن يتكون من 9 أرقام';
                        return null;
                      },
                    ),
                    const SizedBox(height: DesktopSpacing.sm),

                    _buildLabel('الدور والصلاحية'),
                    _buildRoleDropdown(),

                    const SizedBox(height: DesktopSpacing.lg),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: DesktopSpacing.md, vertical: DesktopSpacing.sm),
                          ),
                          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: DesktopSpacing.xs),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _updateUser,
                          style: DesktopButtonTheme.elevatedButtonTheme.style,
                          child: _isLoading
                              ? const SizedBox(
                                  width: DesktopSpacing.md,
                                  height: DesktopSpacing.md,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      decoration: InputDecoration(
        enabledBorder: DesktopInputTheme.inputDecorationTheme.enabledBorder,
        focusedBorder: DesktopInputTheme.inputDecorationTheme.focusedBorder,
        filled: true,
        fillColor: Colors.grey[50],
        prefixIcon: const Icon(Icons.security, color: Colors.grey),
      ),
      hint: const Text('اختر الصلاحية'),
      items: _roles.map((role) {
        return DropdownMenuItem(
          value: role,
          child: Text(role),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedRole = val),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}
