import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'faculty_members_view_model.dart';
import 'faculty_member_model.dart';
import 'package:url_launcher/url_launcher.dart';

class AddFacultyMemberDialog extends StatefulWidget {
  final FacultyMembersViewModel viewModel;
  final FacultyMemberModel? memberToEdit;

  const AddFacultyMemberDialog({
    super.key,
    required this.viewModel,
    this.memberToEdit,
  });

  @override
  State<AddFacultyMemberDialog> createState() => _AddFacultyMemberDialogState();
}

class _AddFacultyMemberDialogState extends State<AddFacultyMemberDialog> {
  final _formKey = GlobalKey<FormState>();

  final Map<String, TextEditingController> _controllers = {};

  String? _selectedDepartment;
  String? _selectedDegree;
  String? _selectedStatus = 'نشط';
  bool _isLoading = false;
  List<String> _selectedLocalFilePaths = [];
  List<String> _selectedFileUrls = [];

  // قائمة ديناميكية تُجلب من قاعدة البيانات
  List<String> _departments = [];

  final List<String> _degrees = [
    'أستاذ',
    'أستاذ مشارك',
    'أستاذ مساعد',
    'مدرس',
    'معيد',
    'غير محدد'
  ];
  final List<String> _statuses = ['نشط', 'متفرغ', 'منتدب', 'غير نشط'];

  // متغيرات الجداول التفاعلية للإجازات والتفرغ
  List<Map<String, String>> _sabbaticalList = [];
  List<Map<String, String>> _unpaidList = [];

  final TextEditingController _sabStartCtrl = TextEditingController();
  final TextEditingController _sabEndCtrl = TextEditingController();
  final TextEditingController _sabUnivCtrl = TextEditingController();

  final TextEditingController _unpStartCtrl = TextEditingController();
  final TextEditingController _unpEndCtrl = TextEditingController();
  final TextEditingController _unpNotesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadDepartments(); // جلب الأقسام عند بدء الشاشة
  }

  // 🌟 دالة جلب الأقسام من جدول الأقسام
  Future<void> _loadDepartments() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final departmentsData = await db.query('departments');

      if (mounted) {
        setState(() {
          // استخراج أسماء الأقسام من البيانات
          _departments = departmentsData
              .map((d) => d['name'].toString())
              .toSet() // لمنع التكرار
              .toList();

          // حماية لواجهة التعديل
          if (widget.memberToEdit != null) {
            String currentDept = widget.memberToEdit!.department;
            if (currentDept.isNotEmpty && currentDept != 'غير محدد') {
              if (!_departments.contains(currentDept)) {
                _departments.add(currentDept);
              }
              _selectedDepartment = currentDept;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading departments: $e');
    }
  }

  // 🌟 دالة اختيار ملفات الدكتور (PDF أو صور)
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
      allowMultiple: true, // 👈 تفعيل اختيار أكثر من ملف
    );

    if (result != null && result.paths.isNotEmpty) {
      setState(() {
        for (var path in result.paths) {
          if (path != null && !_selectedLocalFilePaths.contains(path)) {
            _selectedLocalFilePaths.add(path);
            _selectedFileUrls.add(''); // إضافة رابط فارغ للملف الجديد
          }
        }
      });
    }
  }

  

  void _initControllers() {
    final fields = [
      'name', // حقل الاسم الذي سيكتبه المستخدم يدوياً
      'fileNumber',
      'idCardNumber',
      'jobNumber',
      'birthPlace',
      'birthDate',
      'firstAppointmentDate',
      'univAppointmentDate',
      'bscDegree',
      'bscDate',
      'bscUniversity',
      'bscCountry',
      'bscAcademicTitle',
      'bscTitleTransferDate',
      'bscSpecialization',
      'mscDegree',
      'mscDate',
      'mscUniversity',
      'mscCountry',
      'mscAcademicTitle',
      'mscTitleTransferDate',
      'mscDecisionNumber',
      'mscExactSpecialization',
      'currentDegree',
      'currentDegreeDate',
      'currentUniversity',
      'currentCountry',
      'assistantProfDate',
      'assistantProfDecision',
      'assocProfDate',
      'assocProfDecision',
      'titleTransferDate',
      'generalSpecialization',
      'exactSpecialization',
    ];

    for (var f in fields) {
      _controllers[f] = TextEditingController();
    }

    if (widget.memberToEdit != null) {
      final m = widget.memberToEdit!;

      _controllers['name']?.text = m.name;
      _controllers['fileNumber']?.text = m.fileNumber;
      _controllers['idCardNumber']?.text = m.idCardNumber;
      _controllers['jobNumber']?.text = m.jobNumber;
      _controllers['birthPlace']?.text = m.birthPlace;
      _controllers['birthDate']?.text = m.birthDate;
      _controllers['firstAppointmentDate']?.text = m.firstAppointmentDate;
      _controllers['univAppointmentDate']?.text = m.universityAppointmentDate;

      _controllers['bscDegree']?.text = m.bscDegree;
      _controllers['bscDate']?.text = m.bscDate;
      _controllers['bscUniversity']?.text = m.bscUniversity;
      _controllers['bscCountry']?.text = m.bscCountry;
      _controllers['bscAcademicTitle']?.text = m.bscAcademicTitle;
      _controllers['bscTitleTransferDate']?.text = m.bscTitleTransferDate;
      _controllers['bscSpecialization']?.text = m.bscSpecialization;

      _controllers['mscDegree']?.text = m.mscDegree;
      _controllers['mscDate']?.text = m.mscDate;
      _controllers['mscUniversity']?.text = m.mscUniversity;
      _controllers['mscCountry']?.text = m.mscCountry;
      _controllers['mscAcademicTitle']?.text = m.mscAcademicTitle;
      _controllers['mscTitleTransferDate']?.text = m.mscTitleTransferDate;
      _controllers['mscDecisionNumber']?.text = m.mscDecisionNumber;
      _controllers['mscExactSpecialization']?.text = m.mscExactSpecialization;

      _controllers['currentDegree']?.text = m.currentDegree;
      _controllers['currentDegreeDate']?.text = m.currentDegreeDate;
      _controllers['currentUniversity']?.text = m.currentUniversity;
      _controllers['currentCountry']?.text = m.currentCountry;

      _controllers['assistantProfDate']?.text = m.assistantProfDate;
      _controllers['assistantProfDecision']?.text = m.assistantProfDecision;
      _controllers['assocProfDate']?.text = m.assocProfDate;
      _controllers['assocProfDecision']?.text = m.assocProfDecision;

      _controllers['titleTransferDate']?.text = m.titleTransferDate;
      _controllers['generalSpecialization']?.text = m.generalSpecialization;
      _controllers['exactSpecialization']?.text = m.exactSpecialization;

      _selectedDegree = _degrees.contains(m.currentAcademicTitle)
          ? m.currentAcademicTitle
          : null;

      _selectedStatus = _statuses.contains(m.status) ? m.status : 'نشط';

      try {
        if (m.sabbaticalLeaves.isNotEmpty) {
          final List decoded = jsonDecode(m.sabbaticalLeaves);
          _sabbaticalList =
              decoded.map((e) => Map<String, String>.from(e)).toList();
        }
        if (m.unpaidLeaves.isNotEmpty) {
          final List decoded = jsonDecode(m.unpaidLeaves);
          _unpaidList =
              decoded.map((e) => Map<String, String>.from(e)).toList();
        }
        
        // تحميل الملفات المرفقة السابقة (المحلية والسحابية)
        List<String> paths = [];
        if (m.localFilePath.isNotEmpty) {
          if (m.localFilePath.startsWith('[')) {
            try { paths = List<String>.from(jsonDecode(m.localFilePath)); } catch(e) { paths = [m.localFilePath]; }
          } else { paths = [m.localFilePath]; }
        }
        
        List<String> urls = [];
        if (m.fileUrl.isNotEmpty) {
          if (m.fileUrl.startsWith('[')) {
            try { urls = List<String>.from(jsonDecode(m.fileUrl)); } catch(e) { urls = [m.fileUrl]; }
          } else { urls = [m.fileUrl]; }
        }
        
        int count = paths.length > urls.length ? paths.length : urls.length;
        for (int i = 0; i < count; i++) {
           String p = i < paths.length ? paths[i] : '';
           String u = i < urls.length ? urls[i] : '';
           
           if (p.isNotEmpty || u.isNotEmpty) {
             _selectedLocalFilePaths.add(p);
             _selectedFileUrls.add(u);
           }
        }
      } catch (e) {
        debugPrint('Error parsing leaves JSON: $e');
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _sabStartCtrl.dispose();
    _sabEndCtrl.dispose();
    _sabUnivCtrl.dispose();
    _unpStartCtrl.dispose();
    _unpEndCtrl.dispose();
    _unpNotesCtrl.dispose();
    super.dispose();
  }

  // 🌟 الدالة الذكية لربط أو إنشاء المستخدم
  Future<String> _getOrCreateUserId(String name) async {
    final db = await DatabaseHelper.instance.database;

    final existingUsers = await db.query(
      'users',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existingUsers.isNotEmpty) {
      return existingUsers.first['id'].toString();
    } else {
      String newUserId = DateTime.now().millisecondsSinceEpoch.toString();
      await db.insert('users', {
        'id': newUserId,
        'name': name,
        'email': '', // لا يوجد إيميل إجباري
        'phone': '',
        'role': 'Faculty Member',
        'faculty': '',
        'department': _selectedDepartment ?? '',
        'status': 'نشط',
        'created_at': DateTime.now().toIso8601String(),
      });
      return newUserId;
    }
  }

  Future<void> _saveFacultyMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final typedName = _controllers['name']!.text.trim();

      // الحصول على معرّف المستخدم (ربط أو إنشاء)
      String finalUserId = widget.memberToEdit != null
          ? widget.memberToEdit!.userId
          : await _getOrCreateUserId(typedName);

      final newModel = FacultyMemberModel(
        id: widget.memberToEdit != null
            ? widget.memberToEdit!.id
            : 'fac_${DateTime.now().millisecondsSinceEpoch}',

        userId: finalUserId,
        name: typedName,
        status: _selectedStatus ?? 'نشط',
        department: _selectedDepartment ?? 'غير محدد',
        currentAcademicTitle: _selectedDegree ?? 'غير محدد',

        // 👈 تمرير مسارات الملف (سيتم معالجتها في الـ ViewModel للرفع المحلي والسحابي)
        localFilePath: jsonEncode(_selectedLocalFilePaths),
        fileUrl: jsonEncode(_selectedFileUrls),

        fileNumber: _controllers['fileNumber']!.text.trim(),
        idCardNumber: _controllers['idCardNumber']!.text.trim(),
        jobNumber: _controllers['jobNumber']!.text.trim(),
        birthPlace: _controllers['birthPlace']!.text.trim(),
        birthDate: _controllers['birthDate']!.text.trim(),
        firstAppointmentDate: _controllers['firstAppointmentDate']!.text.trim(),
        universityAppointmentDate:
            _controllers['univAppointmentDate']!.text.trim(),

        bscDegree: _controllers['bscDegree']!.text.trim(),
        bscDate: _controllers['bscDate']!.text.trim(),
        bscUniversity: _controllers['bscUniversity']!.text.trim(),
        bscCountry: _controllers['bscCountry']!.text.trim(),
        bscAcademicTitle: _controllers['bscAcademicTitle']!.text.trim(),
        bscTitleTransferDate: _controllers['bscTitleTransferDate']!.text.trim(),
        bscSpecialization: _controllers['bscSpecialization']!.text.trim(),

        mscDegree: _controllers['mscDegree']!.text.trim(),
        mscDate: _controllers['mscDate']!.text.trim(),
        mscUniversity: _controllers['mscUniversity']!.text.trim(),
        mscCountry: _controllers['mscCountry']!.text.trim(),
        mscAcademicTitle: _controllers['mscAcademicTitle']!.text.trim(),
        mscTitleTransferDate: _controllers['mscTitleTransferDate']!.text.trim(),
        mscDecisionNumber: _controllers['mscDecisionNumber']!.text.trim(),
        mscExactSpecialization:
            _controllers['mscExactSpecialization']!.text.trim(),

        currentDegree: _controllers['currentDegree']!.text.trim(),
        currentDegreeDate: _controllers['currentDegreeDate']!.text.trim(),
        currentUniversity: _controllers['currentUniversity']!.text.trim(),
        currentCountry: _controllers['currentCountry']!.text.trim(),

        assistantProfDate: _controllers['assistantProfDate']!.text.trim(),
        assistantProfDecision:
            _controllers['assistantProfDecision']!.text.trim(),
        assocProfDate: _controllers['assocProfDate']!.text.trim(),
        assocProfDecision: _controllers['assocProfDecision']!.text.trim(),

        titleTransferDate: _controllers['titleTransferDate']!.text.trim(),
        generalSpecialization:
            _controllers['generalSpecialization']!.text.trim(),
        exactSpecialization: _controllers['exactSpecialization']!.text.trim(),

        sabbaticalLeaves: jsonEncode(_sabbaticalList),
        unpaidLeaves: jsonEncode(_unpaidList),

        createdAt:
            widget.memberToEdit?.createdAt ?? DateTime.now().toIso8601String(),
      );

      if (widget.memberToEdit == null) {
        await widget.viewModel.addFacultyMember(newModel);
      } else {
        await widget.viewModel
            .updateFacultyMember(widget.memberToEdit!.id, newModel);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم حفظ الملف الأكاديمي بنجاح'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... الأجزاء العلوية من الملف كما هي دون تغيير ...

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: Container(
        width: 1000,
        height: MediaQuery.of(context).size.height * 0.90,
        padding: const EdgeInsets.all(DesktopSpacing.lg),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    widget.memberToEdit == null
                        ? 'إضافة دكتور جديد'
                        : 'تعديل الملف الأكاديمي الشامل',
                    style: DesktopTextStyles.heading1),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 16, left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('البيانات الأساسية'),
                      _buildRowFields([
                        _buildInput('اسم عضو هيئة التدريس', 'name', true,
                            isReadOnly: widget.memberToEdit != null),
                        _buildInput('رقم الملف', 'fileNumber', false),
                      ]),

                      // 🌟 تم التصحيح هنا: حذف الـ Expanded اليدوي لأن _buildRowFields يوفره تلقائياً
                      _buildRowFields([
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('الوثائق والمرفقات (PDF/صور)'),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: List.generate(_selectedLocalFilePaths.length, (index) {
                                      String path = _selectedLocalFilePaths[index];
                                      String url = _selectedFileUrls.length > index ? _selectedFileUrls[index] : '';
                                      
                                      String fileName;
                                      if (path.isEmpty && url.isNotEmpty) {
                                        Uri parsedUrl = Uri.parse(url);
                                        fileName = 'ملف سحابي: ${parsedUrl.pathSegments.last.split('%2F').last.split('?').first}';
                                      } else {
                                        fileName = path.split(RegExp(r'[\\/]')).last;
                                      }
                                      return Chip(
                                        label: Text(
                                          fileName,
                                          style: const TextStyle(fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onDeleted: () {
                                          setState(() {
                                            _selectedLocalFilePaths.removeAt(index);
                                            if (index < _selectedFileUrls.length) {
                                              _selectedFileUrls.removeAt(index);
                                            }
                                          });
                                        },
                                        deleteIcon: const Icon(Icons.close, size: 16),
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                          side: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      );
                                    }),
                                  ),
                                  if (_selectedLocalFilePaths.isNotEmpty)
                                    const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      onPressed: _pickFile,
                                      icon: const Icon(Icons.attach_file),
                                      label: const Text('إضافة ملفات أخرى'),
                                    ),
                                  ),
                                  if (_selectedLocalFilePaths.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        'لم يتم إرفاق أي ملفات',
                                        style: TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ]),

                      _buildRowFields([
                        _buildInput(
                            'رقم البطاقة الشخصية', 'idCardNumber', false),
                        _buildInput('الرقم الوظيفي', 'jobNumber', false),
                      ]),
                      _buildRowFields([
                        _buildInput('مكان الميلاد', 'birthPlace', false),
                        _buildDateInput('تاريخ الميلاد', 'birthDate', false),
                      ]),

                      // ... باقي الأقسام (الوضع الأكاديمي، البكالوريوس، الماجستير، إلخ) تظل كما هي تماماً ...
                      _buildSectionTitle('الوضع الأكاديمي والتعيين بالجامعة'),
                      _buildRowFields([
                        _buildDropdown(
                            'القسم',
                            _selectedDepartment,
                            _departments,
                            (v) => setState(() => _selectedDepartment = v)),
                        _buildDropdown(
                            'اللقب العلمي (الحالي)',
                            _selectedDegree,
                            _degrees,
                            (v) => setState(() => _selectedDegree = v)),
                        _buildDropdown('الحالة', _selectedStatus, _statuses,
                            (v) => setState(() => _selectedStatus = v)),
                      ]),
                      _buildRowFields([
                        _buildDateInput('تاريخ التعيين لأول مرة',
                            'firstAppointmentDate', false),
                        _buildDateInput('تاريخ التعيين بالجامعة',
                            'univAppointmentDate', false),
                        _buildDateInput('تاريخ نقل اللقب الحالي',
                            'titleTransferDate', false),
                      ]),
                      _buildRowFields([
                        _buildInput(
                            'التخصص العام', 'generalSpecialization', false),
                        _buildInput(
                            'التخصص الدقيق', 'exactSpecialization', false),
                      ]),
                      _buildSectionTitle('بيانات البكالوريوس'),
                      _buildRowFields([
                        _buildInput('الدرجة العلمية', 'bscDegree', false),
                        _buildDateInput('تاريخها', 'bscDate', false),
                        _buildInput('الجامعة', 'bscUniversity', false),
                        _buildInput('الدولة', 'bscCountry', false),
                      ]),
                      _buildRowFields([
                        _buildInput('التخصص', 'bscSpecialization', false),
                        _buildInput(
                            'اللقب العلمي (وقتها)', 'bscAcademicTitle', false),
                        _buildDateInput(
                            'تاريخ نقل اللقب', 'bscTitleTransferDate', false),
                      ]),
                      _buildSectionTitle('بيانات الماجستير'),
                      _buildRowFields([
                        _buildInput('الدرجة العلمية', 'mscDegree', false),
                        _buildDateInput('تاريخها', 'mscDate', false),
                        _buildInput('الجامعة', 'mscUniversity', false),
                        _buildInput('الدولة', 'mscCountry', false),
                      ]),
                      _buildRowFields([
                        _buildInput(
                            'التخصص الدقيق', 'mscExactSpecialization', false),
                        _buildInput(
                            'اللقب العلمي (وقتها)', 'mscAcademicTitle', false),
                        _buildDateInput(
                            'تاريخ نقل اللقب', 'mscTitleTransferDate', false),
                        _buildInput('رقم القرار', 'mscDecisionNumber', false),
                      ]),
                      _buildSectionTitle('البيانات الحالية (الدكتوراه)'),
                      _buildRowFields([
                        _buildInput('الدرجة العلمية', 'currentDegree', false),
                        _buildDateInput('تاريخها', 'currentDegreeDate', false),
                        _buildInput('الجامعة', 'currentUniversity', false),
                        _buildInput('الدولة', 'currentCountry', false),
                      ]),
                      _buildSectionTitle('الترقيات الوظيفية'),
                      _buildRowFields([
                        _buildDateInput('تاريخ ترقية (أستاذ مساعد)',
                            'assistantProfDate', false),
                        _buildInput('رقم قرار (أستاذ مساعد)',
                            'assistantProfDecision', false),
                      ]),
                      _buildRowFields([
                        _buildDateInput('تاريخ ترقية (أستاذ مشارك)',
                            'assocProfDate', false),
                        _buildInput('رقم قرار (أستاذ مشارك)',
                            'assocProfDecision', false),
                      ]),
                      _buildSectionTitle('سجل التفرغ العلمي'),
                      _buildDynamicLeaveSection(
                        title: 'التفرغ العلمي',
                        list: _sabbaticalList,
                        startCtrl: _sabStartCtrl,
                        endCtrl: _sabEndCtrl,
                        thirdCtrl: _sabUnivCtrl,
                        thirdHint: 'الجامعة/الجهة',
                        onAdd: () {
                          if (_sabStartCtrl.text.isEmpty) return;
                          setState(() {
                            _sabbaticalList.add({
                              'start': _sabStartCtrl.text,
                              'end': _sabEndCtrl.text,
                              'details': _sabUnivCtrl.text,
                            });
                            _sabStartCtrl.clear();
                            _sabEndCtrl.clear();
                            _sabUnivCtrl.clear();
                          });
                        },
                      ),
                      _buildSectionTitle('سجل الإجازات بدون راتب'),
                      _buildDynamicLeaveSection(
                        title: 'إجازة',
                        list: _unpaidList,
                        startCtrl: _unpStartCtrl,
                        endCtrl: _unpEndCtrl,
                        thirdCtrl: _unpNotesCtrl,
                        thirdHint: 'ملاحظات/السبب',
                        onAdd: () {
                          if (_unpStartCtrl.text.isEmpty) return;
                          setState(() {
                            _unpaidList.add({
                              'start': _unpStartCtrl.text,
                              'end': _unpEndCtrl.text,
                              'details': _unpNotesCtrl.text,
                            });
                            _unpStartCtrl.clear();
                            _unpEndCtrl.clear();
                            _unpNotesCtrl.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء')),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveFacultyMember,
                  style: DesktopButtonTheme.elevatedButtonTheme.style,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ الملف الشامل'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ================= دوال الواجهة =================

  Widget _buildDateInput(String label, String controllerKey, bool isRequired) {
    return TextFormField(
      controller: _controllers[controllerKey],
      readOnly: true,
      validator: (val) => isRequired && val!.isEmpty ? 'مطلوب' : null,
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1940),
          lastDate: DateTime(2050),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: DesktopColors.primary,
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (pickedDate != null) {
          String formattedDate =
              "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
          setState(() {
            _controllers[controllerKey]!.text = formattedDate;
          });
        }
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        suffixIcon:
            const Icon(Icons.calendar_month, color: DesktopColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSmallDateInput(TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2050),
        );
        if (pickedDate != null) {
          String formattedDate =
              "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
          setState(() {
            ctrl.text = formattedDate;
          });
        }
      },
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        suffixIcon: const Icon(Icons.calendar_month,
            size: 16, color: DesktopColors.primary),
      ),
    );
  }

  Widget _buildDynamicLeaveSection({
    required String title,
    required List<Map<String, String>> list,
    required TextEditingController startCtrl,
    required TextEditingController endCtrl,
    required TextEditingController thirdCtrl,
    required String thirdHint,
    required VoidCallback onAdd,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _buildSmallDateInput(startCtrl, 'من تاريخ')),
              const SizedBox(width: 8),
              Expanded(child: _buildSmallDateInput(endCtrl, 'إلى تاريخ')),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _buildSmallInput(thirdCtrl, thirdHint)),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isNotEmpty)
            DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 40,
              columns: const [
                DataColumn(
                    label: Text('من تاريخ',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('إلى تاريخ',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('التفاصيل',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('حذف',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: list.map((item) {
                return DataRow(cells: [
                  DataCell(Text(item['start'] ?? '')),
                  DataCell(Text(item['end'] ?? '')),
                  DataCell(Text(item['details'] ?? '')),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 20),
                      onPressed: () {
                        setState(() {
                          list.remove(item);
                        });
                      },
                    ),
                  ),
                ]);
              }).toList(),
            )
          else
            const Center(
                child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('لا توجد سجلات مضافة.',
                  style: TextStyle(color: Colors.grey)),
            )),
        ],
      ),
    );
  }

  Widget _buildSmallInput(TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: DesktopColors.primary)),
    );
  }

  Widget _buildRowFields(List<Widget> fields) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
          children: fields
              .map((f) => Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: f)))
              .toList()),
    );
  }

  Widget _buildInput(String label, String controllerKey, bool isRequired,
      {bool isReadOnly = false}) {
    return TextFormField(
      controller: _controllers[controllerKey],
      readOnly: isReadOnly,
      validator: (val) => isRequired && val!.isEmpty ? 'مطلوب' : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: isReadOnly ? Colors.grey[200] : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items,
      Function(String?) onChanged) {
    // تأمين القائمة إذا كان العنصر غير موجود
    String? safeValue = value;
    if (safeValue != null && !items.contains(safeValue)) safeValue = null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      items: items
          .map((e) => DropdownMenuItem(
              value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text,
          style: DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}
