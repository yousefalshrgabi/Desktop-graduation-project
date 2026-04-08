import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'department_model.dart';

class DepartmentsViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    _initStream();
  }

  // ── Stream رئيسي ────────────────────────────────────────────────────────────
  void _initStream() {
    _firestore.collection('departments').snapshots().listen((snapshot) async {
      isLoading = true;
      notifyListeners();

      allDepartments =
          snapshot.docs.map((d) => DepartmentModel.fromFirestore(d)).toList();

      await Future.wait([_fetchCollegeNames(), _fetchHodNames()]);

      _applyFilters();
    }, onError: (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    });
  }

  // ── جلب أسماء الكليات ───────────────────────────────────────────────────────
  Future<void> _fetchCollegeNames() async {
    final ids = allDepartments
        .map((d) => d.collegeId)
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final id in ids) {
      if (!collegeNames.containsKey(id)) {
        try {
          final doc = await _firestore.collection('colleges').doc(id).get();
          if (doc.exists) {
            final data = doc.data()!;
            collegeNames[id] =
                data['ar_name']?.toString() ?? 'غير معروف';
          } else {
            collegeNames[id] = 'كلية محذوفة';
          }
        } catch (_) {
          collegeNames[id] = 'خطأ في الجلب';
        }
      }
    }
  }

  // ── جلب أسماء رؤساء الأقسام ─────────────────────────────────────────────────
  Future<void> _fetchHodNames() async {
    final ids = allDepartments
        .map((d) => d.hodId)
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final id in ids) {
      if (!hodNames.containsKey(id)) {
        try {
          final doc = await _firestore.collection('users').doc(id).get();
          if (doc.exists) {
            hodNames[id] = doc.data()?['name']?.toString() ?? 'غير معروف';
          } else {
            hodNames[id] = 'مستخدم غير موجود';
          }
        } catch (_) {
          hodNames[id] = 'خطأ في الجلب';
        }
      }
    }
  }

  // ── جلب قوائم الاختيار (للnماذج) ────────────────────────────────────────────
  Future<void> fetchAvailableColleges() async {
    try {
      final snapshot = await _firestore.collection('colleges').get();
      availableColleges = snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          'id': doc.id,
          'name': data['ar_name']?.toString() ?? 'بدون اسم',
        };
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching colleges: $e');
    }
  }

  Future<void> fetchAvailableUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      availableUsers = snapshot.docs.map((doc) {
        return <String, dynamic>{
          'id': doc.id,
          'name': doc.data()['name']?.toString() ?? 'بدون اسم',
        };
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching users: $e');
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
      data['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('departments').add(data);
    } catch (e) {
      debugPrint('Error adding department: $e');
      rethrow;
    }
  }

  Future<void> updateDepartment(
      String departmentId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('departments').doc(departmentId).update(data);
    } catch (e) {
      debugPrint('Error updating department: $e');
      rethrow;
    }
  }

  Future<void> deleteDepartment(String departmentId) async {
    try {
      await _firestore.collection('departments').doc(departmentId).delete();
    } catch (e) {
      debugPrint('Error deleting department: $e');
      rethrow;
    }
  }
}
