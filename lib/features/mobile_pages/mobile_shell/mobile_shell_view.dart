import 'package:academic_affairs_management/main.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/services/sync_service.dart';
import 'mobile_shell_view_model.dart';
import '../mobile_profile/mobile_profile_view.dart';
import '../mobile_requests/mobile_requests_view.dart';
import '../mobile_role_tasks/mobile_role_tasks_view.dart';
import '../mobile_schedule/mobile_schedule_view.dart';
import '../mobile_home/mobile_home_view.dart';
import 'notification_details_view.dart';

/// واجهة الموبايل الرئيسية الموحدة لجميع الأدوار (عضو، عميد، نائب عميد، رئيس قسم)
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  final MobileShellViewModel _viewModel = MobileShellViewModel();
  late final List<_NavItem> _navItems;

  @override
  void initState() {
    super.initState();
    _buildNavItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingEmail();
    });
  }

  Future<void> _checkPendingEmail() async {
    final session = AppSession();
    if (session.userId.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(session.userId)
          .get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final pendingEmail = data['pending_email']?.toString() ?? '';

      if (pendingEmail.isNotEmpty && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.mark_email_unread, color: Colors.blue),
                SizedBox(width: 8),
                Text('تأكيد تغيير البريد الإلكتروني'),
              ],
            ),
            content: Text(
                'لقد وافقت النيابة على تغيير بريدك الإلكتروني إلى:\n\n$pendingEmail\n\nهل تريد تأكيد التغيير الآن؟ سيتم إرسال رابط تحقق إلى بريدك الجديد ولن يكتمل التغيير حتى تضغط عليه. سيتم تسجيل خروجك وعليك الدخول بالبريد الجديد بعد التحقق.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('تأجيل'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('تأكيد وتغيير البريد'),
              ),
            ],
          ),
        );

        if (confirm == true && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );

          try {
            await FirebaseAuth.instance.currentUser!
                .verifyBeforeUpdateEmail(pendingEmail);

            // تحديث قاعدة البيانات
            await FirebaseFirestore.instance
                .collection('users')
                .doc(session.userId)
                .update({
              'email': pendingEmail,
              'pending_email': FieldValue.delete(),
            });

            final facultyQuery = await FirebaseFirestore.instance
                .collection('faculty_members')
                .where('user_id', isEqualTo: session.userId)
                .limit(1)
                .get();
            if (facultyQuery.docs.isNotEmpty) {
              await facultyQuery.docs.first.reference.update({
                'email': pendingEmail,
              });
            }

            await AppSession().clear();
            await FirebaseAuth.instance.signOut();

            if (mounted) {
              Navigator.of(context, rootNavigator: true)
                  .pop(); // إغلاق الدايلوج
              MyApp.restartApp(context, loggedIn: false);
            }
          } catch (e) {
            if (mounted) {
              Navigator.of(context, rootNavigator: true)
                  .pop(); // إغلاق الدايلوج
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'حدث خطأ أثناء التحديث (قد تحتاج لإعادة تسجيل الدخول أولاً لتحديث البريد): $e')));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking pending email: $e');
    }
  }

  void _buildNavItems() {
    _navItems = [
      _NavItem(
        label: 'الرئيسية',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        page: MobileHomeView(
          onTabChange: (index) {
            _viewModel.changeTab(index);
          },
        ),
      ),
      _NavItem(
        label: 'ملفي',
        icon: Icons.person_outlined,
        activeIcon: Icons.person,
        page: const MobileProfilePage(),
      ),
      _NavItem(
        label: 'الطلبات',
        icon: Icons.request_page_outlined,
        activeIcon: Icons.request_page,
        page: const MobileRequestsView(),
      ),
      _NavItem(
        label: 'الجداول',
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month,
        page: const MobileScheduleView(),
      ),
    ];

    // إضافة تبويب لكل دور إضافي (قد يكون أكثر من دور)
    for (final roleKey in _viewModel.extraRoleKeys) {
      _navItems.add(
        _NavItem(
          label: _viewModel.roleKeyToLabel(roleKey),
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings,
          page: MobileRoleTasksPage(
            role: roleKey,
            onTabChange: (index) => _viewModel.changeTab(index),
          ),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final int? choice = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('تسجيل الخروج'),
          ],
        ),
        content: const Text('هل ترغب في مزامنة بياناتك مع السحابة قبل الخروج لضمان عدم فقدان أي تعديلات، أم ترغب في الخروج السريع (بدون مزامنة)؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 2),
            child: const Text('خروج بدون مزامنة', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 1),
            style: ElevatedButton.styleFrom(backgroundColor: DesktopColors.primary),
            child: const Text('مزامنة ثم خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (choice == null || choice == 0) return;

    if (!mounted) return;

    final bool skipSync = (choice == 2);

    // 1. إظهار مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(skipSync ? 'جاري تسجيل الخروج السريع...' : 'جاري تسجيل الخروج ورفع البيانات...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 2. استدعاء تسجيل الخروج
      bool success = await _viewModel.logout(skipSync: skipSync);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // إغلاق الدايلوج
      }

      if (success && mounted) {
        MyApp.restartApp(context, loggedIn: false);
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_viewModel.logoutErrorMessage.isNotEmpty
                ? _viewModel.logoutErrorMessage
                : 'حدث خطأ أثناء تسجيل الخروج'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ غير متوقع: $e')),
        );
      }
    }
  }

  Future<void> _performSync() async {
    final syncService = SyncService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري المزامنة مع السحابة...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await syncService.performSmartSync();
      if (!mounted) return;
      Navigator.pop(context); // إغلاق الحوار
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت المزامنة بنجاح!')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // إغلاق الحوار
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('فشلت المزامنة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F9),
          appBar: _buildAppBar(),
          body: IndexedStack(
            index: _viewModel.currentIndex,
            children: _navItems.map((item) => item.page).toList(),
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: DesktopColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          const Icon(Icons.school, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'نظام الشؤون الأكاديمية',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  _viewModel.roleDisplayName,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.sync_rounded),
          tooltip: 'مزامنة',
          onPressed: _performSync,
        ),
        // قائمة الإشعارات المتصلة بـ Firestore مع شارة العدد غير المقروء (مفرزة محلياً لتجنب الحاجة لفهرس سحابي)
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

              // ترتيب الإشعارات محلياً من الأحدث إلى الأقدم
              sortedDocs = List.from(snapshot.data!.docs);
              sortedDocs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = aData['createdAt'] as Timestamp?;
                final bTime = bData['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime); // ترتيب تنازلي (الأحدث أولاً)
              });
            }

            return Badge(
              label: Text(unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
              isLabelVisible: unreadCount > 0,
              backgroundColor: Colors.red,
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'الإشعارات',
                onPressed: () =>
                    _showNotificationsBottomSheet(context, sortedDocs),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'تسجيل الخروج',
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  // عرض قائمة الإشعارات في لوحة سفلية منبثقة
  void _showNotificationsBottomSheet(
      BuildContext context, List<QueryDocumentSnapshot> docs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الإشعارات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    if (docs.any((d) =>
                        (d.data() as Map<String, dynamic>)['isRead'] == false))
                      TextButton(
                        onPressed: () async {
                          // تحديد كل الإشعارات كمقروءة دفعة واحدة
                          final batch = FirebaseFirestore.instance.batch();
                          for (var doc in docs) {
                            batch.update(doc.reference, {'isRead': true});
                          }
                          await batch.commit();
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text(
                          'تحديد الكل كمقروء',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const Divider(),
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
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isRead
                                    ? Colors.transparent
                                    : DesktopColors.primary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.notifications_active_outlined,
                                  color: isRead
                                      ? Colors.grey
                                      : DesktopColors.primary,
                                ),
                                title: Text(
                                  data['title'] ?? 'إشعار جديد',
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    fontSize: 14,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                subtitle: Text(
                                  data['body'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 12, fontFamily: 'Cairo'),
                                ),
                                onTap: () async {
                                  // تحديد الإشعار كمقروء عند النقر عليه
                                  await docs[index]
                                      .reference
                                      .update({'isRead': true});
                                  if (context.mounted) {
                                    Navigator.pop(context); // إغلاق اللوحة السفلية
                                    if (data['type'] == 'request') {
                                      _viewModel.changeTab(2); // الانتقال إلى تبويب الطلبات (فهرس 2)
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => NotificationDetailsView(
                                            notificationId: docs[index].id,
                                            notificationData: data,
                                          ),
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
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _viewModel.currentIndex,
          onTap: (i) => _viewModel.changeTab(i),
          backgroundColor: Colors.white,
          selectedItemColor: DesktopColors.primary,
          unselectedItemColor: const Color(0xFF6B7280),
          selectedLabelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: _navItems
              .map(
                (item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });
}
