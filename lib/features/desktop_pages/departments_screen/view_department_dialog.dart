import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'department_model.dart';
import 'departments_view_model.dart';

class ViewDepartmentDialog extends StatelessWidget {
  final DepartmentModel department;
  final DepartmentsViewModel viewModel;

  const ViewDepartmentDialog(
      {super.key, required this.department, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final collegeName =
        viewModel.collegeNames[department.collegeId] ?? 'غير محدد';
    final hodName = viewModel.hodNames[department.hodId] ?? 'غير محدد';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(DesktopSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('تفاصيل القسم', style: DesktopTextStyles.heading1),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(height: DesktopSpacing.lg),
            _buildRow('اسم القسم:', department.name),
            _buildRow('الكلية:', collegeName),
            _buildRow('رئيس القسم:', hodName),
            _buildRow('تاريخ الإنشاء:', department.createdAt),
            const SizedBox(height: DesktopSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: DesktopButtonTheme.elevatedButtonTheme.style,
                child: const Text('إغلاق'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesktopSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: DesktopTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.grey[700])),
          ),
          Expanded(child: Text(value, style: DesktopTextStyles.body)),
        ],
      ),
    );
  }
}
