import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/features/authentiction/login_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart'; // إضافة الحزمة

enum LoginStatus { idle, loading, success, error }

class LoginViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  LoginStatus status = LoginStatus.idle;
  String errorMessage = '';

  // متغير للاحتفاظ بنوع المستخدم بعد تسجيل الدخول لتوجيهه لاحقاً
  String? currentUserRole;

  User? get currentUser => _auth.currentUser;

  // أضفنا مُعامل rememberMe
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

      // ==========================================
      // التعديل الجديد: البحث بواسطة الإيميل بدلاً من الـ uid
      // ==========================================
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim()) // نبحث عن الإيميل المطابق
          .limit(1) // نحتاج نتيجة واحدة فقط
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception(
            'بيانات المستخدم غير موجودة في قاعدة البيانات (Firestore)');
      }

      // حفظ نوع المستخدم في المتغير
      final userData = userQuery.docs.first.data() as Map<String, dynamic>;
      currentUserRole = userData['role'] ?? 'unknown';

      // ==========================================

      // 3. مزامنة جميع البيانات إلى SQLite للاستخدام بدون إنترنت
      bool syncSuccess = await syncAllData();
      // ... باقي الكود كما هو
      if (!syncSuccess) {
        debugPrint(
            '[LOGIN DEBUG] تحذير: فشلت المزامنة المحلية، لكن تم تسجيل الدخول.');
      }

      // 4. حفظ حالة تسجيل الدخول في SharedPreferences
      if (syncSuccess && rememberMe) {
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
      // 1. تسجيل الخروج من Firebase
      await _auth.signOut();

      // 2. مسح بيانات الجلسة من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('userId');
      await prefs.remove('userRole');

      // ملاحظة: يمكنك استخدام await prefs.clear(); إذا كنت متأكداً
      // أنك لا تحفظ إعدادات أخرى مثل (الوضع الليلي أو اللغة) وتريد مسح كل شيء.

      // 3. مسح البيانات المحلية من SQLite (الدالة موجودة مسبقاً في DatabaseHelper)
      await DatabaseHelper.instance.clearAllData();

      // 4. تصفير المتغيرات
      currentUserRole = null;
      status = LoginStatus.idle;
      notifyListeners();

      // 5. توجيه المستخدم لصفحة الدخول ومسح كل الصفحات السابقة من الذاكرة
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginView()),
          (route) => false, // يحذف كل الـ history الخاص بالصفحات
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

  Future<bool> syncAllData() async {
    debugPrint(
        '[SYNC DEBUG] 🟢 1. بدء عملية المزامنة الشاملة من السيرفر إلى الجهاز...');

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. مسح البيانات القديمة محلياً (لتجنب التكرار وتحديث البيانات المحذوفة من السيرفر)
      debugPrint('[SYNC DEBUG] 🟡 2. جاري مسح البيانات المحلية القديمة...');
      await DatabaseHelper.instance.clearAllData();

      // 2. إنشاء Batch لتجميع عمليات الإدخال لتسريع الأداء
      Batch batch = db.batch();

      // =========================================================
      // 1. مزامنة الكليات (Colleges)
      // =========================================================
      debugPrint('[SYNC DEBUG] 🟡 3. جاري جلب الكليات...');
      final collegesSnapshot = await _firestore.collection('colleges').get();
      for (var doc in collegesSnapshot.docs) {
        final data = doc.data();
        batch.insert('colleges', {
          'id': doc.id,
          'ar_name': data['ar_name'] ?? 'غير محدد',
          'en_name': data['en_name'] ?? 'غير محدد',
          'code': data['code'] ?? 'غير محدد',
          'dean_id': data['deanId'] ?? '', // لاحظ اختلاف المسمى في فايربيس
          'created_at': _formatTimestamp(data['createdAt']),
        });
      }

      // =========================================================
      // 2. مزامنة الأقسام (Departments)
      // =========================================================
      debugPrint('[SYNC DEBUG] 🟡 4. جاري جلب الأقسام...');
      final deptsSnapshot = await _firestore.collection('departments').get();
      for (var doc in deptsSnapshot.docs) {
        final data = doc.data();
        batch.insert('departments', {
          'id': doc.id,
          'name': data['name'] ?? 'غير محدد',
          'college_id': data['collegeId'] ?? '',
          'hod_id': data['HODId'] ?? '', // HODId في فايربيس
          'created_at': _formatTimestamp(data['createdAt']),
        });
      }

      // =========================================================
      // 3. مزامنة أعضاء هيئة التدريس (Faculty Members)
      // =========================================================
      debugPrint('[SYNC DEBUG] 🟡 5. جاري جلب أعضاء هيئة التدريس...');
      final facultySnapshot = await _firestore
          .collection('faculty_members')
          .get(); // تأكد من اسم الكولكشن في فايربيس
      for (var doc in facultySnapshot.docs) {
        final data = doc.data();
        batch.insert('faculty_members', {
          'id': doc.id,
          'name': data['name'] ?? 'غير معروف',
          'email': data['email'] ?? 'غير متوفر',
          'department': data['department'] ?? 'غير محدد',
          'academic_degree': data['academicDegree'] ?? 'غير محدد',
          'status': data['status'] ?? 'نشط',
          'created_at': _formatTimestamp(data['createdAt']),
        });
      }

      // =========================================================
      // 4. مزامنة المستخدمين (Users)
      // =========================================================
      debugPrint('[SYNC DEBUG] 🟡 6. جاري جلب المستخدمين...');
      final usersSnapshot = await _firestore.collection('users').get();
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        batch.insert('users', {
          'id': doc.id,
          'name': data['name'] ?? 'غير معروف',
          'email': data['email'] ?? 'غير معروف',
          'phone': data['phone'] ?? 'غير معروف',
          'role': data['role'] ?? 'غير محدد',
          'created_at': _formatTimestamp(data[
              'createAt']), // لاحظ في الموديل الخاص بك اسمها createAt بدون d
          'faculty': data['faculty'],
          'department': data['department'],
          'level': data['level'],
          'status': data['status'],
        });
      }

      // =========================================================
      // 5. مزامنة الخطط الدراسية (Study Plans)
      // =========================================================
      debugPrint('[SYNC DEBUG] 🟡 7. جاري جلب الخطط الدراسية...');
      final plansSnapshot = await _firestore.collection('studyPlans').get();
      for (var doc in plansSnapshot.docs) {
        final data = doc.data();
        // تفكيك كائن contactHours المدمج
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

      // =========================================================
      // 6. مزامنة المواد (Subjects)
      // =========================================================
      debugPrint('[SYNC DEBUG] 🟡 8. جاري جلب المواد...');
      final subjectsSnapshot = await _firestore.collection('subjects').get();
      for (var doc in subjectsSnapshot.docs) {
        final data = doc.data();
        batch.insert('subjects', {
          'id': doc.id,
          'ar_name': data['ar_name'] ?? 'غير محدد',
          'en_name': data['en_name'] ?? 'غير محدد',
        });
      }

      // =========================================================
      // تنفيذ كل عمليات الحفظ دفعة واحدة (Commit)
      // =========================================================
      debugPrint(
          '[SYNC DEBUG] 🟡 9. جاري حقن البيانات في SQLite دفعة واحدة...');
      await batch.commit(
          noResult:
              true); // noResult: true تجعل العملية أسرع لأننا لا نحتاج إرجاع أرقام الصفوف

      debugPrint(
          '[SYNC DEBUG] ✅ 🎉 تمت المزامنة بنجاح! جميع البيانات متوفرة الآن بدون إنترنت.');
      return true;
    } catch (e, stacktrace) {
      debugPrint('[SYNC DEBUG] ❌ حدث خطأ فادح أثناء المزامنة: $e');
      debugPrint('[SYNC DEBUG] $stacktrace');
      return false;
    }
  }

  // دالة مساعدة لتحويل Timestamp الخاص بفايربيس إلى نص (String) مناسب لـ SQLite
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null || timestamp is! Timestamp) return '-';
    final dt = timestamp.toDate();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

}
