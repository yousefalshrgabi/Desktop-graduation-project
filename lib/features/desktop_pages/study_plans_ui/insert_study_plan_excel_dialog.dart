import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/widgets/searchable_user_dropdown.dart';
import 'package:file_picker/file_picker.dart';
import 'study_plans_viewmodel.dart';

class InsertStudyPlanExcelDialog extends StatefulWidget {
  final StudyPlansViewModel viewModel;

  const InsertStudyPlanExcelDialog({Key? key, required this.viewModel})
      : super(key: key);

  @override
  State<InsertStudyPlanExcelDialog> createState() =>
      _InsertStudyPlanExcelDialogState();
}

class _InsertStudyPlanExcelDialogState
    extends State<InsertStudyPlanExcelDialog> {
  String? _selectedDeptId;
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  void _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xls', 'xlsx'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  void _submit() async {
    if (_selectedDeptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار القسم أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار ملف إكسل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      await widget.viewModel
          .uploadStudyPlanExcel(_selectedDeptId!, _selectedFile!);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفع الخطة الدراسية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الرفع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.upload_file, color: DesktopColors.primary),
          SizedBox(width: 8),
          Text('إدراج خطة دراسية (Excel)'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'القسم',
              style: DesktopTextStyles.caption,
            ),
            const SizedBox(height: DesktopSpacing.xs),
            SearchableUserDropdown(
              value: _selectedDeptId,
              hint: 'اختر القسم',
              items: widget.viewModel.departments,
              onChanged: (val) {
                setState(() {
                  _selectedDeptId = val;
                });
              },
            ),
            const SizedBox(height: DesktopSpacing.md),
            const Text(
              'ملف الخطة (Excel)',
              style: DesktopTextStyles.caption,
            ),
            const SizedBox(height: DesktopSpacing.xs),
            InkWell(
              onTap: _isUploading ? null : _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(DesktopSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: DesktopColors.border),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null
                          ? Icons.check_circle
                          : Icons.upload_file,
                      color: _selectedFile != null
                          ? Colors.green
                          : DesktopColors.primary,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile != null
                          ? _selectedFile!.name
                          : 'اضغط لاختيار ملف Excel',
                      style: DesktopTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            if (_isUploading) ...[
              const SizedBox(height: DesktopSpacing.lg),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(child: Text('جاري رفع الملف...')),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _submit,
          style: DesktopButtonTheme.elevatedButtonTheme.style,
          child: const Text('رفع وحفظ'),
        ),
      ],
    );
  }
}
