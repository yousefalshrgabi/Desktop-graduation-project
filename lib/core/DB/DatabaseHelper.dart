import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart'; // ضروري لاستخدام debugPrint

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    debugPrint(
        '[SQLITE DEBUG] 🟡 لم يتم العثور على قاعدة بيانات نشطة، جاري التهيئة...');
    _database = await _initDB('academic_affairss.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    debugPrint('[SQLITE DEBUG] 🟢 1. تحديد مسار الحفظ في الهاتف...');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    debugPrint('[SQLITE DEBUG] 📍 المسار: $path');

    debugPrint('[SQLITE DEBUG] 🟡 2. جاري فتح/إنشاء قاعدة البيانات...');
    return await openDatabase(path,
        version: 6, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    debugPrint(
        '[SQLITE DEBUG] 🛠️ جاري الترقية من $oldVersion إلى $newVersion');
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS programs (
          id TEXT PRIMARY KEY, 
          name_ar TEXT NOT NULL, 
          name_en TEXT NOT NULL,
          total_levels INTEGER NOT NULL, 
          status TEXT NOT NULL, 
          tracks TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول programs خلال الترقية');
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS studyPlans (
          id TEXT PRIMARY KEY,
          program_id TEXT NOT NULL,
          track_id TEXT,
          ar_level TEXT NOT NULL,
          en_level TEXT NOT NULL,
          ar_semester TEXT NOT NULL,
          en_semester TEXT NOT NULL,
          semester_totals TEXT NOT NULL,
          courses TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول studyPlans خلال الترقية');
    }

    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS studyPlans (
          id TEXT PRIMARY KEY,
          program_id TEXT NOT NULL,
          track_id TEXT,
          ar_level TEXT NOT NULL,
          en_level TEXT NOT NULL,
          ar_semester TEXT NOT NULL,
          en_semester TEXT NOT NULL,
          semester_totals TEXT NOT NULL,
          courses TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول studyPlans (v6) خلال الترقية');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    debugPrint(
        '[SQLITE DEBUG] 🛠️ 3. جاري إنشاء الجداول (الإصدار $version)...');
    try {
      await db.execute('''
        CREATE TABLE colleges (
          id TEXT PRIMARY KEY, ar_name TEXT NOT NULL, en_name TEXT NOT NULL,
          code TEXT NOT NULL, dean_id TEXT NOT NULL, created_at TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول colleges');

      await db.execute('''
        CREATE TABLE departments (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, college_id TEXT NOT NULL,
          hod_id TEXT NOT NULL, created_at TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول departments');

      await db.execute('''
        CREATE TABLE faculty_members (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL,
          department TEXT NOT NULL, academic_degree TEXT NOT NULL,
          status TEXT NOT NULL, created_at TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول faculty_members');

      await db.execute('''
        CREATE TABLE users (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL,
          phone TEXT NOT NULL, role TEXT NOT NULL, created_at TEXT NOT NULL,
          faculty TEXT, department TEXT, level TEXT, status TEXT
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول users');

      await db.execute('''
        CREATE TABLE study_plans (
          id TEXT PRIMARY KEY, contact_hours_lab INTEGER NOT NULL,
          contact_hours_th INTEGER NOT NULL, course_type TEXT NOT NULL,
          credit_hours INTEGER NOT NULL, dept_id TEXT NOT NULL,
          level INTEGER NOT NULL, semester INTEGER NOT NULL,
          state TEXT NOT NULL, subject_id TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول study_plans');

      await db.execute('''
        CREATE TABLE subjects (
          id TEXT PRIMARY KEY, ar_name TEXT NOT NULL, en_name TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول subjects');

      await db.execute('''
        CREATE TABLE programs (
          id TEXT PRIMARY KEY, 
          name_ar TEXT NOT NULL, 
          name_en TEXT NOT NULL,
          total_levels INTEGER NOT NULL, 
          status TEXT NOT NULL, 
          tracks TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول programs');

      await db.execute('''
        CREATE TABLE deleted_records (
          id TEXT PRIMARY KEY,
          table_name TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول deleted_records');

      await db.execute('''
        CREATE TABLE studyPlans (
          id TEXT PRIMARY KEY,
          program_id TEXT NOT NULL,
          track_id TEXT,
          ar_level TEXT NOT NULL,
          en_level TEXT NOT NULL,
          ar_semester TEXT NOT NULL,
          en_semester TEXT NOT NULL,
          semester_totals TEXT NOT NULL,
          courses TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول studyPlans');

      debugPrint('[SQLITE DEBUG] 🎉 اكتمل بناء قاعدة البيانات المحلية بنجاح!');
    } catch (e) {
      debugPrint('[SQLITE DEBUG] ❌ خطأ فادح أثناء إنشاء الجداول: $e');
    }
  }

  // =================================================================
  // مثال: دوال المراقبة والإدخال لجدول الـ Users
  // =================================================================

  // دالة إدخال مستخدم (مع المراقبة)
  Future<void> insertUserLocal(Map<String, dynamic> userMap) async {
    debugPrint(
        '[SQLITE DEBUG] 🟡 محاولة حفظ المستخدم (${userMap['email']}) محلياً...');
    try {
      final db = await instance.database;

      // نستخدم ConflictAlgorithm.replace لكي يقوم بتحديث البيانات إذا كان الـ ID موجود مسبقاً
      int result = await db.insert(
        'users',
        userMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('[SQLITE DEBUG] ✅ تم حفظ المستخدم بنجاح! رقم الصف: $result');
    } catch (e) {
      debugPrint('[SQLITE DEBUG] ❌ فشل حفظ المستخدم: $e');
    }
  }

  // دالة جلب المستخدمين (مع المراقبة)
  Future<List<Map<String, dynamic>>> getLocalUsers() async {
    debugPrint('[SQLITE DEBUG] 🟡 جاري جلب قائمة المستخدمين من SQLite...');
    try {
      final db = await instance.database;
      final result = await db.query('users');

      debugPrint(
          '[SQLITE DEBUG] ✅ تم جلب البيانات. عدد المستخدمين: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('[SQLITE DEBUG] ❌ فشل جلب المستخدمين: $e');
      return [];
    }
  }

  // =================================================================

  Future<void> clearAllData() async {
    debugPrint(
        '[SQLITE DEBUG] 🧹 جاري مسح جميع البيانات من الجداول (Logout)...');
    try {
      final db = await instance.database;
      await db.delete('colleges');
      await db.delete('departments');
      await db.delete('faculty_members');
      await db.delete('users');
      await db.delete('subjects');
      await db.delete('programs');
      await db.delete('studyPlans');
      debugPrint('[SQLITE DEBUG] ✅ تم تنظيف قاعدة البيانات بنجاح.');
    } catch (e) {
      debugPrint('[SQLITE DEBUG] ❌ فشل عملية التنظيف: $e');
    }
  }

  Future<void> close() async {
    debugPrint('[SQLITE DEBUG] 🔒 جاري إغلاق قاعدة البيانات...');
    final db = await instance.database;
    db.close();
    debugPrint('[SQLITE DEBUG] ✅ تم الإغلاق.');
  }
}
