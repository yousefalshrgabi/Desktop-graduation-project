import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart'; // تأكد من المسار
import 'faculty_member_model.dart';

class FacultyMembersViewModel extends ChangeNotifier {
  List<FacultyMemberModel> allMembers = [];

  bool isLoading = true;
  String errorMessage = '';

  FacultyMembersViewModel() {
    fetchFacultyMembers();
  }

  // 1. جلب البيانات من SQLite محلياً وبشكل فوري
  Future<void> fetchFacultyMembers() async {
    isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> result =
          await db.query('faculty_members');

      allMembers =
          result.map((map) => FacultyMemberModel.fromMap(map)).toList();

      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('Error fetching faculty members: $e');
      isLoading = false;
      notifyListeners();
    }
  }

  // 2. دالة الإضافة (تم نقلها من الـ Dialog إلى هنا)
  Future<void> addFacultyMember(Map<String, dynamic> data) async {
    try {
      final db = await DatabaseHelper.instance.database;

      data['id'] =
          data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      data['created_at'] = DateTime.now().toIso8601String();

      // تحويل الاسم القديم للاسم المتوافق مع قاعدة بياناتك
      if (data.containsKey('academicDegree')) {
        data['academic_degree'] = data.remove('academicDegree');
      }

      await db.insert('faculty_members', data);
      await fetchFacultyMembers(); // تحديث الواجهة فوراً
      debugPrint('Faculty member added successfully: ${data['ar_name']}');
    } catch (e) {
      debugPrint('Error adding faculty member: $e');
      rethrow;
    }
  }

  // 3. دالة الحذف
  Future<void> deleteFacultyMember(String memberId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'faculty_members',
        where: 'id = ?',
        whereArgs: [memberId],
      );
      await fetchFacultyMembers(); // تحديث الواجهة فوراً
      debugPrint('Faculty member deleted successfully: $memberId');
    } catch (e) {
      debugPrint('Error deleting faculty member: $e');
      rethrow;
    }
  }

  // 4. دالة التعديل
  Future<void> updateFacultyMember(
      String memberId, Map<String, dynamic> data) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // تحويل الاسم القديم للاسم المتوافق مع SQLite
      if (data.containsKey('academicDegree')) {
        data['academic_degree'] = data.remove('academicDegree');
      }

      // تنظيف التاريخ لمنع تعديله بالخطأ
      data.remove('createdAt');
      data.remove('created_at');

      await db.update(
        'faculty_members',
        data,
        where: 'id = ?',
        whereArgs: [memberId],
      );

      await fetchFacultyMembers(); // تحديث الواجهة فوراً
      debugPrint('Faculty member updated successfully: $memberId');
    } catch (e) {
      debugPrint('Error updating faculty member: $e');
      rethrow;
    }
  }
}
