import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import '../models/study_plan.dart';
import '../services/study_plan_firestore_service.dart';

class StudyPlanListViewModel extends ChangeNotifier {
  final _service = StudyPlanFirestoreService();

  final String? initialCollege;
  final bool canEdit;
  final bool lockCollege;
  final String? initialProgram;
  final bool lockProgram;

  StudyPlanListViewModel({
    required this.initialCollege,
    required this.canEdit,
    required this.lockCollege,
    required this.initialProgram,
    required this.lockProgram,
  }) {
    _collegeFilter = lockCollege ? initialCollege : null;
  }

  String? _collegeFilter;
  String? get collegeFilter => _collegeFilter;

  bool _deleting = false;
  bool get deleting => _deleting;

  List<String> _colleges = [];
  List<String> get colleges => _colleges;

  List<StudyPlanSummary> _plans = [];
  List<StudyPlanSummary> get plans => _plans;

  bool _loading = true;
  bool get loading => _loading;

  Future<void> init() async {
    await loadColleges();
    await reload();
  }

  Future<void> loadColleges() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('colleges');
      final names = result
          .map((c) => (c['ar_name'] ?? '').toString().trim())
          .where((n) => n.isNotEmpty)
          .toList();
      names.sort();
      _colleges = names;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> reload() async {
    _loading = true;
    notifyListeners();
    try {
      final allPlans = await _service.listPlans(collegeFilter: _collegeFilter);
      if (lockProgram && initialProgram != null) {
        final query = initialProgram!.trim().toLowerCase();
        _plans = allPlans.where((p) {
          final prog = p.programName.toLowerCase();
          return prog.contains(query) || query.contains(prog);
        }).toList();
      } else {
        _plans = allPlans;
      }
    } catch (e) {
      debugPrint('Error reloading plans: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setCollegeFilter(String? val) {
    _collegeFilter = val;
    notifyListeners();
    reload();
  }

  Future<void> deletePlan(String planId) async {
    _deleting = true;
    notifyListeners();
    try {
      await _service.deletePlan(planId);
      await reload();
    } finally {
      _deleting = false;
      notifyListeners();
    }
  }
}
