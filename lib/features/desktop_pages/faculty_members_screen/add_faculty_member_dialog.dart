import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';

class AddFacultyMemberDialog extends StatefulWidget {
  const AddFacultyMemberDialog({super.key});

  @override
  State<AddFacultyMemberDialog> createState() => _AddFacultyMemberDialogState();
}

class _AddFacultyMemberDialogState extends State<AddFacultyMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  String? _selectedDepartment;
  String? _selectedDegree;
  String? _selectedStatus = 'نشط'; // افتراضي
  bool _isLoading = false;

  final List<String> _departments = [
    'علوم الحاسوب',
    'نظم المعلومات',
    'تقنية المعلومات',
    'هندسة البرمجيات'
  ];

  final List<String> _degrees = [
    'أستاذ',
    'أستاذ مشارك',
    'أستاذ مساعد',
    'معيد'
  ];

  final List<String> _statuses = [
    'نشط',
    'متفرغ',
    'منتدب',
    'غير نشط'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveFacultyMember() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDepartment == null || _selectedDegree == null || _selectedStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تعبئة جميع الحقول المطلوبة (القسم، الدرجة، الحالة)')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // إضافة البيانات إلى Firestore
      await FirebaseFirestore.instance.collection('faculty_members').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'department': _selectedDepartment,
        'academicDegree': _selectedDegree,
        'status': _selectedStatus,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pop(); // إغلاق النافذة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إضافة عضو هيئة التدريس بنجاح'), backgroundColor: Colors.green),
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
                        const Text('إضافة عضو هيئة تدريس', style: DesktopTextStyles.heading1),
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
                      hint: 'أدخل اسم العضو رباعياً',
                      icon: Icons.person_outline,
                      validator: (val) => val!.isEmpty ? 'هذا الحقل مطلوب' : null,
                    ),
                    const SizedBox(height: DesktopSpacing.sm),
          
                    _buildLabel('البريد الإلكتروني'),
                    _buildTextField(
                      controller: _emailController,
                      hint: 'example@domain.com',
                      icon: Icons.email_outlined,
                      validator: (val) => !val!.contains('@') ? 'بريد غير صالح' : null,
                    ),
                    const SizedBox(height: DesktopSpacing.sm),
          
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('القسم الأكاديمي'),
                              _buildDropdown(
                                value: _selectedDepartment,
                                items: _departments,
                                hint: 'اختر القسم',
                                icon: Icons.category_outlined,
                                onChanged: (val) => setState(() => _selectedDepartment = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: DesktopSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('الدرجة العلمية'),
                              _buildDropdown(
                                value: _selectedDegree,
                                items: _degrees,
                                hint: 'اختر الدرجة',
                                icon: Icons.school_outlined,
                                onChanged: (val) => setState(() => _selectedDegree = val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesktopSpacing.sm),

                    _buildLabel('الحالة الوظيفية'),
                    _buildDropdown(
                      value: _selectedStatus,
                      items: _statuses,
                      hint: 'اختر الحالة',
                      icon: Icons.work_outline,
                      onChanged: (val) => setState(() => _selectedStatus = val),
                    ),
          
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
                          onPressed: _isLoading ? null : _saveFacultyMember,
                          style: DesktopButtonTheme.elevatedButtonTheme.style,
                          child: _isLoading
                              ? const SizedBox(
                                  width:DesktopSpacing.md,
                                  height: DesktopSpacing.md,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        enabledBorder: DesktopInputTheme.inputDecorationTheme.enabledBorder,
        focusedBorder: DesktopInputTheme.inputDecorationTheme.focusedBorder,
        filled: true,
        fillColor: Colors.grey[50],
        prefixIcon: Icon(icon, color: Colors.grey),
      ),
      hint: Text(hint),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}
