import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:academic_affairs_management/core/services/app_session.dart';
import '../models/timetable_entry.dart';
import '../services/timetable_csv_parser.dart';
import '../services/timetable_firestore_service.dart';
import '../utils/csv_load.dart';

class UploadScheduleScreen extends StatefulWidget {
  const UploadScheduleScreen({super.key});

  @override
  State<UploadScheduleScreen> createState() => _UploadScheduleScreenState();
}

class _UploadScheduleScreenState extends State<UploadScheduleScreen> {
  final TimetableFirestoreService _firestore = TimetableFirestoreService();
  bool _busy = false;

  Future<void> _pickAndUpload() async {
    setState(() => _busy = true);
    final userCollege = AppSession().userCollege.trim();

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final file = result.files.single;
      final text = await loadPickedCsvText(file);
      if (text == null || text.trim().isEmpty) {
        _toast(
            'تعذر قراءة محتوى الملف. جرّب نسخ الملف إلى التخزين الداخلي أو أعد الاختيار.');
        if (mounted) setState(() => _busy = false);
        return;
      }

      final parser = TimetableCsvParser();
      final List<TimetableEntry> entries = parser.parse(text);
      if (entries.isEmpty) {
        _toast('لم يُستخرج أي نشاط من الملف. تحقق من صيغة CSV.');
        if (mounted) setState(() => _busy = false);
        return;
      }

      // رفع الجدول مخصصاً للكلية التي ينتمي إليها النائب الأكاديمي تلقائياً
      await _firestore.replaceAll(
        entries,
        collegeName: userCollege,
      );

      if (!mounted) return;
      _toast('✅ تم رفع ${entries.length} نشاطاً لكلية ($userCollege) بنجاح');
    } catch (e) {
      if (mounted) {
        _toast('خطأ: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userCollege = AppSession().userCollege.trim();
    final hasCollege = userCollege.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.upload_file, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        'استيراد جدول من FET',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'اختر ملف CSV مُصدَّر من برنامج FET. سيتم استبدال جدول كليتك فقط.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasCollege
                                ? 'سيتم تخصيص الرفع تلقائياً لـ: $userCollege'
                                : '⚠️ خطأ: لم يتم التعرف على كليتك!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  hasCollege ? null : theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy || !hasCollege ? null : _pickAndUpload,
            icon: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.folder_open),
            label: Text(_busy ? 'جاري الرفع...' : 'اختيار ملف ورفعه'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
