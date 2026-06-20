import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart'; // ضروري لاستخدام debugPrint

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database>? _initDatabaseFuture;

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (_initDatabaseFuture == null) {
      debugPrint(
          '[SQLITE DEBUG] 🟡 لم يتم العثور على قاعدة بيانات نشطة، جاري التهيئة...');
      _initDatabaseFuture = _initDB('academic_affairss.db');
    }

    _database = await _initDatabaseFuture!;
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
      version: 16,
      // 👈 تفعيل القيود المرجعية (Foreign Keys) لضمان صحة الربط بين الجداول
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
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

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS study_plans_storage (
          id TEXT PRIMARY KEY,
          dept_id TEXT NOT NULL,
          url TEXT NOT NULL,
          date TEXT NOT NULL,
          local_path TEXT NOT NULL
        )
      ''');
      debugPrint(
          '[SQLITE DEBUG] ✅ تم إنشاء جدول study_plans_storage (v7) خلال الترقية');
    }

    if (oldVersion < 8) {
      await db.execute(
          'ALTER TABLE colleges ADD COLUMN academic_vice_dean_id TEXT');
      await db
          .execute('ALTER TABLE colleges ADD COLUMN student_vice_dean_id TEXT');
      debugPrint('[SQLITE DEBUG] ✅ تم إضافة أعمدة نواب العميد لجدول colleges');
    }

    if (oldVersion < 10) {
      // 👈 التأكد من وجود كافة الأعمدة المطلوبة في جدول الطلبات (للمستخدمين القدامى)
      try {
        await db.execute('ALTER TABLE requests ADD COLUMN localFilePath TEXT');
      } catch (e) {
        debugPrint('Column localFilePath already exists');
      }
      try {
        await db.execute('ALTER TABLE requests ADD COLUMN senderId TEXT');
      } catch (e) {
        debugPrint('Column senderId already exists');
      }
      debugPrint('[SQLITE DEBUG] ✅ تم التأكد من تحديث أعمدة جدول requests');
    }

    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE requests ADD COLUMN extraData TEXT');
      } catch (e) {
        debugPrint('Column extraData already exists');
      }
      debugPrint('[SQLITE DEBUG] ✅ تم إضافة عمود extraData لجدول requests');
    }

    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN idCardNumber TEXT');
      } catch (e) {
        debugPrint('Column idCardNumber already exists');
      }
      try {
        await db.execute('ALTER TABLE users ADD COLUMN phone TEXT');
      } catch (e) {
        debugPrint('Column phone already exists');
      }
      debugPrint('[SQLITE DEBUG] ✅ تم إضافة أعمدة جديدة لجدول users');
    }

    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS course_assignments (
          id TEXT PRIMARY KEY,
          plan_id TEXT NOT NULL,
          course_id TEXT NOT NULL,
          course_name_ar TEXT NOT NULL,
          course_name_en TEXT NOT NULL,
          faculty_member_id TEXT NOT NULL,
          faculty_member_name TEXT NOT NULL,
          theoretical_groups INTEGER NOT NULL DEFAULT 1,
          practical_groups INTEGER NOT NULL DEFAULT 0,
          is_synced INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      debugPrint(
          '[SQLITE DEBUG] ✅ تم إنشاء جدول course_assignments (v13) خلال الترقية');
    }

    if (oldVersion < 14) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS timetables (
          id TEXT PRIMARY KEY,
          day TEXT NOT NULL,
          hour TEXT NOT NULL,
          subject TEXT NOT NULL,
          teachers TEXT NOT NULL,
          studentSets TEXT NOT NULL,
          room TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      debugPrint(
          '[SQLITE DEBUG] ✅ تم إنشاء جدول timetables (v14) خلال الترقية');
    }

    if (oldVersion < 16) {
      // إضافة عمود updated_at للجداول الرئيسية (للمزامنة التفاضلية)
      final tables = ['users', 'colleges', 'departments', 'faculty_members'];
      for (final table in tables) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN updated_at TEXT');
          // تعيين قيمة افتراضية قديمة جداً لضمان رفع كل السجلات في أول مزامنة
          await db.execute("UPDATE $table SET updated_at = '1970-01-01T00:00:00.000'");
        } catch (e) {
          debugPrint('[SQLITE v15] ⚠️ العمود updated_at موجود بالفعل في $table: $e');
        }
      }

      // إنشاء الـ Triggers للتحديث التلقائي لـ updated_at
      await _createUpdateTimestampTriggers(db);
      debugPrint('[SQLITE DEBUG] ✅ تم إضافة updated_at والـ Triggers (v15)');
    }

    if (oldVersion < 16) {
      try {
        await db.execute('ALTER TABLE faculty_members ADD COLUMN updated_at TEXT');
        await db.execute("UPDATE faculty_members SET updated_at = '1970-01-01T00:00:00.000'");
      } catch (e) {
        debugPrint('[SQLITE v16] ⚠️ العمود updated_at موجود بالفعل في faculty_members: $e');
      }
      debugPrint('[SQLITE DEBUG] ✅ تم ترقية قاعدة البيانات للإصدار 16 وإضافة updated_at لجدول faculty_members');
    }
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
          status TEXT,
          idCardNumber TEXT,
          updated_at TEXT
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول users');

      // 2. جدول الكليات
      await db.execute('''
        CREATE TABLE colleges (
          id TEXT PRIMARY KEY, ar_name TEXT NOT NULL, en_name TEXT NOT NULL,
          code TEXT NOT NULL, dean_id TEXT NOT NULL, 
          academic_vice_dean_id TEXT, student_vice_dean_id TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول colleges');

      // 3. جدول الأقسام
      await db.execute('''
        CREATE TABLE departments (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, college_id TEXT NOT NULL,
          hod_id TEXT NOT NULL, created_at TEXT NOT NULL,
          updated_at TEXT
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
          updated_at TEXT,
          
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

      // 8. جدول الطلبات (لأرشفة الطلبات والوصول إليها بدون إنترنت)
      await db.execute('''
        CREATE TABLE requests (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          applicantName TEXT NOT NULL,
          senderCollege TEXT NOT NULL,
          destinationCollege TEXT NOT NULL,
          type TEXT NOT NULL,
          description TEXT NOT NULL,
          dateSent TEXT NOT NULL,
          dateReplied TEXT,
          status TEXT NOT NULL,
          rejectionReason TEXT,
          fileUrl TEXT,
          localFilePath TEXT,
          senderId TEXT,
          extraData TEXT
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول requests');

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

      await db.execute('''
        CREATE TABLE study_plans_storage (
          id TEXT PRIMARY KEY,
          dept_id TEXT NOT NULL,
          url TEXT NOT NULL,
          date TEXT NOT NULL,
          local_path TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول study_plans_storage');

      // 10. جدول ربط المقررات (الأنصبة)
      await db.execute('''
        CREATE TABLE course_assignments (
          id TEXT PRIMARY KEY,
          plan_id TEXT NOT NULL,
          course_id TEXT NOT NULL,
          course_name_ar TEXT NOT NULL,
          course_name_en TEXT NOT NULL,
          faculty_member_id TEXT NOT NULL,
          faculty_member_name TEXT NOT NULL,
          theoretical_groups INTEGER NOT NULL DEFAULT 1,
          practical_groups INTEGER NOT NULL DEFAULT 0,
          is_synced INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول course_assignments');

      // 11. جدول الجداول الدراسية (Timetables)
      await db.execute('''
        CREATE TABLE timetables (
          id TEXT PRIMARY KEY,
          day TEXT NOT NULL,
          hour TEXT NOT NULL,
          subject TEXT NOT NULL,
          teachers TEXT NOT NULL,
          studentSets TEXT NOT NULL,
          room TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جدول timetables');

      // إنشاء الـ Triggers للتحديث التلقائي لـ updated_at
      await _createUpdateTimestampTriggers(db);

      debugPrint('[SQLITE DEBUG] 🎉 اكتمل بناء قاعدة البيانات المحلية بنجاح!');
    } catch (e) {
      debugPrint('[SQLITE DEBUG] ❌ خطأ فادح أثناء إنشاء الجداول: $e');
    }
  }

  /// ينشئ Triggers في SQLite تضبط updated_at تلقائياً عند أي INSERT أو UPDATE
  Future<void> _createUpdateTimestampTriggers(Database db) async {
    final tables = ['users', 'colleges', 'departments', 'faculty_members'];
    for (final table in tables) {
      // Trigger عند الإدخال
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS ${table}_set_updated_at_insert
        AFTER INSERT ON $table
        FOR EACH ROW
        BEGIN
          UPDATE $table SET updated_at = STRFTIME('%Y-%m-%dT%H:%M:%f', 'NOW') WHERE id = NEW.id;
        END;
      ''');
      // Trigger عند التعديل (أي عمود)
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS ${table}_set_updated_at_update
        AFTER UPDATE ON $table
        FOR EACH ROW
        BEGIN
          UPDATE $table SET updated_at = STRFTIME('%Y-%m-%dT%H:%M:%f', 'NOW') WHERE id = NEW.id;
        END;
      ''');
    }
    debugPrint('[SQLITE DEBUG] ✅ تم إنشاء جميع الـ Triggers للتحديث التلقائي.');
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
      await db.delete('requests');
      debugPrint('[SQLITE DEBUG] ✅ تم تنظيف قاعدة البيانات بنجاح.');
    } catch (e) {
      debugPrint('[SQLITE DEBUG] ❌ فشل عملية التنظيف: $e');
    }
  }

  // =================================================================
  // دوال التحديث المحلي (Offline-First Updates)
  // =================================================================
  Future<void> updateRecordLocal(
      String table, String id, Map<String, dynamic> data,
      {String whereColumn = 'id'}) async {
    try {
      final db = await instance.database;

      // التحديث المحلي
      int rowsAffected = await db.update(
        table,
        data,
        where: '$whereColumn = ?',
        whereArgs: [id],
      );

      if (rowsAffected > 0) {
        debugPrint(
            '[SQLITE DEBUG] ✅ تم تحديث السجل $id محلياً في جدول $table (الصفوف: $rowsAffected)');
      } else {
        debugPrint(
            '[SQLITE DEBUG] ⚠️ لم يتم العثور على السجل $id في جدول $table لتحديثه!');
      }
    } catch (e) {
      debugPrint('[SQLITE DEBUG] ❌ فشل تحديث السجل محلياً في جدول $table: $e');
    }
  }

  // =================================================================
  // دوال الطلبات (Requests)
  // =================================================================

  Future<void> insertRequestLocal(Map<String, dynamic> requestMap) async {
    try {
      final db = await instance.database;
      await db.insert(
        'requests',
        requestMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // تم إزالة جملة الطباعة هنا لمنع التكرار المزعج في السجلات
    } catch (e) {
      debugPrint('[SQLITE DEBUG] ❌ فشل حفظ الطلب محلياً: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLocalRequests() async {
    try {
      final db = await instance.database;
      return await db.query('requests', orderBy: 'dateSent DESC');
    } catch (e) {
      debugPrint('[SQLITE DEBUG] ❌ فشل جلب الطلبات محلياً: $e');
      return [];
    }
  }

  Future<void> updateRequestLocalPath(
      String requestId, String localPath) async {
    try {
      final db = await instance.database;
      await db.update(
        'requests',
        {'localFilePath': localPath},
        where: 'id = ?',
        whereArgs: [requestId],
      );
    } catch (e) {
      debugPrint('[SQLITE DEBUG] ❌ فشل تحديث مسار الملف المحلي: $e');
    }
  }

  Future<void> close() async {
    debugPrint('[SQLITE DEBUG] 🔒 جاري إغلاق قاعدة البيانات...');
    final db = await instance.database;
    db.close();
    debugPrint('[SQLITE DEBUG] ✅ تم الإغلاق.');
  }
}
