import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_model.dart'; // استدعاء الموديل

class UsersViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<UserModel> allUsers = [];
  List<UserModel> filteredUsers = [];
  bool isLoading = true;
  String errorMessage = '';

  String searchQuery = '';
  String? selectedRole;

  // Dynamic dropdown lists based on existing data
  List<String> get availableRoles => allUsers.map((u) => u.role).whereType<String>().where((s) => s.isNotEmpty).toSet().toList();
  UsersViewModel() {
    _initStream();
  }

  void _initStream() {
    _firestore.collection('users').snapshots().listen((snapshot) {
      allUsers = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
      _applyFilters();
    }, onError: (error) {
      errorMessage = error.toString();
      isLoading = false;
      notifyListeners();
    });
  }

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
      final matchesRole = (selectedRole == null || selectedRole == 'الكل') || u.role == selectedRole;
      
      return matchesSearch && matchesRole;
    }).toList();
    isLoading = false;
    notifyListeners();
  }

  // 2. دالة الحذف
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  // 3. إضافة مستخدم جديد
  Future<void> addUser(Map<String, dynamic> data) async {
    try {
      data['createAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').add(data);
    } catch (e) {
      debugPrint('Error adding user: $e');
      rethrow;
    }
  }

  // 4. تعديل بيانات مستخدم
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }
}
