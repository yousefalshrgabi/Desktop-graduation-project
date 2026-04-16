import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/core/services/sync_service.dart'; // استدعاء خدمة المزامنة
import 'package:academic_affairs_management/features/authentiction/login_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

enum LoginStatus { idle, loading, success, error }

class LoginViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SyncService _syncService = SyncService(); // استخدام كائن المزامنة

  LoginStatus status = LoginStatus.idle;
  String errorMessage = '';

  // متغير للاحتفاظ بنوع المستخدم بعد تسجيل الدخول لتوجيهه لاحقاً
  String? currentUserRole;

  User? get currentUser => _auth.currentUser;

  Future<void> login(
      {required String email,
      required String password,
      required bool rememberMe}) async {
    if (email.isEmpty || password.isEmpty) {
      errorMessage = 'يرجى إدخال البريد الإلكتروني وكلمة المرور';
      status = LoginStatus.error;
      notifyListeners();
      return;
    }

    status = LoginStatus.loading;
    errorMessage = '';
    notifyListeners();

    try {
      // 1. تسجيل الدخول عبر Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final String uid = userCredential.user!.uid;

      // 2. البحث بواسطة الإيميل في قاعدة المستخدمين
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception(
            'بيانات المستخدم غير موجودة في قاعدة البيانات (Firestore)');
      }

      // حفظ نوع المستخدم
      final userData = userQuery.docs.first.data() as Map<String, dynamic>;
      currentUserRole = userData['role'] ?? 'unknown';

      // 3. مزامنة جميع البيانات إلى SQLite للاستخدام بدون إنترنت
      // نستخدم دالة pullFromFirebase من SyncService لضمان توحيد آلية التنزيل
      debugPrint('[LOGIN DEBUG] جاري تنزيل البيانات الأساسية للجهاز...');
      try {
        await DatabaseHelper.instance.clearAllData(); // تنظيف القديم أولاً
        await _syncService
            .pullFromFirebase(); // تنزيل الأقسام والكليات والأعضاء والمستخدمين
        await syncExtraData(); // دالة مخصصة لتنزيل الجداول الأخرى غير المشمولة في SyncService
        debugPrint('[LOGIN DEBUG] تم تنزيل البيانات بنجاح.');
      } catch (e) {
        debugPrint('[LOGIN DEBUG] تحذير: فشلت المزامنة المحلية: $e');
      }

      // 4. حفظ حالة تسجيل الدخول في SharedPreferences
      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', uid);
        await prefs.setString('userRole', currentUserRole!);
      }

      status = LoginStatus.success;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      status = LoginStatus.error;
      errorMessage = _mapFirebaseError(e.code);
      notifyListeners();
    } catch (e) {
      status = LoginStatus.error;
      errorMessage = 'حدث خطأ غير متوقع: $e';
      notifyListeners();
    }
  }

  Future<void> logout(BuildContext context) async {
    status = LoginStatus.loading;
    notifyListeners();

    try {
      await _auth.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('userId');
      await prefs.remove('userRole');

      await DatabaseHelper.instance.clearAllData();

      currentUserRole = null;
      status = LoginStatus.idle;
      notifyListeners();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginView()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('[LOGOUT DEBUG] ❌ حدث خطأ أثناء تسجيل الخروج: $e');
      status = LoginStatus.error;
      errorMessage = 'فشل تسجيل الخروج، يرجى المحاولة لاحقاً';
      notifyListeners();
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'user-disabled':
        return 'هذا الحساب معطل، تواصل مع المدير';
      case 'too-many-requests':
        return 'محاولات كثيرة جداً، يرجى الانتظار قليلاً';
      case 'network-request-failed':
        return 'تحقق من اتصالك بالإنترنت';
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      default:
        return 'حدث خطأ: $code';
    }
  }

  // دالة إضافية لتنزيل الجداول التي لم يتم تضمينها في SyncService (مثل الخطط والمواد)
  Future<void> syncExtraData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      Batch batch = db.batch();

      // مزامنة الخطط الدراسية
      final plansSnapshot = await _firestore.collection('studyPlans').get();
      for (var doc in plansSnapshot.docs) {
        final data = doc.data();
        final contactHours =
            data['contactHours'] as Map<String, dynamic>? ?? {};

        batch.insert('study_plans', {
          'id': doc.id,
          'contact_hours_lab': contactHours['lab'] ?? 0,
          'contact_hours_th': contactHours['th'] ?? 0,
          'course_type': data['courseType'] ?? '',
          'credit_hours': data['creditHours'] ?? 0,
          'dept_id': data['deptId'] ?? '',
          'level': data['level'] ?? 0,
          'semester': data['semester'] ?? 0,
          'state': data['state'] ?? '',
          'subject_id': data['subjectId'] ?? '',
        });
      }

      // مزامنة المواد
      final subjectsSnapshot = await _firestore.collection('subjects').get();
      for (var doc in subjectsSnapshot.docs) {
        final data = doc.data();
        batch.insert('subjects', {
          'id': doc.id,
          'ar_name': data['ar_name'] ?? 'غير محدد',
          'en_name': data['en_name'] ?? 'غير محدد',
        });
      }

      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[SYNC EXTRA DATA] خطأ في تنزيل البيانات الإضافية: $e');
    }
  }

  // =================================================================
  // دالة جديدة: تفعيل حساب لمستخدم تم إضافته مسبقاً من قبل الإدارة
  // =================================================================
  Future<void> activateAccount({
    required String email,
    required String newPassword,
  }) async {
    if (email.isEmpty || newPassword.isEmpty) {
      errorMessage = 'يرجى إدخال البريد الإلكتروني وكلمة المرور الجديدة';
      status = LoginStatus.error;
      notifyListeners();
      return;
    }

    if (newPassword.length < 6) {
      errorMessage = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
      status = LoginStatus.error;
      notifyListeners();
      return;
    }

    status = LoginStatus.loading;
    errorMessage = '';
    notifyListeners();

    try {
      // 1. التحقق هل البريد مسجل مسبقاً في Firestore (هل الإدارة أضافته؟)
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception(
            'هذا البريد غير معتمد من قبل الإدارة. يرجى مراجعة شؤون الموظفين.');
      }

      // 2. إذا كان معتمداً، نقوم بإنشاء حساب له في Firebase Auth
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: newPassword.trim(),
      );

      // 3. (اختياري) يمكننا تحديث حالة المستخدم في Firestore إلى "نشط"
      // String docId = userQuery.docs.first.id;
      // await _firestore.collection('users').doc(docId).update({'status': 'نشط'});

      status = LoginStatus.success;
      errorMessage = 'تم تفعيل حسابك بنجاح! يمكنك الآن تسجيل الدخول.';
      notifyListeners();

      // ملاحظة: createUserWithEmailAndPassword يقوم بتسجيل الدخول تلقائياً،
      // لذا يمكنك تسجيل خروجه فوراً وطلب تسجيل الدخول منه، أو تنفيذ كود تسجيل الدخول مباشرة.
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      status = LoginStatus.error;
      // إذا كان الإيميل مستخدم في Auth مسبقاً (أي أنه فعل حسابه من قبل)
      if (e.code == 'email-already-in-use') {
        errorMessage = 'هذا الحساب مفعل مسبقاً! يرجى العودة لتسجيل الدخول.';
      } else {
        errorMessage = _mapFirebaseError(e.code);
      }
      notifyListeners();
    } catch (e) {
      status = LoginStatus.error;
      errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }
}
