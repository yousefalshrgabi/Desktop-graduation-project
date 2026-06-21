import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/features/desktop_pages/SyncDialog.dart';

class SharedDesktopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? extraActions;
  final String? customTitle;

  const SharedDesktopAppBar({
    super.key,
    this.extraActions,
    this.customTitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          const SizedBox(width: 48), // مسافة محجوزة لزر القائمة الجانبية لتفادي التداخل
          const Icon(Icons.school, color: DesktopColors.primary),
          const SizedBox(width: DesktopSpacing.xs),
          Text(
            customTitle ?? 'نظام الشؤون الأكاديمية',
            style: DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        if (extraActions != null) ...extraActions!,
        TextButton(onPressed: () {}, child: const Text('العربية | EN')),
        IconButton(
          tooltip: 'مزامنة السحابة',
          icon: const Icon(Icons.cloud_sync_outlined, color: DesktopColors.primary),
          onPressed: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const SyncDialog(),
            );
          },
        ),
        IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: CircleAvatar(
            backgroundColor: Color.fromARGB(255, 219, 215, 220),
            child: Text('أ'),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
