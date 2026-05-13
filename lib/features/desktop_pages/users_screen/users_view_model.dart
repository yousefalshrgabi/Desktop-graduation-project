import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'user_model.dart';

class UsersViewModel extends ChangeNotifier {
  List<UserModel> allUsers = [];
  List<UserModel> filteredUsers = [];
  bool isLoading = true;
  String errorMessage = '';

  String searchQuery = '';
  String? selectedRole;
  String? selectedFaculty;
  List<String> colleges = [];

  // استخراج الأدوار المتاحة من البيانات الموجودة لتعبئة الـ Dropdown الديناميكي
  List<String> get availableRoles => allUsers
      .expand((u) => u.rolesList)
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  UsersViewModel() {
    fetchUsers();
  }

  // داخل كلاس UsersViewModel
  static const Map<String, String> roleTranslations = {
    'super_admin': 'مدير النظام',
    'Public Prosecution': 'النيابة العامة',
    'Dean': 'عميد',
    'Vice Dean for Academic Affairs': 'نائب العميد للشؤون الاكاديمية',
    'Vice Dean for Student Affairs': 'نائب العميد لشؤون الطلاب',
    'Head of department': 'رئيس قسم',
    'Faculty Member': 'عضو هيئة تدريس',
  };

// دالة مساعدة لتحويل الإنجليزي إلى عربي للعرض
  String translateRole(String role) => roleTranslations[role] ?? role;

  // 1. جلب البيانات (محلياً وفورياً)
  Future<void> fetchUsers() async {
    isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;

      // جلب المستخدمين
      final List<Map<String, dynamic>> userResult = await db.query('users');
      allUsers = userResult.map((doc) => UserModel.fromMap(doc)).toList();

      // 👈 جلب أسماء الكليات لتعبئة الفلتر
      final List<Map<String, dynamic>> collegeResult =
          await db.query('colleges');
      colleges = collegeResult.map((c) => c['ar_name'].toString()).toList();

      _applyFilters();
    } catch (error) {
      errorMessage = error.toString();
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
    selectedFaculty = null;
    _applyFilters();
  }

  void updateFacultyFilter(String? val) {
    selectedFaculty = val;
    _applyFilters();
  }

  void _applyFilters() {
    filteredUsers = allUsers.where((u) {
      final matchesSearch = u.name.toLowerCase().contains(searchQuery) ||
          u.email.toLowerCase().contains(searchQuery) ||
          u.phone.contains(searchQuery);

      final matchesRole = (selectedRole == null || selectedRole == 'الكل') ||
          u.rolesList.contains(selectedRole);

      // 👈 إضافة شرط فلتر الكلية
      final matchesFaculty =
          (selectedFaculty == null || selectedFaculty == 'كل الكليات') ||
              u.faculty == selectedFaculty;

      return matchesSearch && matchesRole && matchesFaculty;
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

      // تحديث الاسم أيضاً في جدول أعضاء هيئة التدريس إذا تم تغيير اسم المستخدم
      if (data.containsKey('name')) {
        await db.update('faculty_members', {'name': data['name']},
            where: 'user_id = ?', whereArgs: [userId]);
      }

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

  // 3. إضافة مستخدم جديد (تم التعديل لإنشاء ملف أكاديمي تلقائياً بدون حقل الإيميل)
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
          'Dean',
          'Vice Dean for Academic Affairs',
          'Vice Dean for Student Affairs',
          'Faculty Member'
        ];

        if (academicRoles.contains(data['role'])) {
          String facultyId = 'fac_${DateTime.now().millisecondsSinceEpoch}';

          await txn.insert('faculty_members', {
            'id': facultyId,
            'user_id': userId, // 🔗 هذا هو حقل الربط السحري!
            'name': data['name'],
            // ❌ تم حذف إدخال الإيميل من هنا نهائياً ليطابق التحديث الأخير للقاعدة
            'status': 'نشط',
            'created_at': DateTime.now().toIso8601String(),
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

  // ==================== دوال مساعدة للتعامل مع مصفوفة الصلاحيات ====================

  // الأدوار الإدارية التي تلغي ظهور "عضو هيئة تدريس"
  static const List<String> _adminRoles = [
    'Dean',
    'Vice Dean for Academic Affairs',
    'Vice Dean for Student Affairs',
    'Head of department',
  ];

  static List<String> _parseRoles(String roleStr) {
    if (roleStr.isEmpty) return [];
    if (roleStr.startsWith('[')) {
      try { return List<String>.from(jsonDecode(roleStr)); } catch(e) { return [roleStr]; }
    }
    return [roleStr];
  }

  static bool _hasAdminRole(List<String> roles) =>
      roles.any((r) => _adminRoles.contains(r));

  static Future<void> addRoleToUser(DatabaseExecutor txnOrDb, String userId, String newRole) async {
    final res = await txnOrDb.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);
    if (res.isEmpty) return;

    List<String> roles = _parseRoles(res.first['role']?.toString() ?? '');

    if (!roles.contains(newRole)) {
      roles.add(newRole);
    }

    // إذا أصبح للمستخدم دور إداري، احذف "عضو هيئة تدريس" تلقائياً (لا داعي لعرضه)
    if (_hasAdminRole(roles)) {
      roles.remove('Faculty Member');
    }

    await txnOrDb.update('users', {'role': jsonEncode(roles)}, where: 'id = ?', whereArgs: [userId]);
  }

  static Future<void> removeRoleFromUser(DatabaseExecutor txnOrDb, String userId, String roleToRemove) async {
    final res = await txnOrDb.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);
    if (res.isEmpty) return;

    List<String> roles = _parseRoles(res.first['role']?.toString() ?? '');

    if (roles.contains(roleToRemove)) {
      roles.remove(roleToRemove);
    }

    // إذا لم يبقَ أي دور إداري، أعد "عضو هيئة تدريس" كدور افتراضي
    if (!_hasAdminRole(roles)) {
      if (!roles.contains('Faculty Member')) {
        roles.add('Faculty Member');
      }
    }

    // إذا أصبحت القائمة فارغة تماماً (احتياط)
    if (roles.isEmpty) roles.add('Faculty Member');

    await txnOrDb.update('users', {'role': jsonEncode(roles)}, where: 'id = ?', whereArgs: [userId]);
  }
}

