import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'departments_view_model.dart';

class AddDepartmentDialog extends StatefulWidget {
  final DepartmentsViewModel viewModel;
  const AddDepartmentDialog({super.key, required this.viewModel});

  @override
  State<AddDepartmentDialog> createState() => _AddDepartmentDialogState();
}

class _AddDepartmentDialogState extends State<AddDepartmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  String? _selectedCollegeId;
  String? _selectedHodId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.fetchAvailableColleges();
    widget.viewModel.fetchAvailableUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await widget.viewModel.addDepartment({
        'name': _nameController.text.trim(),
        'collegeId': _selectedCollegeId ?? '',
        'HODId': _selectedHodId ?? '',
      });
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إضافة القسم بنجاح'),
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
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(DesktopSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إضافة قسم جديد',
                        style: DesktopTextStyles.heading1),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: DesktopSpacing.md),

                // ── اسم القسم ────────────────────────────────────────────────
                _buildLabel('اسم القسم'),
                TextFormField(
                  controller: _nameController,
                  validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                  decoration: InputDecoration(
                    hintText: 'أدخل اسم القسم',
                    prefixIcon:
                        const Icon(Icons.account_tree_outlined, color: Colors.grey),
                    enabledBorder:
                        DesktopInputTheme.inputDecorationTheme.enabledBorder,
                    focusedBorder:
                        DesktopInputTheme.inputDecorationTheme.focusedBorder,
                    errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red)),
                    focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: DesktopSpacing.sm),

                // ── الكلية ────────────────────────────────────────────────────
                _buildLabel('الكلية التابع لها'),
                _buildDropdown(
                  value: _selectedCollegeId,
                  items: widget.viewModel.availableColleges,
                  hint: 'اختر الكلية',
                  icon: Icons.business_outlined,
                  onChanged: (v) => setState(() => _selectedCollegeId = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'يجب اختيار الكلية' : null,
                ),
                const SizedBox(height: DesktopSpacing.sm),

                // ── رئيس القسم ───────────────────────────────────────────────
                _buildLabel('رئيس القسم (اختياري)'),
                _buildDropdown(
                  value: _selectedHodId,
                  items: widget.viewModel.availableUsers,
                  hint: 'اختر رئيس القسم',
                  icon: Icons.person_outline,
                  onChanged: (v) => setState(() => _selectedHodId = v),
                  nullable: true,
                ),
                const SizedBox(height: DesktopSpacing.lg),

                // ── Buttons ──────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: DesktopSpacing.xs),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: DesktopButtonTheme.elevatedButtonTheme.style,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('حفظ البيانات'),
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

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style:
                DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _buildDropdown({
    required String? value,
    required List<Map<String, dynamic>> items,
    required String hint,
    required IconData icon,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
    bool nullable = false,
  }) {
    final exists = items.any((e) => e['id'] == value);
    final effectiveValue = exists ? value : null;

    return DropdownButtonFormField<String>(
      value: effectiveValue,
      validator: validator,
      decoration: InputDecoration(
        enabledBorder: DesktopInputTheme.inputDecorationTheme.enabledBorder,
        focusedBorder: DesktopInputTheme.inputDecorationTheme.focusedBorder,
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red)),
        filled: true,
        fillColor: Colors.grey[50],
        prefixIcon: Icon(icon, color: Colors.grey),
      ),
      hint: Text(hint),
      items: [
        if (nullable)
          const DropdownMenuItem(value: null, child: Text('لا يوجد (غير محدد)')),
        ...items.map((e) => DropdownMenuItem<String>(
              value: e['id'] as String,
              child: Text(e['name'] as String),
            )),
      ],
      onChanged: onChanged,
    );
  }
}
