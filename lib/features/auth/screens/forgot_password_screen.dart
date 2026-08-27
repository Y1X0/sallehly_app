import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import 'login_screen.dart';
import '../../../core/widgets/success_feedback.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // الخطوة 1 = إدخال البريد، الخطوة 2 = إدخال الكود وكلمة السر الجديدة
  int step = 1;

  final emailController = TextEditingController();
  final otpController = TextEditingController();
  final passwordController = TextEditingController();

  final emailFormKey = GlobalKey<FormState>();
  final resetFormKey = GlobalKey<FormState>();

  bool hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    otpController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> sendCode() async {
    if (!emailFormKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    try {
      final message = await auth.forgotPassword(email: emailController.text);

      if (!mounted) return;

      showInfo(message);
      setState(() {
        step = 2;
      });
    } on ApiException catch (e) {
      showErrorSnackBar(context, e.message);
    } catch (_) {
      showErrorSnackBar(context, AppLocalizations.of(context)!.sendCodeFailedMessage);
    }
  }

  Future<void> resetPassword() async {
    if (!resetFormKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    try {
      final message = await auth.resetPassword(
        email: emailController.text,
        otp: otpController.text,
        newPassword: passwordController.text,
      );

      if (!mounted) return;

      showInfo(message);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      showErrorSnackBar(context, e.message);
    } catch (_) {
      showErrorSnackBar(context, AppLocalizations.of(context)!.resetPasswordFailedMessage);
    }
  }

  void showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final loading = context.watch<AuthProvider>().loading;

    return Scaffold(
      body: AppBackground(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.lock_reset_rounded,
                  size: 76,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  t.forgotPasswordTitle,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  step == 1
                      ? t.forgotPasswordEmailStepSubtitle
                      : t.forgotPasswordResetStepSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                step == 1 ? _buildEmailStep(loading) : _buildResetStep(loading),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  child: Text(t.backToLoginButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep(bool loading) {
    final t = AppLocalizations.of(context)!;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: emailFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: t.emailFieldLabel,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return t.emailRequiredValidation;
                if (!email.contains('@')) return t.emailInvalidValidation;
                return null;
              },
            ),
            const SizedBox(height: 22),
            GradientButton(
              label: t.sendCodeButton,
              icon: Icons.send_rounded,
              loading: loading,
              onPressed: loading ? null : sendCode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetStep(bool loading) {
    final t = AppLocalizations.of(context)!;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: resetFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: otpController,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                letterSpacing: 6,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: t.otpFieldLabel,
                counterText: '',
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
              validator: (value) {
                final code = value?.trim() ?? '';
                if (code.length != 6) {
                  return t.otpLengthValidation;
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
                labelText: t.newPasswordFieldLabel,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: hidePassword ? t.showPasswordTooltip : t.hidePasswordTooltip,
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
                  return t.newPasswordRequiredValidation;
                }
                if (value.length < 8) {
                  return t.newPasswordMinLengthValidation;
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            GradientButton(
              label: t.changePasswordTitle,
              icon: Icons.check_rounded,
              loading: loading,
              onPressed: loading ? null : resetPassword,
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: loading
                  ? null
                  : () {
                      setState(() {
                        step = 1;
                      });
                    },
              child: Text(t.resendCodeLink),
            ),
          ],
        ),
      ),
    );
  }
}
