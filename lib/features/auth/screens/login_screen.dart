// [FEAT-GOOGLESIGNIN-01] firebase_auth يصدّر AuthProvider (صنف أساسي لمزوّدي
// المصادقة كـGoogleAuthProvider) بنفس اسم providers/auth_provider.dart —
// نستخدم فقط FirebaseAuth وGoogleAuthProvider من هذه الحزمة، لا AuthProvider
// نفسه، فإخفاؤه هنا يزيل التعارض دون أي أثر آخر.
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../config/app_config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/google_logo.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../routes/route_guard.dart';
import 'forgot_password_screen.dart';
import 'register_role_screen.dart';
import '../../../core/widgets/success_feedback.dart';

// [FEAT-APPLESIGNIN-01] nonce عشوائي مُجزَّأ (sha256) يربط طلب Sign in with
// Apple برد Firebase ويحمي من إعادة تشغيل (replay) — توصية Apple/Firebase
// الرسمية لهذا التدفّق بالضبط.
String _generateNonce([int length = 32]) {
  const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
}

String _sha256OfString(String input) => sha256.convert(utf8.encode(input)).toString();

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
  bool googleLoading = false;
  bool appleLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// [FEAT-GOOGLESIGNIN-01] راجع auth_provider.dart (loginWithGoogle) —
  /// حالة تحميل محلية منفصلة عن AuthProvider.loading (تغطي فقط مربّع اختيار
  /// حساب جوجل الأصلي + تبادل التوكن، قبل أي استدعاء API فعلي).
  Future<void> signInWithGoogle() async {
    if (AppConfig.googleServerClientId.isEmpty) return;

    setState(() => googleLoading = true);
    final t = AppLocalizations.of(context)!;

    try {
      final account = await GoogleSignIn.instance.authenticate();
      final googleIdToken = account.authentication.idToken;
      if (googleIdToken == null) throw Exception('no google id token');

      final credential = GoogleAuthProvider.credential(idToken: googleIdToken);
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null) throw Exception('no firebase id token');

      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final result = await auth.loginWithGoogle(firebaseIdToken);

      if (!mounted) return;

      if (result.needsRegistration) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterRoleScreen(
              googleIdToken: firebaseIdToken,
              googlePrefillName: result.googleName,
              googlePrefillEmail: result.googleEmail,
            ),
          ),
        );
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => RouteGuard.homeForUser(auth.user),
        ),
        (route) => false,
      );
    } on GoogleSignInException catch (e) {
      // المستخدم أغلق مربّع اختيار الحساب بنفسه — ليس خطأً يستحق رسالة.
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      if (!mounted) return;
      showErrorSnackBar(context, t.googleSignInFailedMessage);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.googleSignInFailedMessage);
    } finally {
      if (mounted) setState(() => googleLoading = false);
    }
  }

  /// [FEAT-APPLESIGNIN-01] نسخة طبق الأصل من signInWithGoogle أعلاه — الفرق
  /// الوحيد: SignInWithApple.getAppleIDCredential بدل GoogleSignIn.instance
  /// (تفويض أصلي عبر iOS نفسه، بلا مربّع اختيار حساب Google)، وnonce مُجزَّأ
  /// يُربَط بـOAuthProvider("apple.com") — راجع Firebase/Apple التوثيق
  /// الرسمي لهذا النمط بالضبط. Apple تعيد givenName/familyName فقط أول مرة
  /// يوافق فيها المستخدم على مشاركتها (لا تتكرر بمحاولات لاحقة لنفس الحساب
  /// على نفس التطبيق) — التعبئة المسبقة بشاشة استكمال التسجيل قد تكون فارغة
  /// بمحاولات لاحقة، وهذا سلوك Apple نفسه لا عطل بكودنا.
  Future<void> signInWithApple() async {
    setState(() => appleLoading = true);
    final t = AppLocalizations.of(context)!;

    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256OfString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null) throw Exception('no firebase id token');

      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final result = await auth.loginWithApple(firebaseIdToken);

      if (!mounted) return;

      if (result.needsRegistration) {
        final appleName = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].where((s) => s != null && s.isNotEmpty).join(' ');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterRoleScreen(
              appleIdToken: firebaseIdToken,
              applePrefillName: appleName.isNotEmpty ? appleName : result.appleName,
              applePrefillEmail: result.appleEmail,
            ),
          ),
        );
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => RouteGuard.homeForUser(auth.user),
        ),
        (route) => false,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      // المستخدم ألغى مربّع تفويض Apple بنفسه — ليس خطأً يستحق رسالة.
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (!mounted) return;
      showErrorSnackBar(context, t.appleSignInFailedMessage);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.appleSignInFailedMessage);
    } finally {
      if (mounted) setState(() => appleLoading = false);
    }
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    // [SEC-FIX-CTXAWAIT-01] راجع DECISIONS.md.
    final t = AppLocalizations.of(context)!;

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
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.loginGenericErrorMessage);
    }
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
                      t.loginWelcomeBackTitle,
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
                      t.loginSubtitle,
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
                          decoration: InputDecoration(
                            labelText: t.emailFieldLabel,
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return t.emailRequiredValidation;
                            if (!email.contains('@')) {
                              return t.emailInvalidValidation;
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
                            labelText: t.passwordFieldLabel,
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
                          // [FEAT-DEDUP-01] راجع DECISIONS.md — عمداً بلا فحص
                          // طول هنا (بعكس شاشات الإنشاء/التغيير الأربع). حساب
                          // قديم بكلمة سر أقصر من 8 (سياسة سابقة) يجب أن يبقى
                          // قادراً على تسجيل الدخول — الخادم نفسه لا يفرض حداً
                          // أدنى عند الدخول (فقط حد أقصى 72 لحماية bcrypt)،
                          // فالتحقق المحلي هنا يجب ألا يرفض ما سيقبله الخادم.
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return t.passwordRequiredValidation;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),
                        GradientButton(
                          label: t.loginSubmitButton,
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
                          child: Text(t.forgotPasswordLink),
                        ),
                      ],
                    ),
                  ),
                  ),
                  // [FEAT-GOOGLESIGNIN-01] يظهر فقط بعد ضبط Web client ID
                  // فعلياً (راجع AppConfig.googleServerClientId) — بدل زر
                  // معطَّل بصمت بأي نسخة لم تُضبَط بعد.
                  if (AppConfig.googleServerClientId.isNotEmpty ||
                      Platform.isIOS) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            t.orDividerLabel,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.border)),
                      ],
                    ),
                    if (AppConfig.googleServerClientId.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _GoogleSignInButton(
                        loading: googleLoading,
                        enabled: !loading && !googleLoading && !appleLoading,
                        label: t.signInWithGoogleButton,
                        onPressed: signInWithGoogle,
                      ),
                    ],
                    // [FEAT-APPLESIGNIN-01] Sign in with Apple لا معنى له خارج
                    // iOS/macOS (لا مزوّد أصلي على أندرويد) — يظهر فقط على iOS،
                    // بعكس زر جوجل المشروط بضبط Web client ID فقط بغض النظر
                    // عن المنصة.
                    if (Platform.isIOS) ...[
                      const SizedBox(height: 14),
                      _AppleSignInButton(
                        loading: appleLoading,
                        enabled: !loading && !googleLoading && !appleLoading,
                        label: t.signInWithAppleButton,
                        onPressed: signInWithApple,
                      ),
                    ],
                  ],
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
                    child: Text(t.noAccountCreateOneLink),
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

/// [FEAT-GOOGLESIGNIN-01] زر "المتابعة بحساب جوجل" بالتصميم الرسمي المعتمَد
/// من جوجل لأزرار تسجيل الدخول (خلفية بيضاء ثابتة بغض النظر عن الوضع
/// الداكن/الفاتح للتطبيق — هذا مقصود، وليس نسياناً لاستخدام AppColors: زر
/// جوجل يجب أن يبقى بهويته البصرية الرسمية دائماً، لا يتبع تصميم التطبيق).
class _GoogleSignInButton extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  const _GoogleSignInButton({
    required this.loading,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Color(0xFF757575),
                    ),
                  )
                else
                  const GoogleLogo(size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF3C4043),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [FEAT-APPLESIGNIN-01] زر "المتابعة بحساب Apple" بالتصميم الرسمي المعتمَد
/// من Apple (Human Interface Guidelines): خلفية سوداء ثابتة + شعار/نص أبيض،
/// بغض النظر عن الوضع الداكن/الفاتح للتطبيق — نفس فلسفة زر جوجل أعلاه
/// بالضبط (هوية بصرية رسمية ثابتة، لا تتبع تصميم التطبيق).
class _AppleSignInButton extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  const _AppleSignInButton({
    required this.loading,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(Icons.apple, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}