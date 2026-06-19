import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'meeting_model.dart';
import 'meetings_viewmodel.dart';
import 'schedule_meeting_view.dart';
import 'write_minutes_view.dart';
import 'review_meeting_dialog.dart';

class MeetingsListView extends StatelessWidget {
  const MeetingsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MeetingsViewModel(),
      child: const _MeetingsListViewContent(),
    );
  }
}

class _MeetingsListViewContent extends StatefulWidget {
  const _MeetingsListViewContent();

  @override
  State<_MeetingsListViewContent> createState() => _MeetingsListViewContentState();
}

class _MeetingsListViewContentState extends State<_MeetingsListViewContent> {
  final AppSession _session = AppSession();

  Future<void> _openDocument(String? documentUrl) async {
    if (documentUrl == null || documentUrl.isEmpty) return;
    final url = Uri.parse(documentUrl);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('تعذر فتح رابط الملف.')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<MeetingsViewModel>(context, listen: false).loadMeetings();
      }
    });
  }

  bool get _isHOD => _session.isDeptHead;
  bool get _isViceDean => _session.isViceDean;
  bool get _isDean => _session.isDean;

  Color _getStatusColor(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.scheduled:
        return DesktopColors.primary;
      case MeetingStatus.draft:
        return Colors.grey;
      case MeetingStatus.pendingViceDean:
        return Colors.orange;
      case MeetingStatus.pendingDean:
        return Colors.indigo;
      case MeetingStatus.forwardedToPresidency:
        return Colors.green;
      case MeetingStatus.rejected:
        return Colors.red;
      case MeetingStatus.canceled:
        return Colors.black54;
    }
  }

  void _onMeetingTapped(MeetingModel meeting) {
    final meetingsViewModel = Provider.of<MeetingsViewModel>(context, listen: false);
    
    // Check if the current user (could be HOD who is also Vice Dean/Dean) can review this meeting
    final canReview = (_isViceDean && meeting.status == MeetingStatus.pendingViceDean) ||
                      (_isDean && meeting.status == MeetingStatus.pendingDean);

    if (canReview) {
      showDialog(
        context: context,
        builder: (context) => ChangeNotifierProvider.value(
          value: meetingsViewModel,
          child: ReviewMeetingDialog(meeting: meeting),
        ),
      ).then((success) {
        if (success == true && mounted) {
          meetingsViewModel.loadMeetings();
        }
      });
    } else if (_isHOD &&
        (meeting.status == MeetingStatus.scheduled ||
         meeting.status == MeetingStatus.draft ||
         meeting.status == MeetingStatus.rejected)) {
      // Navigate to write/edit minutes
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider.value(
            value: meetingsViewModel,
            child: WriteMinutesView(meeting: meeting),
          ),
        ),
      ).then((_) {
        if (mounted) {
          meetingsViewModel.loadMeetings();
        }
      });
    } else {
      // Show status dialog for already submitted or approved
      _showMeetingDetailDialog(meeting);
    }
  }

  void _editMeeting(BuildContext context, MeetingModel meeting) {
    final meetingsViewModel = Provider.of<MeetingsViewModel>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: meetingsViewModel,
          child: ScheduleMeetingView(meeting: meeting),
        ),
      ),
    ).then((success) {
      if (success == true && mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('تم تعديل الاجتماع بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        meetingsViewModel.loadMeetings();
      }
    });
  }

  void _confirmCancelMeeting(BuildContext context, MeetingModel meeting) {
    final meetingsViewModel = Provider.of<MeetingsViewModel>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد إلغاء الاجتماع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من رغبتك في إلغاء الاجتماع بعنوان "${meeting.title}"؟\nسيتم إرسال إشعار إلغاء للحاضرين.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تراجع', style: TextStyle(fontFamily: 'Cairo')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final success = await meetingsViewModel.cancelMeeting(meeting);
                if (success && mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('تم إلغاء الاجتماع بنجاح!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                } else if (mounted && meetingsViewModel.errorMessage != null) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(meetingsViewModel.errorMessage!),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('نعم، إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showMeetingDetailDialog(MeetingModel meeting) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(meeting.title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التاريخ: ${meeting.date}  |  الوقت: ${meeting.time}'),
                if (meeting.room.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('القاعة: ${meeting.room}'),
                ],
                const SizedBox(height: 12),
                const Text('حالة الاعتماد:', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(meeting.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getStatusColor(meeting.status).withOpacity(0.3)),
                  ),
                  child: Text(
                    meeting.status.displayName,
                    style: TextStyle(color: _getStatusColor(meeting.status), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                  ),
                ),
                if (meeting.status == MeetingStatus.rejected && meeting.rejectReason != null) ...[
                  const SizedBox(height: 12),
                  const Text('سبب طلب التعديل/الرفض:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  Text(meeting.rejectReason!, style: const TextStyle(color: Colors.black87)),
                ],
                const SizedBox(height: 16),
                const Text('جدول الأعمال:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...meeting.agenda.map((a) => Text('• $a')),
                if (meeting.previousMinutesUrl != null && meeting.previousMinutesUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('محضر الاجتماع السابق المرفق:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _openDocument(meeting.previousMinutesUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: DesktopColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: DesktopColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description, color: DesktopColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              meeting.previousMinutesName ?? 'محضر الاجتماع السابق.docx',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo', color: DesktopColors.primary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.open_in_new, color: DesktopColors.primary, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
                if (meeting.documentUrl != null && meeting.documentUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('مستند محضر الاجتماع المرفوع:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: meeting.documentUrl == 'local_pending_upload'
                        ? null
                        : () => _openDocument(meeting.documentUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: DesktopColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: DesktopColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description, color: DesktopColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              meeting.documentUrl == 'local_pending_upload'
                                  ? 'بانتظار مزامنة ورفع الملف إلى السيرفر...'
                                  : 'عرض ملف المحضر المرفوع (.docx / .pdf)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo', color: DesktopColors.primary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (meeting.documentUrl == 'local_pending_upload')
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            const Icon(Icons.open_in_new, color: DesktopColors.primary, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اجتماعات مجلس القسم', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: DesktopColors.primary,
          foregroundColor: Colors.white,
          actions: [
            if (_isHOD)
              IconButton(
                icon: const Icon(Icons.add_task),
                tooltip: 'جدولة اجتماع جديد',
                onPressed: () {
                  final meetingsViewModel = Provider.of<MeetingsViewModel>(context, listen: false);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangeNotifierProvider.value(
                        value: meetingsViewModel,
                        child: const ScheduleMeetingView(),
                      ),
                    ),
                  ).then((success) {
                    if (success == true && mounted) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('تمت جدولة الاجتماع بنجاح!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  });
                },
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث البيانات',
              onPressed: () => Provider.of<MeetingsViewModel>(context, listen: false).loadMeetings(),
            ),
          ],
        ),
        body: Consumer<MeetingsViewModel>(
          builder: (context, vm, child) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final meetingsList = vm.filteredMeetings;

            if (meetingsList.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد اجتماعات مسجلة حالياً.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16, fontFamily: 'Cairo'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: meetingsList.length,
              itemBuilder: (context, index) {
                final meeting = meetingsList[index];
                final statusColor = _getStatusColor(meeting.status);

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _onMeetingTapped(meeting),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  meeting.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: statusColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  meeting.status.displayName,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                              if (_isHOD &&
                                  (meeting.status == MeetingStatus.scheduled ||
                                   meeting.status == MeetingStatus.draft ||
                                   meeting.status == MeetingStatus.rejected)) ...[
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editMeeting(context, meeting);
                                    } else if (value == 'cancel') {
                                      _confirmCancelMeeting(context, meeting);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, color: DesktopColors.primary, size: 18),
                                          SizedBox(width: 8),
                                          Text('تعديل التفاصيل', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'cancel',
                                      child: Row(
                                        children: [
                                          Icon(Icons.cancel, color: Colors.red, size: 18),
                                          SizedBox(width: 8),
                                          Text('إلغاء الاجتماع', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_month, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text('التاريخ: ${meeting.date}', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontFamily: 'Cairo')),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text('الوقت: ${meeting.time}', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontFamily: 'Cairo')),
                                ],
                              ),
                              if (meeting.room.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.room, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text('القاعة: ${meeting.room}', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontFamily: 'Cairo')),
                                  ],
                                ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.list_alt, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'جدول الأعمال: ${meeting.agenda.join('، ')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[800], fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          if (_isHOD && meeting.status == MeetingStatus.rejected && meeting.rejectReason != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'تنبيه: تم رفض المحضر وبحاجة لتعديل: ${meeting.rejectReason}',
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
