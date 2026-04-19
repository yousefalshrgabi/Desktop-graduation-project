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

  // 2. دالة الحذف (تم التعديل لربط الحذف مع جدول أعضاء هيئة التدريس)
  Future<void> deleteUser(String userId) async {
    try {
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        // أ. البحث عن الملف الأكاديمي المرتبط بهذا المستخدم (إن وجد)
        final linkedFaculty = await txn.query('faculty_members',
            where: 'user_id = ?', whereArgs: [userId]);

        // ب. الحذف من جدول المستخدمين الأساسي
        await txn.delete('users', where: 'id = ?', whereArgs: [userId]);
        await txn.insert('deleted_records',
            {'id': userId, 'table_name': 'users'}); // تسجيل في المهملات

        // ج. إذا كان له ملف أكاديمي، ستقوم قاعدة البيانات بحذفه محلياً تلقائياً بسبب (ON DELETE CASCADE)
        // ولكن يجب علينا تسجيل الـ ID الخاص بالملف الأكاديمي في سلة المهملات ليتم حذفه من الفايربيس!
        for (var fac in linkedFaculty) {
          await txn.insert('deleted_records',
              {'id': fac['id'], 'table_name': 'faculty_members'});
        }
      });

      await fetchUsers(); // تحديث الواجهة
      debugPrint(
          'تم حذف المستخدم وملفاته المرتبطة وتسجيلهما في سلة المهملات: $userId');
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  // 3. إضافة مستخدم جديد (تم التعديل لإنشاء ملف أكاديمي تلقائياً)
  Future<void> addUser(Map<String, dynamic> data) async {
    // التحقق من صيغة البريد الإلكتروني
    final String email = data['email']?.toString().trim() ?? '';
    final bool isEmailValid = RegExp(
            r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email);

    if (!isEmailValid) {
      throw Exception(
          'صيغة البريد الإلكتروني غير صحيحة. يجب أن تكون مثل: name@example.com');
    }

    try {
      final db = await DatabaseHelper.instance.database;

      // تجهيز بيانات المستخدم
      String userId =
          data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      data['id'] = userId;
      data['created_at'] = DateTime.now().toIso8601String();

      data.remove('createAt');
      data.remove('createdAt');

      // 👈 استخدام Transaction لضمان إنشاء الحساب والملف معاً
      await db.transaction((txn) async {
        // أ. إنشاء حساب الدخول
        await txn.insert('users', data);

        // ب. التحقق من الدور (Role). إذا كان أكاديمياً، ننشئ له ملفاً في faculty_members
        List<String> academicRoles = [
          'Head of department',
          'Deputy Dean',
          'Faculty Member'
        ];

        if (academicRoles.contains(data['role'])) {
          String facultyId = 'fac_${DateTime.now().millisecondsSinceEpoch}';

          await txn.insert('faculty_members', {
            'id': facultyId,
            'user_id': userId, // 🔗 هذا هو حقل الربط السحري!
            'name': data['name'],
            'email': email,
            'created_at': DateTime.now().toIso8601String(),
            // باقي الحقول ستكون فارغة، وسيقوم الدكتور لاحقاً بتعبئتها من حسابه!
          });
          debugPrint(
              'تم إنشاء ملف أكاديمي مبدئي للمستخدم الجديد برقم: $facultyId');
        }
      });

      await fetchUsers(); // تحديث الواجهة
    } catch (e) {
      debugPrint('Error adding user: $e');
      rethrow;
    }
  }
}
