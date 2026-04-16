import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/features/desktop_pages/colleges_screen/college_model.dart';
import 'package:flutter/material.dart';

class CollegesViewModel extends ChangeNotifier {
  List<CollegeModel> allColleges = [];
  List<CollegeModel> filteredColleges = [];

  // خريطة لتخزين أسماء العمداء لتسهيل عرضها في الواجهة
  Map<String, String> deanNames = {};

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
        _fetchDeanNames(),
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

  Future<void> _fetchDeanNames() async {
    final Set<String> deanIds =
        allColleges.map((c) => c.deanId).where((id) => id.isNotEmpty).toSet();

    final db = await DatabaseHelper.instance.database;

    for (String deanId in deanIds) {
      if (!deanNames.containsKey(deanId)) {
        try {
          final List<Map<String, dynamic>> userResult = await db.query(
            'users',
            where: 'id = ?',
            whereArgs: [deanId],
            limit: 1,
          );

          if (userResult.isNotEmpty) {
            final userName = userResult.first['name'] ?? 'غير معروف';
            deanNames[deanId] = userName.toString();
          } else {
            deanNames[deanId] = 'غير موجود';
          }
        } catch (e) {
          deanNames[deanId] = 'خطأ';
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
      final deanName = deanNames[c.deanId]?.toLowerCase() ?? '';
      final matchesSearch = c.arName.toLowerCase().contains(searchQuery) ||
          c.enName.toLowerCase().contains(searchQuery) ||
          c.code.toLowerCase().contains(searchQuery) ||
          deanName.contains(searchQuery);

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

      if (data.containsKey('arName')) data['ar_name'] = data.remove('arName');
      if (data.containsKey('enName')) data['en_name'] = data.remove('enName');
      if (data.containsKey('deanId')) data['dean_id'] = data.remove('deanId');

      data.remove('createdAt');

      data['dean_id'] = data['dean_id'] ?? '';
      data['ar_name'] = data['ar_name'] ?? 'بدون اسم';
      data['en_name'] = data['en_name'] ?? 'No Name';
      data['code'] = data['code'] ?? '';

      await db.insert('colleges', data);
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

      if (data.containsKey('arName')) data['ar_name'] = data.remove('arName');
      if (data.containsKey('enName')) data['en_name'] = data.remove('enName');
      if (data.containsKey('deanId')) data['dean_id'] = data.remove('deanId');

      data.remove('createdAt');

      await db.update(
        'colleges',
        data,
        where: 'id = ?',
        whereArgs: [collegeId],
      );

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
    });

    fetchColleges(); // تحديث الواجهة
  }
}
