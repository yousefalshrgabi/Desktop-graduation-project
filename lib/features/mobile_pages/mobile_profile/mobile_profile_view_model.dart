import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/features/desktop_pages/faculty_members_screen/faculty_member_model.dart';
import 'package:academic_affairs_management/features/desktop_pages/requests_screen/request_view_model.dart';

class MobileProfileViewModel extends ChangeNotifier {
  final AppSession _session = AppSession();
  FacultyMemberModel? _member;
  bool _isLoading = true;
  String? _error;

  FacultyMemberModel? get member => _member;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AppSession get session => _session;

  Future<void> loadMemberData() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // البحث عن بيانات العضو محلياً باستخدام SQLite لضمان تكامل الأوفلاين
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'faculty_members',
        where: 'user_id = ?',
        whereArgs: [_session.userId],
        limit: 1,
      );

      if (result.isNotEmpty) {
        _member = FacultyMemberModel.fromMap(result.first);
        _isLoading = false;
      } else {
        _error = 'لم يتم العثور على بياناتك. تواصل مع النيابة الأكاديمية.';
        _isLoading = false;
      }
    } catch (e) {
      _error = 'خطأ في تحميل البيانات: $e';
      _isLoading = false;
    }
    notifyListeners();
  }

  /// إرسال طلب التعديل المنظم
  Future<bool> sendEditRequest({
    required Map<String, dynamic> extraData,
    required List<String> changes,
    required List<PlatformFile> selectedFiles,
  }) async {
    if (changes.isEmpty && selectedFiles.isEmpty) {
      return false;
    }

    String description = changes.isEmpty
        ? 'تم إرفاق ملفات جديدة للحفظ ضمن ملفات العضو.'
        : 'التعديلات المطلوبة:\n${changes.join('\n')}';

    final requestVM = RequestViewModel();
    requestVM.setUserData(
      name: _session.userName,
      college: _session.userCollege,
      role: _session.userRole,
      userId: _session.userId,
    );

    bool success = await requestVM.sendRequest(
      title: 'طلب تعديل بيانات الملف الشخصي',
      destinationCollege: 'نيابة الشؤون الأكاديمية',
      type: 'تعديل معلومات',
      description: description,
      attachedFiles: selectedFiles,
      extraData: extraData.isNotEmpty ? extraData : null,
    );

    return success;
  }
}
