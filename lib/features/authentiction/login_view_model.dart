import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/services/sync_service.dart'; // استدعاء خدمة المزامنة
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

  Future<void> login({
    required String email,
    required String password,
    required bool rememberMe,
    bool skipSync = false,
  }) async {
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
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

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
      final String systemUserId = userQuery.docs.first.id; // المعرف الداخلي الصحيح
      currentUserRole = userData['role'] ?? 'unknown';

      // 3. مزامنة جميع البيانات إلى SQLite للاستخدام بدون إنترنت
      if (!skipSync) {
        debugPrint('[LOGIN DEBUG] جاري تنزيل البيانات الأساسية للجهاز...');
        try {
          await DatabaseHelper.instance.clearAllData();
          await _syncService.performSmartSync();
          await syncExtraData();
          debugPrint('[LOGIN DEBUG] تم تنزيل البيانات بنجاح.');
        } catch (e) {
          debugPrint('[LOGIN DEBUG] تحذير: فشلت المزامنة المحلية: $e');
        }
      } else {
        debugPrint('[LOGIN DEBUG] تم تخطي تنزيل البيانات (دخول سريع).');
      }

      // 4. حفظ حالة تسجيل الدخول في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', systemUserId); // المعرف الداخلي
      await prefs.setString('userRole', currentUserRole!);
      await prefs.setString('userName', userData['name'] ?? 'مستخدم');
      await prefs.setString('userEmail', email.trim());
      await prefs.setString('college', userData['faculty'] ?? userData['college'] ?? 'غير محدد');
      await prefs.setString('userDepartment', userData['department'] ?? '');
      if (!rememberMe) {
        // إذا لم يختر "تذكرني"، نحفظ الجلسة بشكل مؤقت فقط
        await prefs.setBool('isLoggedIn', true);
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

  Future<bool> logout({bool forceLogout = false, bool sync = true}) async {
    status = LoginStatus.loading;
    notifyListeners();

    try {
      if (sync) {
        debugPrint(
            '[LOGOUT DEBUG] جاري تأمين ورفع البيانات المحلية قبل الخروج...');
        try {
          await _syncService.performSmartSync();
        } catch (syncError) {
          if (!forceLogout) {
            throw Exception('فشل المزامنة'); // نمرر هذه الكلمة المفتاحية للواجهة
          }
          debugPrint('[LOGOUT DEBUG] Sync failed, but forceLogout is true. Proceeding...');
        }
      } else {
        debugPrint('[LOGOUT DEBUG] تسجيل خروج مباشر بدون مزامنة...');
      }

      // 1. تسجيل الخروج من Firebase
      await _auth.signOut();

      // 2. مسح بيانات الجلسة من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('userId');
      await prefs.remove('userRole');

      // 3. مسح البيانات المحلية من SQLite والذاكرة المؤقتة
      await DatabaseHelper.instance.clearAllData();
      await AppSession().clear(); // تم النقل لهنا لضمان التصفير الكامل

      // 4. تصفير المتغيرات
      currentUserRole = null;
      status = LoginStatus.idle;

      // 🛑 (تم حذف كود الـ Navigator من هنا)

      notifyListeners();
      return true; // 👈 إرجاع "نجاح"
    } catch (e) {
      debugPrint('[LOGOUT DEBUG] ❌ حدث خطأ أثناء تسجيل الخروج: $e');
      status = LoginStatus.error;
      errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false; // 👈 إرجاع "فشل"
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

  // دالة إضافية لتنزيل الجداول التي لم يتم تضمينها في SyncService (مثل المواد)
  Future<void> syncExtraData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      Batch batch = db.batch();

      // مزامنة المواد
      final subjectsSnapshot = await _firestore.collection('subjects').get();
      for (var doc in subjectsSnapshot.docs) {
        final data = doc.data();
        batch.insert(
          'subjects',
          {
            'id': doc.id,
            'ar_name': data['ar_name'] ?? 'غير محدد',
            'en_name': data['en_name'] ?? 'غير محدد',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[SYNC EXTRA DATA] خطأ في تنزيل البيانات الإضافية: $e');
    }
  }

  // =================================================================
  // دالة جديدة: تفعيل حساب لمستخدم تم إضافته مسبقاً من قبل الإدارة
  // =================================================================
  // =================================================================
  // دالة إرسال رابط التفعيل (حسب الفكرة الجديدة)
  // =================================================================
  Future<void> sendActivationLink(String email) async {
    if (email.isEmpty) {
      errorMessage = 'يرجى إدخال البريد الإلكتروني';
      status = LoginStatus.error;
      notifyListeners();
      return;
    }

    status = LoginStatus.loading;
    errorMessage = '';
    notifyListeners();

    try {
      // 1. التحقق: هل الإدارة أضافت هذا البريد في قاعدة البيانات؟
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('هذا البريد غير مسجل في النظام. يرجى مراجعة الإدارة.');
      }

      // 2. توليد كلمة مرور عشوائية قوية جداً ومعقدة (لن يعرفها أحد)
      String tempPassword =
          '${DateTime.now().millisecondsSinceEpoch}#XyZ@9!${email.length}';

      // 3. إنشاء الحساب بصمت في Firebase Auth
      try {
        await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: tempPassword,
        );
      } on FirebaseAuthException catch (authError) {
        // إذا كان الحساب موجوداً مسبقاً، لا مشكلة، سنتجاهل الخطأ
        // وننتقل للخطوة التالية (إرسال رابط إعادة التعيين) كنوع من استعادة الحساب
        if (authError.code != 'email-already-in-use') {
          rethrow; // إعادة رمي الخطأ إذا كان لسبب آخر غير التكرار
        }
      }

      // 4. إرسال رابط "إعادة تعيين كلمة المرور" للبريد الخاص به
      await _auth.sendPasswordResetEmail(email: email.trim());

      status = LoginStatus.success;
      errorMessage =
          'تم إرسال رابط تفعيل الحساب إلى بريدك. يرجى التحقق من صندوق الوارد (أو البريد المزعج/Spam).';
      notifyListeners();
    } catch (e) {
      status = LoginStatus.error;
      // تنظيف رسالة الخطأ لتكون مقروءة
      errorMessage = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('[firebase_auth/invalid-email]', 'صيغة البريد غير صحيحة');
      notifyListeners();
    }
  }
}
