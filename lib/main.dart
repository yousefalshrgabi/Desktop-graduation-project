import 'dart:io';
import 'package:academic_affairs_management/features/mobile_pages/mobile_home.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // سطر مهم جداً
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

// استيراد شاشاتك
import 'package:academic_affairs_management/features/authentiction/login_view.dart';
import 'package:academic_affairs_management/features/desktop_pages/dashboard_screen/main_shell.dart';

void main() async {
  // 1. ضمان تهيئة الروابط مع نظام التشغيل
  WidgetsFlutterBinding.ensureInitialized();

  // 2. تهيئة SQLite لسطح المكتب (حل مشكلة الـ Database Crash)
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 3. تهيئة فايربيس
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🛑 حل مشكلة الـ Debug في Windows (Firestore Threading Fix)
  // هذا السطر يمنع الـ Crash في وضع الـ Debug على ويندوز
  if (Platform.isWindows) {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint("Firestore settings already initialized: $e");
    }
  }

  // 4. قراءة حالة تسجيل الدخول
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
    // تحديد الشاشة الابتدائية
    Widget initialScreen = (isLoggedIn && userRole != null)
        ? const MainShell()
        : const LoginView(); // تم تصحيحها هنا لتوجه للـ Login إذا لم يسجل الدخول

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نظام الإدارة الأكاديمية',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo', // يفضل استخدامه لدعم العربية بشكل جميل
      ),
      home://MobileHomePage(),
          initialScreen,
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
  }
}
