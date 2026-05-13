import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'college_model.dart';
import 'colleges_view_model.dart';

class ViewCollegeDialog extends StatelessWidget {
  final CollegeModel college;
  final CollegesViewModel viewModel;

  const ViewCollegeDialog({
    super.key,
    required this.college,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    // جلب الأسماء من الـ ViewModel إذا كانت متاحة
    final deanName = viewModel.userNames[college.deanId] ?? 'غير محدد';
    final academicViceDeanName = viewModel.userNames[college.academicViceDeanId] ?? 'غير محدد';
    final studentViceDeanName = viewModel.userNames[college.studentViceDeanId] ?? 'غير محدد';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(DesktopSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('تفاصيل الكلية', style: DesktopTextStyles.heading1),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: DesktopSpacing.md),
            _buildDetailRow('اسم الكلية (عربي):', college.arName),
            _buildDetailRow('اسم الكلية (إنجليزي):', college.enName),
            _buildDetailRow('الرمز الأكاديمي:', college.code),
            _buildDetailRow('العميد:', deanName),
            _buildDetailRow('نائب الشؤون الأكاديمية:', academicViceDeanName),
            _buildDetailRow('نائب شؤون الطلاب:', studentViceDeanName),
            _buildDetailRow('تاريخ الإنشاء:', college.createdAt),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesktopSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: DesktopTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: DesktopTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}
