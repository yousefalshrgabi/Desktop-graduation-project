import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';

class SplashViewModel extends ChangeNotifier {
  Future<String> checkLoginStatus() async {
    // انتظار مدة عرض شاشة البداية لتجربة مستخدم سلسة
    await Future.delayed(const Duration(milliseconds: 2800));

    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      await AppSession().loadFromPrefs();
      final session = AppSession();
      if (session.isAdminOrDeanship) {
        return 'admin';
      } else if (session.userRole.isNotEmpty) {
        return 'mobile';
      } else {
        return 'login';
      }
    } else {
      return 'login';
    }
  }
}
