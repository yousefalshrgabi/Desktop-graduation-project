import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';

import '../services/course_need_letter_service.dart';
import 'course_need_preview_screen.dart';

class CourseNeedRequestsScreen extends StatefulWidget {
  const CourseNeedRequestsScreen({super.key});

  @override
  State<CourseNeedRequestsScreen> createState() =>
      _CourseNeedRequestsScreenState();
}

class _CourseNeedRequestsScreenState extends State<CourseNeedRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = CourseNeedLetterService();
  final _session = AppSession();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  ({String label, Color color, IconData icon}) _getStatusInfo(String status) {
    switch (status) {
      case 'pending_dean':
        return (
          label: 'بانتظار العميد',
          color: Colors.blue,
          icon: Icons.pending_actions
        );
      case 'pending_academic_affairs':
        return (
          label: 'بانتظار النيابة',
          color: Colors.orange,
          icon: Icons.hourglass_top
        );
      case 'rejected_by_dean':
        return (
          label: 'مرفوضة من العميد',
          color: Colors.red,
          icon: Icons.cancel
        );
      case 'approved':
        return (
          label: 'معتمدة نهائياً',
          color: Colors.green,
          icon: Icons.check_circle
        );
      case 'rejected_by_academic_affairs':
        return (
          label: 'مرفوضة من النيابة',
          color: Colors.red.shade900,
          icon: Icons.block
        );
      default:
        return (
          label: 'غير معروف',
          color: Colors.grey,
          icon: Icons.help_outline
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const SharedDesktopAppBar(
          customTitle: 'مقررات الاحتياج (الوارد والصادر)',
        ),
        body: Column(
          children: [
            Container(
              color: DesktopColors.primary,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(icon: Icon(Icons.move_to_inbox), text: 'البريد الوارد'),
                  Tab(icon: Icon(Icons.outbox), text: 'البريد الصادر'),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<SavedCourseNeedLetter>>(
                stream: _service.watchLetters(collegeName: null),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                  }

                  final allRequests = snapshot.data ?? [];
                  final inbox = <SavedCourseNeedLetter>[];
                  final outbox = <SavedCourseNeedLetter>[];

                  debugPrint('[NEEDS_REQUESTS] =============================');
                  debugPrint('[NEEDS_REQUESTS] UID الحالي: $currentUid');
                  debugPrint('[NEEDS_REQUESTS] Email الحالي: $currentEmail');
                  debugPrint(
                      '[NEEDS_REQUESTS] isViceDean: ${_session.isViceDean}');
                  debugPrint('[NEEDS_REQUESTS] isDean: ${_session.isDean}');
                  debugPrint(
                      '[NEEDS_REQUESTS] isAdmin: ${_session.isAdminOrDeanship}');
                  debugPrint(
                      '[NEEDS_REQUESTS] إجمالي الخطابات: ${allRequests.length}');

                  for (final req in allRequests) {
                    final s = req.status;
                    debugPrint(
                        '[NEEDS_REQUESTS] خطاب: id=${req.id}, status=$s, createdByUid=${req.createdByUid}, createdByEmail=${req.createdByEmail}');

                    if (_session.isAdminOrDeanship) {
                      if (s == 'pending_academic_affairs') inbox.add(req);
                      if (s == 'approved' ||
                          s == 'rejected_by_academic_affairs') outbox.add(req);
                    } else if (_session.isDean) {
                      if (s == 'pending_dean' ||
                          s == 'approved' ||
                          s == 'rejected_by_academic_affairs') inbox.add(req);
                      if (s == 'pending_academic_affairs' ||
                          s == 'rejected_by_dean') outbox.add(req);
                    } else {
                      final isMyLetter = (currentUid.isNotEmpty &&
                              req.createdByUid == currentUid) ||
                          (currentEmail.isNotEmpty &&
                              req.createdByEmail == currentEmail);

                      debugPrint(
                          '[NEEDS_REQUESTS] isMyLetter=$isMyLetter (uidMatch=${req.createdByUid == currentUid}, emailMatch=${req.createdByEmail == currentEmail})');

                      if (isMyLetter) {
                        if (s == 'rejected_by_dean' ||
                            s == 'approved' ||
                            s == 'rejected_by_academic_affairs') {
                          inbox.add(req);
                        }
                        if (s == 'pending_dean' ||
                            s == 'pending_academic_affairs') {
                          outbox.add(req);
                        }
                      }
                    }
                  }

                  debugPrint(
                      '[NEEDS_REQUESTS] الوارد: ${inbox.length}, الصادر: ${outbox.length}');

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(inbox, 'لا توجد طلبات في البريد الوارد.'),
                      _buildList(outbox, 'لا توجد طلبات في البريد الصادر.'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<SavedCourseNeedLetter> list, String emptyMessage) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final req = list[index];
        final statusInfo = _getStatusInfo(req.status);
        final dateStr = req.createdAt != null
            ? '${req.createdAt!.year}-${req.createdAt!.month.toString().padLeft(2, '0')}-${req.createdAt!.day.toString().padLeft(2, '0')}'
            : '';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              'خطاب احتياج - كلية ${req.collegeName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'الفصل الدراسي: ${req.term == 'first' ? 'الأول' : 'الثاني'}'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(statusInfo.icon, size: 16, color: statusInfo.color),
                      const SizedBox(width: 4),
                      Text(
                        statusInfo.label,
                        style: TextStyle(
                            color: statusInfo.color,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(dateStr,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CourseNeedPreviewScreen(
                    collegeName: req.collegeName,
                    term: req.term,
                    data: req.data,
                    savedLetter:
                        req, // We will add this to CourseNeedPreviewScreen
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
