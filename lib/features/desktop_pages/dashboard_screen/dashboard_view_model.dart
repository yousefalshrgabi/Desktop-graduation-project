import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/features/desktop_pages/dashboard_screen/dashboard_stats_model.dart';
import 'package:academic_affairs_management/features/desktop_pages/colleges_screen/college_model.dart';
import 'package:academic_affairs_management/features/desktop_pages/faculty_members_screen/faculty_member_model.dart';
import 'package:sqflite/sqflite.dart';

class DashboardViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DashboardStats stats = DashboardStats();
  bool isLoading = true;
  String? errorMessage;

  DashboardViewModel() {
    refreshStats();
  }

  Future<void> refreshStats() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      debugPrint('[DASHBOARD DEBUG] جاري جلب الإحصائيات من SQLite...');
      // الحصول على مثيل قاعدة البيانات
      final db = await DatabaseHelper.instance.database;

      // =======================================================
      // 1. جلب الإحصائيات (العدد الإجمالي) باستخدام rawQuery
      // =======================================================
      final collegesCountResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM colleges');
      final int totalColleges = Sqflite.firstIntValue(collegesCountResult) ?? 0;

      final facultyCountResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM faculty_members');
      final int totalFaculty = Sqflite.firstIntValue(facultyCountResult) ?? 0;

      final usersCountResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM users');
      final int totalUsers = Sqflite.firstIntValue(usersCountResult) ?? 0;

      // =======================================================
      // 2. جلب أحدث الكليات المضافة (ترتيب تنازلي حسب تاريخ الإنشاء)
      // =======================================================
      final recentCollegesLocal = await db.query(
        'colleges',
        orderBy: 'created_at DESC', // الترتيب من الأحدث للأقدم
        limit: 5, // جلب 5 فقط
      );

      // تحويل الـ Map القادم من SQLite إلى CollegeModel
      // ملاحظة: تأكد أن دالة fromJson لديك في CollegeModel تقبل هذه المفاتيح
      final recentColleges = recentCollegesLocal.map((map) {
        return CollegeModel(
          id: map['id'] as String,
          arName: map['ar_name'] as String,
          enName: map['en_name'] as String,
          code: map['code'] as String,
          deanId: map['dean_id'] as String,
          createdAt: map['created_at'] as String, // أو حسب نوعها في الموديل
        );
      }).toList();

      // =======================================================
      // 3. جلب أحدث أعضاء هيئة التدريس المضافين
      // =======================================================
      final recentFacultyLocal = await db.query(
        'faculty_members',
        orderBy: 'created_at DESC',
        limit: 5,
      );

      final recentFaculty = recentFacultyLocal.map((map) {
        return FacultyMemberModel(
          id: map['id'] as String,
          name: map['name'] as String,
          email: map['email'] as String,
          department: map['department'] as String,
          academicDegree: map['academic_degree'] as String,
          status: map['status'] as String,
          createdAt: map['created_at'] as String, // أو حسب نوعها
        );
      }).toList();

      // =======================================================
      // 4. تعيين البيانات وتحديث الواجهة
      // =======================================================
      stats = DashboardStats(
        totalColleges: totalColleges,
        totalFacultyMembers: totalFaculty,
        totalUsers: totalUsers,
        recentColleges: recentColleges,
        recentFaculty: recentFaculty,
      );

      isLoading = false;
      notifyListeners();
      debugPrint('[DASHBOARD DEBUG] تم جلب الإحصائيات من SQLite بنجاح.');
    } catch (e) {
      isLoading = false;
      errorMessage = 'حدث خطأ أثناء جلب البيانات المحلية: $e';
      debugPrint('[DASHBOARD DEBUG] Error: $e');
      notifyListeners();
    }
  }

  Future<void> refreshStatsfire() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // جلب الإحصائيات (العدد الإجمالي)
      final collegesCount =
          await _firestore.collection('colleges').count().get();
      final facultyCount =
          await _firestore.collection('faculty_members').count().get();
      final usersCount = await _firestore.collection('users').count().get();

      // جلب أحدث الكليات المضافة
      final recentCollegesSnapshot = await _firestore
          .collection('colleges')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final recentColleges = recentCollegesSnapshot.docs
          .map((doc) => CollegeModel.fromFirestore(doc))
          .toList();

      // جلب أحدث أعضاء هيئة التدريس المضافين
      final recentFacultySnapshot = await _firestore
          .collection('faculty_members')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final recentFaculty = recentFacultySnapshot.docs
          .map((doc) => FacultyMemberModel.fromFirestore(doc))
          .toList();

      stats = DashboardStats(
        totalColleges: collegesCount.count ?? 0,
        totalFacultyMembers: facultyCount.count ?? 0,
        totalUsers: usersCount.count ?? 0,
        recentColleges: recentColleges,
        recentFaculty: recentFaculty,
      );

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      errorMessage = 'حدث خطأ أثناء جلب البيانات: $e';
      debugPrint('Dashboard Error: $e');
      notifyListeners();
    }
  }
}
