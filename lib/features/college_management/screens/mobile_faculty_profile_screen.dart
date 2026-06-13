import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class MobileFacultyProfileScreen extends StatelessWidget {
  final Map<String, dynamic> facultyData;

  const MobileFacultyProfileScreen({super.key, required this.facultyData});

  String _getString(String key, {String? fallbackKey}) {
    String val = facultyData[key]?.toString() ?? '';
    if ((val.isEmpty || val == 'غير محدد') && fallbackKey != null) {
      val = facultyData[fallbackKey]?.toString() ?? '';
    }
    return val;
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesSection() {
    String fileUrlStr = _getString('file_url');
    if (fileUrlStr.isEmpty) return const Text('لا توجد ملفات مرفقة');

    try {
      Map<String, dynamic> urls = jsonDecode(fileUrlStr);
      List<Widget> fileWidgets = [];

      final categories = {
        'idCard': 'صورة الهوية / الجواز',
        'contract': 'العقد',
        'personalPhoto': 'صورة شخصية',
        'certificates': 'الشهادات',
        'others': 'ملفات أخرى'
      };

      urls.forEach((key, valueList) {
        if (valueList is List && valueList.isNotEmpty) {
          String catName = categories[key] ?? key;

          bool hasValidUrls = false;
          List<Widget> categoryWidgets = [];

          categoryWidgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(catName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );

          for (int i = 0; i < valueList.length; i++) {
            String url = valueList[i].toString();
            if (url.isNotEmpty) {
              hasValidUrls = true;
              categoryWidgets
                  .add(FileItemWidget(url: url, title: 'ملف المرفق ${i + 1}'));
            }
          }

          if (hasValidUrls) {
            fileWidgets.addAll(categoryWidgets);
          }
        }
      });

      if (fileWidgets.isEmpty) return const Text('لا توجد ملفات مرفقة');
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: fileWidgets);
    } catch (e) {
      return const Text('خطأ في قراءة المرفقات');
    }
  }

  Widget _buildLeavesSection(String key, String title) {
    String leavesStr = _getString(key);
    if (leavesStr.isEmpty) return const SizedBox.shrink();

    try {
      List<dynamic> leaves = jsonDecode(leavesStr);
      if (leaves.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ...leaves.map((l) {
            Map<String, dynamic> leaf = l as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: leaf.entries
                      .map((e) => Text('${e.key}: ${e.value}'))
                      .toList(),
                ),
              ),
            );
          }),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الملف الشخصي: ${_getString('name')}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // البيانات الأساسية
            _buildSectionHeader(context, 'البيانات الأساسية', Icons.person),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow('الاسم الكامل', _getString('name')),
                    _buildInfoRow('الرقم الوظيفي', _getString('job_number')),
                    _buildInfoRow('رقم الملف', _getString('file_number')),
                    _buildInfoRow('رقم الهوية', _getString('id_card_number')),
                    _buildInfoRow('مكان الميلاد', _getString('birth_place')),
                    _buildInfoRow('تاريخ الميلاد', _getString('birth_date')),
                    const Divider(),
                    _buildInfoRow('القسم', _getString('department', fallbackKey: 'user_dept')),
                    _buildInfoRow(
                        'التخصص العام', _getString('general_specialization')),
                    _buildInfoRow(
                        'التخصص الدقيق', _getString('exact_specialization')),
                    _buildInfoRow('حالة العضو', _getString('status')),
                  ],
                ),
              ),
            ),

            // التعيينات
            _buildSectionHeader(context, 'تواريخ التعيين', Icons.work_history),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow('تاريخ أول تعيين',
                        _getString('first_appointment_date')),
                    _buildInfoRow('تاريخ التعيين بالجامعة',
                        _getString('university_appointment_date')),
                  ],
                ),
              ),
            ),

            // المؤهلات الأكاديمية
            _buildSectionHeader(context, 'المؤهلات الأكاديمية', Icons.school),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('البكالوريوس',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue)),
                    _buildInfoRow('الدرجة', _getString('bsc_degree')),
                    _buildInfoRow('التاريخ', _getString('bsc_date')),
                    _buildInfoRow('الجامعة', _getString('bsc_university')),
                    _buildInfoRow('الدولة', _getString('bsc_country')),
                    _buildInfoRow('التخصص', _getString('bsc_specialization')),
                    const Divider(),
                    const Text('الماجستير',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue)),
                    _buildInfoRow('الدرجة', _getString('msc_degree')),
                    _buildInfoRow('التاريخ', _getString('msc_date')),
                    _buildInfoRow('الجامعة', _getString('msc_university')),
                    _buildInfoRow('الدولة', _getString('msc_country')),
                    _buildInfoRow('التخصص الدقيق',
                        _getString('msc_exact_specialization')),
                    const Divider(),
                    const Text('الدرجة الحالية (دكتوراه وما يعادلها)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue)),
                    _buildInfoRow('الدرجة', _getString('current_degree')),
                    _buildInfoRow('التاريخ', _getString('current_degree_date')),
                    _buildInfoRow('الجامعة', _getString('current_university')),
                    _buildInfoRow('الدولة', _getString('current_country')),
                  ],
                ),
              ),
            ),

            // الترقيات
            _buildSectionHeader(
                context, 'الترقيات الأكاديمية', Icons.trending_up),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow(
                        'تاريخ أستاذ مساعد', _getString('assistant_prof_date')),
                    _buildInfoRow(
                        'رقم القرار', _getString('assistant_prof_decision')),
                    const Divider(),
                    _buildInfoRow(
                        'تاريخ أستاذ مشارك', _getString('assoc_prof_date')),
                    _buildInfoRow(
                        'رقم القرار', _getString('assoc_prof_decision')),
                    const Divider(),
                    _buildInfoRow('اللقب الأكاديمي الحالي',
                        _getString('current_academic_title')),
                    _buildInfoRow(
                        'تاريخ نقل اللقب', _getString('title_transfer_date')),
                  ],
                ),
              ),
            ),

            // الإجازات
            _buildSectionHeader(
                context, 'الإجازات الأكاديمية', Icons.event_busy),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLeavesSection(
                        'sabbatical_leaves', 'إجازات التفرغ العلمي'),
                    const SizedBox(height: 8),
                    _buildLeavesSection('unpaid_leaves', 'إجازات بدون راتب'),
                    if (_getString('sabbatical_leaves').isEmpty &&
                        _getString('unpaid_leaves').isEmpty)
                      const Text('لا توجد إجازات مسجلة'),
                  ],
                ),
              ),
            ),

            // الملفات المرفقة
            _buildSectionHeader(context, 'الملفات المرفقة', Icons.attach_file),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildFilesSection(),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class FileItemWidget extends StatefulWidget {
  final String url;
  final String title;
  const FileItemWidget({super.key, required this.url, required this.title});

  @override
  State<FileItemWidget> createState() => _FileItemWidgetState();
}

class _FileItemWidgetState extends State<FileItemWidget> {
  bool _isDownloading = false;

  Future<void> _downloadAndOpenFile() async {
    setState(() => _isDownloading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();

      String ext = '.pdf'; // default
      try {
        String rawPath = Uri.parse(widget.url).path;
        String possibleExt =
            rawPath.split('.').last.split('?').first.toLowerCase();
        if (possibleExt.length <= 5) ext = '.$possibleExt';
      } catch (_) {}

      final fileName = 'temp_file_${DateTime.now().millisecondsSinceEpoch}$ext';
      final savePath = '${directory.path}/$fileName';
      final file = File(savePath);

      // تحميل الملف من Firebase Storage
      await FirebaseStorage.instance.refFromURL(widget.url).writeToFile(file);

      // فتح الملف محلياً
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'لا يوجد تطبيق متاح لفتح هذا الملف (${result.message})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل الملف: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: _isDownloading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.download, color: Colors.blue),
      title: Text(widget.title,
          style: const TextStyle(
              color: Colors.blue, decoration: TextDecoration.underline)),
      onTap: _isDownloading ? null : _downloadAndOpenFile,
    );
  }
}
