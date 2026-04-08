import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/features/desktop_pages/dashboard_screen/dashboard_stats_model.dart';
import 'package:academic_affairs_management/features/desktop_pages/colleges_screen/college_model.dart';
import 'package:academic_affairs_management/features/desktop_pages/faculty_members_screen/faculty_member_model.dart';

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
      // جلب الإحصائيات (العدد الإجمالي)
      final collegesCount = await _firestore.collection('colleges').count().get();
      final facultyCount = await _firestore.collection('faculty_members').count().get();
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
