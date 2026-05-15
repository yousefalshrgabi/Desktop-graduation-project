import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'study_plans_model.dart';
import 'package:academic_affairs_management/features/desktop_pages/programs_screen/programs_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class StudyPlansViewModel extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────
  List<StudyPlanModel> _plans = [];
  List<ProgramModel> _programs = [];
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _departments = [];
  bool _disposed = false; // 👈 إضافة متغير لمتابعة حالة الكائن

  List<StudyPlanModel> get plans => _plans;
  bool get disposed => _disposed; // 👈 إضافة Getter
  List<ProgramModel> get programs => _programs;
  List<Map<String, dynamic>> get departments => _departments;
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
    if (!disposed) notifyListeners();
  }

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    if (!disposed) notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;

      // تحميل البرامج للعرض في القوائم
      final progResult = await db.query('programs');
      _programs = progResult.map((e) => ProgramModel.fromSQLite(e)).toList();

      // تحميل الخطط
      final plansResult = await db.query('studyPlans');
      _plans =
          plansResult.map((e) => StudyPlanModel.fromSQLiteMap(e)).toList();

      // تحميل الأقسام
      final depsResult = await db.query('departments');
      _departments = depsResult;

      // مزامنة العناصر غير المرفوعة في الخلفية
      _syncPendingPlans();
    } catch (e) {
      _errorMessage = 'خطأ في تحميل الخطط الدراسية: $e';
    } finally {
      _isLoading = false;
      if (!disposed) notifyListeners();
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
      if (!disposed) notifyListeners();

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
        if (!disposed) notifyListeners();
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
      if (!disposed) notifyListeners();

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
        if (!disposed) notifyListeners();
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

  // ── Excel Upload ───────────────────────────────────────────────────────────
  Future<void> uploadStudyPlanExcel(String deptId, PlatformFile file) async {
    try {
      // 1. Save locally
      final docsDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(docsDir.path, 'AcademicAffairs', 'StudyPlans'));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final localPath = p.join(targetDir.path, file.name);
      
      if (file.path != null) {
        final localFile = File(file.path!);
        await localFile.copy(localPath);
      }

      // 2. Upload to Firebase
      String downloadUrl = '';
      if (await hasInternet()) {
        // 👈 الحصول على اسم القسم لاستخدامه في مسار التخزين
        final deptName = _departments.firstWhere(
          (d) => d['id'].toString() == deptId, 
          orElse: () => {'name': 'Unknown'}
        )['name'];

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('study_plans/$deptName/${const Uuid().v4()}_${file.name}');
            
        UploadTask uploadTask;
        if (file.bytes != null) {
          uploadTask = storageRef.putData(file.bytes!);
        } else if (file.path != null) {
          uploadTask = storageRef.putFile(File(file.path!));
        } else {
          throw Exception("No file data found.");
        }
        
        final snapshot = await uploadTask;
        downloadUrl = await snapshot.ref.getDownloadURL();
      } else {
        throw Exception("لا يوجد اتصال بالإنترنت للرفع على فايربيس");
      }

      // 3. Save to Firestore
      final id = const Uuid().v4();
      final date = DateTime.now().toIso8601String();
      final record = {
        'id': id,
        'dept_id': deptId,
        'url': downloadUrl,
        'date': date,
        'local_path': localPath,
      };
      
      await _firestore.collection('study_plans_storage').doc(id).set(record);

      // 4. Save to SQLite
      final db = await DatabaseHelper.instance.database;
      await db.insert('study_plans_storage', record, conflictAlgorithm: ConflictAlgorithm.replace);

    } catch (e) {
      debugPrint('خطأ في إدراج ملف الخطة الدراسية: $e');
      rethrow;
    }
  }
  @override
  void dispose() {
    _disposed = true; // 👈 تحديث الحالة عند الإغلاق
    super.dispose();
  }
}
