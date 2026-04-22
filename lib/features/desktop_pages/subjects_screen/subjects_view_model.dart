import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'subject_model.dart';

class SubjectsViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<SubjectModel> allSubjects = [];
  List<SubjectModel> filteredSubjects = [];

  bool isLoading = true;
  String errorMessage = '';
  String searchQuery = '';

  SubjectsViewModel() {
    _initStream();
  }

  void _initStream() {
    _firestore.collection('subjects').snapshots().listen((snapshot) {
      isLoading = true;
      notifyListeners();
      allSubjects =
          snapshot.docs.map((d) => SubjectModel.fromFirestore(d)).toList();
      _applyFilters();
    }, onError: (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    });
  }

  void updateSearchQuery(String query) {
    searchQuery = query.toLowerCase();
    _applyFilters();
  }

  void _applyFilters() {
    filteredSubjects = allSubjects.where((s) {
      return s.arName.toLowerCase().contains(searchQuery) ||
          s.enName.toLowerCase().contains(searchQuery);
    }).toList();
    isLoading = false;
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> addSubject({
    required String arName,
    required String enName,
  }) async {
    try {
      await _firestore.collection('subjects').add({
        'ar_name': arName.trim(),
        'en_name': enName.trim(),
      });
    } catch (e) {
      debugPrint('Error adding subject: $e');
      rethrow;
    }
  }

  Future<void> updateSubject(
    String id, {
    required String arName,
    required String enName,
  }) async {
    try {
      await _firestore.collection('subjects').doc(id).update({
        'ar_name': arName.trim(),
        'en_name': enName.trim(),
      });
    } catch (e) {
      debugPrint('Error updating subject: $e');
      rethrow;
    }
  }

  Future<void> deleteSubject(String id) async {
    try {
      await _firestore.collection('subjects').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting subject: $e');
      rethrow;
    }
  }
}
