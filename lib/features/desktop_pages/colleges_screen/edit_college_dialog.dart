import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'colleges_view_model.dart';
import 'college_model.dart';

class EditCollegeDialog extends StatefulWidget {
  final CollegeModel college;
  final CollegesViewModel viewModel;
  
  const EditCollegeDialog({
    super.key, 
    required this.college,
    required this.viewModel,
  });

  @override
  State<EditCollegeDialog> createState() => _EditCollegeDialogState();
}

class _EditCollegeDialogState extends State<EditCollegeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _arNameController;
  late TextEditingController _enNameController;
  late TextEditingController _codeController;
  
  String? _selectedDeanId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _arNameController = TextEditingController(text: widget.college.arName);
    _enNameController = TextEditingController(text: widget.college.enName);
    _codeController = TextEditingController(text: widget.college.code);
    _selectedDeanId = widget.college.deanId.isNotEmpty ? widget.college.deanId : null;
    widget.viewModel.fetchPotentialDeans();
  }



  @override
  void dispose() {
    _arNameController.dispose();
    _enNameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _updateCollege() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      await widget.viewModel.updateCollege(widget.college.id, {
        'ar_name': _arNameController.text.trim(),
        'en_name': _enNameController.text.trim(),
        'code': _codeController.text.trim(),
        'deanId': _selectedDeanId ?? '',
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تحديث الكلية بنجاح'),
              backgroundColor: Colors.blue),
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
      child: Dialog(
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
                    const Text('تعديل الكلية', style: DesktopTextStyles.heading1),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: DesktopSpacing.md),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('اسم الكلية (عربي)'),
                          _buildTextField(
                            controller: _arNameController,
                            hint: 'الاسم بالعربية',
                            icon: Icons.business,
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DesktopSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('اسم الكلية (إنجليزي)'),
                          _buildTextField(
                            controller: _enNameController,
                            hint: 'الاسم بالإنجليزية',
                            icon: Icons.business,
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesktopSpacing.sm),

                _buildLabel('الرمز الأكاديمي للكلية'),
                _buildTextField(
                  controller: _codeController,
                  hint: 'مثال: CS, ENG',
                  icon: Icons.code,
                  validator: (val) => val!.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                const SizedBox(height: DesktopSpacing.sm),

                _buildLabel('قائم بأعمال العميد (اختياري)'),
                _buildDeanDropdown(),
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
                      onPressed: _isLoading ? null : _updateCollege,
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

  Widget _buildDeanDropdown() {
    // التحقق مما إذا كانت القيمة المختارة موجودة فعلياً في القائمة الحالية لتجنب الـ Assertion Error
    final bool valueExists = widget.viewModel.potentialDeans.any((user) => user['id'] == _selectedDeanId);
    final String? effectiveValue = valueExists ? _selectedDeanId : null;

    return DropdownButtonFormField<String>(
      value: effectiveValue,
      decoration: InputDecoration(
        enabledBorder: DesktopInputTheme.inputDecorationTheme.enabledBorder,
        focusedBorder: DesktopInputTheme.inputDecorationTheme.focusedBorder,
        filled: true,
        fillColor: Colors.grey[50],
        prefixIcon: const Icon(Icons.person, color: Colors.grey),
      ),
      hint: const Text('اختر العميد'),
      items: [
        const DropdownMenuItem(value: null, child: Text('لا يوجد (غير محدد)')),
        ...widget.viewModel.potentialDeans.map((user) {
          return DropdownMenuItem<String>(
            value: user['id'],
            child: Text(user['name']),
          );
        }),
      ],
      onChanged: (val) => setState(() => _selectedDeanId = val),
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
