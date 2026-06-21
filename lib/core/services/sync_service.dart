import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/features/desktop_pages/faculty_members_screen/faculty_member_model.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =======================================================================
  // المزامنة الذكية: تدمج بين الرفع والتنزيل لضمان عدم ضياع أي عمل محلي
  // =======================================================================
  Future<void> performSmartSync() async {
    try {
      debugPrint('🔄 بدء عملية المزامنة الذكية...');

      // 1. مزامنة الحذفيات أولاً (لتنظيف السحابة من الملفات المحذوفة محلياً)
      await _syncDeletionsFirst();

      // 2. الرفع (Push) - نرفع البيانات المحلية الجديدة أو المعدلة للسحابة
      await _pushToFirebase();

      // 3. التنزيل (Pull) - نجلب البيانات الجديدة من السحابة لدمجها محلياً
      await pullFromFirebase();

      debugPrint('✅ اكتملت المزامنة الذكية بنجاح!');
    } catch (e) {
      debugPrint('❌ فشل في عملية المزامنة: $e');
      rethrow;
    }
  }

  // =======================================================================
  // 1. معالجة الحذفيات
  // =======================================================================
  Future<void> _syncDeletionsFirst() async {
    final db = await DatabaseHelper.instance.database;
    WriteBatch batch = _firestore.batch();
    final deletedItems = await db.query('deleted_records');

    if (deletedItems.isEmpty) return;

    for (var item in deletedItems) {
      final ref = _firestore
          .collection(item['table_name'].toString())
          .doc(item['id'].toString());
      batch.delete(ref);
    }

    await batch.commit().timeout(
          const Duration(seconds: 60),
          onTimeout: () =>
              throw TimeoutException('فشل الاتصال أثناء مزامنة الحذفيات.'),
        );

    // تنظيف سلة المهملات المحلية بعد تأكيد الحذف من السحابة
    await db.delete('deleted_records');
    debugPrint('🗑️ تم رفع الحذفيات للسحابة.');
  }

  // =======================================================================
  // 2. الرفع التفاضلي (Delta Push) — يرفع فقط ما تغيّر
  // =======================================================================
  Future<void> _pushToFirebase() async {
    final db = await DatabaseHelper.instance.database;
    final prefs = await SharedPreferences.getInstance();
    
    // قراءة وقت آخر مزامنة ناجحة (null = مجرد تشغيل = رفع كل شيء)
    final String? lastPushStr = prefs.getString('last_push_timestamp');
    final DateTime? lastPushTime = lastPushStr != null ? DateTime.tryParse(lastPushStr) : null;

    if (lastPushTime == null) {
      debugPrint('📤 [DELTA SYNC] أول مزامنة — سيتم رفع جميع البيانات...');
    } else {
      debugPrint('📤 [DELTA SYNC] آخر مزامنة: $lastPushStr — سيتم رفع السجلات المتغيّرة فقط.');
    }

    WriteBatch batch = _firestore.batch();
    int batchCount = 0;
    int batchIndex = 1;
    int totalUploaded = 0;

    Future<void> commitBatch() async {
      if (batchCount > 0) {
        debugPrint('⏳ [SYNC] جاري رفع الدفعة رقم $batchIndex (تحتوي على $batchCount عنصر)...');
        try {
          await batch.commit().timeout(
                const Duration(seconds: 120),
                onTimeout: () => throw TimeoutException('انتهى وقت الرفع للسحابة في الدفعة رقم $batchIndex.'),
              );
          debugPrint('✅ [SYNC] تمت بنجاح الدفعة رقم $batchIndex.');
        } catch (e) {
          debugPrint('❌ [SYNC] فشل رفع الدفعة رقم $batchIndex. الخطأ: $e');
          rethrow;
        }
        totalUploaded += batchCount;
        batch = _firestore.batch();
        batchCount = 0;
        batchIndex++;
      }
    }

    Future<void> addToBatch(DocumentReference ref, Map<String, dynamic> data) async {
      batch.set(ref, data, SetOptions(merge: true));
      batchCount++;
      if (batchCount >= 400) {
        await commitBatch();
      }
    }

    // دالة مساعدة لرفع السجلات المتغيّرة فقط (الديلتا)
    Future<void> uploadChangedRecords(String tableName, {bool isFaculty = false}) async {
      List<Map<String, dynamic>> records;

      if (lastPushTime == null) {
        // مزامنة كاملة للمرة الأولى
        records = await db.query(tableName);
      } else {
        // رفع السجلات التي updated_at أحدث من آخر مزامنة فقط
        records = await db.query(
          tableName,
          where: "updated_at > ?",
          whereArgs: [lastPushStr],
        );
      }

      if (records.isEmpty) {
        debugPrint('✅ [DELTA SYNC] لا تغييرات في جدول: $tableName');
        return;
      }

      debugPrint('📤 [DELTA SYNC] جدول $tableName: سيتم رفع ${records.length} سجل متغيّر.');

      for (var record in records) {
        final ref = _firestore.collection(tableName).doc(record['id'].toString());
        Map<String, dynamic> dataToUpload;

        if (isFaculty) {
          final faculty = FacultyMemberModel.fromMap(record);
          dataToUpload = faculty.toMap();
          dataToUpload['created_at'] = _toFirebaseTimestamp(faculty.createdAt);
        } else {
          dataToUpload = Map<String, dynamic>.from(record);
          // حذف updated_at من البيانات التي ترفع للسحابة (حقل محلي بحت)
          dataToUpload.remove('updated_at');
          if (dataToUpload.containsKey('created_at')) {
            dataToUpload['created_at'] = _toFirebaseTimestamp(dataToUpload['created_at']);
          }
        }

        if (tableName == 'users') {
          dataToUpload['level'] = FieldValue.delete();
        }

        await addToBatch(ref, dataToUpload);
      }
    }

    await uploadChangedRecords('users');
    await uploadChangedRecords('colleges');
    await uploadChangedRecords('departments');
    await uploadChangedRecords('faculty_members', isFaculty: true);
    await uploadChangedRecords('graduation_projects');

    // -- رفع البرامج غير المتزامنة (is_synced = 0) — كما هو --
    final programs = await db.query('programs', where: 'is_synced = ?', whereArgs: [0]);
    for (var p in programs) {
      final ref = _firestore.collection('programs').doc(p['id'].toString());
      List<dynamic> tracksList = [];
      try {
        tracksList = jsonDecode(p['tracks'].toString());
      } catch (e) {
        debugPrint('[SYNC] تحذير: فشل تحليل tracks للبرنامج ${p['id']}: $e');
      }
      await addToBatch(ref, {
        'name_ar': p['name_ar'],
        'name_en': p['name_en'],
        'total_levels': p['total_levels'],
        'status': p['status'],
        'tracks': tracksList,
        'created_at': _toFirebaseTimestamp(p['created_at']),
      });
      await db.update('programs', {'is_synced': 1},
          where: 'id = ?', whereArgs: [p['id']]);
    }

    // الرفع النهائي لما تبقى في الدفعة
    await commitBatch();

    // حفظ وقت آخر مزامنة ناجحة (فقط إذا تم الرفع بنجاح)
    if (totalUploaded > 0 || programs.isNotEmpty) {
      await prefs.setString('last_push_timestamp', DateTime.now().toIso8601String());
      debugPrint('📅 [DELTA SYNC] تم حفظ وقت آخر مزامنة ناجحة.');
    } else {
      // حتى لو لم يكن هناك شيء يُرفع، نحدد وقت المزامنة لتجنب إعادة فحص نفس السجلات
      await prefs.setString('last_push_timestamp', DateTime.now().toIso8601String());
      debugPrint('✅ [DELTA SYNC] لا تغييرات جديدة للرفع — تم تحديث وقت المزامنة.');
    }

    debugPrint('📤 [DELTA SYNC] انتهت عملية الرفع — إجمالي ما تم رفعه: $totalUploaded سجل.');
  }

  // =======================================================================
  // 3. التنزيل الذكي من السحابة (Pull)
  // =======================================================================
  Future<void> pullFromFirebase() async {
    final db = await DatabaseHelper.instance.database;
    Batch localBatch = db.batch();

    // Source.server تضمن أننا نجلب أحدث نسخة فعلية من السيرفر وليس من الكاش
    const GetOptions serverOnly = GetOptions(source: Source.server);

    try {
      // دالة مساعدة لتنزيل البيانات وحفظها محلياً بذكاء (ConflictAlgorithm.replace)
      Future<void> downloadTable(String collectionName, String tableName,
          {bool isFaculty = false}) async {
        final snap =
            await _firestore.collection(collectionName).get(serverOnly);

        // جلب أعمدة الجدول المحلي لتصفية الحقول الغريبة
        final tableInfo = await db.rawQuery("PRAGMA table_info($tableName)");
        final validColumns = tableInfo.map((col) => col['name'] as String).toSet();

        for (var doc in snap.docs) {
          Map<String, dynamic> data = doc.data();
          Map<String, dynamic> localData;

          if (isFaculty) {
            final faculty = FacultyMemberModel.fromFirestore(doc);
            localData = faculty.toMap();
          } else {
            localData = {
              'id': doc.id,
              ...data,
            };
            // توحيد صيغة التاريخ
            if (data.containsKey('createdAt') ||
                data.containsKey('created_at')) {
              localData['created_at'] =
                  _toLocalIsoString(data['createdAt'] ?? data['created_at']);
              localData.remove('createdAt');
            }

            // تجاهل حقل level القديم إذا كان موجوداً لمنع حدوث خطأ في SQLite
            if (tableName == 'users' && localData.containsKey('level')) {
              localData.remove('level');
            }
          }

          // ⚠️ إزالة updated_at من البيانات القادمة من السحابة
          // لأنها لا تحتوي عليه وإدخاله كـ null يُفسد آلية الديلتا
          localData.remove('updated_at');

          // تصفية الحقول الغريبة التي لا توجد في schema المحلي
          localData.removeWhere((key, _) => !validColumns.contains(key));

          localBatch.insert(
            tableName,
            localData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // التنزيل بالترتيب الصحيح للحفاظ على العلاقات (Foreign Keys)
      await downloadTable('users', 'users');
      await downloadTable('colleges', 'colleges');
      await downloadTable('departments', 'departments');
      await downloadTable('faculty_members', 'faculty_members',
          isFaculty: true);
      await downloadTable('graduation_projects', 'graduation_projects');

      // -- تنزيل البرامج --
      final progSnap = await _firestore.collection('programs').get(serverOnly);
      for (var doc in progSnap.docs) {
        final data = doc.data();
        localBatch.insert(
            'programs',
            {
              'id': doc.id,
              'name_ar': data['name_ar'] ?? '',
              'name_en': data['name_en'] ?? '',
              'total_levels': data['total_levels'] ?? 4,
              'status': data['status'] ?? 'active',
              'tracks': jsonEncode(data['tracks'] ?? []),
              'is_synced': 1,
              'created_at':
                  _toLocalIsoString(data['created_at'] ?? data['createdAt']),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }


      await localBatch.commit(noResult: true);
      debugPrint('📥 تم تنزيل البيانات من السحابة وتحديث الجهاز المحلي.');
    } catch (e) {
      debugPrint('[SYNC PULL ERROR]: $e');
      rethrow;
    }
  }

  // =======================================================================
  // دوال مساعدة لمعالجة التواريخ
  // =======================================================================
  Timestamp _toFirebaseTimestamp(dynamic localDate) {
    if (localDate == null || localDate == '-' || localDate.toString().isEmpty) {
      return Timestamp.now();
    }
    DateTime? dt = DateTime.tryParse(localDate.toString());
    return dt != null ? Timestamp.fromDate(dt) : Timestamp.now();
  }

  String _toLocalIsoString(dynamic firebaseDate) {
    if (firebaseDate == null) return DateTime.now().toIso8601String();
    if (firebaseDate is Timestamp) {
      return firebaseDate.toDate().toIso8601String();
    }
    if (firebaseDate is String) {
      return DateTime.tryParse(firebaseDate)?.toIso8601String() ?? firebaseDate;
    }
    return DateTime.now().toIso8601String();
  }
}
