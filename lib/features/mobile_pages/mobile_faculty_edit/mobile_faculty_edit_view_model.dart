import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/features/desktop_pages/requests_screen/request_view_model.dart';

class MobileFacultyEditViewModel extends ChangeNotifier {
  final Map<String, dynamic> facultyData;
  final Map<String, TextEditingController> ctrls = {};
  bool _isSubmitting = false;

  bool get isSubmitting => _isSubmitting;

  final List<String> fields = [
    'name', 'email', 'status', 'file_number', 'id_card_number', 'job_number', 
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
  final Map<String, List<String>> existingFiles = {};
  
  // تتبع الملفات التي طلب النائب حذفها
  final List<String> deletedFilesUrls = [];

  // تتبع الملفات الجديدة التي أرفقها النائب وتصنيفاتها
  final List<PlatformFile> newAttachedFiles = [];
  final Map<String, List<int>> newFilesMapping = {};

  final Map<String, String> fileCategories = {
    'idCard': 'صورة الهوية / الجواز',
    'contract': 'العقد',
    'personalPhoto': 'صورة شخصية',
    'certificates': 'الشهادات',
    'others': 'ملفات أخرى'
  };

  MobileFacultyEditViewModel({required this.facultyData}) {
    for (String field in fields) {
      String val = facultyData[field]?.toString() ?? '';
      if (field == 'department' && val.isEmpty) {
        val = facultyData['user_dept']?.toString() ?? '';
      }
      ctrls[field] = TextEditingController(text: val);
    }

    if (ctrls['email']!.text.isEmpty) {
      _fetchUserEmail();
    }

    _loadExistingFiles();
  }

  Future<void> _fetchUserEmail() async {
    final userId = facultyData['user_id']?.toString() ?? '';
    if (userId.isEmpty && AppSession().isMemberOnly) {
      ctrls['email']!.text = AppSession().userEmail;
      notifyListeners();
      return;
    }
    if (userId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (doc.exists) {
          final email = doc.data()?['email']?.toString() ?? '';
          if (email.isNotEmpty) {
            ctrls['email']!.text = email;
            notifyListeners();
          }
        }
      } catch (_) {}
    }
  }

  void _loadExistingFiles() {
    String fileUrlStr = facultyData['file_url']?.toString() ?? '';
    if (fileUrlStr.isNotEmpty) {
      try {
        Map<String, dynamic> urls = jsonDecode(fileUrlStr);
        urls.forEach((key, valList) {
          if (valList is List) {
            existingFiles[key] = valList.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
          }
        });
      } catch (_) {}
    }
    // تهيئة التصنيفات حتى لو كانت فارغة
    for (var k in fileCategories.keys) {
      existingFiles[k] ??= [];
      newFilesMapping[k] ??= [];
    }
  }

  Future<void> pickNewFile(String category) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png', 'jpeg'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      for (var file in result.files) {
        newAttachedFiles.add(file);
        int newIndex = newAttachedFiles.length - 1;
        newFilesMapping[category]!.add(newIndex);
      }
      notifyListeners();
    }
  }

  void removeNewFile(String category, int mappedIndex) {
    newFilesMapping[category]!.remove(mappedIndex);
    notifyListeners();
  }

  void markExistingFileForDeletion(String category, String url) {
    existingFiles[category]!.remove(url);
    deletedFilesUrls.add(url);
    notifyListeners();
  }

  Future<bool> submitRequest(BuildContext context) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final session = AppSession();
      final requestVM = RequestViewModel();
      requestVM.setUserData(
        name: session.userName,
        college: session.userCollege,
        role: session.userRole,
        userId: session.userId,
      );

      final originalData = facultyData;
      
      String changesText = 'طلب تعديل شامل لبيانات العضو: ${ctrls['name']!.text.trim()}\n\nالتغييرات المطلوبة:\n';
      final Map<String, dynamic> changedFields = {};
      
      void checkChange(String key, String title) {
        String oldVal = originalData[key]?.toString() ?? '';
        if (key == 'department' && oldVal.isEmpty) {
           oldVal = originalData['user_dept']?.toString() ?? '';
        }
        String newVal = ctrls[key]!.text.trim();

        if (oldVal.trim() != newVal) {
          changesText += '- $title: (من: ${oldVal.isEmpty ? "فارغ" : oldVal} --> إلى: $newVal)\n';
          changedFields[key] = newVal;
        }
      }

      checkChange('name', 'الاسم'); checkChange('email', 'البريد الإلكتروني'); checkChange('status', 'الحالة'); checkChange('file_number', 'رقم الملف');
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

      int newFilesCount = newFilesMapping.values.expand((element) => element).length;
      if (changedFields.isEmpty && deletedFilesUrls.isEmpty && newFilesCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم إجراء أي تغييرات لإرسالها')),
        );
        _isSubmitting = false;
        notifyListeners();
        return false;
      }

      if (deletedFilesUrls.isNotEmpty) {
        changesText += '\n- تم طلب حذف ${deletedFilesUrls.length} مرفقات سابقة.\n';
      }
      if (newFilesCount > 0) {
        changesText += '- تم إرفاق $newFilesCount ملفات جديدة.\n';
      }
      if (ctrls['notes']!.text.trim().isNotEmpty) {
        changesText += '\nملاحظات النائب:\n${ctrls['notes']!.text.trim()}';
      }

      final Map<String, dynamic> requestExtraData = {
        'faculty_doc_id': originalData['id'].toString(),
        'deleted_files': deletedFilesUrls,
        'new_files_mapping': newFilesMapping,
      };
      
      requestExtraData.addAll(changedFields);

      final success = await requestVM.sendRequest(
        title: 'تحديث بيانات شامل ومرفقات (عضو هيئة تدريس)',
        destinationCollege: 'نيابة الشؤون الأكاديمية',
        type: 'تعديل معلومات',
        description: changesText,
        attachedFiles: newAttachedFiles,
        extraData: requestExtraData,
      );

      _isSubmitting = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('Error submitting request: $e');
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    for (var ctrl in ctrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }
}
