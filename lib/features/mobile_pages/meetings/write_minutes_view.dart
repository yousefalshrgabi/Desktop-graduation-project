import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'meeting_model.dart';
import 'meetings_viewmodel.dart';

class WriteMinutesView extends StatefulWidget {
  final MeetingModel meeting;

  const WriteMinutesView({super.key, required this.meeting});

  @override
  State<WriteMinutesView> createState() => _WriteMinutesViewState();
}

class _WriteMinutesViewState extends State<WriteMinutesView> {
  final _minutesController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _localSaving = false;

  @override
  void initState() {
    super.initState();
    _minutesController.text = widget.meeting.minutes;
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم اختيار الملف: ${_selectedFile!.name}')),
        );
      }
    }
  }

  Future<void> _exportDocx() async {
    if (_minutesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة محتوى المحضر أولاً قبل التصدير.')),
      );
      return;
    }

    setState(() => _localSaving = true);
    final vm = Provider.of<MeetingsViewModel>(context, listen: false);
    final success = await vm.exportMinutesToDocx(widget.meeting, _minutesController.text.trim());
    setState(() => _localSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير وحفظ ملف Word بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'فشل تصدير ملف Word.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _localSaving = true);
    final vm = Provider.of<MeetingsViewModel>(context, listen: false);
    final success = await vm.saveMinutesDraft(widget.meeting.id, _minutesController.text.trim());
    setState(() => _localSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ المسودة بنجاح.'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _submitForApproval() async {
    if (_minutesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة تفاصيل المحضر أولاً.')),
      );
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار/تصدير ملف المحضر المرفوع (.docx / .pdf) أولاً للتقديم.')),
      );
      return;
    }

    final vm = Provider.of<MeetingsViewModel>(context, listen: false);
    final success = await vm.uploadAndSubmitMinutes(
      meeting: widget.meeting,
      file: _selectedFile!,
      minutesText: _minutesController.text.trim(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تقديم المحضر بنجاح إلى نائب العميد للمراجعة.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'فشلت عملية التقديم.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كتابة وتوثيق محضر الاجتماع', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: DesktopColors.primary,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── معلومات الاجتماع ──
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.meeting_room, color: DesktopColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.meeting.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber[200]!),
                            ),
                            child: Text(
                              widget.meeting.status.displayName,
                              style: TextStyle(color: Colors.amber[900], fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('التاريخ: ${widget.meeting.date}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(width: 16),
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('الوقت: ${widget.meeting.time}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                      if (widget.meeting.status == MeetingStatus.rejected && widget.meeting.rejectReason != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[100]!),
                          ),
                          child: Text(
                            'سبب طلب التعديل: ${widget.meeting.rejectReason}',
                            style: const TextStyle(color: Colors.red, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── بنود جدول الأعمال والحاضرين ──
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('جدول الأعمال والحاضرين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.meeting.agenda.map((a) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Expanded(child: Text(a, style: const TextStyle(fontSize: 13))),
                                ],
                              ),
                            )).toList(),
                      ),
                      if (widget.meeting.attendees.isNotEmpty) ...[
                        const Divider(height: 24),
                        const Text('الحاضرون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.meeting.attendees.map((att) => Chip(
                            avatar: const Icon(Icons.person, size: 14, color: Colors.grey),
                            label: Text(att, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.grey[100],
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── حقل كتابة المحضر وتصدير ورفع الملف ──
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تفاصيل المحضر والمناقشات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _minutesController,
                        maxLines: 12,
                        minLines: 6,
                        decoration: InputDecoration(
                          hintText: 'اكتب هنا تفاصيل الاجتماع، التوصيات، والقرارات المتخذة...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // أزرار التصدير والرفع وحفظ المسودة
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _localSaving ? null : _exportDocx,
                            icon: const Icon(Icons.download),
                            label: const Text('تصدير كـ Word (.docx)', style: TextStyle(fontFamily: 'Cairo')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[800],
                              foregroundColor: Colors.white,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _localSaving ? null : _saveDraft,
                            icon: const Icon(Icons.save),
                            label: const Text('حفظ كمسودة', style: TextStyle(fontFamily: 'Cairo')),
                          ),
                          ElevatedButton.icon(
                            onPressed: _pickFile,
                            icon: Icon(_selectedFile != null ? Icons.check_circle : Icons.upload_file,
                                color: _selectedFile != null ? Colors.green : null),
                            label: Text(
                              _selectedFile != null ? 'تغيير الملف المختار' : 'اختر ملف المحضر النهائي',
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedFile != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[100]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'الملف المختار للرفع: ${_selectedFile!.name}',
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // زر التقديم النهائي
              Consumer<MeetingsViewModel>(
                builder: (context, vm, child) {
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: vm.isSaving ? null : _submitForApproval,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesktopColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: vm.isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'تقديم المحضر للاعتماد (إرسال إلى نائب العميد)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
