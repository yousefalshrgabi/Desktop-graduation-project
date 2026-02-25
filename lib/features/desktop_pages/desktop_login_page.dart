import 'package:flutter/material.dart';
import '../../core/theme/desktop_theme.dart'; // تأكد من صحة المسار

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesktopColors.primary,
      body: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 1,
            child: Container(
                color: DesktopColors.background,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'images/uni_logo.png',
                    height: 250,
                  ),
                  const SizedBox(height: DesktopSpacing.lg),
                  Text(
                    'منصة موحدة لإدارة الشؤون الأكاديمية',
                    style: DesktopTextStyles.heading2.copyWith(
                      color: DesktopColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DesktopSpacing.xl),
                child: Container(
                 
                  child: Card(
                    color: DesktopColors.background.withOpacity(1),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(DesktopSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // أيقونة صغيرة في الأعلى
                          Icon(Icons.school, color: DesktopColors.primary, size: 40),
                          const SizedBox(height: DesktopSpacing.md),

                          const Text(
                            'نظام إدارة الشؤون الأكاديمية',
                            style: DesktopTextStyles.heading2,
                            textAlign: TextAlign.center,
                          ),
                          const Text(
                            'Academic Management System',
                            style: DesktopTextStyles.caption,
                          ),
                          const SizedBox(height: DesktopSpacing.lg),

                          // حقل اسم المستخدم
                          _buildInputLabel("اسم المستخدم"),
                          const TextField(
                            decoration: InputDecoration(
                              hintText: 'أدخل اسم المستخدم أو البريد الجامعي',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: DesktopSpacing.md),

                          // حقل كلمة المرور
                          _buildInputLabel("كلمة المرور"),
                          const TextField(
                            obscureText: true,
                            decoration: InputDecoration(
                              hintText: 'أدخل كلمة المرور',
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: Icon(Icons.visibility_outlined),
                            ),
                          ),
                          const SizedBox(height: DesktopSpacing.sm),

                          // تذكرني ونسيت كلمة المرور
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(value: false, onChanged: (v) {}),
                                  const Text("تذكرني على هذا الجهاز"),
                                ],
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text("نسيت كلمة المرور؟"),
                              ),
                            ],
                          ),
                          const SizedBox(height: DesktopSpacing.lg),

                          // زر الدخول
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {},
                              child: const Text("دخول"),
                            ),
                          ),
                          const SizedBox(height: DesktopSpacing.md),

                          // الدعم الفني
                          TextButton(
                            onPressed: () {},
                            child: const Text("مشكلة في تسجيل الدخول؟ تواصل مع الدعم الفني"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ويدجت مساعد لعنوان الحقول
  Widget _buildInputLabel(String label) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          label,
          style: DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}