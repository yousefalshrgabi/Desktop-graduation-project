import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'users_view_model.dart';
import 'user_model.dart';

class ViewUserDialog extends StatelessWidget {
  final UserModel user;
  const ViewUserDialog({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(DesktopSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('تفاصيل المستخدم', style: DesktopTextStyles.heading1),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: DesktopSpacing.lg),
            
            _buildInfoRow(Icons.person, 'الاسم الكامل:', user.name),
            _buildInfoRow(Icons.email, 'البريد الإلكتروني:', user.email),
            _buildInfoRow(Icons.phone, 'رقم الجوال:', user.phone),
            _buildInfoRow(Icons.security, 'الدور والصلاحية:', user.rolesList.map((r) => UsersViewModel.roleTranslations[r] ?? r).join('، ')),
            _buildInfoRow(Icons.date_range, 'تاريخ الإنشاء:', user.createdAt),
            
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
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesktopSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: DesktopColors.primary, size: 24),
          const SizedBox(width: DesktopSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DesktopTextStyles.caption.copyWith(color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(value, style: DesktopTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
