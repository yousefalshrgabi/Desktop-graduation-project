import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/features/desktop_pages/faculty_members_screen/faculty_member_model.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/features/desktop_pages/requests_screen/request_view_model.dart';
import 'package:file_picker/file_picker.dart';

/// صفحة الملف الشخصي للعضو - تعرض معلوماته مع إمكانية طلب تعديلها
class MobileProfilePage extends StatefulWidget {
  const MobileProfilePage({super.key});

  @override
  State<MobileProfilePage> createState() => _MobileProfilePageState();
}

class _MobileProfilePageState extends State<MobileProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  FacultyMemberModel? _member;
  bool _isLoading = true;
  String? _error;

  final _session = AppSession();
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMemberData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMemberData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // البحث عن بيانات العضو محلياً باستخدام SQLite لضمان تكامل الأوفلاين
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'faculty_members',
        where: 'user_id = ?',
        whereArgs: [_session.userId],
        limit: 1,
      );

      if (result.isNotEmpty) {
        setState(() {
          _member = FacultyMemberModel.fromMap(result.first);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'لم يتم العثور على بياناتك. تواصل مع النيابة الأكاديمية.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'خطأ في تحميل البيانات: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openLocalFile(BuildContext context, String path, String url, String memberName) async {
    String actualPath = path;

    if (actualPath.isEmpty && url.isNotEmpty) {
      String cleanName = memberName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      Directory appDocDir = await getApplicationDocumentsDirectory();
      
      Uri parsedUrl = Uri.parse(url);
      String ext = '.pdf';
      if (parsedUrl.path.contains('.')) {
        String possibleExt = parsedUrl.path.split('.').last;
        if (possibleExt.length <= 4) ext = '.$possibleExt';
      }
      String fileName = 'document_${DateTime.now().millisecondsSinceEpoch}$ext';
      
      actualPath = p.join(appDocDir.path, 'AcademicAffairs', 'FacultyFiles', cleanName, fileName);
    }

    if (actualPath.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح الملف، المسار غير متوفر')),
        );
      }
      return;
    }

    final File file = File(actualPath);
    if (await file.exists()) {
      final Uri uri = Uri.file(actualPath);
      if (!await launchUrl(uri)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر فتح الملف في المسار: $actualPath')),
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

          final Uri uri = Uri.file(actualPath);
          if (!await launchUrl(uri)) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تعذر فتح الملف بعد التحميل: $actualPath')),
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
            const SnackBar(content: Text('الملف غير موجود محلياً ولا يوجد رابط سحابي له.')),
          );
        }
      }
    }
  }

  void _viewFiles() async {
    final member = _member;
    if (member == null) return;
    
    if (member.localFilePath.isNotEmpty || member.fileUrl.isNotEmpty) {
      List<String> paths = [];
      if (member.localFilePath.isNotEmpty) {
        if (member.localFilePath.startsWith('[')) {
          try {
            paths = List<String>.from(jsonDecode(member.localFilePath));
          } catch (e) {
            paths = [member.localFilePath];
          }
        } else {
          paths = [member.localFilePath];
        }
      }

      List<String> urls = [];
      if (member.fileUrl.isNotEmpty) {
        if (member.fileUrl.startsWith('[')) {
          try {
            urls = List<String>.from(jsonDecode(member.fileUrl));
          } catch (e) {
            urls = [member.fileUrl];
          }
        } else {
          urls = [member.fileUrl];
        }
      }

      int count = paths.length > urls.length ? paths.length : urls.length;

      if (count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد ملف مرفق لهذا العضو')),
        );
      } else if (count == 1) {
        String p = paths.isNotEmpty ? paths[0] : '';
        String u = urls.isNotEmpty ? urls[0] : '';
        await _openLocalFile(context, p, u, member.name);
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('اختيار الملف المرفق'),
            content: SizedBox(
              width: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: count,
                itemBuilder: (c, i) {
                  String p = i < paths.length ? paths[i] : '';
                  String u = i < urls.length ? urls[i] : '';
                  String fileName = p.isNotEmpty 
                      ? p.split(RegExp(r'[\\/]')).last 
                      : 'ملف ${i + 1} من السحابة';
                      
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                    title: Text(fileName),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openLocalFile(context, p, u, member.name);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              )
            ],
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('لا يوجد ملف مرفق لهذا العضو')),
      );
    }
  }

  void _showBulkEditDialog() {
    final m = _member!;

    // Map of labels to old values and their controllers
    final Map<String, Map<String, dynamic>> fields = {
      'الاسم الكامل': {
        'old': m.name,
        'ctrl': TextEditingController(text: m.name)
      },
      'رقم الملف': {
        'old': m.fileNumber,
        'ctrl': TextEditingController(text: m.fileNumber)
      },
      'رقم الهوية': {
        'old': m.idCardNumber,
        'ctrl': TextEditingController(text: m.idCardNumber)
      },
      'الرقم الوظيفي': {
        'old': m.jobNumber,
        'ctrl': TextEditingController(text: m.jobNumber)
      },
      'محل الميلاد': {
        'old': m.birthPlace,
        'ctrl': TextEditingController(text: m.birthPlace)
      },
      'تاريخ الميلاد': {
        'old': m.birthDate,
        'ctrl': TextEditingController(text: m.birthDate)
      },
      'القسم': {
        'old': m.department,
        'ctrl': TextEditingController(text: m.department)
      },
      'تاريخ التعيين': {
        'old': m.universityAppointmentDate,
        'ctrl': TextEditingController(text: m.universityAppointmentDate)
      },
      'البكالوريوس': {
        'old': m.bscDegree,
        'ctrl': TextEditingController(text: m.bscDegree)
      },
      'الماجستير': {
        'old': m.mscDegree,
        'ctrl': TextEditingController(text: m.mscDegree)
      },
      'الدرجة الحالية': {
        'old': m.currentDegree,
        'ctrl': TextEditingController(text: m.currentDegree)
      },
      'التخصص الدقيق': {
        'old': m.exactSpecialization,
        'ctrl': TextEditingController(text: m.exactSpecialization)
      },
      'اللقب الأكاديمي': {
        'old': m.currentAcademicTitle,
        'ctrl': TextEditingController(text: m.currentAcademicTitle)
      },
    };

    List<PlatformFile> selectedFiles = [];
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
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            selectedFiles.isNotEmpty
                                                ? 'تم إرفاق (${selectedFiles.length}) ملفات'
                                                : 'يمكنك إرفاق ملفات لدعم طلب التعديل',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: selectedFiles.isNotEmpty
                                                    ? Colors.blue.shade900
                                                    : Colors.black87),
                                          ),
                                        ),
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
                                              setSheetState(() =>
                                                  selectedFiles = result.files);
                                            }
                                          },
                                          icon: const Icon(Icons.attach_file,
                                              size: 16),
                                          label: const Text('إرفاق'),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor:
                                                  Colors.blue.shade700),
                                        ),
                                      ],
                                    ),
                                    if (selectedFiles.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Column(
                                          children: selectedFiles
                                              .map((f) => Row(
                                                    children: [
                                                      const Icon(
                                                          Icons.description,
                                                          size: 14,
                                                          color: Colors.blue),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                          child: Text(f.name,
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          11))),
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.close,
                                                            size: 14,
                                                            color: Colors.red),
                                                        onPressed: () =>
                                                            setSheetState(() =>
                                                                selectedFiles
                                                                    .remove(f)),
                                                      )
                                                    ],
                                                  ))
                                              .toList(),
                                        ),
                                      )
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
                                  // 1. تجهيز البيانات المنظمة للتحديث الآلي
                                  Map<String, String> fieldMapping = {
                                    'الاسم الكامل': 'name',
                                    'رقم الملف': 'fileNumber',
                                    'رقم الهوية': 'idCardNumber',
                                    'الرقم الوظيفي': 'jobNumber',
                                    'محل الميلاد': 'birthPlace',
                                    'تاريخ الميلاد': 'birthDate',
                                    'القسم': 'department',
                                    'تاريخ التعيين':
                                        'universityAppointmentDate',
                                    'البكالوريوس': 'bscDegree',
                                    'الماجستير': 'mscDegree',
                                    'الدرجة الحالية': 'currentDegree',
                                    'التخصص الدقيق': 'exactSpecialization',
                                    'اللقب الأكاديمي': 'currentAcademicTitle',
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

                                  if (changes.isEmpty && selectedFiles.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'لم تقم بإجراء أي تعديلات.')),
                                    );
                                    return;
                                  }

                                  String description = changes.isEmpty
                                      ? 'تم إرفاق ملفات جديدة للحفظ ضمن ملفات العضو.'
                                      : 'التعديلات المطلوبة:\n${changes.join('\n')}';

                                  setSheetState(() => isSubmitting = true);

                                  final requestVM = RequestViewModel();
                                  requestVM.setUserData(
                                    name: _session.userName,
                                    college: _session.userCollege,
                                    role: _session.userRole,
                                    userId: _session.userId,
                                  );

                                  bool success = await requestVM.sendRequest(
                                    title: 'طلب تعديل بيانات الملف الشخصي',
                                    destinationCollege:
                                        'نيابة الشؤون الأكاديمية',
                                    type: 'تعديل معلومات',
                                    description: description,
                                    attachedFiles: selectedFiles,
                                    extraData:
                                        extraData.isNotEmpty ? extraData : null,
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
          if (_member != null)
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: 'استعراض ملفاتي',
              onPressed: _viewFiles,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadMemberData,
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
          ],
        ),
      ),
      floatingActionButton: _member != null
          ? FloatingActionButton.extended(
              onPressed: _showBulkEditDialog,
              icon: const Icon(Icons.edit_note),
              label: const Text('تعديل البيانات'),
              backgroundColor: DesktopColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPersonalInfoTab(),
                    _buildEducationTab(),
                    _buildCareerTab(),
                  ],
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
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMemberData,
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
    final m = _member!;
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
        _buildEditableInfoCard('الكلية', 'department', _session.userCollege,
            editable: false),
        _buildEditableInfoCard('القسم', 'department', m.department),
      ],
    );
  }

  // =================== التبويب 2: المؤهلات العلمية ===================
  Widget _buildEducationTab() {
    final m = _member!;
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
    final m = _member!;
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
            child: Divider(color: DesktopColors.primary.withOpacity(0.3)),
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
