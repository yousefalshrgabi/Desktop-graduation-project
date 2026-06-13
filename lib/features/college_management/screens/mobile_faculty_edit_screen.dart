import 'dart:convert';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/features/desktop_pages/requests_screen/request_view_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class MobileFacultyEditScreen extends StatefulWidget {
  final Map<String, dynamic> facultyData;

  const MobileFacultyEditScreen({super.key, required this.facultyData});

  @override
  State<MobileFacultyEditScreen> createState() =>
      _MobileFacultyEditScreenState();
}

class _MobileFacultyEditScreenState extends State<MobileFacultyEditScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  late TabController _tabController;

  final Map<String, TextEditingController> _ctrls = {};

  final List<String> _fields = [
    'name', 'status', 'file_number', 'id_card_number', 'job_number', 
    'birth_place', 'birth_date', 'department',
    'first_appointment_date', 'university_appointment_date',
    'bsc_degree', 'bsc_date', 'bsc_university', 'bsc_country', 'bsc_academic_title', 'bsc_title_transfer_date', 'bsc_specialization',
    'msc_degree', 'msc_date', 'msc_university', 'msc_country', 'msc_academic_title', 'msc_title_transfer_date', 'msc_decision_number', 'msc_exact_specialization',
    'current_degree', 'current_degree_date', 'current_university', 'current_country',
    'assistant_prof_date', 'assistant_prof_decision',
    'assoc_prof_date', 'assoc_prof_decision',
    'current_academic_title', 'title_transfer_date',
    'general_specialization', 'exact_specialization',
    'notes'
  ];

  // قوائم ومسارات الملفات القديمة المعروضة
  final Map<String, List<String>> _existingFiles = {};
  
  // تتبع الملفات التي طلب النائب حذفها
  final List<String> _deletedFilesUrls = [];

  // تتبع الملفات الجديدة التي أرفقها النائب وتصنيفاتها
  final List<PlatformFile> _newAttachedFiles = [];
  final Map<String, List<int>> _newFilesMapping = {};

  final Map<String, String> _fileCategories = {
    'idCard': 'صورة الهوية / الجواز',
    'contract': 'العقد',
    'personalPhoto': 'صورة شخصية',
    'certificates': 'الشهادات',
    'others': 'ملفات أخرى'
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this); // إضافة تبويب للملفات

    final d = widget.facultyData;
    for (String field in _fields) {
      String val = d[field]?.toString() ?? '';
      if (field == 'department' && val.isEmpty) {
        val = d['user_dept']?.toString() ?? '';
      }
      _ctrls[field] = TextEditingController(text: val);
    }

    _loadExistingFiles();
  }

  void _loadExistingFiles() {
    String fileUrlStr = widget.facultyData['file_url']?.toString() ?? '';
    if (fileUrlStr.isNotEmpty) {
      try {
        Map<String, dynamic> urls = jsonDecode(fileUrlStr);
        urls.forEach((key, valList) {
          if (valList is List) {
            _existingFiles[key] = valList.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
          }
        });
      } catch (_) {}
    }
    // تهيئة التصنيفات حتى لو كانت فارغة
    for (var k in _fileCategories.keys) {
      _existingFiles[k] ??= [];
      _newFilesMapping[k] ??= [];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var ctrl in _ctrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickNewFile(String category) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png', 'jpeg'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (var file in result.files) {
          _newAttachedFiles.add(file);
          int newIndex = _newAttachedFiles.length - 1;
          _newFilesMapping[category]!.add(newIndex);
        }
      });
    }
  }

  void _removeNewFile(String category, int mappedIndex) {
    setState(() {
      _newFilesMapping[category]!.remove(mappedIndex);
      // ملاحظة: لا نحذف من _newAttachedFiles لأن الفهرسة (index) للـ mapping ستتأثر.
      // عند الإرسال، سيرسل كل الملفات في _newAttachedFiles، والـ backend سيقرأ الـ index فقط من mapping
    });
  }

  void _markExistingFileForDeletion(String category, String url) {
    setState(() {
      _existingFiles[category]!.remove(url);
      _deletedFilesUrls.add(url);
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final session = AppSession();
      final requestVM = RequestViewModel();
      requestVM.setUserData(
        name: session.userName,
        college: session.userCollege,
        role: session.userRole,
        userId: session.userId,
      );

      final originalData = widget.facultyData;
      
      String changesText = 'طلب تعديل شامل لبيانات العضو: ${_ctrls['name']!.text.trim()}\n\nالتغييرات المطلوبة:\n';
      final Map<String, dynamic> changedFields = {};
      
      void checkChange(String key, String title) {
        String oldVal = originalData[key]?.toString() ?? '';
        if (key == 'department' && oldVal.isEmpty) {
           oldVal = originalData['user_dept']?.toString() ?? '';
        }
        String newVal = _ctrls[key]!.text.trim();

        if (oldVal.trim() != newVal) {
          changesText += '- $title: (من: ${oldVal.isEmpty ? "فارغ" : oldVal} --> إلى: $newVal)\n';
          changedFields[key] = newVal;
        }
      }

      checkChange('name', 'الاسم'); checkChange('status', 'الحالة'); checkChange('file_number', 'رقم الملف');
      checkChange('id_card_number', 'رقم الهوية'); checkChange('job_number', 'الرقم الوظيفي');
      checkChange('birth_place', 'مكان الميلاد'); checkChange('birth_date', 'تاريخ الميلاد');
      checkChange('department', 'القسم'); checkChange('general_specialization', 'التخصص العام');
      checkChange('exact_specialization', 'التخصص الدقيق'); checkChange('first_appointment_date', 'تاريخ أول تعيين');
      checkChange('university_appointment_date', 'تاريخ التعيين بالجامعة'); checkChange('bsc_degree', 'درجة البكالوريوس');
      checkChange('bsc_date', 'تاريخ البكالوريوس'); checkChange('bsc_university', 'جامعة البكالوريوس');
      checkChange('bsc_country', 'دولة البكالوريوس'); checkChange('bsc_academic_title', 'لقب البكالوريوس');
      checkChange('bsc_title_transfer_date', 'تاريخ النقل (بكالوريوس)'); checkChange('bsc_specialization', 'تخصص البكالوريوس');
      checkChange('msc_degree', 'درجة الماجستير'); checkChange('msc_date', 'تاريخ الماجستير');
      checkChange('msc_university', 'جامعة الماجستير'); checkChange('msc_country', 'دولة الماجستير');
      checkChange('msc_academic_title', 'لقب الماجستير'); checkChange('msc_title_transfer_date', 'تاريخ النقل (ماجستير)');
      checkChange('msc_decision_number', 'رقم القرار (ماجستير)'); checkChange('msc_exact_specialization', 'التخصص الدقيق (ماجستير)');
      checkChange('current_degree', 'الدرجة الحالية (دكتوراه)'); checkChange('current_degree_date', 'تاريخ الدرجة الحالية');
      checkChange('current_university', 'جامعة الدرجة الحالية'); checkChange('current_country', 'دولة الدرجة الحالية');
      checkChange('assistant_prof_date', 'تاريخ أستاذ مساعد'); checkChange('assistant_prof_decision', 'قرار أستاذ مساعد');
      checkChange('assoc_prof_date', 'تاريخ أستاذ مشارك'); checkChange('assoc_prof_decision', 'قرار أستاذ مشارك');
      checkChange('current_academic_title', 'اللقب الأكاديمي الحالي'); checkChange('title_transfer_date', 'تاريخ نقل اللقب');

      int newFilesCount = _newFilesMapping.values.expand((element) => element).length;
      if (changedFields.isEmpty && _deletedFilesUrls.isEmpty && newFilesCount == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم إجراء أي تغييرات لإرسالها')),
          );
        }
        return;
      }

      if (_deletedFilesUrls.isNotEmpty) {
        changesText += '\n- تم طلب حذف ${_deletedFilesUrls.length} مرفقات سابقة.\n';
      }
      if (newFilesCount > 0) {
        changesText += '- تم إرفاق $newFilesCount ملفات جديدة.\n';
      }
      if (_ctrls['notes']!.text.trim().isNotEmpty) {
        changesText += '\nملاحظات النائب:\n${_ctrls['notes']!.text.trim()}';
      }

      final Map<String, dynamic> requestExtraData = {
        'faculty_doc_id': originalData['id'].toString(),
        'deleted_files': _deletedFilesUrls,
        'new_files_mapping': _newFilesMapping,
      };
      
      // إضافة الحقول المعدلة مباشرة داخل extraData وليس ككائن متداخل
      requestExtraData.addAll(changedFields);

      final success = await requestVM.sendRequest(
        title: 'تحديث بيانات شامل ومرفقات (عضو هيئة تدريس)',
        destinationCollege: 'نيابة الشؤون الأكاديمية',
        type: 'تعديل معلومات',
        description: changesText,
        attachedFiles: _newAttachedFiles,
        extraData: requestExtraData,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرسال الطلب للنيابة بنجاح'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل إرسال الطلب: ${requestVM.errorMessage}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildField(String key, String label, {bool isRequired = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: _ctrls[key],
        maxLines: maxLines,
        validator: isRequired ? (val) => (val == null || val.trim().isEmpty) ? 'مطلوب' : null : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildFilesTab() {
    List<Widget> children = [];

    _fileCategories.forEach((catKey, catLabel) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(catLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      );

      // الملفات الحالية (قابلة للحذف)
      if (_existingFiles[catKey] != null && _existingFiles[catKey]!.isNotEmpty) {
        for (String url in _existingFiles[catKey]!) {
          children.add(
            Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.file_present),
                title: const Text('ملف محفوظ مسبقاً', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _markExistingFileForDeletion(catKey, url),
                ),
              ),
            ),
          );
        }
      }

      // الملفات الجديدة المضافة
      if (_newFilesMapping[catKey] != null && _newFilesMapping[catKey]!.isNotEmpty) {
        for (int mappedIndex in _newFilesMapping[catKey]!) {
          PlatformFile pFile = _newAttachedFiles[mappedIndex];
          children.add(
            Card(
              margin: const EdgeInsets.only(bottom: 4),
              color: Colors.green.shade50,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.upload_file, color: Colors.green),
                title: Text(pFile.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _removeNewFile(catKey, mappedIndex),
                ),
              ),
            ),
          );
        }
      }

      // زر الإضافة لهذه الفئة
      children.add(
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _pickNewFile(catKey),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('إرفاق ملف جديد'),
          ),
        ),
      );
      children.add(const Divider());
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل البيانات والمرفقات'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded),
            onPressed: _isSubmitting ? null : _submitRequest,
            tooltip: 'إرسال التعديلات',
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'أساسي'),
            Tab(text: 'بكالوريوس'),
            Tab(text: 'ماجستير'),
            Tab(text: 'دكتوراه'),
            Tab(text: 'الترقيات'),
            Tab(text: 'المرفقات'), // تبويب المرفقات الجديد
          ],
        ),
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. أساسي
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildField('name', 'الاسم الكامل', isRequired: true),
                      _buildField('department', 'القسم العلمي', isRequired: true),
                      _buildField('status', 'حالة العضو (نشط/متفرغ..)'),
                      _buildField('job_number', 'الرقم الوظيفي'),
                      _buildField('file_number', 'رقم الملف'),
                      _buildField('id_card_number', 'رقم الهوية'),
                      Row(
                        children: [
                          Expanded(child: _buildField('birth_place', 'مكان الميلاد')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildField('birth_date', 'تاريخ الميلاد')),
                        ],
                      ),
                      _buildField('general_specialization', 'التخصص العام'),
                      _buildField('exact_specialization', 'التخصص الدقيق'),
                      const Divider(),
                      _buildField('first_appointment_date', 'تاريخ أول تعيين'),
                      _buildField('university_appointment_date', 'تاريخ التعيين بالجامعة'),
                      const Divider(),
                      _buildField('notes', 'ملاحظات للنيابة حول التعديل', maxLines: 3),
                    ],
                  ),
                  // 2. بكالوريوس
                  ListView(padding: const EdgeInsets.all(16), children: [
                    _buildField('bsc_degree', 'الدرجة'), _buildField('bsc_specialization', 'التخصص'),
                    _buildField('bsc_university', 'الجامعة'), _buildField('bsc_country', 'الدولة'),
                    _buildField('bsc_date', 'التاريخ'), _buildField('bsc_academic_title', 'اللقب الأكاديمي'),
                    _buildField('bsc_title_transfer_date', 'تاريخ نقل اللقب'),
                  ]),
                  // 3. ماجستير
                  ListView(padding: const EdgeInsets.all(16), children: [
                    _buildField('msc_degree', 'الدرجة'), _buildField('msc_exact_specialization', 'التخصص الدقيق'),
                    _buildField('msc_university', 'الجامعة'), _buildField('msc_country', 'الدولة'),
                    _buildField('msc_date', 'التاريخ'), _buildField('msc_decision_number', 'رقم القرار'),
                    _buildField('msc_academic_title', 'اللقب الأكاديمي'), _buildField('msc_title_transfer_date', 'تاريخ نقل اللقب'),
                  ]),
                  // 4. دكتوراه
                  ListView(padding: const EdgeInsets.all(16), children: [
                    _buildField('current_degree', 'الدرجة الحالية'), _buildField('current_university', 'الجامعة'),
                    _buildField('current_country', 'الدولة'), _buildField('current_degree_date', 'التاريخ'),
                  ]),
                  // 5. الترقيات
                  ListView(padding: const EdgeInsets.all(16), children: [
                    _buildField('assistant_prof_date', 'تاريخ أستاذ مساعد'), _buildField('assistant_prof_decision', 'قرار أستاذ مساعد'), const Divider(),
                    _buildField('assoc_prof_date', 'تاريخ أستاذ مشارك'), _buildField('assoc_prof_decision', 'قرار أستاذ مشارك'), const Divider(),
                    _buildField('current_academic_title', 'اللقب الأكاديمي الحالي'), _buildField('title_transfer_date', 'تاريخ نقل اللقب'),
                  ]),
                  // 6. المرفقات
                  _buildFilesTab(),
                ],
              ),
            ),
    );
  }
}
