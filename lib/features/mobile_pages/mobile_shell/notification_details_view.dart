import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/features/mobile_pages/meetings/meeting_model.dart';

class NotificationDetailsView extends StatefulWidget {
  final String notificationId;
  final Map<String, dynamic> notificationData;

  const NotificationDetailsView({
    super.key,
    required this.notificationId,
    required this.notificationData,
  });

  @override
  State<NotificationDetailsView> createState() => _NotificationDetailsViewState();
}

class _NotificationDetailsViewState extends State<NotificationDetailsView> {
  bool _isLoadingMeeting = false;
  MeetingModel? _meeting;
  String? _meetingLoadError;

  @override
  void initState() {
    super.initState();
    _loadAssociatedMeeting();
  }

  Future<void> _loadAssociatedMeeting() async {
    final type = widget.notificationData['type'];
    final meetingId = widget.notificationData['meetingId'];

    if (type == 'meeting' && meetingId != null && meetingId.toString().isNotEmpty) {
      setState(() {
        _isLoadingMeeting = true;
        _meetingLoadError = null;
      });

      try {
        final doc = await FirebaseFirestore.instance
            .collection('meetings')
            .doc(meetingId)
            .get();

        if (doc.exists && doc.data() != null) {
          setState(() {
            _meeting = MeetingModel.fromMap(doc.data()!);
          });
        } else {
          setState(() {
            _meetingLoadError = 'لم يتم العثور على بيانات الاجتماع المرتبط أو تم حذفه.';
          });
        }
      } catch (e) {
        setState(() {
          _meetingLoadError = 'حدث خطأ أثناء تحميل بيانات الاجتماع: $e';
        });
      } finally {
        setState(() {
          _isLoadingMeeting = false;
        });
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return '';
    }
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

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

  @override
  Widget build(BuildContext context) {
    final title = widget.notificationData['title'] ?? 'تفاصيل الإشعار';
    final body = widget.notificationData['body'] ?? '';
    final createdAt = widget.notificationData['createdAt'];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text(
            'تفاصيل الإشعار',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          backgroundColor: DesktopColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // كارد تفاصيل الإشعار الرئيسي
              Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: DesktopColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_active_outlined,
                              color: DesktopColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                    color: DesktopColors.textPrimary,
                                  ),
                                ),
                                if (createdAt != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatTimestamp(createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Cairo',
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14.0),
                        child: Divider(),
                      ),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          fontFamily: 'Cairo',
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // جزء الاجتماع المرتبط بالإشعار
              if (widget.notificationData['type'] == 'meeting') ...[
                if (_isLoadingMeeting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'جاري تحميل تفاصيل الاجتماع والملفات المرفقة...',
                            style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_meetingLoadError != null)
                  Card(
                    color: Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red.shade100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _meetingLoadError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontFamily: 'Cairo',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_meeting != null)
                  _buildMeetingDetailsCard(_meeting!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingDetailsCard(MeetingModel meeting) {
    final statusColor = _getStatusColor(meeting.status);

    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            Row(
              children: [
                const Icon(Icons.event, color: DesktopColors.primary, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'تفاصيل الاجتماع',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: DesktopColors.primary,
                  ),
                ),
                const Spacer(),
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
            const Divider(height: 24),

            // معلومات الوقت والمكان
            _buildDetailRow(Icons.title, 'موضوع الاجتماع', meeting.title),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow(Icons.calendar_today_outlined, 'التاريخ', meeting.date),
                ),
                Expanded(
                  child: _buildDetailRow(Icons.access_time, 'الوقت', meeting.time),
                ),
              ],
            ),
            if (meeting.room.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildDetailRow(Icons.place_outlined, 'القاعة / المكان', meeting.room),
            ],

            const SizedBox(height: 20),

            // جدول الأعمال
            const Text(
              'جدول الأعمال:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                fontSize: 14,
                color: DesktopColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ...meeting.agenda.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0, right: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_left, color: DesktopColors.primary, size: 18),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Cairo',
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 20),

            // المدعوون
            const Text(
              'أعضاء هيئة التدريس المدعوون:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                fontSize: 14,
                color: DesktopColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: meeting.attendees.map((attendee) {
                return Chip(
                  avatar: const CircleAvatar(
                    backgroundColor: DesktopColors.primary,
                    child: Icon(Icons.person, size: 12, color: Colors.white),
                  ),
                  label: Text(
                    attendee,
                    style: const TextStyle(fontSize: 12, fontFamily: 'Cairo'),
                  ),
                  backgroundColor: Colors.grey.shade50,
                  side: BorderSide(color: Colors.grey.shade200),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                );
              }).toList(),
            ),

            // الملفات المرفقة
            const Divider(height: 36),
            Row(
              children: const [
                Icon(Icons.attach_file, color: DesktopColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'الملفات والمحاضر المرفقة',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: DesktopColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 1. المحضر السابق
            if (meeting.previousMinutesUrl != null && meeting.previousMinutesUrl!.isNotEmpty) ...[
              _buildAttachmentCard(
                title: 'محضر الاجتماع السابق المرفق',
                fileName: meeting.previousMinutesName ?? 'محضر الاجتماع السابق.docx',
                url: meeting.previousMinutesUrl!,
              ),
              const SizedBox(height: 10),
            ],

            // 2. مستند المحضر الحالي المرفوع (إن وُجد)
            if (meeting.documentUrl != null && meeting.documentUrl!.isNotEmpty) ...[
              _buildAttachmentCard(
                title: 'مستند محضر هذا الاجتماع',
                fileName: meeting.documentUrl == 'local_pending_upload'
                    ? 'بانتظار مزامنة ورفع الملف إلى السيرفر...'
                    : 'محضر الاجتماع الحالي.docx',
                url: meeting.documentUrl!,
                isPending: meeting.documentUrl == 'local_pending_upload',
              ),
            ],

            if ((meeting.previousMinutesUrl == null || meeting.previousMinutesUrl!.isEmpty) &&
                (meeting.documentUrl == null || meeting.documentUrl!.isEmpty))
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'لا توجد ملفات مرفقة بهذا الاجتماع.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Cairo',
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Cairo',
                  color: DesktopColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentCard({
    required String title,
    required String fileName,
    required String url,
    bool isPending = false,
  }) {
    return InkWell(
      onTap: isPending ? null : () => _openDocument(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DesktopColors.primary.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DesktopColors.primary.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DesktopColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.description,
                color: DesktopColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'Cairo',
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: DesktopColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isPending)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                Icons.open_in_new,
                color: DesktopColors.primary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
