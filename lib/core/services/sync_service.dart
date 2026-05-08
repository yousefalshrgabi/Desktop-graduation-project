import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
      await _pullFromFirebase();

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
          const Duration(seconds: 10),
          onTimeout: () =>
              throw TimeoutException('فشل الاتصال أثناء مزامنة الحذفيات.'),
        );

    // تنظيف سلة المهملات المحلية بعد تأكيد الحذف من السحابة
    await db.delete('deleted_records');
    debugPrint('🗑️ تم رفع الحذفيات للسحابة.');
  }

  // =======================================================================
  // 2. الرفع الآمن للسحابة (Push)
  // =======================================================================
  Future<void> _pushToFirebase() async {
    final db = await DatabaseHelper.instance.database;
    WriteBatch batch = _firestore.batch();

    // دالة مساعدة لرفع أي جدول ديناميكياً
    Future<void> uploadTable(String tableName, {bool isFaculty = false}) async {
      final records = await db.query(tableName);
      for (var record in records) {
        final ref =
            _firestore.collection(tableName).doc(record['id'].toString());

        Map<String, dynamic> dataToUpload;

        if (isFaculty) {
          // استخدام المودل لضمان تضمين روابط الملفات (file_url) وغيرها
          final faculty = FacultyMemberModel.fromMap(record);
          dataToUpload = faculty.toMap();
          dataToUpload['created_at'] = _toFirebaseTimestamp(faculty.createdAt);
        } else {
          dataToUpload = Map<String, dynamic>.from(record);
          if (dataToUpload.containsKey('created_at')) {
            dataToUpload['created_at'] =
                _toFirebaseTimestamp(dataToUpload['created_at']);
          }
        }

        // دمج البيانات: SetOptions(merge: true) تضمن أننا لا نمسح حقولاً في السحابة قد لا تكون موجودة محلياً
        batch.set(ref, dataToUpload, SetOptions(merge: true));
      }
    }

    await uploadTable('users');
    await uploadTable('colleges');
    await uploadTable('departments');
    await uploadTable('subjects');
    await uploadTable('study_plans');
    await uploadTable('faculty_members', isFaculty: true);

    await batch.commit().timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('انتهى وقت الرفع للسحابة.'),
        );
    debugPrint('📤 تم رفع التعديلات المحلية للسحابة.');
  }

  // =======================================================================
  // 3. التنزيل الذكي من السحابة (Pull)
  // =======================================================================
  Future<void> _pullFromFirebase() async {
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

        for (var doc in snap.docs) {
          Map<String, dynamic> data = doc.data();
          Map<String, dynamic> localData;

          if (isFaculty) {
            final faculty = FacultyMemberModel.fromFirestore(doc);
            localData = faculty.toMap();
          } else {
            // تحويل مفاتيح الفايربيس (camelCase) إلى SQLite (snake_case) إن تطلب الأمر
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
          }

          // استخدام ConflictAlgorithm.replace يضمن أن البيانات القادمة من السحابة
          // (والتي أصبحت الآن أحدث نسخة لأننا رفعنا تعديلاتنا للتو) ستحدث القاعدة المحلية
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
      await downloadTable('subjects', 'subjects');
      await downloadTable('study_plans', 'study_plans');
      await downloadTable('faculty_members', 'faculty_members',
          isFaculty: true);

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
