import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../providers/auth_provider.dart';
import '../../../routes/route_guard.dart';
import 'forgot_password_screen.dart';
import 'register_role_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  bool hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    try {
      await auth.login(
        email: emailController.text,
        password: passwordController.text,
      );

      if (!mounted) return;

      // [FIX-BACK-LOGOUT-01] كانت هذه الشاشة تستخدم pushReplacement، وهو
      // بيستبدل شاشة تسجيل الدخول نفسها بس — أي شاشة تحتها بالمكدّس (متل
      // شاشة الهبوط اللي فتحت منها تسجيل الدخول أصلاً عبر Navigator.push)
      // تضل موجودة! وهيك Navigator.canPop() بيصير true داخل لوحة الأدمن/
      // العميل/الفني، فيضيف Flutter تلقائياً سهم رجوع بأعلى الشاشة — والضغط
      // عليه يرجّع المستخدم لشاشة ما قبل تسجيل الدخول (يشبه تسجيل خروج فعلي
      // بدون تنظيف الجلسة بشكل صحيح). الحل: pushAndRemoveUntil يمسح كل شي
      // تحته، تماماً متل الاستخدام الصحيح أصلاً بـ verify_otp_screen.dart.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => RouteGuard.homeForUser(auth.user),
        ),
        (route) => false,
      );
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('حدث خطأ أثناء تسجيل الدخول');
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;

    return Scaffold(
      body: AppBackground(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  const FadeIn(
                    child: AppLogo(
                      size: 74,
                      showText: false,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FadeIn(
                    delay: Duration(milliseconds: 90),
                    child: Text(
                      'أهلاً بعودتك',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeIn(
                    delay: Duration(milliseconds: 160),
                    child: Text(
                      'سجّل دخولك لإدارة طلباتك ومحادثاتك',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeIn(
                    delay: const Duration(milliseconds: 240),
                    child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return 'أدخل البريد الإلكتروني';
                            if (!email.contains('@')) {
                              return 'البريد الإلكتروني غير صحيح';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: passwordController,
                          obscureText: hidePassword,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: hidePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                              onPressed: () {
                                setState(() {
                                  hidePassword = !hidePassword;
                                });
                              },
                              icon: Icon(
                                hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'أدخل كلمة المرور';
                            }
                            if (value.length < 6) {
                              return 'كلمة المرور قصيرة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),
                        GradientButton(
                          label: 'تسجيل الدخول',
                          icon: Icons.login_rounded,
                          loading: loading,
                          onPressed: loading ? null : submit,
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: loading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ],
                    ),
                  ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterRoleScreen(),
                        ),
                      );
                    },
                    child: const Text('ليس لديك حساب؟ إنشاء حساب جديد'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}