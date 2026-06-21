import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/features/desktop_pages/SyncDialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/features/desktop_pages/dashboard_screen/main_shell.dart';

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
        if (AppSession().userId.isEmpty)
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {})
        else
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: AppSession().userId)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadCount = 0;
              List<QueryDocumentSnapshot> sortedDocs = [];

              if (snapshot.hasData) {
                unreadCount = snapshot.data!.docs
                    .where((doc) =>
                        (doc.data() as Map<String, dynamic>)['isRead'] == false)
                    .length;

                sortedDocs = List.from(snapshot.data!.docs);
                sortedDocs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });
              }

              return Badge(
                label: Text(unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
                isLabelVisible: unreadCount > 0,
                backgroundColor: Colors.red,
                child: IconButton(
                  icon: const Icon(Icons.notifications_none),
                  tooltip: 'الإشعارات',
                  onPressed: () => _showNotificationsDialog(context, sortedDocs),
                ),
              );
            },
          ),
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

  void _showNotificationsDialog(BuildContext context, List<QueryDocumentSnapshot> docs) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              width: 500,
              constraints: const BoxConstraints(maxHeight: 600),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الإشعارات',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                          color: DesktopColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          if (docs.any((d) =>
                              (d.data() as Map<String, dynamic>)['isRead'] == false))
                            TextButton.icon(
                              onPressed: () async {
                                final batch = FirebaseFirestore.instance.batch();
                                for (var doc in docs) {
                                  batch.update(doc.reference, {'isRead': true});
                                }
                                await batch.commit();
                                if (context.mounted) Navigator.pop(context);
                              },
                              icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                              label: const Text(
                                'تحديد الكل كمقروء',
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                              ),
                            ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: docs.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد إشعارات حالياً',
                              style: TextStyle(
                                  fontFamily: 'Cairo', color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data =
                                  docs[index].data() as Map<String, dynamic>;
                              final isRead = data['isRead'] ?? false;

                              String timeStr = '';
                              final timestamp = data['createdAt'] as Timestamp?;
                              if (timestamp != null) {
                                final date = timestamp.toDate();
                                timeStr = '${date.hour}:${date.minute.toString().padLeft(2, '0')} - ${date.day}/${date.month}/${date.year}';
                              }

                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 8),
                                color: isRead
                                    ? Colors.grey[50]
                                    : DesktopColors.primary.withOpacity(0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isRead
                                        ? Colors.grey[200]!
                                        : DesktopColors.primary.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: isRead
                                        ? Colors.grey[200]
                                        : DesktopColors.primary.withOpacity(0.1),
                                    child: Icon(
                                      isRead
                                          ? Icons.notifications_none_outlined
                                          : Icons.notifications_active_outlined,
                                      color: isRead
                                          ? Colors.grey
                                          : DesktopColors.primary,
                                    ),
                                  ),
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          data['title'] ?? 'إشعار جديد',
                                          style: TextStyle(
                                            fontWeight: isRead
                                                ? FontWeight.normal
                                                : FontWeight.bold,
                                            fontSize: 14,
                                            fontFamily: 'Cairo',
                                            color: DesktopColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (timeStr.isNotEmpty)
                                        Text(
                                          timeStr,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      data['body'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontFamily: 'Cairo',
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  onTap: () async {
                                    await docs[index]
                                        .reference
                                        .update({'isRead': true});
                                    if (context.mounted) {
                                      Navigator.pop(context); // إغلاق حوار الإشعارات
                                      
                                      // إذا كان إشعار طلبات، نقوم بالانتقال لصفحة الطلبات
                                      if (data['type'] == 'request') {
                                        final mainShellState = context.findAncestorStateOfType<MainShellState>();
                                        if (mainShellState != null) {
                                          mainShellState.navigateTo(6);
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('تم تعليم الإشعار كمقروء. يرجى الذهاب إلى صفحة الطلبات من القائمة الجانبية.'),
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('تم تعليم الإشعار كمقروء.'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
