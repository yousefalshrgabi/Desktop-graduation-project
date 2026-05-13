import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'programs_model.dart';
import 'package:sqflite/sqflite.dart';

class ProgramsViewModel extends ChangeNotifier {
  List<ProgramModel> _programs = [];
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;

  List<ProgramModel> get programs => _programs;
  List<ProgramModel> get filteredPrograms {
    if (_searchQuery.isEmpty) return _programs;
    return _programs.where((p) {
      return p.nameAr.contains(_searchQuery) || 
             p.nameEn.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ProgramsViewModel() {
    loadPrograms();
  }

  // تحديث نص البحث المتزامن
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // تحميل البيانات من الداتا بيس المحلية (SQLite)
  Future<void> loadPrograms() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('programs');
      _programs = result.map((map) => ProgramModel.fromSQLite(map)).toList();

      // مزامنة العناصر غير المرفوعة في الخلفية
      _syncPendingPrograms();
    } catch (e) {
      _errorMessage = "خطأ في تحميل البرامج: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // إضافة برنامج جديد
  Future<void> addProgram(ProgramModel program) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // التأكد من أن البرنامج غير متزامن كبداية
      program.isSynced = false;

      // 1. الحفظ محلياً
      await db.insert(
        'programs',
        program.toSQLiteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. تحديث الواجهة مباشرة (Offline-first)
      _programs.add(program);
      notifyListeners();

      // 3. المحاولة لرفعها للفايربيس
      await _syncSingleProgram(program);
    } catch (e) {
      debugPrint("خطأ في إضافة البرنامج محلياً: \$e");
    }
  }

  // تعديل برنامج موجود
  Future<void> updateProgram(ProgramModel program) async {
    try {
      final db = await DatabaseHelper.instance.database;
      program.isSynced = false;

      await db.update(
        'programs',
        program.toSQLiteMap(),
        where: 'id = ?',
        whereArgs: [program.id],
      );

      final index = _programs.indexWhere((p) => p.id == program.id);
      if (index != -1) {
        _programs[index] = program;
        notifyListeners();
      }

      await _syncSingleProgram(program);
    } catch (e) {
      debugPrint("خطأ في تحديث البرنامج محلياً: \$e");
    }
  }

  // حذف برنامج
  Future<void> deleteProgram(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. الحذف محلياً
      await db.delete('programs', where: 'id = ?', whereArgs: [id]);

      // حذف من الواجهة مباشرة
      _programs.removeWhere((p) => p.id == id);
      notifyListeners();

      // 2. الحذف من الفايربيس أو إضافته لجدول الحذفيات
      try {
        await _firestore.collection('programs').doc(id).delete();
      } catch (e) {
        // في حال عدم وجود إنترنت، يتم إضافة السجل لجدول deleted_records كما هو معمول به في النظام
        await db.insert('deleted_records', {
          'id': id,
          'table_name': 'programs'
        });
      }
    } catch (e) {
      debugPrint("خطأ في حذف البرنامج: \$e");
    }
  }

  // دالة مساعدة لرفع برنامج واحد لفايربيس
  Future<void> _syncSingleProgram(ProgramModel program) async {
    try {
      await _firestore.collection('programs').doc(program.id).set(program.toFirestoreMap());

      // إذا نجح الرفع، قم بتحديث الحالة محلياً إلى متزامن
      final db = await DatabaseHelper.instance.database;
      await db.update('programs', {'is_synced': 1}, where: 'id = ?', whereArgs: [program.id]);

      // تحديث الحالة في الواجهة
      int index = _programs.indexWhere((p) => p.id == program.id);
      if (index != -1) {
        _programs[index].isSynced = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("لم يتم رفع البرنامج للفايربيس الآن، سيتم الرفع لاحقاً: \$e");
      // سيبقى isSynced = false
    }
  }

  // دالة المزامنة التلقائية للبيانات غير المرفوعة
  Future<void> _syncPendingPrograms() async {
    final pendingPrograms = _programs.where((p) => !p.isSynced).toList();
    for (var program in pendingPrograms) {
      await _syncSingleProgram(program);
    }
  }

  // توليد ID للفايربيس
  String generateId() {
    return _firestore.collection('programs').doc().id;
  }
}
