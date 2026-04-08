import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum LoginStatus { idle, loading, success, error }

class LoginViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  LoginStatus status = LoginStatus.idle;
  String errorMessage = '';

  // تحقق هل المستخدم مسجل دخوله بالفعل
  User? get currentUser => _auth.currentUser;

  Future<void> login({required String email, required String password}) async {
    debugPrint('[LOGIN DEBUG] Login requested for: $email');
    if (email.isEmpty || password.isEmpty) {
      debugPrint('[LOGIN DEBUG] Validation failed: Empty fields');
      errorMessage = 'يرجى إدخال البريد الإلكتروني وكلمة المرور';
      status = LoginStatus.error;
      notifyListeners();
      return;
    }

    status = LoginStatus.loading;
    errorMessage = '';
    notifyListeners();
    debugPrint('[LOGIN DEBUG] State set to loading');

    try {
      debugPrint('[LOGIN DEBUG] Attempting Firebase signInWithEmailAndPassword...');
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      debugPrint('[LOGIN DEBUG] Firebase Sign-in SUCCESS');
      status = LoginStatus.success;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      debugPrint('[LOGIN DEBUG] Firebase Auth Exception: ${e.code} - ${e.message}');
      status = LoginStatus.error;
      errorMessage = _mapFirebaseError(e.code);
      notifyListeners();
    } catch (e) {
      debugPrint('[LOGIN DEBUG] UNKNOWN Exception: $e');
      status = LoginStatus.error;
      errorMessage = 'حدث خطأ غير متوقع، حاول مجدداً';
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    status = LoginStatus.idle;
    notifyListeners();
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
}
