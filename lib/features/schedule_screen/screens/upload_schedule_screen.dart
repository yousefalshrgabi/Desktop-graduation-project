import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:academic_affairs_management/core/services/app_session.dart';
import '../models/timetable_entry.dart';
import '../services/timetable_csv_parser.dart';
import '../services/timetable_firestore_service.dart';
import '../utils/csv_load.dart';
import '../services/teacher_alias_service.dart';
import '../models/teacher_alias.dart';
import '../../desktop_pages/workload_management/models/faculty_option.dart';
import '../../desktop_pages/workload_management/services/faculty_firestore_service.dart';
import '../widgets/teacher_sync_dialog.dart';

class UploadScheduleScreen extends StatefulWidget {
  const UploadScheduleScreen({super.key});

  @override
  State<UploadScheduleScreen> createState() => _UploadScheduleScreenState();
}

class _UploadScheduleScreenState extends State<UploadScheduleScreen> {
  final TimetableFirestoreService _firestore = TimetableFirestoreService();
  final FacultyFirestoreService _facultyService = FacultyFirestoreService();
  final TeacherAliasService _aliasService = TeacherAliasService();

  bool _busy = false;
  bool _isLoadingSyncData = false;
  
  List<TimetableEntry> _allEntries = [];
  List<FacultyOption> _facultyMembers = [];
  List<TeacherAlias> _aliases = [];
  List<String> _unmappedNames = [];

  @override
  void initState() {
    super.initState();
    _loadSyncData();
  }

  Future<void> _loadSyncData() async {
    setState(() => _isLoadingSyncData = true);
    final userCollege = AppSession().userCollege.trim();
    if (userCollege.isEmpty) {
      if (mounted) setState(() => _isLoadingSyncData = false);
      return;
    }

    try {
      final futures = await Future.wait([
        _firestore.getByCollegeCachedFirst(userCollege, forceRefresh: true),
        _facultyService.listUniversityWide(forceRefresh: true),
        _aliasService.getAliasesForCollege(userCollege),
      ]);

      _allEntries = futures[0] as List<TimetableEntry>;
      _facultyMembers = futures[1] as List<FacultyOption>;
      _aliases = futures[2] as List<TeacherAlias>;

      _computeUnmappedNames();
    } catch (e) {
      debugPrint('Error loading sync data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSyncData = false);
    }
  }

  void _computeUnmappedNames() {
    final set = <String>{};
    for (final e in _allEntries) {
      for (final t in e.teachers) {
        if (t.trim().isNotEmpty) set.add(t.trim());
      }
    }
    final scheduleNames = set.toList()..sort();

    final facultyNames = _facultyMembers.map((f) => f.name.trim()).toSet();
    final aliasMap = {for (var a in _aliases) a.aliasName: a.canonicalName};

    final unmapped = <String>[];
    for (final name in scheduleNames) {
      if (!facultyNames.contains(name) && !aliasMap.containsKey(name)) {
        unmapped.add(name);
      }
    }
    _unmappedNames = unmapped;
  }

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
      
      // Reload sync data after upload
      await _loadSyncData();
      
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

    return SingleChildScrollView(
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
                          theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
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
          const SizedBox(height: 32),
          if (hasCollege) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: _unmappedNames.isNotEmpty
                        ? Colors.orange.shade300
                        : theme.colorScheme.outlineVariant),
              ),
              color: _unmappedNames.isNotEmpty ? Colors.orange.shade50 : null,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sync_alt,
                            color: _unmappedNames.isNotEmpty
                                ? Colors.orange.shade900
                                : theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          'مزامنة أسماء المعلمين المرفوعة',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _unmappedNames.isNotEmpty
                                ? Colors.orange.shade900
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'للربط بين أسماء المعلمين في الجداول المرفوعة من FET مع قاعدة البيانات الرسمية حتى يتم احتساب أنصبتهم بشكل صحيح.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (_isLoadingSyncData)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_unmappedNames.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'يوجد ${_unmappedNames.length} أسماء بحاجة للربط!',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => TeacherSyncDialog(
                              collegeName: userCollege,
                              unmappedNames: _unmappedNames,
                              facultyMembers: _facultyMembers,
                              onSyncComplete: _loadSyncData,
                            ),
                          );
                        },
                        icon: const Icon(Icons.link),
                        label: const Text('ربط الأسماء الآن'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange.shade200,
                          foregroundColor: Colors.orange.shade900,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'جميع الأسماء في الجداول مربوطة بنجاح.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
