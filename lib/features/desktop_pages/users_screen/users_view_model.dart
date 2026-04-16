import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart'; // تأكد من مسار قاعدة البيانات
import 'user_model.dart';

class UsersViewModel extends ChangeNotifier {
  List<UserModel> allUsers = [];
  List<UserModel> filteredUsers = [];
  bool isLoading = true;
  String errorMessage = '';

  String searchQuery = '';
  String? selectedRole;

  // استخراج الأدوار المتاحة من البيانات الموجودة لتعبئة الـ Dropdown الديناميكي
  List<String> get availableRoles => allUsers
      .map((u) => u.role)
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  UsersViewModel() {
    fetchUsers();
  }

  // 1. جلب البيانات (محلياً وفورياً)
  Future<void> fetchUsers() async {
    isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> result = await db.query('users');

      allUsers = result.map((doc) => UserModel.fromMap(doc)).toList();
      _applyFilters();
    } catch (error) {
      errorMessage = error.toString();
      debugPrint('Error fetching users: $error');
      isLoading = false;
      notifyListeners();
    }
  }

  // ==================== الفلاتر ====================

  void updateSearchQuery(String query) {
    searchQuery = query.toLowerCase();
    _applyFilters();
  }

  void updateRoleFilter(String? val) {
    selectedRole = val;
    _applyFilters();
  }

  void clearFilters() {
    searchQuery = '';
    selectedRole = null;
    _applyFilters();
  }

  void _applyFilters() {
    filteredUsers = allUsers.where((u) {
      final matchesSearch = u.name.toLowerCase().contains(searchQuery) ||
          u.email.toLowerCase().contains(searchQuery) ||
          u.phone.contains(searchQuery);

      final matchesRole = (selectedRole == null || selectedRole == 'الكل') ||
          u.role == selectedRole;

      return matchesSearch && matchesRole;
    }).toList();

    isLoading = false;
    notifyListeners();
  }

  // ==================== العمليات الأساسية ====================

  // 2. دالة الحذف
  Future<void> deleteUser(String userId) async {
    try {
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        // 1. الحذف من الجدول الأساسي
        await txn.delete('users', where: 'id = ?', whereArgs: [userId]);
        // 2. التسجيل في سلة المهملات
        await txn
            .insert('deleted_records', {'id': userId, 'table_name': 'users'});
      });

      await fetchUsers(); // تحديث الواجهة
      debugPrint('تم حذف المستخدم وتسجيله في سلة المهملات: $userId');
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  // 3. إضافة مستخدم جديد
  Future<void> addUser(Map<String, dynamic> data) async {
    // ==========================================
    // 👈 التعديل الجديد: التحقق من صيغة البريد الإلكتروني
    // ==========================================
    final String email = data['email']?.toString().trim() ?? '';

    // هذا التعبير النمطي (RegEx) يتأكد أن البريد يحتوي على @ ونقطة وصيغة صحيحة
    final bool isEmailValid = RegExp(
            r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email);

    if (!isEmailValid) {
      // إذا كان البريد خاطئاً، نوقف العملية ونرسل رسالة خطأ للواجهة
      throw Exception(
          'صيغة البريد الإلكتروني غير صحيحة. يجب أن تكون مثل: name@example.com');
    }
    // ==========================================

    try {
      final db = await DatabaseHelper.instance.database;

      data['id'] =
          data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      data['created_at'] = DateTime.now().toIso8601String();

      data.remove('createAt');
      data.remove('createdAt');

      await db.insert('users', data);
      await fetchUsers(); // تحديث الواجهة
    } catch (e) {
      debugPrint('Error adding user: $e');
      rethrow;
    }
  }

  // 4. تعديل بيانات مستخدم
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // منع تعديل تاريخ الإنشاء، وإزالة الأسماء القديمة
      data.remove('createAt');
      data.remove('createdAt');
      data.remove('created_at');

      await db.update(
        'users',
        data,
        where: 'id = ?',
        whereArgs: [userId],
      );
      await fetchUsers(); // تحديث الواجهة
      debugPrint('User with ID $userId updated successfully');
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }
}
