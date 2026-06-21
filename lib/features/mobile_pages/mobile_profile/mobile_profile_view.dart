import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'mobile_profile_view_model.dart';
import 'package:academic_affairs_management/core/widgets/change_password_dialog.dart';

/// صفحة الملف الشخصي للعضو - تعرض معلوماته مع إمكانية طلب تعديلها
class MobileProfilePage extends StatefulWidget {
  const MobileProfilePage({super.key});

  @override
  State<MobileProfilePage> createState() => _MobileProfilePageState();
}

class _MobileProfilePageState extends State<MobileProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MobileProfileViewModel _viewModel = MobileProfileViewModel();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _viewModel.loadMemberData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _getLocalTargetPath(
      String path, String url, String memberName) async {
    if (path.isNotEmpty) {
      try {
        if (await File(path).exists()) return path;
      } catch (_) {}
    }

    String cleanName = memberName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    Directory appDocDir = await getApplicationDocumentsDirectory();

    String fileName = 'document';
    if (path.isNotEmpty) {
      fileName = path.split(RegExp(r'[\\/]')).last;
    } else if (url.isNotEmpty) {
      Uri parsedUrl = Uri.parse(url);
      String ext = '.pdf';
      if (parsedUrl.path.contains('.')) {
        String possibleExt = parsedUrl.path.split('.').last;
        if (possibleExt.length <= 4) ext = '.$possibleExt';
      }
      fileName = 'document_${url.hashCode}$ext';
    }

    return p.join(
        appDocDir.path, 'AcademicAffairs', 'Downloads', cleanName, fileName);
  }

  Future<bool> _checkIfFileExists(
      String path, String url, String memberName) async {
    String targetPath = await _getLocalTargetPath(path, url, memberName);
    try {
      return await File(targetPath).exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> _openLocalFile(
      BuildContext context, String path, String url, String memberName) async {
    String targetPath = await _getLocalTargetPath(path, url, memberName);

    bool fileExistsLocally = false;
    try {
      fileExistsLocally = await File(targetPath).exists();
    } catch (_) {}

    if (targetPath.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح الملف، المسار غير متوفر')),
        );
      }
      return;
    }

    final File file = File(targetPath);

    if (fileExistsLocally) {
      final result = await OpenFilex.open(targetPath);
      if (result.type != ResultType.done) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر فتح الملف: ${result.message}')),
          );
        }
      }
    } else {
      if (url.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('جاري تحميل الملف من السحابة...'),
              ],
            ),
          ),
        );

        try {
          final dir = file.parent;
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }

          final request = await HttpClient().getUrl(Uri.parse(url));
          final response = await request.close();

          if (response.statusCode == 200) {
            await response.pipe(file.openWrite());
          } else {
            throw Exception('فشل التحميل، كود الخطأ: ${response.statusCode}');
          }

          if (context.mounted) {
            Navigator.pop(context);
          }

          // Trigger UI rebuild so the icon changes from download to open
          if (mounted) setState(() {});

          final result = await OpenFilex.open(targetPath);
          if (result.type != ResultType.done) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('تعذر فتح الملف بعد التحميل: ${result.message}')),
              );
            }
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('فشل تحميل الملف: $e')),
            );
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('الملف غير موجود محلياً ولا يوجد رابط سحابي له.')),
          );
        }
      }
    }
  }

  List<Widget> _buildFileCards() {
    List<Widget> widgets = [];
    final member = _viewModel.member;
    if (member == null) return widgets;

    debugPrint(
        '[MOBILE_PROFILE] member.localFilePath: ${member.localFilePath}');
    debugPrint('[MOBILE_PROFILE] member.fileUrl: ${member.fileUrl}');

    if (member.localFilePath.isEmpty && member.fileUrl.isEmpty) {
      return [
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange.shade200),
          ),
          color: Colors.orange.shade50,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text('لا توجد ملفات مرفقة',
                    style: TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        )
      ];
    }

    Map<String, List<String>> localPathsMap = {};
    if (member.localFilePath.startsWith('{')) {
      try {
        Map<String, dynamic> decoded = jsonDecode(member.localFilePath);
        debugPrint('[MOBILE_PROFILE] localFilePath decoded: $decoded');
        decoded.forEach((key, value) {
          localPathsMap[key] = List<String>.from(value);
        });
      } catch (e) {
        debugPrint('[MOBILE_PROFILE] localFilePath jsonDecode error: $e');
      }
    } else if (member.localFilePath.startsWith('[')) {
      try {
        localPathsMap['others'] =
            List<String>.from(jsonDecode(member.localFilePath));
      } catch (e) {}
    } else if (member.localFilePath.isNotEmpty) {
      localPathsMap['others'] = [member.localFilePath];
    }

    Map<String, List<String>> urlsMap = {};
    if (member.fileUrl.startsWith('{')) {
      try {
        Map<String, dynamic> decoded = jsonDecode(member.fileUrl);
        debugPrint('[MOBILE_PROFILE] fileUrl decoded: $decoded');
        decoded.forEach((key, value) {
          urlsMap[key] = List<String>.from(value);
        });
      } catch (e) {
        debugPrint('[MOBILE_PROFILE] fileUrl jsonDecode error: $e');
      }
    } else if (member.fileUrl.startsWith('[')) {
      try {
        urlsMap['others'] = List<String>.from(jsonDecode(member.fileUrl));
      } catch (e) {}
    } else if (member.fileUrl.isNotEmpty) {
      urlsMap['others'] = [member.fileUrl];
    }

    final Map<String, String> categoryTitles = {
      'idCard': 'بطاقة شخصية / جواز السفر',
      'contract': 'العقد',
      'personalPhoto': 'صورة شخصية',
      'certificates': 'الشهادات',
      'others': 'ملفات أخرى'
    };

    categoryTitles.forEach((key, title) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, right: 4),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: DesktopColors.primary)),
      ));

      List<String> paths = localPathsMap[key] ?? [];
      List<String> urls = urlsMap[key] ?? [];
      int count = paths.length > urls.length ? paths.length : urls.length;

      if (count == 0) {
        widgets.add(Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          color: Colors.grey.shade50,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 20),
                SizedBox(width: 8),
                Text('لم يتم إرفاق ملفات في هذا القسم',
                    style: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ));
      } else {
        for (int i = 0; i < count; i++) {
          String p = i < paths.length ? paths[i] : '';
          String u = i < urls.length ? urls[i] : '';

          if (p.isEmpty && u.isEmpty) continue;

          String fileName = p.isNotEmpty
              ? p.split(RegExp(r'[\\/]')).last
              : 'ملف ${i + 1} من السحابة';

          widgets.add(Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            color: Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openLocalFile(context, p, u, member.name),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                        (key == 'idCard' || key == 'personalPhoto')
                            ? Icons.image
                            : Icons.picture_as_pdf,
                        color: Colors.redAccent,
                        size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<bool>(
                        future: _checkIfFileExists(p, u, member.name),
                        builder: (context, snapshot) {
                          bool exists = snapshot.data ?? false;
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fileName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF1A1A1A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      exists
                                          ? 'متاح محلياً - انقر للفتح'
                                          : 'انقر لتحميل الملف',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: exists
                                            ? Colors.green.shade700
                                            : DesktopColors.primary
                                                .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                exists
                                    ? Icons.file_open
                                    : Icons.download_rounded,
                                color: exists
                                    ? Colors.green.shade700
                                    : Colors.grey,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  _showDeleteFileConfirmDialog(
                                      key, u, fileName);
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ));
        }
      }
    });

    return widgets;
  }

  void _showDeleteFileConfirmDialog(
      String category, String fileUrl, String fileName) {
    if (fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن حذف ملف غير محفوظ سحابياً')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف الملف'),
        content: Text(
            'هل أنت متأكد من رغبتك في إرسال طلب لحذف الملف المرفق "$fileName"؟\n\nبمجرد موافقة النيابة سيتم حذف الملف نهائياً ولن يمكن استعادته.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              bool success = await _viewModel.sendDeleteFileRequest(
                category: category,
                fileUrl: fileUrl,
                fileName: fileName,
              );
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تم إرسال طلب حذف الملف للنيابة بنجاح')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text(_viewModel.error ?? 'فشل في إرسال طلب الحذف')),
                  );
                }
              }
            },
            child: const Text('إرسال طلب الحذف',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBulkEditDialog() {
    final m = _viewModel.member!;

    // Map of labels to old values and their controllers
    final Map<String, Map<String, dynamic>> fields = {
      'الاسم الكامل': {'old': m.name, 'ctrl': TextEditingController(text: m.name)},
      'البريد الإلكتروني': {'old': _viewModel.session.userEmail, 'ctrl': TextEditingController(text: _viewModel.session.userEmail)},
      'رقم الملف': {'old': m.fileNumber, 'ctrl': TextEditingController(text: m.fileNumber)},
      'رقم الهوية': {'old': m.idCardNumber, 'ctrl': TextEditingController(text: m.idCardNumber)},
      'الرقم الوظيفي': {'old': m.jobNumber, 'ctrl': TextEditingController(text: m.jobNumber)},
      'محل الميلاد': {'old': m.birthPlace, 'ctrl': TextEditingController(text: m.birthPlace)},
      'تاريخ الميلاد': {'old': m.birthDate, 'ctrl': TextEditingController(text: m.birthDate)},
      'القسم': {'old': m.department, 'ctrl': TextEditingController(text: m.department)},
      
      'تاريخ أول تعيين': {'old': m.firstAppointmentDate, 'ctrl': TextEditingController(text: m.firstAppointmentDate)},
      'تاريخ التعيين بالجامعة': {'old': m.universityAppointmentDate, 'ctrl': TextEditingController(text: m.universityAppointmentDate)},
      
      'شهادة البكالوريوس': {'old': m.bscDegree, 'ctrl': TextEditingController(text: m.bscDegree)},
      'تاريخ البكالوريوس': {'old': m.bscDate, 'ctrl': TextEditingController(text: m.bscDate)},
      'جامعة البكالوريوس': {'old': m.bscUniversity, 'ctrl': TextEditingController(text: m.bscUniversity)},
      'بلد البكالوريوس': {'old': m.bscCountry, 'ctrl': TextEditingController(text: m.bscCountry)},
      'اللقب الأكاديمي (بكالوريوس)': {'old': m.bscAcademicTitle, 'ctrl': TextEditingController(text: m.bscAcademicTitle)},
      'تاريخ نقل اللقب (بكالوريوس)': {'old': m.bscTitleTransferDate, 'ctrl': TextEditingController(text: m.bscTitleTransferDate)},
      'تخصص البكالوريوس': {'old': m.bscSpecialization, 'ctrl': TextEditingController(text: m.bscSpecialization)},

      'شهادة الماجستير': {'old': m.mscDegree, 'ctrl': TextEditingController(text: m.mscDegree)},
      'تاريخ الماجستير': {'old': m.mscDate, 'ctrl': TextEditingController(text: m.mscDate)},
      'جامعة الماجستير': {'old': m.mscUniversity, 'ctrl': TextEditingController(text: m.mscUniversity)},
      'بلد الماجستير': {'old': m.mscCountry, 'ctrl': TextEditingController(text: m.mscCountry)},
      'اللقب الأكاديمي (ماجستير)': {'old': m.mscAcademicTitle, 'ctrl': TextEditingController(text: m.mscAcademicTitle)},
      'تاريخ نقل اللقب (ماجستير)': {'old': m.mscTitleTransferDate, 'ctrl': TextEditingController(text: m.mscTitleTransferDate)},
      'رقم قرار الماجستير': {'old': m.mscDecisionNumber, 'ctrl': TextEditingController(text: m.mscDecisionNumber)},
      'التخصص الدقيق (ماجستير)': {'old': m.mscExactSpecialization, 'ctrl': TextEditingController(text: m.mscExactSpecialization)},

      'الدرجة الحالية': {'old': m.currentDegree, 'ctrl': TextEditingController(text: m.currentDegree)},
      'تاريخ الدرجة الحالية': {'old': m.currentDegreeDate, 'ctrl': TextEditingController(text: m.currentDegreeDate)},
      'الجامعة الحالية': {'old': m.currentUniversity, 'ctrl': TextEditingController(text: m.currentUniversity)},
      'البلد الحالي': {'old': m.currentCountry, 'ctrl': TextEditingController(text: m.currentCountry)},

      'تاريخ أستاذ مساعد': {'old': m.assistantProfDate, 'ctrl': TextEditingController(text: m.assistantProfDate)},
      'قرار أستاذ مساعد': {'old': m.assistantProfDecision, 'ctrl': TextEditingController(text: m.assistantProfDecision)},
      'تاريخ أستاذ مشارك': {'old': m.assocProfDate, 'ctrl': TextEditingController(text: m.assocProfDate)},
      'قرار أستاذ مشارك': {'old': m.assocProfDecision, 'ctrl': TextEditingController(text: m.assocProfDecision)},

      'اللقب الأكاديمي الحالي': {'old': m.currentAcademicTitle, 'ctrl': TextEditingController(text: m.currentAcademicTitle)},
      'تاريخ نقل اللقب الحالي': {'old': m.titleTransferDate, 'ctrl': TextEditingController(text: m.titleTransferDate)},
      'التخصص العام': {'old': m.generalSpecialization, 'ctrl': TextEditingController(text: m.generalSpecialization)},
      'التخصص الدقيق': {'old': m.exactSpecialization, 'ctrl': TextEditingController(text: m.exactSpecialization)},
    };

    Map<String, List<PlatformFile>> categorizedFiles = {
      'idCard': [],
      'contract': [],
      'personalPhoto': [],
      'certificates': [],
      'others': [],
    };
    String selectedCategory = 'others';
    final Map<String, String> categoryTitles = {
      'idCard': 'بطاقة شخصية / جواز السفر',
      'contract': 'العقد',
      'personalPhoto': 'صورة شخصية',
      'certificates': 'الشهادات',
      'others': 'ملفات أخرى'
    };

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (statefulContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(
                  children: [
                    const Text(
                      'طلب تعديل البيانات',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'قم بتعديل الحقول المطلوبة، وسيتم إرسال طلب واحد للنيابة يحتوي على كافة تعديلاتك.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        children: fields.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: entry.value['ctrl'],
                              decoration: InputDecoration(
                                labelText: entry.key,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                              ),
                            ),
                          );
                        }).toList()
                          ..add(
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 8, bottom: 20),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: DesktopColors.primary.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: DesktopColors.primary.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('إرفاق ملفات داعمة للموافقة',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: DesktopColors.primary)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child:
                                              DropdownButtonFormField<String>(
                                            initialValue: selectedCategory,
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              filled: true,
                                              fillColor: Colors.white,
                                            ),
                                            items: categoryTitles.entries
                                                .map((e) => DropdownMenuItem(
                                                    value: e.key,
                                                    child: Text(e.value,
                                                        style: const TextStyle(
                                                            fontSize: 13))))
                                                .toList(),
                                            onChanged: (val) {
                                              if (val != null)
                                                setSheetState(() =>
                                                    selectedCategory = val);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            FilePickerResult? result =
                                                await FilePicker.pickFiles(
                                              type: FileType.custom,
                                              allowedExtensions: [
                                                'pdf',
                                                'jpg',
                                                'png',
                                                'doc',
                                                'docx'
                                              ],
                                              allowMultiple: true,
                                            );
                                            if (result != null) {
                                              setSheetState(() {
                                                categorizedFiles[
                                                        selectedCategory]!
                                                    .addAll(result.files);
                                              });
                                            }
                                          },
                                          icon: const Icon(Icons.attach_file,
                                              size: 16),
                                          label: const Text('إرفاق'),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor:
                                                  DesktopColors.primary,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8))),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ...categoryTitles.keys.map((catKey) {
                                      final files = categorizedFiles[catKey]!;
                                      if (files.isEmpty)
                                        return const SizedBox.shrink();
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(categoryTitles[catKey]!,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        DesktopColors.primary)),
                                            ...files
                                                .map((f) => Row(
                                                      children: [
                                                        const Icon(
                                                            Icons.description,
                                                            size: 14,
                                                            color: DesktopColors.primary),
                                                        const SizedBox(
                                                            width: 4),
                                                        Expanded(
                                                            child: Text(f.name,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        11))),
                                                        IconButton(
                                                          icon: const Icon(
                                                              Icons.close,
                                                              size: 14,
                                                              color:
                                                                  Colors.red),
                                                          onPressed: () =>
                                                              setSheetState(() =>
                                                                  categorizedFiles[
                                                                          catKey]!
                                                                      .remove(
                                                                          f)),
                                                          padding:
                                                              EdgeInsets.zero,
                                                          constraints:
                                                              const BoxConstraints(),
                                                        )
                                                      ],
                                                    ))
                                                .toList(),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: isSubmitting
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () async {
                                  Map<String, String> fieldMapping = {
                                    'الاسم الكامل': 'name',
                                    'البريد الإلكتروني': 'email',
                                    'رقم الملف': 'fileNumber',
                                    'رقم الهوية': 'idCardNumber',
                                    'الرقم الوظيفي': 'jobNumber',
                                    'محل الميلاد': 'birthPlace',
                                    'تاريخ الميلاد': 'birthDate',
                                    'القسم': 'department',
                                    
                                    'تاريخ أول تعيين': 'firstAppointmentDate',
                                    'تاريخ التعيين بالجامعة': 'universityAppointmentDate',
                                    
                                    'شهادة البكالوريوس': 'bscDegree',
                                    'تاريخ البكالوريوس': 'bscDate',
                                    'جامعة البكالوريوس': 'bscUniversity',
                                    'بلد البكالوريوس': 'bscCountry',
                                    'اللقب الأكاديمي (بكالوريوس)': 'bscAcademicTitle',
                                    'تاريخ نقل اللقب (بكالوريوس)': 'bscTitleTransferDate',
                                    'تخصص البكالوريوس': 'bscSpecialization',

                                    'شهادة الماجستير': 'mscDegree',
                                    'تاريخ الماجستير': 'mscDate',
                                    'جامعة الماجستير': 'mscUniversity',
                                    'بلد الماجستير': 'mscCountry',
                                    'اللقب الأكاديمي (ماجستير)': 'mscAcademicTitle',
                                    'تاريخ نقل اللقب (ماجستير)': 'mscTitleTransferDate',
                                    'رقم قرار الماجستير': 'mscDecisionNumber',
                                    'التخصص الدقيق (ماجستير)': 'mscExactSpecialization',

                                    'الدرجة الحالية': 'currentDegree',
                                    'تاريخ الدرجة الحالية': 'currentDegreeDate',
                                    'الجامعة الحالية': 'currentUniversity',
                                    'البلد الحالي': 'currentCountry',

                                    'تاريخ أستاذ مساعد': 'assistantProfDate',
                                    'قرار أستاذ مساعد': 'assistantProfDecision',
                                    'تاريخ أستاذ مشارك': 'assocProfDate',
                                    'قرار أستاذ مشارك': 'assocProfDecision',

                                    'اللقب الأكاديمي الحالي': 'currentAcademicTitle',
                                    'تاريخ نقل اللقب الحالي': 'titleTransferDate',
                                    'التخصص العام': 'generalSpecialization',
                                    'التخصص الدقيق': 'exactSpecialization',
                                  };

                                  List<String> changes = [];
                                  Map<String, dynamic> extraData = {};

                                  for (var entry in fields.entries) {
                                    String oldVal =
                                        entry.value['old'] ?? 'غير محدد';
                                    String newVal =
                                        entry.value['ctrl'].text.trim();
                                    if (oldVal == '') oldVal = 'غير محدد';
                                    if (newVal == '') newVal = 'غير محدد';

                                    if (oldVal != newVal) {
                                      changes.add(
                                          '- ${entry.key}: من [$oldVal] إلى [$newVal]');
                                      String? technicalKey =
                                          fieldMapping[entry.key];
                                      if (technicalKey != null) {
                                        extraData[technicalKey] = newVal;
                                      }
                                    }
                                  }

                                  bool hasFiles = categorizedFiles.values
                                      .any((list) => list.isNotEmpty);

                                  if (changes.isEmpty && !hasFiles) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'لم تقم بإجراء أي تعديلات.')),
                                    );
                                    return;
                                  }

                                  setSheetState(() => isSubmitting = true);

                                  Map<String, List<PlatformFile>> finalFiles =
                                      {};
                                  categorizedFiles.forEach((k, v) {
                                    if (v.isNotEmpty) finalFiles[k] = v;
                                  });

                                  bool success =
                                      await _viewModel.sendEditRequest(
                                    extraData: extraData,
                                    changes: changes,
                                    categorizedFiles: finalFiles,
                                  );

                                  setSheetState(() => isSubmitting = false);

                                  if (!mounted) return;
                                  Navigator.pop(context);

                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            'تم إرسال طلب التعديل للنيابة بنجاح.'),
                                        backgroundColor: Colors.green.shade700,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            'فشل إرسال الطلب، تأكد من اتصالك بالإنترنت.'),
                                        backgroundColor: Colors.red.shade700,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DesktopColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('إرسال طلب التعديل',
                                    style: TextStyle(fontSize: 16)),
                              ),
                            ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('ملفي الشخصي'),
        backgroundColor: DesktopColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key),
            tooltip: 'تغيير كلمة المرور',
            onPressed: () async {
              final success = await showDialog<bool>(
                context: context,
                builder: (context) => const ChangePasswordDialog(),
              );
              if (success == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تغيير كلمة المرور بنجاح.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _viewModel.refreshData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'البيانات الشخصية'),
            Tab(icon: Icon(Icons.school), text: 'المؤهلات العلمية'),
            Tab(icon: Icon(Icons.work), text: 'المسار الوظيفي'),
            Tab(icon: Icon(Icons.folder_special), text: 'الملفات المرفقة'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          return _viewModel.member != null
              ? FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: _showBulkEditDialog,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('تعديل البيانات'),
                  backgroundColor: DesktopColors.primary,
                  foregroundColor: Colors.white,
                )
              : const SizedBox.shrink();
        },
      ),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_viewModel.error != null) {
            return _buildErrorState();
          }

          return RefreshIndicator(
            onRefresh: _viewModel.refreshData,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPersonalInfoTab(),
                _buildEducationTab(),
                _buildCareerTab(),
                _buildFilesTab(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _viewModel.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _viewModel.loadMemberData,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesktopColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =================== التبويب 1: البيانات الشخصية ===================
  Widget _buildPersonalInfoTab() {
    final m = _viewModel.member!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('المعلومات الأساسية', Icons.badge_outlined),
        _buildEditableInfoCard('الاسم الكامل', 'name', m.name),
        _buildEditableInfoCard('رقم الملف', 'file_number', m.fileNumber),
        _buildEditableInfoCard('رقم الهوية', 'id_card_number', m.idCardNumber),
        _buildEditableInfoCard('الرقم الوظيفي', 'job_number', m.jobNumber),
        _buildEditableInfoCard('محل الميلاد', 'birth_place', m.birthPlace),
        _buildEditableInfoCard('تاريخ الميلاد', 'birth_date', m.birthDate),
        const SizedBox(height: 8),
        _buildSectionHeader('تاريخ التعيين', Icons.calendar_today_outlined),
        _buildEditableInfoCard('تاريخ أول تعيين', 'first_appointment_date',
            m.firstAppointmentDate),
        _buildEditableInfoCard('تاريخ التعيين بالجامعة',
            'university_appointment_date', m.universityAppointmentDate),
        const SizedBox(height: 8),
        _buildSectionHeader('معلومات الكلية والقسم', Icons.business_outlined),
        _buildEditableInfoCard(
            'الكلية', 'department', _viewModel.session.userCollege,
            editable: false),
        _buildEditableInfoCard('القسم', 'department', m.department),
      ],
    );
  }

  // =================== التبويب الجديد: الملفات المرفقة ===================
  Widget _buildFilesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('الملفات والمستندات', Icons.folder_open_outlined),
        ..._buildFileCards(),
      ],
    );
  }

  // =================== التبويب 2: المؤهلات العلمية ===================
  Widget _buildEducationTab() {
    final m = _viewModel.member!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('درجة البكالوريوس', Icons.school_outlined),
        _buildEditableInfoCard('الدرجة', 'bsc_degree', m.bscDegree),
        _buildEditableInfoCard('تاريخ الحصول', 'bsc_date', m.bscDate),
        _buildEditableInfoCard('الجامعة', 'bsc_university', m.bscUniversity),
        _buildEditableInfoCard('الدولة', 'bsc_country', m.bscCountry),
        _buildEditableInfoCard(
            'التخصص', 'bsc_specialization', m.bscSpecialization),
        const SizedBox(height: 8),
        _buildSectionHeader('درجة الماجستير', Icons.auto_stories_outlined),
        _buildEditableInfoCard('الدرجة', 'msc_degree', m.mscDegree),
        _buildEditableInfoCard('تاريخ الحصول', 'msc_date', m.mscDate),
        _buildEditableInfoCard('الجامعة', 'msc_university', m.mscUniversity),
        _buildEditableInfoCard('الدولة', 'msc_country', m.mscCountry),
        _buildEditableInfoCard('التخصص الدقيق', 'msc_exact_specialization',
            m.mscExactSpecialization),
        const SizedBox(height: 8),
        _buildSectionHeader('الدرجة الحالية', Icons.emoji_events_outlined),
        _buildEditableInfoCard('الدرجة', 'current_degree', m.currentDegree),
        _buildEditableInfoCard(
            'تاريخ الحصول', 'current_degree_date', m.currentDegreeDate),
        _buildEditableInfoCard(
            'الجامعة', 'current_university', m.currentUniversity),
        _buildEditableInfoCard('الدولة', 'current_country', m.currentCountry),
        const SizedBox(height: 8),
        _buildSectionHeader('التخصص', Icons.biotech_outlined),
        _buildEditableInfoCard(
            'التخصص العام', 'general_specialization', m.generalSpecialization),
        _buildEditableInfoCard(
            'التخصص الدقيق', 'exact_specialization', m.exactSpecialization),
      ],
    );
  }

  // =================== التبويب 3: المسار الوظيفي ===================
  Widget _buildCareerTab() {
    final m = _viewModel.member!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
            'اللقب الأكاديمي الحالي', Icons.military_tech_outlined),
        _buildEditableInfoCard(
            'اللقب', 'current_academic_title', m.currentAcademicTitle),
        _buildEditableInfoCard(
            'تاريخ الانتقال', 'title_transfer_date', m.titleTransferDate),
        const SizedBox(height: 8),
        _buildSectionHeader('مساعد أستاذ', Icons.person_outlined),
        _buildEditableInfoCard(
            'تاريخ التعيين', 'assistant_prof_date', m.assistantProfDate),
        _buildEditableInfoCard(
            'رقم القرار', 'assistant_prof_decision', m.assistantProfDecision),
        const SizedBox(height: 8),
        _buildSectionHeader('أستاذ مشارك', Icons.people_outline),
        _buildEditableInfoCard(
            'تاريخ التعيين', 'assoc_prof_date', m.assocProfDate),
        _buildEditableInfoCard(
            'رقم القرار', 'assoc_prof_decision', m.assocProfDecision),
        const SizedBox(height: 8),
        _buildSectionHeader('الإجازات', Icons.beach_access_outlined),
        _buildEditableInfoCard(
            'إجازات تفرغية', 'sabbatical_leaves', m.sabbaticalLeaves),
        _buildEditableInfoCard(
            'إجازات بدون راتب', 'unpaid_leaves', m.unpaidLeaves),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, color: DesktopColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: DesktopColors.primary.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableInfoCard(
    String label,
    String fieldKey,
    String value, {
    bool editable = true,
  }) {
    final displayValue = value.isEmpty ? 'غير محدد' : value;
    final isEmpty = value.isEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isEmpty ? Colors.orange.shade200 : const Color(0xFFE5E7EB),
        ),
      ),
      color: isEmpty ? Colors.orange.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: 15,
                      color: isEmpty
                          ? Colors.orange.shade700
                          : const Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
