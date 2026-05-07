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
    return await openDatabase(
      path,
      version: 1,
      // 👈 تفعيل القيود المرجعية (Foreign Keys) لضمان صحة الربط بين الجداول
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    debugPrint(
        '[SQLITE DEBUG] 🛠️ 3. جاري إنشاء الجداول (الإصدار $version)...');
    try {
      // 1. جدول المستخدمين (حسابات الدخول)
      await db.execute('''
        CREATE TABLE users (
          id TEXT PRIMARY KEY, 
          name TEXT NOT NULL, 
          email TEXT NOT NULL,
          phone TEXT NOT NULL, 
          role TEXT NOT NULL, 
          created_at TEXT NOT NULL,
          faculty TEXT, 
          department TEXT, 
          status TEXT
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول users');

      // 2. جدول الكليات
      await db.execute('''
        CREATE TABLE colleges (
          id TEXT PRIMARY KEY, ar_name TEXT NOT NULL, en_name TEXT NOT NULL,
          code TEXT NOT NULL, dean_id TEXT NOT NULL, created_at TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول colleges');

      // 3. جدول الأقسام
      await db.execute('''
        CREATE TABLE departments (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, college_id TEXT NOT NULL,
          hod_id TEXT NOT NULL, created_at TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول departments');

// 4. جدول أعضاء هيئة التدريس (النسخة الشاملة والمحدثة)
      await db.execute('''
        CREATE TABLE faculty_members (
          id TEXT PRIMARY KEY, 
          user_id TEXT,
          name TEXT NOT NULL, 
          status TEXT,      -- 👈 تمت إضافة عمود الحالة
          
          -- 📁 حقول الملفات
          file_number TEXT,        -- 👈 تمت إضافته هنا (مهم جداً للإكسل)
          file_url TEXT,
          local_file_path TEXT,
          
          -- 👤 البيانات الأساسية والشخصية
          id_card_number TEXT,
          job_number TEXT,
          birth_place TEXT,
          birth_date TEXT,
          first_appointment_date TEXT,
          university_appointment_date TEXT,
          
          -- 🎓 بيانات البكالوريوس
          bsc_degree TEXT,
          bsc_date TEXT,
          bsc_university TEXT,
          bsc_country TEXT,
          bsc_academic_title TEXT,
          bsc_title_transfer_date TEXT,
          bsc_specialization TEXT,
          
          -- 🎓 بيانات الماجستير
          msc_degree TEXT,
          msc_date TEXT,
          msc_university TEXT,
          msc_country TEXT,
          msc_academic_title TEXT,
          msc_title_transfer_date TEXT,
          msc_decision_number TEXT,
          msc_exact_specialization TEXT,
          
          -- 🎓 البيانات الحالية (الدكتوراه)
          current_degree TEXT,
          current_degree_date TEXT,
          current_university TEXT,
          current_country TEXT,
          
          -- 📈 الترقيات
          assistant_prof_date TEXT,
          assistant_prof_decision TEXT,
          assoc_prof_date TEXT,
          assoc_prof_decision TEXT,
          
          -- 🏫 الوضع الأكاديمي الحالي بالجامعة
          current_academic_title TEXT,
          title_transfer_date TEXT,
          department TEXT,
          general_specialization TEXT,
          exact_specialization TEXT,
          
          -- ✈️ الإجازات والتفرغ (تُخزن بصيغة JSON)
          sabbatical_leaves TEXT,
          unpaid_leaves TEXT,

          created_at TEXT NOT NULL,
          
          -- 🔗 الربط المرجعي بجدول المستخدمين
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول faculty_members المحدث');

      // 5. جدول الخطط الدراسية
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

      // 6. جدول المواد
      await db.execute('''
        CREATE TABLE subjects (
          id TEXT PRIMARY KEY, ar_name TEXT NOT NULL, en_name TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول subjects');

      // 7. جدول سلة المهملات
      await db.execute('''
        CREATE TABLE deleted_records (
          id TEXT PRIMARY KEY,
          table_name TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول deleted_records');

      debugPrint('[SQLITE DEBUG] 🎉 اكتمل بناء قاعدة البيانات المحلية بنجاح!');
    } catch (e) {
      debugPrint('[SQLITE DEBUG] ❌ خطأ فادح أثناء إنشاء الجداول: $e');
    }
  }

  // =================================================================
  // دوال الإدخال والمسح (كما هي في كودك السابق)
  // =================================================================

  Future<void> insertUserLocal(Map<String, dynamic> userMap) async {
    debugPrint(
        '[SQLITE DEBUG] 🟡 محاولة حفظ المستخدم (${userMap['email']}) محلياً...');
    try {
      final db = await instance.database;
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

  Future<void> clearAllData() async {
    debugPrint(
        '[SQLITE DEBUG] 🧹 جاري مسح جميع البيانات من الجداول (Logout)...');
    try {
      final db = await instance.database;
      await db.delete('colleges');
      await db.delete('departments');
      await db.delete('faculty_members');
      await db.delete('users');
      await db.delete('study_plans');
      await db.delete('subjects');
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
