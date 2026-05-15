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
  List<Map<String, dynamic>> _excelPlans = []; // 👈 قائمة ملفات الإكسل المرفوعة
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _departments = [];
  bool _disposed = false;

  List<StudyPlanModel> get plans => _plans;
  
  // 👈 جلب ملفات الإكسل مع التأكد من وجود الملفات المحلية وترتيبها (المحلي أولاً)
  List<Map<String, dynamic>> get excelPlans {
    final List<Map<String, dynamic>> sorted = List.from(_excelPlans);
    sorted.sort((a, b) {
      final aLocal = a['local_path'] != null && File(a['local_path']).existsSync();
      final bLocal = b['local_path'] != null && File(b['local_path']).existsSync();
      if (aLocal && !bLocal) return -1;
      if (!aLocal && bLocal) return 1;
      return 0;
    });
    return sorted;
  }

  bool get disposed => _disposed;
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
      _plans = plansResult.map((e) => StudyPlanModel.fromSQLiteMap(e)).toList();

      // تحميل الأقسام
      final depsResult = await db.query('departments');
      _departments = depsResult;

      // تحميل ملفات الإكسل المخزنة
      final excelResult = await db.query('study_plans_storage', orderBy: 'date DESC');
      _excelPlans = List<Map<String, dynamic>>.from(excelResult);

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
      debugPrint('🚀 بدء عملية الرفع: ${file.name}');

      // 1. التخزين المحلي
      final docsDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(docsDir.path, 'AcademicAffairs', 'StudyPlans'));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      
      // تنظيف اسم الملف للاستخدام في المسارات
      final sanitizedName = file.name.replaceAll(RegExp(r'[#\[\]*?%:]'), '_');
      final localPath = p.join(targetDir.path, sanitizedName);
      
      if (file.path != null) {
        await File(file.path!).copy(localPath);
        debugPrint('✅ تم الحفظ محلياً في: $localPath');
      }

      // 2. الرفع إلى Firebase
      String downloadUrl = '';
      if (await hasInternet()) {
        final deptName = _departments.firstWhere(
            (d) => d['id'].toString() == deptId,
            orElse: () => {'name': 'Unknown'})['name'];

        // استخدام "/" دائماً لمسارات Firebase Storage بغض النظر عن نظام التشغيل
        final storagePath = 'study_plans/${deptName.toString().replaceAll(' ', '_')}/${const Uuid().v4()}_$sanitizedName';
        final storageRef = FirebaseStorage.instance.ref().child(storagePath);
            
        debugPrint('☁️ جاري الرفع إلى المسار: $storagePath');

        UploadTask uploadTask;
        if (file.bytes != null) {
          uploadTask = storageRef.putData(file.bytes!);
        } else if (file.path != null) {
          uploadTask = storageRef.putFile(File(file.path!));
        } else {
          throw Exception("لا توجد بيانات للملف (file.path and file.bytes are null)");
        }
        
        final snapshot = await uploadTask;
        downloadUrl = await snapshot.ref.getDownloadURL();
        debugPrint('✅ تم الرفع بنجاح، الرابط: $downloadUrl');
      } else {
        throw Exception("لا يوجد اتصال بالإنترنت للرفع على فايربيس");
      }

      // 3. الحفظ في Firestore
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
      debugPrint('✅ تم الحفظ في Firestore');

      // 4. الحفظ في SQLite
      final db = await DatabaseHelper.instance.database;
      await db.insert('study_plans_storage', record,
          conflictAlgorithm: ConflictAlgorithm.replace);
      
      _excelPlans.insert(0, record);
      if (!disposed) notifyListeners();
      debugPrint('✨ اكتملت العملية بنجاح');

    } catch (e, stackTrace) {
      debugPrint('❌ خطأ في إدراج ملف الخطة الدراسية: $e');
      debugPrint('Stacktrace: $stackTrace');
      rethrow;
    }
  }

  // 👈 دالة مساعدة لتنظيف اسم الملف من روابط Firebase Storage
  String getCleanFileName(String url) {
    try {
      // 1. فك تشفير الرابط (لتحويل %2F إلى / وغيرها)
      String decodedPath = Uri.decodeFull(Uri.parse(url).path);
      // 2. الحصول على الجزء الأخير (اسم الملف الفعلي)
      String fileName = p.basename(decodedPath);
      // 3. إزالة الـ UUID (كل ما قبل أول شرطة سفلية)
      if (fileName.contains('_')) {
        return fileName.substring(fileName.indexOf('_') + 1);
      }
      return fileName;
    } catch (e) {
      return 'study_plan.xlsx';
    }
  }

  // ── Download Excel ────────────────────────────────────────────────────────
  Future<void> downloadExcelFile(Map<String, dynamic> excelRecord) async {
    try {
      final String? url = excelRecord['url'];
      if (url == null || url.isEmpty) throw Exception('رابط الملف غير موجود');

      // 1. اختيار مسار الحفظ من قبل المستخدم باستخدام الدالة الجديدة
      String fileName = getCleanFileName(url);
      final String? localPath = excelRecord['local_path'];

      // 2. التحقق مما إذا كان الملف موجوداً محلياً بالفعل للاقتصاد في Firebase
      bool existsLocally = localPath != null && File(localPath).existsSync();

      final String? selectedPath = await FilePicker.saveFile(
        dialogTitle: existsLocally ? 'حفظ نسخة من الملف المحلي' : 'تحميل الخطة من السحابة',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (selectedPath == null) return; // المستخدم ألغى العملية

      _isLoading = true;
      if (!disposed) notifyListeners();

      if (existsLocally) {
        // 🚀 توفير في Firebase: نسخ الملف من الجهاز مباشرة
        await File(localPath!).copy(selectedPath);
        debugPrint('✅ تم نسخ الملف محلياً (توفير في Firebase): $selectedPath');
      } else {
        // ☁️ التحميل من Firebase Storage فقط عند الضرورة
        final File file = File(selectedPath);
        await FirebaseStorage.instance.refFromURL(url).writeToFile(file);
        debugPrint('☁️ تم التحميل من السحاب: $selectedPath');
      }

      _isLoading = false;
      if (!disposed) notifyListeners();
    } catch (e) {
      debugPrint('❌ خطأ أثناء تحميل ملف الإكسل: $e');
      _isLoading = false;
      if (!disposed) notifyListeners();
      rethrow;
    }
  }

  // ── Delete Excel Plan ─────────────────────────────────────────────────────
  Future<void> deleteExcelPlan(Map<String, dynamic> excelRecord) async {
    try {
      final String id = excelRecord['id'];
      final String? url = excelRecord['url'];
      final String? localPath = excelRecord['local_path'];

      // 1. الحذف من Firebase Storage
      if (url != null && url.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (e) {
          debugPrint('تحذير: تعذر حذف الملف من Storage (ربما غير موجود): $e');
        }
      }

      // 2. الحذف من Firestore
      await _firestore.collection('study_plans_storage').doc(id).delete();

      // 3. الحذف من SQLite
      final db = await DatabaseHelper.instance.database;
      await db.delete('study_plans_storage', where: 'id = ?', whereArgs: [id]);

      // 4. الحذف من الجهاز محلياً
      if (localPath != null && File(localPath).existsSync()) {
        try {
          await File(localPath).delete();
        } catch (e) {
          debugPrint('تحذير: تعذر حذف الملف من الجهاز: $e');
        }
      }

      // 5. تحديث القائمة المحلية
      _excelPlans.removeWhere((e) => e['id'] == id);
      if (!disposed) notifyListeners();

      debugPrint('✅ تم حذف الملف والبيانات بنجاح');
    } catch (e) {
      debugPrint('❌ خطأ في حذف ملف الإكسل: $e');
      rethrow;
    }
  }

  // ── Fetch from Cloud (Sync) ────────────────────────────────────────────────
  Future<void> fetchExcelPlansFromCloud() async {
    try {
      _isLoading = true;
      if (!disposed) notifyListeners();

      if (!await hasInternet()) {
        throw Exception("لا يوجد اتصال بالإنترنت للمزامنة");
      }

      final snapshot = await _firestore.collection('study_plans_storage').get();
      final db = await DatabaseHelper.instance.database;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // الحفاظ على المسار المحلي إذا كان السجل موجوداً مسبقاً
        final existing = await db.query('study_plans_storage', where: 'id = ?', whereArgs: [data['id']]);
        if (existing.isNotEmpty) {
          data['local_path'] = existing.first['local_path'];
        }

        await db.insert('study_plans_storage', data, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // إعادة تحميل القائمة المحلية
      final excelResult = await db.query('study_plans_storage', orderBy: 'date DESC');
      _excelPlans = List<Map<String, dynamic>>.from(excelResult);

      _isLoading = false;
      if (!disposed) notifyListeners();
      
      debugPrint('✅ اكتملت مزامنة ملفات الإكسل من السحاب');
    } catch (e) {
      _isLoading = false;
      if (!disposed) notifyListeners();
      debugPrint('❌ خطأ في مزامنة السحاب: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true; // 👈 تحديث الحالة عند الإغلاق
    super.dispose();
  }
}
