import 'package:flutter/material.dart';
import '../models/study_plan.dart';
import '../services/study_plan_firestore_service.dart';

class StudyPlanDetailViewModel extends ChangeNotifier {
  final _service = StudyPlanFirestoreService();
  final String planId;
  final bool canEdit;

  StudyPlanDetailViewModel({
    required this.planId,
    required this.canEdit,
  });

  bool _loading = true;
  bool get loading => _loading;

  bool _deleting = false;
  bool get deleting => _deleting;

  StudyPlanSummary? _summary;
  StudyPlanSummary? get summary => _summary;

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> get courses => _courses;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String val) {
    _searchQuery = val;
    notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _summary = await _service.getPlanSummary(planId);
      _courses = await _service.getPlanCoursesRaw(planId);
    } catch (e) {
      debugPrint('Error loading plan details: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> deletePlan() async {
    _deleting = true;
    notifyListeners();
    try {
      await _service.deletePlan(planId);
    } finally {
      _deleting = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> getFilteredCourses() {
    final query = _searchQuery.trim().toLowerCase();
    return _courses.where((row) {
      if (query.isEmpty) return true;
      final name = (row['nameAr'] ?? '').toString().toLowerCase();
      final code = (row['codeLocal'] ?? '').toString().toLowerCase();
      final en = (row['codeEn'] ?? '').toString().toLowerCase();
      return name.contains(query) || code.contains(query) || en.contains(query);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> getGroupedCourses() {
    final filtered = getFilteredCourses();
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in filtered) {
      final key = (row['semesterLabelAr'] ?? row['semesterKey'] ?? 'عام').toString();
      grouped.putIfAbsent(key, () => []).add(row);
    }
    return grouped;
  }
}
