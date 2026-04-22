import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'study_plans_model.dart';
import 'package:academic_affairs_management/features/desktop_pages/programs_screen/programs_model.dart';

class StudyPlansViewModel extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────
  List<StudyPlanModel> _plans = [];
  List<ProgramModel> _programs = [];
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;

  List<StudyPlanModel> get plans => _plans;
  List<ProgramModel> get programs => _programs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<StudyPlanModel> get filteredPlans {
    if (_searchQuery.isEmpty) return _plans;
    final q = _searchQuery.toLowerCase();
    return _plans.where((p) {
      final progName = _programName(p.programId).toLowerCase();
      return p.arLevel.contains(_searchQuery) ||
          p.enLevel.toLowerCase().contains(q) ||
          p.arSemester.contains(_searchQuery) ||
          progName.contains(q);
    }).toList();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StudyPlansViewModel() {
    loadData();
  }

  // ── Helper ─────────────────────────────────────────────────────────────────
  String _programName(String programId) {
    try {
      return _programs.firstWhere((p) => p.id == programId).nameAr;
    } catch (_) {
      return programId;
    }
  }

  String programName(String programId) => _programName(programId);

  String trackName(String programId, String? trackId) {
    if (trackId == null || trackId.isEmpty) return 'الخطة العامة';
    try {
      final prog = _programs.firstWhere((p) => p.id == programId);
      return prog.tracks.firstWhere((t) => t.trackId == trackId).nameAr;
    } catch (_) {
      return trackId;
    }
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;

      // تحميل البرامج للعرض في القوائم
      final progResult = await db.query('programs');
      _programs = progResult.map((e) => ProgramModel.fromSQLite(e)).toList();

      // تحميل الخطط
      final plansResult = await db.query('studyPlans');
      _plans =
          plansResult.map((e) => StudyPlanModel.fromSQLiteMap(e)).toList();

      // مزامنة العناصر غير المرفوعة في الخلفية
      _syncPendingPlans();
    } catch (e) {
      _errorMessage = 'خطأ في تحميل الخطط الدراسية: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Add ────────────────────────────────────────────────────────────────────
  Future<void> addPlan(StudyPlanModel plan) async {
    try {
      final db = await DatabaseHelper.instance.database;
      plan.isSynced = false;
      _recalculateTotals(plan);

      await db.insert('studyPlans', plan.toSQLiteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      _plans.add(plan);
      notifyListeners();

      await _syncSinglePlan(plan);
    } catch (e) {
      debugPrint('خطأ في إضافة الخطة: $e');
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────
  Future<void> updatePlan(StudyPlanModel plan) async {
    try {
      final db = await DatabaseHelper.instance.database;
      plan.isSynced = false;
      _recalculateTotals(plan);

      await db.update('studyPlans', plan.toSQLiteMap(),
          where: 'id = ?', whereArgs: [plan.id]);
      final index = _plans.indexWhere((p) => p.id == plan.id);
      if (index != -1) {
        _plans[index] = plan;
        notifyListeners();
      }

      await _syncSinglePlan(plan);
    } catch (e) {
      debugPrint('خطأ في تحديث الخطة: $e');
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> deletePlan(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('studyPlans', where: 'id = ?', whereArgs: [id]);
      _plans.removeWhere((p) => p.id == id);
      notifyListeners();

      try {
        await _firestore.collection('studyPlans').doc(id).delete();
      } catch (_) {
        await db.insert('deleted_records', {
          'id': id,
          'table_name': 'studyPlans',
        });
      }
    } catch (e) {
      debugPrint('خطأ في حذف الخطة: $e');
    }
  }

  // ── Recalculate totals ─────────────────────────────────────────────────────
  void _recalculateTotals(StudyPlanModel plan) {
    int totalActual = 0, totalCredit = 0;
    for (final c in plan.courses) {
      totalActual += c.courseHours.actual.total;
      totalCredit += c.courseHours.credit.total;
    }
    plan.semesterTotals.totalActualHours = totalActual;
    plan.semesterTotals.totalCreditHours = totalCredit;
  }

  // ── Sync ───────────────────────────────────────────────────────────────────
  Future<void> _syncSinglePlan(StudyPlanModel plan) async {
    try {
      await _firestore
          .collection('studyPlans')
          .doc(plan.id)
          .set(plan.toFirestoreMap());

      final db = await DatabaseHelper.instance.database;
      await db.update('studyPlans', {'is_synced': 1},
          where: 'id = ?', whereArgs: [plan.id]);

      final index = _plans.indexWhere((p) => p.id == plan.id);
      if (index != -1) {
        _plans[index].isSynced = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('لم يتم رفع الخطة الآن، سيتم الرفع لاحقاً: $e');
    }
  }

  Future<void> _syncPendingPlans() async {
    final pending = _plans.where((p) => !p.isSynced).toList();
    for (final plan in pending) {
      await _syncSinglePlan(plan);
    }
  }

  // ── Generate ID ────────────────────────────────────────────────────────────
  String generateId() => _firestore.collection('studyPlans').doc().id;

  // ── Internet check ─────────────────────────────────────────────────────────
  Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
