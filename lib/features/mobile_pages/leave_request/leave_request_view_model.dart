import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/features/desktop_pages/requests_screen/request_view_model.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';

class LeaveRequestViewModel extends ChangeNotifier {
  final RequestViewModel _requestViewModel = RequestViewModel();

  // Controllers / States
  final TextEditingController nameController = TextEditingController();
  final TextEditingController collegeController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController durationController = TextEditingController();

  List<String> departments = [];
  String? selectedDepartment;
  String? selectedLeaveType;
  DateTime? startDate;
  final DateTime requestDate = DateTime.now();

  bool isLoading = false;
  String errorMessage = '';

  final List<String> leaveTypes = [
    "إجازة لأداء الحج",
    "إجازة لأداء العمرة",
    "إجازة وضع",
    "إجازة مرضية",
    "إجازة مرافقة مريض للعلاج في الخارج",
    "إجازة اضطرارية"
  ];

  LeaveRequestViewModel() {
    // تعبئة البيانات تلقائياً من الجلسة
    nameController.text = AppSession().userName;
    collegeController.text = AppSession().userCollege;
    selectedDepartment = AppSession().userDepartment.isNotEmpty ? AppSession().userDepartment : null;
    departmentController.text = selectedDepartment ?? '';
    loadDepartments();
  }

  Future<void> loadDepartments() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final colleges = await db.query('colleges');
      final depts = await db.query('departments');

      final college = colleges.firstWhere(
        (c) => c['ar_name'].toString() == AppSession().userCollege,
        orElse: () => {},
      );

      if (college.isNotEmpty) {
        final collegeId = college['id'];
        final list = depts
            .where((d) => d['college_id'] == collegeId)
            .map((d) => d['name'].toString())
            .toList();
        
        departments = list;
        if (selectedDepartment != null && !departments.contains(selectedDepartment)) {
          departments.add(selectedDepartment!);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading departments on mobile: $e');
    }
  }

  void setSelectedDepartment(String? value) {
    selectedDepartment = value;
    departmentController.text = value ?? '';
    notifyListeners();
  }

  void setSelectedLeaveType(String? value) {
    selectedLeaveType = value;
    notifyListeners();
  }

  void setStartDate(DateTime? date) {
    startDate = date;
    notifyListeners();
  }

  Future<bool> submitForm() async {
    if (selectedLeaveType == null || startDate == null || durationController.text.isEmpty) {
      errorMessage = 'الرجاء إدخال جميع البيانات المطلوبة';
      notifyListeners();
      return false;
    }

    int? duration = int.tryParse(durationController.text);
    if (duration == null) {
      errorMessage = 'الرجاء إدخال مدة صحيحة بالأيام';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = '';
    notifyListeners();

    final Map<String, dynamic> extraData = {
      'form_id': 'faculty_leave_request',
      'leave_type': selectedLeaveType,
      'duration': duration,
      'start_date': startDate!.toIso8601String(),
      'request_date': requestDate.toIso8601String(),
      'current_step_order': 1,
      'sender_department': departmentController.text.trim(),
    };

    bool success = await _requestViewModel.sendRequest(
      title: 'طلب إجازة: $selectedLeaveType',
      destinationCollege: collegeController.text,
      type: 'استمارة طلب إجازة',
      description: 'المدة: ${durationController.text} أيام ابتداءً من ${intl.DateFormat('yyyy/MM/dd').format(startDate!)}',
      applicantName: nameController.text,
      senderCollege: collegeController.text,
      extraData: extraData,
    );

    isLoading = false;
    if (!success) {
      errorMessage = _requestViewModel.errorMessage.isNotEmpty 
          ? _requestViewModel.errorMessage 
          : 'فشل إرسال الطلب. يرجى التحقق من اتصال الإنترنت.';
    }
    notifyListeners();
    return success;
  }

  @override
  void dispose() {
    nameController.dispose();
    collegeController.dispose();
    departmentController.dispose();
    durationController.dispose();
    super.dispose();
  }
}
