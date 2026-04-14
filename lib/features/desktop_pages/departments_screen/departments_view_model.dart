import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/features/desktop_pages/departments_screen/department_model.dart';
import 'package:flutter/material.dart';

class DepartmentsViewModel extends ChangeNotifier {
  List<DepartmentModel> allDepartments = [];
  List<DepartmentModel> filteredDepartments = [];

  /// id -> اسم الكلية (ar_name)
  Map<String, String> collegeNames = {};

  /// id -> اسم رئيس القسم
  Map<String, String> hodNames = {};

  /// قائمة الكليات المتاحة في نماذج الإضافة/التعديل
  List<Map<String, dynamic>> availableColleges = [];

  /// قائمة المستخدمين المتاحين لاختيار رئيس القسم
  List<Map<String, dynamic>> availableUsers = [];

  bool isLoading = true;
  String errorMessage = '';
  String searchQuery = '';

  DepartmentsViewModel() {
    fetchDepartments();
  }

  // ── جلب الأقسام (بديلاً عن Stream) ──────────────────────────────────────────
  // ── جلب الأقسام والبيانات المرتبطة ──────────────────────────────────────────
  Future<void> fetchDepartments() async {
    isLoading = true;
    notifyListeners(); // إظهار مؤشر التحميل العام للشاشة

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. جلب البيانات من جدول الأقسام
      final List<Map<String, dynamic>> result = await db.query('departments');
      allDepartments = result.map((d) => DepartmentModel.fromMap(d)).toList();

      // 2. التحميل المتوازي: جلب الأسماء وقوائم الاختيار في نفس اللحظة (لتقليل وقت الانتظار)
      await Future.wait([
        _fetchCollegeNames(),
        _fetchHodNames(),
        fetchAvailableColleges(), // تحميل قائمة الكليات للقوائم المنسدلة
        fetchAvailableUsers(), // تحميل قائمة المستخدمين للقوائم المنسدلة
      ]);

      _applyFilters(); // هذه الدالة تحتوي على isLoading = false و notifyListeners()
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('Error fetching departments: $e');
      isLoading = false;
      notifyListeners();
    }
  }

  // ── جلب أسماء الكليات ───────────────────────────────────────────────────────
  Future<void> _fetchCollegeNames() async {
    final ids = allDepartments
        .map((d) => d.collegeId)
        .where((id) => id.isNotEmpty)
        .toSet();

    final db = await DatabaseHelper.instance.database;

    for (final id in ids) {
      if (!collegeNames.containsKey(id)) {
        try {
          final doc = await db.query(
            'colleges',
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (doc.isNotEmpty) {
            collegeNames[id] = doc.first['ar_name']?.toString() ?? 'غير معروف';
          } else {
            collegeNames[id] = 'كلية غير موجودة';
          }
        } catch (_) {
          collegeNames[id] = 'خطأ في الجلب';
        }
      }
    }
  }

  // ── جلب أسماء رؤساء الأقسام ─────────────────────────────────────────────────
  Future<void> _fetchHodNames() async {
    final ids =
        allDepartments.map((d) => d.hodId).where((id) => id.isNotEmpty).toSet();

    final db = await DatabaseHelper.instance.database;

    for (final id in ids) {
      if (!hodNames.containsKey(id)) {
        try {
          final doc = await db.query(
            'users',
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (doc.isNotEmpty) {
            hodNames[id] = doc.first['name']?.toString() ?? 'غير معروف';
          } else {
            hodNames[id] = 'مستخدم غير موجود';
          }
        } catch (_) {
          hodNames[id] = 'خطأ في الجلب';
        }
      }
    }
  }

  // ── جلب قوائم الاختيار (للنماذج) ────────────────────────────────────────────
  // ── جلب قوائم الاختيار (للنماذج) ────────────────────────────────────────────
  Future<void> fetchAvailableColleges() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final snapshot = await db.query('colleges');

      availableColleges = snapshot.map((doc) {
        return <String, dynamic>{
          'id': doc['id'].toString(),
          'name': doc['ar_name']?.toString() ?? 'بدون اسم',
        };
      }).toList();
      // تم إزالة notifyListeners() من هنا لأن _applyFilters ستتكفل بها في النهاية
    } catch (e) {
      debugPrint('Error fetching available colleges: $e');
    }
  }

  Future<void> fetchAvailableUsers() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final snapshot = await db.query('users');

      availableUsers = snapshot.map((doc) {
        return <String, dynamic>{
          'id': doc['id'].toString(),
          'name': doc['name']?.toString() ?? 'بدون اسم',
        };
      }).toList();
      // تم إزالة notifyListeners() من هنا أيضاً
    } catch (e) {
      debugPrint('Error fetching available users: $e');
    }
  }

  // ── بحث ─────────────────────────────────────────────────────────────────────
  void updateSearchQuery(String query) {
    searchQuery = query.toLowerCase();
    _applyFilters();
  }

  void _applyFilters() {
    filteredDepartments = allDepartments.where((d) {
      final collegeName = collegeNames[d.collegeId]?.toLowerCase() ?? '';
      final hodName = hodNames[d.hodId]?.toLowerCase() ?? '';
      return d.name.toLowerCase().contains(searchQuery) ||
          collegeName.contains(searchQuery) ||
          hodName.contains(searchQuery);
    }).toList();
    isLoading = false;
    notifyListeners();
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────────

  Future<void> addDepartment(Map<String, dynamic> data) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. توليد المفاتيح الأساسية
      data['id'] =
          data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      data['created_at'] = DateTime.now().toIso8601String();

      // 2. تحويل المفاتيح القديمة (Firebase) إلى الجديدة (SQLite) بأمان
      if (data.containsKey('collegeId'))
        data['college_id'] = data.remove('collegeId');
      if (data.containsKey('hodId')) data['hod_id'] = data.remove('hodId');
      if (data.containsKey('HODId'))
        data['hod_id'] = data.remove('HODId'); // احتياط للـ UI
      data.remove('createdAt');

      // 3. تأكيد وجود القيم المطلوبة لمنع خطأ NOT NULL constraint
      data['name'] = data['name'] ?? 'بدون اسم';
      data['college_id'] = data['college_id'] ?? '';
      data['hod_id'] = data['hod_id'] ?? '';

      await db.insert('departments', data);
      await fetchDepartments();
      debugPrint('Department added successfully: ${data['name']}');
    } catch (e) {
      debugPrint('Error adding department: $e');
      rethrow;
    }
  }

  Future<void> updateDepartment(
      String departmentId, Map<String, dynamic> data) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // تحويل المفاتيح القديمة إلى الجديدة
      if (data.containsKey('collegeId'))
        data['college_id'] = data.remove('collegeId');
      if (data.containsKey('hodId')) data['hod_id'] = data.remove('hodId');
      if (data.containsKey('HODId')) data['hod_id'] = data.remove('HODId');
      data.remove('createdAt');

      await db.update(
        'departments',
        data,
        where: 'id = ?',
        whereArgs: [departmentId],
      );

      await fetchDepartments();
      debugPrint('Department updated successfully: $departmentId');
    } catch (e) {
      debugPrint('Error updating department: $e');
      rethrow;
    }
  }

  Future<void> deleteDepartment(String departmentId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'departments',
        where: 'id = ?',
        whereArgs: [departmentId],
      );
      await fetchDepartments();
      debugPrint('Department deleted successfully: $departmentId');
    } catch (e) {
      debugPrint('Error deleting department: $e');
      rethrow;
    }
  }
}
