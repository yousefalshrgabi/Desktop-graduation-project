import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/features/desktop_pages/colleges_screen/college_model.dart';
import 'package:academic_affairs_management/features/desktop_pages/users_screen/users_view_model.dart';
import 'package:flutter/material.dart';

class CollegesViewModel extends ChangeNotifier {
  List<CollegeModel> allColleges = [];
  List<CollegeModel> filteredColleges = [];

  // خرائط لتخزين أسماء العملاء والنواب لتسهيل عرضها في الواجهة
  Map<String, String> userNames = {};

  // قائمة المستخدمين المتاحين لاختيار العميد
  List<Map<String, dynamic>> potentialDeans = [];

  bool isLoading = true;
  String errorMessage = '';
  String searchQuery = '';

  CollegesViewModel() {
    fetchColleges();
  }

  // ==========================================
  // 1. جلب البيانات (مع التحميل المتوازي)
  // ==========================================

  Future<void> fetchColleges() async {
    isLoading = true;
    notifyListeners(); // إظهار مؤشر التحميل

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. جلب البيانات الأساسية من جدول الكليات
      final List<Map<String, dynamic>> result = await db.query('colleges');
      allColleges = result.map((map) => CollegeModel.fromMap(map)).toList();

      // 2. التحميل المتوازي: جلب الأسماء وقائمة اختيار العمداء معاً في نفس اللحظة
      await Future.wait([
        _fetchUserNames(),
        fetchPotentialDeans(), // تحميل قائمة المستخدمين للقائمة المنسدلة مسبقاً
      ]);

      _applyFilters(); // تقوم بتعطيل isLoading وتحديث الواجهة
    } catch (error) {
      errorMessage = error.toString();
      debugPrint('Error fetching colleges: $error');
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchUserNames() async {
    final Set<String> allIds = {};
    for (var c in allColleges) {
      if (c.deanId.isNotEmpty) allIds.add(c.deanId);
      if (c.academicViceDeanId.isNotEmpty) allIds.add(c.academicViceDeanId);
      if (c.studentViceDeanId.isNotEmpty) allIds.add(c.studentViceDeanId);
    }

    final db = await DatabaseHelper.instance.database;

    for (String id in allIds) {
      if (!userNames.containsKey(id)) {
        try {
          final List<Map<String, dynamic>> userResult = await db.query(
            'users',
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );

          if (userResult.isNotEmpty) {
            userNames[id] = userResult.first['name']?.toString() ?? 'غير معروف';
          } else {
            userNames[id] = 'غير موجود';
          }
        } catch (e) {
          userNames[id] = 'خطأ';
        }
      }
    }
  }

  Future<void> fetchPotentialDeans() async {
    try {
      final db = await DatabaseHelper.instance.database;
      // لجلب المستخدمين لعرضهم كخيارات في الـ Dropdown
      final List<Map<String, dynamic>> snapshot = await db.query('users');

      potentialDeans = snapshot
          .map((doc) => {
                'id': doc['id'].toString(),
                'name': doc['name']?.toString() ?? 'بدون اسم',
              })
          .toList();

      // ❌ تم إزالة notifyListeners() من هنا لتجنب إعادة رسم الشاشة مرتين
    } catch (e) {
      debugPrint('Error fetching potential deans: $e');
    }
  }

  // ==========================================
  // 2. البحث والفلترة
  // ==========================================

  void updateSearchQuery(String query) {
    searchQuery = query.toLowerCase();
    _applyFilters();
  }

  void _applyFilters() {
    filteredColleges = allColleges.where((c) {
      final deanName = userNames[c.deanId]?.toLowerCase() ?? '';
      final academicViceDeanName =
          userNames[c.academicViceDeanId]?.toLowerCase() ?? '';
      final studentViceDeanName =
          userNames[c.studentViceDeanId]?.toLowerCase() ?? '';

      final matchesSearch = c.arName.toLowerCase().contains(searchQuery) ||
          c.enName.toLowerCase().contains(searchQuery) ||
          c.code.toLowerCase().contains(searchQuery) ||
          deanName.contains(searchQuery) ||
          academicViceDeanName.contains(searchQuery) ||
          studentViceDeanName.contains(searchQuery);

      return matchesSearch;
    }).toList();
    isLoading = false;
    notifyListeners();
  }

  // ==========================================
  // 3. العمليات الأساسية (إضافة، تعديل، حذف)
  // ==========================================

  Future<void> addCollege(Map<String, dynamic> data) async {
    try {
      final db = await DatabaseHelper.instance.database;

      data['id'] =
          data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      data['created_at'] = DateTime.now().toIso8601String();
      data['updated_at'] = DateTime.now().toIso8601String();

      // تحويل المسميات لتطابق أعمدة الجدول
      if (data.containsKey('arName')) data['ar_name'] = data.remove('arName');
      if (data.containsKey('enName')) data['en_name'] = data.remove('enName');
      if (data.containsKey('deanId')) data['dean_id'] = data.remove('deanId');
      if (data.containsKey('academicViceDeanId')) {
        data['academic_vice_dean_id'] = data.remove('academicViceDeanId');
      }
      if (data.containsKey('studentViceDeanId')) {
        data['student_vice_dean_id'] = data.remove('studentViceDeanId');
      }

      data.remove('createdAt');

      data['dean_id'] = data['dean_id'] ?? '';
      data['academic_vice_dean_id'] = data['academic_vice_dean_id'] ?? '';
      data['student_vice_dean_id'] = data['student_vice_dean_id'] ?? '';
      data['ar_name'] = data['ar_name'] ?? 'بدون اسم';
      data['en_name'] = data['en_name'] ?? 'No Name';
      data['code'] = data['code'] ?? '';

      await db.transaction((txn) async {
        await txn.insert('colleges', data);

        // 👈 تحديث صلاحيات المستخدمين المختارين للعمادة والنواب بمصفوفة الصلاحيات
        if (data['dean_id'] != null && data['dean_id'].toString().isNotEmpty) {
          await UsersViewModel.addRoleToUser(txn, data['dean_id'].toString(), 'Dean');
        }
        if (data['academic_vice_dean_id'] != null &&
            data['academic_vice_dean_id'].toString().isNotEmpty) {
          await UsersViewModel.addRoleToUser(txn, data['academic_vice_dean_id'].toString(), 'Vice Dean for Academic Affairs');
        }
        if (data['student_vice_dean_id'] != null &&
            data['student_vice_dean_id'].toString().isNotEmpty) {
          await UsersViewModel.addRoleToUser(txn, data['student_vice_dean_id'].toString(), 'Vice Dean for Student Affairs');
        }
      });

      await fetchColleges();
      debugPrint('College added successfully: ${data['ar_name']}');
    } catch (e) {
      debugPrint('Error adding college: $e');
      rethrow;
    }
  }

  Future<void> updateCollege(
      String collegeId, Map<String, dynamic> data) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. جلب البيانات القديمة للمقارنة
      final List<Map<String, dynamic>> oldData = await db.query(
        'colleges',
        where: 'id = ?',
        whereArgs: [collegeId],
        limit: 1,
      );

      final String oldDeanId =
          oldData.isNotEmpty ? oldData.first['dean_id'] ?? '' : '';
      final String oldAcademicViceDeanId = oldData.isNotEmpty
          ? oldData.first['academic_vice_dean_id'] ?? ''
          : '';
      final String oldStudentViceDeanId =
          oldData.isNotEmpty ? oldData.first['student_vice_dean_id'] ?? '' : '';

      // 2. تجهيز البيانات الجديدة
      if (data.containsKey('arName')) data['ar_name'] = data.remove('arName');
      if (data.containsKey('enName')) data['en_name'] = data.remove('enName');
      if (data.containsKey('deanId')) data['dean_id'] = data.remove('deanId');
      if (data.containsKey('academicViceDeanId')) {
        data['academic_vice_dean_id'] = data.remove('academicViceDeanId');
      }
      if (data.containsKey('studentViceDeanId')) {
        data['student_vice_dean_id'] = data.remove('studentViceDeanId');
      }

      data.remove('createdAt');
      data['updated_at'] = DateTime.now().toIso8601String();

      // 3. تحديث الكلية والصلاحيات في عملية واحدة
      await db.transaction((txn) async {
        await txn.update(
          'colleges',
          data,
          where: 'id = ?',
          whereArgs: [collegeId],
        );

        // 👈 إرجاع صلاحية العميد القديم
        if (oldDeanId.isNotEmpty && data['dean_id'] != oldDeanId) {
          await UsersViewModel.removeRoleFromUser(txn, oldDeanId, 'Dean');
        }
        // 👈 تحديث صلاحيات العميد الجديد
        if (data['dean_id'] != null &&
            data['dean_id'].toString().isNotEmpty &&
            data['dean_id'] != oldDeanId) {
          await UsersViewModel.addRoleToUser(txn, data['dean_id'].toString(), 'Dean');
        }

        // 👈 إرجاع صلاحية النائب الأكاديمي القديم
        if (oldAcademicViceDeanId.isNotEmpty &&
            data['academic_vice_dean_id'] != oldAcademicViceDeanId) {
          await UsersViewModel.removeRoleFromUser(txn, oldAcademicViceDeanId, 'Vice Dean for Academic Affairs');
        }
        // 👈 تحديث صلاحيات النائب الأكاديمي الجديد
        if (data['academic_vice_dean_id'] != null &&
            data['academic_vice_dean_id'].toString().isNotEmpty &&
            data['academic_vice_dean_id'] != oldAcademicViceDeanId) {
          await UsersViewModel.addRoleToUser(txn, data['academic_vice_dean_id'].toString(), 'Vice Dean for Academic Affairs');
        }

        // 👈 إرجاع صلاحية نائب شؤون الطلاب القديم
        if (oldStudentViceDeanId.isNotEmpty &&
            data['student_vice_dean_id'] != oldStudentViceDeanId) {
          await UsersViewModel.removeRoleFromUser(txn, oldStudentViceDeanId, 'Vice Dean for Student Affairs');
        }
        // 👈 تحديث صلاحيات نائب شؤون الطلاب الجديد
        if (data['student_vice_dean_id'] != null &&
            data['student_vice_dean_id'].toString().isNotEmpty &&
            data['student_vice_dean_id'] != oldStudentViceDeanId) {
          await UsersViewModel.addRoleToUser(txn, data['student_vice_dean_id'].toString(), 'Vice Dean for Student Affairs');
        }
      });

      await fetchColleges();
      debugPrint('College updated successfully: $collegeId');
    } catch (e) {
      debugPrint('Error updating college: $e');
      rethrow;
    }
  }

  Future<void> deleteCollege(String collegeId) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      // 1. حذف الكلية فعلياً من جدولها (ليختفي من الواجهة فوراً)
      await txn.delete('colleges', where: 'id = ?', whereArgs: [collegeId]);

      // 2. تسجيل عملية الحذف في سلة المهملات للمزامنة لاحقاً
      await txn.insert(
          'deleted_records', {'id': collegeId, 'table_name': 'colleges'});

      // 3. إزالة الصلاحيات من العميد والنواب عند حذف الكلية
      final List<Map<String, dynamic>> oldData = await txn.query(
        'colleges',
        where: 'id = ?',
        whereArgs: [collegeId],
        limit: 1,
      );
      if (oldData.isNotEmpty) {
        final String oldDeanId = oldData.first['dean_id'] ?? '';
        final String oldAcademicViceDeanId = oldData.first['academic_vice_dean_id'] ?? '';
        final String oldStudentViceDeanId = oldData.first['student_vice_dean_id'] ?? '';
        
        if (oldDeanId.isNotEmpty) await UsersViewModel.removeRoleFromUser(txn, oldDeanId, 'Dean');
        if (oldAcademicViceDeanId.isNotEmpty) await UsersViewModel.removeRoleFromUser(txn, oldAcademicViceDeanId, 'Vice Dean for Academic Affairs');
        if (oldStudentViceDeanId.isNotEmpty) await UsersViewModel.removeRoleFromUser(txn, oldStudentViceDeanId, 'Vice Dean for Student Affairs');
      }
    });

    fetchColleges(); // تحديث الواجهة
  }
}
