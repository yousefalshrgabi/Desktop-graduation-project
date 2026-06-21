import 'dart:io';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:academic_affairs_management/features/authentiction/login_view.dart';
import 'package:academic_affairs_management/features/desktop_pages/dashboard_screen/main_shell.dart';
import 'package:academic_affairs_management/features/mobile_pages/mobile_shell/mobile_shell_view.dart';
import 'package:academic_affairs_management/features/splash/splash_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة SQLite لسطح المكتب
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // تهيئة فايربيس
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // تفعيل التخزين المحلي السحابي (Offline Cache) لجميع المنصات
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firestore settings already initialized: $e');
  }

  // قراءة حالة تسجيل الدخول وتحميل بيانات الجلسة
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  if (isLoggedIn) {
    await AppSession().loadFromPrefs();
  }

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  // دالة ثابتة لإعادة تشغيل التطبيق من أي مكان
  static void restartApp(BuildContext context, {bool? loggedIn}) {
    context.findAncestorStateOfType<_MyAppState>()?.restart(loggedIn);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Key _key = UniqueKey();
  late bool _isLoggedIn;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.isLoggedIn;
  }

  void restart(bool? loggedIn) {
    setState(() {
      if (loggedIn != null) _isLoggedIn = loggedIn;
      _showSplash = false;
      _key =
          UniqueKey(); // تغيير المفتاح يجبر Flutter على إعادة بناء التطبيق بالكامل
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget initialScreen;

    if (_isLoggedIn) {
      final session = AppSession();
      if (session.isAdminOrDeanship) {
        initialScreen = const MainShell();
      } else if (session.userRole.isNotEmpty) {
        initialScreen = const MobileShell();
      } else {
        initialScreen = const LoginView();
      }
    } else {
      initialScreen = const LoginView();
    }

    return KeyedSubtree(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'نظام إدارة الشؤون الأكاديمية',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Cairo',
        ),
        home: _showSplash ? const SplashView() : initialScreen,
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child,
          );
        },
      ),
    );
  }
}
