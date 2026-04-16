import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/features/authentiction/login_view_model.dart';
import 'package:academic_affairs_management/features/desktop_pages/dashboard_screen/main_shell.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // في ملف LoginView.dart، ابحث عن دالة _handleLogin وقم بتحديثها كالتالي:

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus(); // إغلاق الكيبورد

    try {
      await _viewModel.login(
        email: _emailController.text,
        password: _passwordController.text,
        rememberMe: _rememberMe, // تمرير حالة "تذكرني"
      );

      if (!mounted) return;

      if (_viewModel.status == LoginStatus.success) {
        // توجيه المستخدم حسب الصلاحية (Role)
        Widget nextScreen;

        switch (_viewModel.currentUserRole) {
          case 'admin':
            // قم بتغييرها لصفحة الإدمن الخاصة بك
            nextScreen = const MainShell();
            break;
          case 'faculty_member':
            // قم بتغييرها لصفحة عضو هيئة التدريس
            nextScreen = const MainShell();
            break;
          case 'student':
            // قم بتغييرها لصفحة الطالب
            nextScreen = const MainShell();
            break;
          default:
            nextScreen = const MainShell(); // الواجهة الافتراضية
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => nextScreen),
        );
      }
    } catch (e) {
      debugPrint('[LOGIN DEBUG] _handleLogin TOP LEVEL ERROR: $e');
    }
  }

  // دالة لفتح نافذة تفعيل الحساب
  void _showActivationDialog() {
    final TextEditingController actEmailController = TextEditingController();
    final TextEditingController actPasswordController = TextEditingController();
    bool isActivating = false;
    String? activationError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تفعيل حساب جديد',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'أدخل بريدك الإلكتروني المعتمد من الإدارة، ثم اختر كلمة مرور جديدة لحسابك.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: actEmailController,
                      decoration: InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: actPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة (6 أحرف على الأقل)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (activationError != null) ...[
                      const SizedBox(height: 12),
                      Text(activationError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13)),
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

                          try {
                            // استدعاء دالة التفعيل من الـ ViewModel
                            await _viewModel.activateAccount(
                              email: actEmailController.text,
                              newPassword: actPasswordController.text,
                            );

                            if (_viewModel.status == LoginStatus.success) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_viewModel.errorMessage),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() {
                                activationError = _viewModel.errorMessage;
                                isActivating = false;
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              activationError = 'حدث خطأ: $e';
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
                      : const Text('تفعيل الحساب',
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

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Center(
        child: Container(
          width: size.width * 0.9,
          height: size.height * 0.88,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
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
                child: AnimatedBuilder(
                  animation: _viewModel,
                  builder: (context, child) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48, vertical: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // العنوان
                          const Text(
                            'مرحباً بك 👋',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'أدخل بياناتك لتسجيل الدخول إلى النظام',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 36),

                          // حقل البريد الإلكتروني
                          _buildLabel('البريد الإلكتروني'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailController,
                            hint: 'example@university.edu',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),

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

                          // 👈 التعديل هنا: زر تفعيل الحساب الجديد
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
                                    horizontal: 24, vertical: 12),
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
                ),
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
