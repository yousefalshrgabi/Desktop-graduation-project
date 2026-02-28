import 'package:academic_affairs_management/features/users.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 1. تأكد من استيراد هذه المكتبة
import 'firebase_options.dart'; // 2. تأكد من استيراد ملف الإعدادات المولد

void main() async { // 3. يجب أن تكون الدالة async
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نظام الإدارة الأكاديمية',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // تأكد أنك تستدعي صفحتك هنا أو داخل التوجيه (Routes)
      home: const Users(), 
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
  }
}