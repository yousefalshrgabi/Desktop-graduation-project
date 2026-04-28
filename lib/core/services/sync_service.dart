import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/features/desktop_pages/faculty_members_screen/faculty_member_model.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. معالجة الحذفيات أولاً
  Future<void> syncDeletionsFirst() async {
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

    await db.delete('deleted_records');
  }

  // 2. رفع البيانات من SQLite إلى Firebase (الشامل)
  Future<void> pushToFirebase() async {
    final db = await DatabaseHelper.instance.database;
    WriteBatch batch = _firestore.batch();

    // -- 1. رفع أعضاء هيئة التدريس --
    final facultyMaps = await db.query('faculty_members');
    for (var map in facultyMaps) {
      final faculty = FacultyMemberModel.fromMap(map);
      final ref = _firestore.collection('faculty_members').doc(faculty.id);

      Map<String, dynamic> dataToUpload = faculty.toMap();
      dataToUpload['created_at'] = _toFirebaseTimestamp(faculty.createdAt);
      batch.set(ref, dataToUpload);
    }

    // -- 2. رفع المستخدمين --
    final users = await db.query('users');
    for (var u in users) {
      final ref = _firestore.collection('users').doc(u['id'].toString());
      batch.set(ref, {
        ...u,
        'created_at': _toFirebaseTimestamp(u['created_at']),
      });
    }

    // -- 3. رفع الكليات --
    final colleges = await db.query('colleges');
    for (var c in colleges) {
      batch.set(_firestore.collection('colleges').doc(c['id'].toString()), {
        ...c,
        'created_at': _toFirebaseTimestamp(c['created_at']),
      });
    }

    // -- 4. رفع الأقسام (كانت مفقودة) --
    final departments = await db.query('departments');
    for (var d in departments) {
      batch.set(_firestore.collection('departments').doc(d['id'].toString()), {
        ...d,
        'created_at': _toFirebaseTimestamp(d['created_at']),
      });
    }

    // -- 5. رفع المواد (كانت مفقودة) --
    final subjects = await db.query('subjects');
    for (var s in subjects) {
      batch.set(_firestore.collection('subjects').doc(s['id'].toString()), {
        ...s,
      });
    }

    // -- 6. رفع الخطط الدراسية (كانت مفقودة) --
    final studyPlans = await db.query('study_plans');
    for (var p in studyPlans) {
      batch.set(_firestore.collection('study_plans').doc(p['id'].toString()), {
        ...p,
      });
    }

    await batch.commit().timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('انتهى وقت الرفع للسحابة.'),
        );
  }

  // 3. تنزيل البيانات من Firebase إلى SQLite (التكامل الكامل والشامل)
  // 3. تنزيل البيانات من Firebase إلى SQLite (بالترتيب الصحيح لتجنب Foreign Key Error)
  Future<void> pullFromFirebase() async {
    final db = await DatabaseHelper.instance.database;
    Batch localBatch = db.batch();

    const GetOptions serverOnly = GetOptions(source: Source.server);

    try {
      // -----------------------------------------------------------
      // 1. تنزيل المستخدمين (الجدول الأب) أولاً
      // -----------------------------------------------------------
      final userSnap = await _firestore.collection('users').get(serverOnly);
      for (var doc in userSnap.docs) {
        Map<String, dynamic> data = doc.data();
        localBatch.insert(
          'users',
          {
            'id': doc.id,
            'name': data['name']?.toString() ?? '',
            'email': data['email']?.toString() ?? '',
            'phone': data['phone']?.toString() ?? '',
            'role': data['role']?.toString() ?? '',
            'faculty': data['faculty']?.toString(),
            'department': data['department']?.toString(),
            'level': data['level']?.toString(),
            'status': data['status']?.toString(),
            'created_at':
                _toLocalIsoString(data['createdAt'] ?? data['created_at']),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // -----------------------------------------------------------
      // 2. تنزيل الكليات (الجدول الأب للأقسام)
      // -----------------------------------------------------------
      final colSnap = await _firestore.collection('colleges').get(serverOnly);
      for (var doc in colSnap.docs) {
        Map<String, dynamic> data = doc.data();
        localBatch.insert(
          'colleges',
          {
            'id': doc.id,
            'ar_name': data['arName'] ?? data['ar_name'] ?? '',
            'en_name': data['enName'] ?? data['en_name'] ?? '',
            'code': data['code'] ?? '',
            'dean_id': data['deanId'] ?? data['dean_id'] ?? '',
            'created_at':
                _toLocalIsoString(data['createdAt'] ?? data['created_at']),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // -----------------------------------------------------------
      // 3. تنزيل الأقسام
      // -----------------------------------------------------------
      final deptSnap =
          await _firestore.collection('departments').get(serverOnly);
      for (var doc in deptSnap.docs) {
        Map<String, dynamic> data = doc.data();
        localBatch.insert(
          'departments',
          {
            'id': doc.id,
            'name': data['name'] ?? '',
            'college_id': data['collegeId'] ?? data['college_id'] ?? '',
            'hod_id': data['hodId'] ?? data['hod_id'] ?? '',
            'created_at':
                _toLocalIsoString(data['createdAt'] ?? data['created_at']),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // -----------------------------------------------------------
      // 4. تنزيل المواد
      // -----------------------------------------------------------
      final subSnap = await _firestore.collection('subjects').get(serverOnly);
      for (var doc in subSnap.docs) {
        Map<String, dynamic> data = doc.data();
        localBatch.insert(
          'subjects',
          {
            'id': doc.id,
            'ar_name': data['ar_name'] ?? data['arName'] ?? '',
            'en_name': data['en_name'] ?? data['enName'] ?? '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // -----------------------------------------------------------
      // 5. تنزيل أعضاء هيئة التدريس (الآن المستخدمين موجودين، لن يحدث خطأ)
      // -----------------------------------------------------------
      final facSnap =
          await _firestore.collection('faculty_members').get(serverOnly);
      for (var doc in facSnap.docs) {
        final faculty = FacultyMemberModel.fromFirestore(doc);
        localBatch.insert(
          'faculty_members',
          faculty.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // -----------------------------------------------------------
      // 6. تنزيل الخطط الدراسية
      // -----------------------------------------------------------
      final planSnap =
          await _firestore.collection('study_plans').get(serverOnly);
      for (var doc in planSnap.docs) {
        Map<String, dynamic> data = doc.data();
        localBatch.insert(
          'study_plans',
          {
            'id': doc.id,
            'subject_id': data['subject_id'] ?? '',
            'dept_id': data['dept_id'] ?? '',
            'level': data['level'] ?? 1,
            'semester': data['semester'] ?? 1,
            'course_type': data['course_type'] ?? '',
            'credit_hours': data['credit_hours'] ?? 0,
            'contact_hours_th': data['contact_hours_th'] ?? 0,
            'contact_hours_lab': data['contact_hours_lab'] ?? 0,
            'state': data['state'] ?? 'نشط',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // تنفيذ كافة العمليات في قاعدة البيانات المحلية دفعة واحدة
      await localBatch.commit(noResult: true);
      debugPrint('[SYNC SUCCESS] تم تنزيل كافة البيانات بنجاح.');
    } catch (e) {
      debugPrint('[SYNC ERROR] فشل في تنزيل البيانات: $e');
      rethrow;
    }
  }

  Timestamp _toFirebaseTimestamp(dynamic localDate) {
    if (localDate == null || localDate == '-') return Timestamp.now();
    DateTime? dt = DateTime.tryParse(localDate.toString());
    return dt != null ? Timestamp.fromDate(dt) : Timestamp.now();
  }

  String _toLocalIsoString(dynamic firebaseDate) {
    if (firebaseDate == null) return DateTime.now().toIso8601String();
    if (firebaseDate is Timestamp)
      return firebaseDate.toDate().toIso8601String();
    if (firebaseDate is String) {
      return DateTime.tryParse(firebaseDate)?.toIso8601String() ?? firebaseDate;
    }
    return DateTime.now().toIso8601String();
  }
}
