import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/widgets/success_feedback.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final currentController = TextEditingController();
  final newController = TextEditingController();
  final confirmController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  bool hideCurrent = true;
  bool hideNew = true;

  @override
  void dispose() {
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    // [SEC-FIX-CTXAWAIT-01] راجع DECISIONS.md.
    final t = AppLocalizations.of(context)!;

    try {
      await auth.changePassword(
        currentPassword: currentController.text,
        newPassword: newController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.changePasswordSuccessMessage)),
      );

      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.changePasswordFailedMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final loading = context.watch<AuthProvider>().loading;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.changePasswordTitle),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        padding: const EdgeInsets.fromLTRB(22, 90, 22, 22),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Icon(
                Icons.password_rounded,
                size: 70,
                color: AppColors.primary,
              ),
              const SizedBox(height: 20),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: currentController,
                        obscureText: hideCurrent,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: t.currentPasswordFieldLabel,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: hideCurrent ? t.showPasswordTooltip : t.hidePasswordTooltip,
                            onPressed: () {
                              setState(() => hideCurrent = !hideCurrent);
                            },
                            icon: Icon(
                              hideCurrent
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return t.currentPasswordRequiredValidation;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: newController,
                        obscureText: hideNew,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: t.newPasswordFieldLabel,
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          suffixIcon: IconButton(
                            tooltip: hideNew ? t.showPasswordTooltip : t.hidePasswordTooltip,
                            onPressed: () {
                              setState(() => hideNew = !hideNew);
                            },
                            icon: Icon(
                              hideNew
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
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: confirmController,
                        obscureText: hideNew,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: t.confirmNewPasswordFieldLabel,
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                        ),
                        validator: (value) {
                          if (value != newController.text) {
                            return t.passwordsMismatchValidation;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),
                      GradientButton(
                        label: t.savePasswordButton,
                        icon: Icons.check_rounded,
                        loading: loading,
                        onPressed: loading ? null : submit,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
