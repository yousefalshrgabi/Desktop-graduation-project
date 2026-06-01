import 'package:flutter/material.dart';
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
        return Colors.blue;
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
    }
  }

  void _onMeetingTapped(MeetingModel meeting) {
    final meetingsViewModel = Provider.of<MeetingsViewModel>(context, listen: false);
    if (_isHOD) {
      if (meeting.status == MeetingStatus.scheduled ||
          meeting.status == MeetingStatus.draft ||
          meeting.status == MeetingStatus.rejected) {
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
        // Show status dialog for already submitted
        _showMeetingDetailDialog(meeting);
      }
    } else if (_isViceDean || _isDean) {
      // Check if status is pending their review
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
      } else {
        _showMeetingDetailDialog(meeting);
      }
    }
  }

  void _showMeetingDetailDialog(MeetingModel meeting) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(meeting.title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('التاريخ: ${meeting.date}  |  الوقت: ${meeting.time}'),
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
            ],
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
                      ScaffoldMessenger.of(context).showSnackBar(
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
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.calendar_month, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text('التاريخ: ${meeting.date}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              const SizedBox(width: 16),
                              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text('الوقت: ${meeting.time}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
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
