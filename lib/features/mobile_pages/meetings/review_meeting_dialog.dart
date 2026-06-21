import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'meeting_model.dart';
import 'meetings_viewmodel.dart';

class ReviewMeetingDialog extends StatefulWidget {
  final MeetingModel meeting;

  const ReviewMeetingDialog({super.key, required this.meeting});

  @override
  State<ReviewMeetingDialog> createState() => _ReviewMeetingDialogState();
}

class _ReviewMeetingDialogState extends State<ReviewMeetingDialog> {
  final _reasonController = TextEditingController();
  bool _showRejectInput = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String? documentUrl) async {
    if (documentUrl == null || documentUrl.isEmpty) return;
    final url = Uri.parse(documentUrl);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح رابط الملف.')),
        );
      }
    }
  }

  Future<void> _approve() async {
    final vm = Provider.of<MeetingsViewModel>(context, listen: false);
    final success = await vm.approveMeeting(widget.meeting);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم اعتماد المحضر بنجاح وتمريره للخطوة التالية.'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.errorMessage ?? 'حدث خطأ أثناء الاعتماد.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reject() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة سبب طلب التعديل.'), backgroundColor: Colors.red),
      );
      return;
    }

    final vm = Provider.of<MeetingsViewModel>(context, listen: false);
    final success = await vm.rejectMeeting(widget.meeting, _reasonController.text.trim());

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرجاع المحضر مع طلب التعديل.'), backgroundColor: Colors.orange),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.errorMessage ?? 'حدث خطأ أثناء الرفض.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: isMobile ? double.infinity : 550,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.rate_review, color: DesktopColors.primary, size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'مراجعة واعتماد المحضر',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // ── تفاصيل الاجتماع ──
                Text(
                  widget.meeting.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 8),
                Text('التاريخ: ${widget.meeting.date}  |  الوقت: ${widget.meeting.time}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 12),

                // ── جدول الأعمال والحاضرين ──
                const Text('جدول الأعمال:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ...widget.meeting.agenda.map((a) => Text('• $a', style: const TextStyle(fontSize: 13))),
                const SizedBox(height: 12),

                const Text('المحضر والمناقشات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.meeting.minutes.isNotEmpty ? widget.meeting.minutes : 'لا توجد تفاصيل نصية.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── رابط المستند المرفوع ──
                if (widget.meeting.documentUrl != null)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: DesktopColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DesktopColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.description, color: DesktopColors.primary),
                      title: const Text('ملف المحضر المرفوع (.docx / .pdf)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                      subtitle: Text(
                        widget.meeting.documentUrl == 'local_pending_upload'
                            ? 'بانتظار مزامنة ورفع الملف إلى السيرفر...'
                            : 'انقر لفتح وتحميل الملف ومراجعته',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: widget.meeting.documentUrl == 'local_pending_upload'
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.open_in_new, color: DesktopColors.primary),
                      onTap: widget.meeting.documentUrl == 'local_pending_upload'
                          ? null
                          : () => _openUrl(widget.meeting.documentUrl),
                    ),
                  )
                else
                  const Text('لم يتم رفع مستند رسمي للاجتماع بعد.', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),

                if (widget.meeting.previousMinutesUrl != null && widget.meeting.previousMinutesUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.description, color: Colors.green),
                      title: Text(widget.meeting.previousMinutesName ?? 'محضر الاجتماع السابق.docx', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                      subtitle: const Text('ملف محضر الاجتماع السابق المرفق', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.open_in_new, color: Colors.green),
                      onTap: () => _openUrl(widget.meeting.previousMinutesUrl),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── خيارات التعديل/الرفض ──
                if (_showRejectInput) ...[
                  const Text('سبب طلب التعديل / الرفض', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'اكتب هنا التعديلات المطلوبة من رئيس القسم...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── الأزرار ──
                Consumer<MeetingsViewModel>(
                  builder: (context, vm, child) {
                    if (vm.isSaving) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return Row(
                      children: [
                        if (!_showRejectInput) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showRejectInput = true;
                                });
                              },
                              icon: const Icon(Icons.cancel, color: Colors.red, size: 16),
                              label: const Text('طلب تعديل / رفض', style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _approve,
                              icon: const Icon(Icons.check_circle, size: 16),
                              label: const Text('اعتماد وموافقة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _showRejectInput = false;
                                });
                              },
                              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _reject,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text('تأكيد الرفض والإرجاع', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
