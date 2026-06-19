import 'package:academic_affairs_management/main.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/features/authentiction/login_view_model.dart';
import 'package:academic_affairs_management/features/desktop_pages/dashboard_screen/main_shell.dart';
import 'package:academic_affairs_management/features/mobile_pages/mobile_shell/mobile_shell_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final LoginViewModel _viewModel = LoginViewModel();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _skipSync = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // في ملف LoginView.dart، ابحث عن دالة _handleLogin وقم بتحديثها كالتالي:

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    try {
      await _viewModel.login(
        email: _emailController.text,
        password: _passwordController.text,
        rememberMe: _rememberMe,
        skipSync: _skipSync,
      );

      if (!mounted) return;

      if (_viewModel.status == LoginStatus.success) {
        // تحميل بيانات الجلسة
        await AppSession().loadFromPrefs();
        if (!mounted) return;

        // إعادة تشغيل التطبيق ليدخل في حالة "مسجل دخول" وينتقل للواجهة الصحيحة
        MyApp.restartApp(context, loggedIn: true);
      }
    } catch (e) {
      debugPrint('[LOGIN DEBUG] _handleLogin ERROR: $e');
    }
  }

  // دالة نافذة طلب رابط التفعيل
  void _showActivationDialog() {
    final TextEditingController actEmailController = TextEditingController();
    bool isActivating = false;
    String? activationError;

    showDialog(
      context: context,
      barrierDismissible: false, // لا يغلق عند الضغط خارج النافذة أثناء التحميل
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تفعيل حسابك',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'أدخل بريدك الإلكتروني المسجل لدينا. سنرسل لك رابطاً آمناً لإنشاء كلمة مرور خاصة بك.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: actEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: const Icon(Icons.mark_email_read_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (activationError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!)),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(activationError!,
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 12))),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isActivating ? null : () => Navigator.pop(context),
                  child:
                      const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isActivating
                      ? null
                      : () async {
                          setDialogState(() {
                            isActivating = true;
                            activationError = null;
                          });

                          await _viewModel
                              .sendActivationLink(actEmailController.text);

                          if (_viewModel.status == LoginStatus.success) {
                            if (context.mounted) {
                              Navigator.pop(context); // إغلاق النافذة
                              // إظهار رسالة النجاح الخضراء
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle,
                                          color: Colors.white),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Text(_viewModel.errorMessage)),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          } else {
                            // إظهار الخطأ داخل النافذة
                            setDialogState(() {
                              activationError = _viewModel.errorMessage;
                              isActivating = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: DesktopColors.primary),
                  child: isActivating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('إرسال رابط التفعيل',
                          style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 750;

    Widget buildLoginForm() {
      return AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : 48, vertical: isMobile ? 24 : 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMobile) ...[
                  // شعار صغير في الأعلى للجوال
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'images/uni_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.school,
                            size: 40,
                            color: Color(0xFF0123C9),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'نظام إدارة الشؤون الأكاديمية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF0123C9),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // العنوان
                Text(
                  'مرحباً بك 👋',
                  style: TextStyle(
                    fontSize: isMobile ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'أدخل بياناتك لتسجيل الدخول إلى النظام',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // حقل البريد الإلكتروني
                _buildLabel('البريد الإلكتروني'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _emailController,
                  hint: 'example@university.edu',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // حقل كلمة المرور
                _buildLabel('كلمة المرور'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _passwordController,
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 12),

                // تذكرني والنسيان
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            activeColor: DesktopColors.primary,
                            onChanged: (v) => setState(
                                () => _rememberMe = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('تذكرني',
                            style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'نسيت كلمة المرور؟',
                        style: TextStyle(
                          color: DesktopColors.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // تسجيل دخول سريع (بدون مزامنة)
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _skipSync,
                        activeColor: Colors.orange,
                        onChanged: (v) => setState(() => _skipSync = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('دخول سريع (تخطي تنزيل البيانات من الإنترنت)',
                        style: TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),

                // رسالة الخطأ
                if (_viewModel.status == LoginStatus.error)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _viewModel.errorMessage,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // زر الدخول
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        _viewModel.status == LoginStatus.loading
                            ? null
                            : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesktopColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: _viewModel.status == LoginStatus.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // زر تفعيل الحساب الجديد
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _showActivationDialog,
                    icon:
                        const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text(
                        'أول مرة تستخدم النظام؟ فعّل حسابك هنا'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesktopColors.primary,
                      side: const BorderSide(
                          color: DesktopColors.primary),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // الدعم الفني
                Center(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.support_agent,
                        size: 16, color: Colors.grey),
                    label: const Text(
                      'مشكلة في الدخول؟ تواصل مع الدعم الفني',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Center(
        child: Container(
          width: isMobile ? size.width : size.width * 0.9,
          height: isMobile ? size.height : size.height * 0.88,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 0 : 24),
            boxShadow: isMobile
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: isMobile
              ? SafeArea(child: buildLoginForm())
              : Row(
                  children: [
                    // القسم الأيسر - الشعار والمعلومات
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF0123C9),
                              const Color(0xFF0123C9).withOpacity(0.75),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // شعار الجامعة
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'images/uni_logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.school,
                                    size: 80,
                                    color: Color(0xFF0123C9),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              'نظام إدارة الشؤون الأكاديمية',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: 60,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Academic Affairs Management System',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // القسم الأيمن - نموذج الدخول
                    Expanded(
                      flex: 6,
                      child: buildLoginForm(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: keyboardType,
      onSubmitted: (_) => _handleLogin(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey[400],
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DesktopColors.primary, width: 2),
        ),
      ),
    );
  }
}
