import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'faculty_member_model.dart';

class FacultyMembersViewModel extends ChangeNotifier {
  List<FacultyMemberModel> allMembers = [];
  bool isLoading = true;
  String errorMessage = '';

  FacultyMembersViewModel() {
    fetchFacultyMembers();
  }

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

  // دالة الإضافة (للأعضاء الذين يضافون من هذه الشاشة مباشرة)
  Future<void> addFacultyMember(FacultyMemberModel member) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('faculty_members', member.toMap());
      await fetchFacultyMembers();
    } catch (e) {
      debugPrint('Error adding faculty member: $e');
      rethrow;
    }
  }

  // دالة التعديل (وهي الأهم لاستكمال بيانات الأعضاء)
  Future<void> updateFacultyMember(
      String memberId, FacultyMemberModel updatedMember) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // نستخدم دالة toMap الجاهزة في المودل التي تحتوي على جميع الـ 30 حقل
      Map<String, dynamic> data = updatedMember.toMap();

      await db.update(
        'faculty_members',
        data,
        where: 'id = ?',
        whereArgs: [memberId],
      );

      await fetchFacultyMembers();
      debugPrint('تم تحديث الملف الأكاديمي الشامل بنجاح: $memberId');
    } catch (e) {
      debugPrint('Error updating faculty member: $e');
      rethrow;
    }
  }

  Future<void> deleteFacultyMember(String memberId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        await txn
            .delete('faculty_members', where: 'id = ?', whereArgs: [memberId]);
        await txn.insert('deleted_records',
            {'id': memberId, 'table_name': 'faculty_members'});
      });
      await fetchFacultyMembers();
    } catch (e) {
      debugPrint('Error deleting faculty member: $e');
      rethrow;
    }
  }
}
