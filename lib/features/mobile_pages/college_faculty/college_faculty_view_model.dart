import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';

class CollegeFacultyViewModel extends ChangeNotifier {
  final String collegeName = AppSession().userCollege;
  List<Map<String, dynamic>> _facultyMembers = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get facultyMembers => _facultyMembers;
  bool get isLoading => _isLoading;

  Future<void> loadData() async {
    if (collegeName.isEmpty || collegeName == 'غير محدد') {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;

      // جلب أعضاء هيئة التدريس التابعين للكلية الحالية عبر ربط جدول الدكاترة مع جدول المستخدمين
      _facultyMembers = await db.rawQuery('''
        SELECT f.*, u.department as user_dept 
        FROM faculty_members f 
        JOIN users u ON f.user_id = u.id 
        WHERE u.faculty = ?
      ''', [collegeName]);
    } catch (e) {
      debugPrint('Error loading faculty members: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
