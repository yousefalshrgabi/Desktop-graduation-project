import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'college_model.dart';

class CollegesViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CollegeModel> allColleges = [];
  List<CollegeModel> filteredColleges = [];

  // خريطة لتخزين أسماء العمداء لتسهيل عرضها في الواجهة بدل المعرفات (ID -> Name)
  Map<String, String> deanNames = {};

  // قائمة المستخدمين المتاحين لاختيار العميد في نماذج الإضافة والتعديل
  List<Map<String, dynamic>> potentialDeans = [];

  bool isLoading = true;
  String errorMessage = '';
  String searchQuery = '';

  CollegesViewModel() {
    _initStream();
  }

  void _initStream() {
    _firestore.collection('colleges').snapshots().listen((snapshot) async {
      isLoading = true;
      notifyListeners();
      
      allColleges = snapshot.docs.map((doc) => CollegeModel.fromFirestore(doc)).toList();
      
      // جلب أسماء العمداء بمجرد الحصول على القائمة
      await _fetchDeanNames();
      
      _applyFilters();
    }, onError: (error) {
      errorMessage = error.toString();
      isLoading = false;
      notifyListeners();
    });
  }

  // الاستعلام عن أسماء المستخدمين (العمداء) من جدول users
  Future<void> _fetchDeanNames() async {
    final Set<String> deanIds = allColleges
        .map((c) => c.deanId)
        .where((id) => id.isNotEmpty)
        .toSet();
        
    for (String deanId in deanIds) {
      if (!deanNames.containsKey(deanId)) {
        try {
          final userDoc = await _firestore.collection('users').doc(deanId).get();
          if (userDoc.exists) {
             final userName = userDoc.data()?['name'] ?? 'غير معروف';
             deanNames[deanId] = userName.toString();
          } else {
             deanNames[deanId] = 'مستخدم محذوف/غير موجود';
          }
        } catch (e) {
          deanNames[deanId] = 'خطأ في جلب الاسم';
        }
      }
    }
  }

  // جلب قائمة المستخدمين المتاحين لاختيارهم كعمداء (للاستخدام في نماذج الإضافة والتعديل)
  Future<void> fetchPotentialDeans() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      potentialDeans = snapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc.data()['name']?.toString() ?? 'بدون اسم',
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching potential deans: $e');
    }
  }

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

  // 1. إضافة كلية جديدة
  Future<void> addCollege(Map<String, dynamic> data) async {
    try {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('colleges').add(data);
    } catch (e) {
      debugPrint('Error adding college: $e');
      rethrow;
    }
  }

  // 2. تعديل بيانات كلية
  Future<void> updateCollege(String collegeId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('colleges').doc(collegeId).update(data);
    } catch (e) {
      debugPrint('Error updating college: $e');
      rethrow;
    }
  }

  // 3. حذف كلية
  Future<void> deleteCollege(String collegeId) async {
    try {
      await _firestore.collection('colleges').doc(collegeId).delete();
    } catch (e) {
      debugPrint('Error deleting college: $e');
      rethrow;
    }
  }
}
