import 'dart:io'; // نحتاجه لمعرفة نوع النظام
import 'package:academic_affairs_management/features/authentiction/login_view.dart';
import 'package:academic_affairs_management/features/desktop_pages/dashboard_screen/main_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // أضف هذا السطر
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

// ... باقي الاستيرادات

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة SQLite للعمل على سطح المكتب (Windows/Linux)
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 2. تهيئة فايربيس
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. قراءة حالة تسجيل الدخول
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final String? userRole = prefs.getString('userRole');

  runApp(MyApp(
    isLoggedIn: isLoggedIn,
    userRole: userRole,
  ));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String? userRole;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    // 3. تحديد الشاشة الافتراضية (الشاشة الأولى)
    Widget initialScreen;

    if (isLoggedIn && userRole != null) {
      // إذا كان مسجل الدخول، نوجهه للوحة التحكم (ويمكنك لاحقاً توجيهه لشاشات مختلفة حسب الـ role هنا أيضاً)
      initialScreen = const MainShell();
    } else {
      // إذا لم يكن مسجل الدخول، نوجهه لصفحة تسجيل الدخول
      initialScreen = const LoginView();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نظام الإدارة الأكاديمية',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: initialScreen, // استخدام المتغير هنا
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
  }
}
