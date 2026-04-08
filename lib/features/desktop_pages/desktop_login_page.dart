// import 'package:flutter/material.dart';
// import '../../core/theme/desktop_theme.dart'; // تأكد من صحة المسار

// class LoginPage extends StatelessWidget {
//   const LoginPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: DesktopColors.primary,
//       body: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Expanded(
//             flex: 1,
//             child: Container(
//                 color: DesktopColors.background,
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Image.asset(
//                     'images/uni_logo.png',
//                     height: 250,
//                   ),
//                   const SizedBox(height: DesktopSpacing.lg),
//                   Text(
//                     'منصة موحدة لإدارة الشؤون الأكاديمية',
//                     style: DesktopTextStyles.heading2.copyWith(
//                       color: DesktopColors.primaryDark,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           Expanded(
//             flex: 2,
//             child: Center(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.all(DesktopSpacing.xl),
//                 child: Container(

//                   child: Card(
//                     color: DesktopColors.background.withOpacity(1),
//                     elevation: 4,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     child: Padding(
//                       padding: const EdgeInsets.all(DesktopSpacing.lg),
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           // أيقونة صغيرة في الأعلى
//                           Icon(Icons.school, color: DesktopColors.primary, size: 40),
//                           const SizedBox(height: DesktopSpacing.md),

//                           const Text(
//                             'نظام إدارة الشؤون الأكاديمية',
//                             style: DesktopTextStyles.heading2,
//                             textAlign: TextAlign.center,
//                           ),
//                           const Text(
//                             'Academic Management System',
//                             style: DesktopTextStyles.caption,
//                           ),
//                           const SizedBox(height: DesktopSpacing.lg),

//                           // حقل اسم المستخدم
//                           _buildInputLabel("اسم المستخدم"),
//                           const TextField(
//                             decoration: InputDecoration(
//                               hintText: 'أدخل اسم المستخدم أو البريد الجامعي',
//                               prefixIcon: Icon(Icons.person_outline),
//                             ),
//                           ),
//                           const SizedBox(height: DesktopSpacing.md),

//                           // حقل كلمة المرور
//                           _buildInputLabel("كلمة المرور"),
//                           const TextField(
//                             obscureText: true,
//                             decoration: InputDecoration(
//                               hintText: 'أدخل كلمة المرور',
//                               prefixIcon: Icon(Icons.lock_outline),
//                               suffixIcon: Icon(Icons.visibility_outlined),
//                             ),
//                           ),
//                           const SizedBox(height: DesktopSpacing.sm),

//                           // تذكرني ونسيت كلمة المرور
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Row(
//                                 children: [
//                                   Checkbox(value: false, onChanged: (v) {}),
//                                   const Text("تذكرني على هذا الجهاز"),
//                                 ],
//                               ),
//                               TextButton(
//                                 onPressed: () {},
//                                 child: const Text("نسيت كلمة المرور؟"),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: DesktopSpacing.lg),

//                           // زر الدخول
//                           SizedBox(
//                             width: double.infinity,
//                             child: ElevatedButton(
//                               onPressed: () {},
//                               child: const Text("دخول"),
//                             ),
//                           ),
//                           const SizedBox(height: DesktopSpacing.md),

//                           // الدعم الفني
//                           TextButton(
//                             onPressed: () {},
//                             child: const Text("مشكلة في تسجيل الدخول؟ تواصل مع الدعم الفني"),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ويدجت مساعد لعنوان الحقول
//   Widget _buildInputLabel(String label) {
//     return Align(
//       alignment: Alignment.centerRight,
//       child: Padding(
//         padding: const EdgeInsets.only(bottom: 8.0),
//         child: Text(
//           label,
//           style: DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import '../../core/theme/desktop_theme.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Color(0xDEDFE5F5),
      body: Container(
        decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(6, 4),
              )
            ],
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.all(
              Radius.circular(50),
            )),
        margin: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: screenHeight * 0.05,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                color: Color(0xDEDFE5F5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'E:/deskop/level4/graduation_project/academic_affairs_management/images/uni_logo.png',
                      height: 250,
                    ),
                    const SizedBox(height: DesktopSpacing.lg),
                    Text(
                      'نظام إدارة الشؤون الأكاديمية',
                      style: DesktopTextStyles.heading2.copyWith(
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(DesktopSpacing.xl),
                  child: Card(
                    color: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(DesktopSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'images/collage_logo.png',
                            height: 100,
                          ),
                          const Text(
                            'كلية الحاسبات',
                            style: DesktopTextStyles.heading2,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: DesktopSpacing.lg),
                          _buildInputLabel("اسم المستخدم"),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'أدخل اسم المستخدم أو البريد الجامعي',
                              prefixIcon: Icon(Icons.person_outline),
                              fillColor: Colors.black.withOpacity(0.05),
                            ),
                          ),
                          const SizedBox(height: DesktopSpacing.md),
                          _buildInputLabel("كلمة المرور"),
                          TextField(
                            obscureText: true,
                            decoration: InputDecoration(
                              hintText: 'أدخل كلمة المرور',
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: Icon(Icons.visibility_outlined),
                              fillColor: Colors.black.withOpacity(.05),
                            ),
                          ),
                          const SizedBox(height: DesktopSpacing.sm),
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
                                child: const Text(
                                  "نسيت كلمة المرور؟",
                                  style:
                                      TextStyle(color: DesktopColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DesktopSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {},
                              child: const Text("دخول"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: DesktopColors.primary),
                            ),
                          ),
                          const SizedBox(height: DesktopSpacing.md),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              "مشكلة في تسجيل الدخول؟ تواصل مع الدعم الفني",
                              style: TextStyle(color: DesktopColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
