import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart'; // تأكد من مسار قاعدة البيانات

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =================================================================
  // 0. معالجة الحذفيات أولاً (الخطوة الجديدة)
  // =================================================================
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

    // 👈 التعديل: إضافة Timeout لمدة 10 ثوانٍ
    await batch.commit().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException(
              'تعذر الاتصال بالسيرفر. تأكد من جودة الإنترنت.'),
        );

    await db.delete('deleted_records');
  }

  // =================================================================
  // 1. رفع البيانات (من SQLite إلى Firebase)
  // =================================================================
  Future<void> pushToFirebase() async {
    final db = await DatabaseHelper.instance.database;
    WriteBatch batch = FirebaseFirestore.instance.batch();

    // -- رفع الكليات --
    final colleges = await db.query('colleges');
    for (var c in colleges) {
      final ref = _firestore.collection('colleges').doc(c['id'].toString());
      batch.set(ref, {
        'arName': c['ar_name'],
        'enName': c['en_name'],
        'code': c['code'],
        'deanId': c['dean_id'],
        'createdAt': _toFirebaseTimestamp(c['created_at']),
      });
    }

    // -- رفع الأقسام --
    final departments = await db.query('departments');
    for (var d in departments) {
      final ref = _firestore.collection('departments').doc(d['id'].toString());
      batch.set(ref, {
        'name': d['name'],
        'collegeId': d['college_id'],
        'hodId': d['hod_id'],
        'createdAt': _toFirebaseTimestamp(d['created_at']),
      });
    }

    // -- رفع أعضاء هيئة التدريس --
    final faculty = await db.query('faculty_members');
    for (var f in faculty) {
      final ref =
          _firestore.collection('faculty_members').doc(f['id'].toString());
      batch.set(ref, {
        'name': f['name'],
        'email': f['email'],
        'department': f['department'],
        'academicDegree': f['academic_degree'],
        'status': f['status'],
        'createdAt': _toFirebaseTimestamp(f['created_at']),
      });
    }

    // -- رفع المستخدمين --
    final users = await db.query('users');
    for (var u in users) {
      final ref = _firestore.collection('users').doc(u['id'].toString());
      batch.set(ref, {
        'name': u['name'],
        'email': u['email'],
        'phone': u['phone'],
        'role': u['role'],
        'faculty': u['faculty'],
        'department': u['department'],
        'level': u['level'],
        'status': u['status'],
        'createdAt': _toFirebaseTimestamp(u['created_at']),
      });
    }

    // تنفيذ الرفع بمراعاة الـ Timeout
    await batch.commit().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
              'انتهى وقت طلب الرفع. تحقق من اتصالك بالإنترنت.'),
        );
  }

  // =================================================================
  // 2. تنزيل البيانات (من Firebase إلى SQLite)
  // =================================================================
  Future<void> pullFromFirebase() async {
    final db = await DatabaseHelper.instance.database;

    // نستخدم db.batch لتسريع عملية إدخال مئات السجلات محلياً
    Batch localBatch = db.batch();

    // 👈 التعديل: إجبار فايربيس على القراءة من السيرفر فقط (Source.server).
    // هذا يجعله يفشل فوراً إذا لم يكن هناك إنترنت بدلاً من قراءة الكاش الوهمي!
    const GetOptions serverOnly = GetOptions(source: Source.server);

    // -- تنزيل الكليات --
    final colSnap = await _firestore.collection('colleges').get(serverOnly);
    for (var doc in colSnap.docs) {
      final data = doc.data();
      localBatch.insert(
          'colleges',
          {
            'id': doc.id,
            'ar_name': data['arName'] ?? data['ar_name'] ?? '',
            'en_name': data['enName'] ?? data['en_name'] ?? '',
            'code': data['code'] ?? '',
            'dean_id': data['deanId'] ?? data['dean_id'] ?? '',
            'created_at':
                _toLocalIsoString(data['createdAt'] ?? data['createAt']),
          },
          conflictAlgorithm:
              ConflictAlgorithm.replace); // Replace للتحديث إذا كان موجوداً
    }

    // -- تنزيل الأقسام --
    final depSnap = await _firestore.collection('departments').get(serverOnly);
    for (var doc in depSnap.docs) {
      final data = doc.data();
      localBatch.insert(
          'departments',
          {
            'id': doc.id,
            'name': data['name'] ?? '',
            'college_id': data['collegeId'] ?? data['college_id'] ?? '',
            'hod_id': data['hodId'] ?? data['HODId'] ?? '',
            'created_at':
                _toLocalIsoString(data['createdAt'] ?? data['createAt']),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // -- تنزيل أعضاء هيئة التدريس --
    final facSnap = await _firestore.collection('faculty_members').get(serverOnly);
    for (var doc in facSnap.docs) {
      final data = doc.data();
      localBatch.insert(
          'faculty_members',
          {
            'id': doc.id,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'department': data['department'] ?? '',
            'academic_degree':
                data['academicDegree'] ?? data['academic_degree'] ?? '',
            'status': data['status'] ?? 'نشط',
            'created_at':
                _toLocalIsoString(data['createdAt'] ?? data['createAt']),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // -- تنزيل المستخدمين --
    final userSnap = await _firestore.collection('users').get(serverOnly);
    for (var doc in userSnap.docs) {
      final data = doc.data();
      localBatch.insert(
          'users',
          {
            'id': doc.id,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
            'role': data['role'] ?? '',
            'faculty': data['faculty'],
            'department': data['department'],
            'level': data['level'],
            'status': data['status'],
            'created_at':
                _toLocalIsoString(data['createdAt'] ?? data['createAt']),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // تنفيذ الحفظ المحلي
    await localBatch.commit(noResult: true);
  }

  // =================================================================
  // دوال مساعدة لمعالجة التواريخ بين النظامين
  // =================================================================
  Timestamp _toFirebaseTimestamp(dynamic localDate) {
    if (localDate == null) return Timestamp.now();
    DateTime? dt = DateTime.tryParse(localDate.toString());
    return dt != null ? Timestamp.fromDate(dt) : Timestamp.now();
  }

  String _toLocalIsoString(dynamic firebaseDate) {
    if (firebaseDate == null) return DateTime.now().toIso8601String();
    if (firebaseDate is Timestamp)
      return firebaseDate.toDate().toIso8601String();
    if (firebaseDate is String) {
      return DateTime.tryParse(firebaseDate)?.toIso8601String() ??
          DateTime.now().toIso8601String();
    }
    return DateTime.now().toIso8601String();
  }
}
