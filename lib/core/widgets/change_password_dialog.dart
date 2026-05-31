import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'لم يتم العثور على مستخدم مسجل الدخول.',
        );
      }

      // 1. إعادة التحقق من كلمة المرور الحالية (Re-authentication)
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);

      // 2. تحديث كلمة المرور الجديدة
      await user.updatePassword(_newPasswordController.text);

      if (mounted) {
        Navigator.pop(context, true); // إرجاع نجاح
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _mapFirebaseError(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ غير متوقع: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'wrong-password':
        return 'كلمة المرور الحالية غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور الجديدة ضعيفة جداً. يجب أن تتكون من 6 أحرف على الأقل.';
      case 'requires-recent-login':
        return 'تتطلب هذه العملية إعادة تسجيل الدخول لتغيير كلمة المرور.';
      case 'no-user':
        return 'لم يتم العثور على حساب مستخدم نشط.';
      case 'user-mismatch':
        return 'البيانات المدخلة لا تطابق المستخدم الحالي.';
      case 'user-not-found':
        return 'لم يتم العثور على حساب المستخدم.';
      default:
        return 'فشلت عملية تغيير كلمة المرور: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        title: Row(
          children: [
            const Icon(Icons.vpn_key, color: DesktopColors.primary, size: 24),
            const SizedBox(width: 8),
            const Text(
              'تغيير كلمة المرور',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SizedBox(
          width: isMobile ? double.infinity : 400,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[100]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── كلمة المرور الحالية ──
                  const Text(
                    'كلمة المرور الحالية',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: DesktopColors.textPrimary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: _obscureCurrent,
                    validator: (v) => v!.isEmpty ? 'يرجى إدخال كلمة المرور الحالية' : null,
                    decoration: InputDecoration(
                      hintText: 'أدخل كلمة المرور الحالية',
                      hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── كلمة المرور الجديدة ──
                  const Text(
                    'كلمة المرور الجديدة',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: DesktopColors.textPrimary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    validator: (v) {
                      if (v!.isEmpty) return 'يرجى إدخال كلمة المرور الجديدة';
                      if (v.length < 6) return 'يجب أن لا تقل كلمة المرور عن 6 أحرف';
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'أدخل كلمة المرور الجديدة',
                      hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── تأكيد كلمة المرور الجديدة ──
                  const Text(
                    'تأكيد كلمة المرور الجديدة',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: DesktopColors.textPrimary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    validator: (v) {
                      if (v!.isEmpty) return 'يرجى تأكيد كلمة المرور الجديدة';
                      if (v != _newPasswordController.text) return 'كلمتا المرور غير متطابقتين';
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'أعد إدخال كلمة المرور الجديدة',
                      hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_clock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: DesktopColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'حفظ التغييرات',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
