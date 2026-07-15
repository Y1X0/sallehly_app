import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/storage/app_storage.dart';
import '../core/storage/token_storage.dart';
import '../features/auth/data/auth_api.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final TokenStorage tokenStorage;
  final AppStorage appStorage;

  late final AuthApi authApi;

  // [FIX-TEST-01] معامل اختياري جديد يسمح بحقن AuthApi جاهز (Mock) للاختبار،
  // بدون أي تأثير على أي مكان يُنشئ AuthProvider حالياً (app.dart لا يمرره
  // إطلاقاً، فيبقى السلوك الفعلي — AuthApi(apiClient) — كما هو تماماً).
  AuthProvider({
    required this.tokenStorage,
    required ApiClient apiClient,
    required this.appStorage,
    AuthApi? authApiOverride,
  }) {
    authApi = authApiOverride ?? AuthApi(apiClient);
  }

  UserModel? _user;
  bool _loading = false;
  String? _error;

  /// تُستدعى بعد نجاح تسجيل الدخول أو استعادة الجلسة → لإعادة وصل السوكت.
  Future<void> Function()? onAuthenticated;

  /// تُستدعى عند تسجيل الخروج → لقطع السوكت.
  void Function()? onLoggedOut;

  UserModel? get user => _user;
  bool get loading => _loading;
  String? get error => _error;

  bool get isLoggedIn => _user != null;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);

    try {
      await tokenStorage.clearToken();
      await appStorage.clear();

      _user = null;

      final result = await authApi.login(
        email: email,
        password: password,
      );

      await _saveSession(
        token: result.token,
        user: result.user,
      );

      _user = result.user;
      _error = null;

      await _sendFcmTokenToServer();

      // أعد وصل السوكت بتوكن المستخدم الجديد.
      await onAuthenticated?.call();

      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } catch (_) {
      _error = 'حدث خطأ غير متوقع';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<RegisterResult> register({
    required String role,
    required String name,
    required String email,
    required String phone,
    required String password,
    String? city,
    String? area,
    String? nationalNumber,
    List<String>? services,
    List<String>? areas,
    String? avatarPath,
  }) async {
    _setLoading(true);

    try {
      final result = await authApi.register(
        role: role,
        name: name,
        email: email,
        phone: phone,
        password: password,
        city: city,
        area: area,
        nationalNumber: nationalNumber,
        services: services,
        areas: areas,
        avatarPath: avatarPath,
      );

      _error = null;
      return result;
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } catch (_) {
      _error = 'حدث خطأ غير متوقع';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<VerifyOtpResult> verifyOtp({
    required String email,
    required String otp,
  }) async {
    _setLoading(true);

    try {
      await tokenStorage.clearToken();
      await appStorage.clear();

      _user = null;

      final result = await authApi.verifyOtp(
        email: email,
        otp: otp,
      );

      await _saveSession(
        token: result.token,
        user: result.user,
      );

      _user = result.user;
      _error = null;

      await _sendFcmTokenToServer();

      // أعد وصل السوكت بتوكن المستخدم الجديد.
      await onAuthenticated?.call();

      notifyListeners();

      return result;
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } catch (_) {
      _error = 'حدث خطأ غير متوقع';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<String> forgotPassword({required String email}) async {
    _setLoading(true);
    try {
      final message = await authApi.forgotPassword(email: email);
      _error = null;
      return message;
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } catch (_) {
      _error = 'حدث خطأ غير متوقع';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      final message = await authApi.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
      _error = null;
      return message;
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } catch (_) {
      _error = 'حدث خطأ غير متوقع';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// يُحدّث بيانات المستخدم (ومنها الرصيد) فوراً عند استلام حدث من السيرفر.
  Future<void> refreshUser() async {
    if (_user == null) return;
    try {
      _user = await authApi.me();
      notifyListeners();
    } catch (_) {}
  }

  Future<List<ReviewModel>> getMyReviews() async {
    final id = _user?.id;
    if (id == null) return [];
    return authApi.getReviews(id);
  }

  Future<void> loadMe() async {
    _setLoading(true);

    try {
      final hasToken = await tokenStorage.hasToken();

      if (!hasToken) {
        _user = null;
        notifyListeners();
        return;
      }

      _user = await authApi.me();

      await appStorage.saveRole(_user!.role);
      await appStorage.saveUserId(_user!.id);
      await appStorage.saveUserName(_user!.name);

      _error = null;

      await _sendFcmTokenToServer();

      // وصل السوكت بعد استعادة الجلسة المحفوظة.
      await onAuthenticated?.call();

      notifyListeners();
    } on ApiException catch (e) {
      // [FIX-AUTH-01] + [FIX-SESSION-02] امسح الجلسة فقط إذا رفض السيرفر
      // التوكن صراحةً (401 = توكن غير صالح/منتهي، 403 = ممنوع). أي خطأ آخر
      // — انقطاع شبكة، مهلة اتصال، بطء خادم (كولد ستارت)، أو 5xx — لا علاقة
      // له بصحة التوكن، فلا يُسجَّل خروج المستخدم بسببه ولا تُمسح جلسته
      // المحفوظة؛ يبقى مسجّل دخول محلياً وستُعاد المحاولة لاحقاً بشكل طبيعي.
      // بدل تجاهل الخطأ بصمت، نحفظ رسالته في _error ونُخطر الواجهة حتى
      // تقدر تعرضه للمستخدم لو احتاجت.
      if (e.statusCode == 401 || e.statusCode == 403) {
        await logout();
      } else {
        _error = e.message;
        notifyListeners();
      }
    } catch (_) {
      // خطأ غير متوقع لا علاقة له بصلاحية التوكن (مثال: فشل تحويل JSON) —
      // لا تمسح الجلسة أيضاً؛ اترك التوكن كما هو ودع المستخدم يعيد المحاولة.
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// [FIX-AUTH-01] يُستدعى من ApiClient.onUnauthorized عند 401 حقيقي فقط.
  /// الشرط isLoggedIn ضروري: طلب تسجيل الدخول بكلمة سر خاطئة يرجع 401 أيضاً
  /// وهو أمر طبيعي تماماً وليس "انتهاء جلسة" — فلا يجوز تنظيف أي شيء حينها
  /// (لا يوجد أصلاً جلسة لتنظيفها بهذه الحالة).
  Future<void> handleUnauthorized() async {
    if (!isLoggedIn) return;
    await logout();
  }

  Future<void> logout() async {
    try {
      await authApi.logout();
    } catch (_) {}

    await tokenStorage.clearToken();
    await appStorage.clear();

    _user = null;
    _error = null;

    // اقطع السوكت حتى لا يبقى متصلاً بتوكن قديم.
    onLoggedOut?.call();

    notifyListeners();
  }

  /// حذف الحساب نهائياً (متطلّب سياسة Google Play لحذف الحساب).
  /// يرمي [ApiException] إن رفض السيرفر الحذف (كلمة سر خاطئة، طلب نشط،
  /// رصيد متبقٍّ) — الشاشة تعرض رسالة الخطأ كما هي للمستخدم.
  /// عند النجاح، تنظّف الجلسة محلياً بنفس أسلوب logout() تماماً.
  Future<void> deleteAccount({required String password}) async {
    await authApi.deleteAccount(password: password);

    await tokenStorage.clearToken();
    await appStorage.clear();

    _user = null;
    _error = null;

    onLoggedOut?.call();

    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    String? city,
    String? area,
    List<String>? services,
    String? avatarPath,
  }) async {
    _setLoading(true);
    try {
      final updated = await authApi.updateProfile(
        name: name,
        phone: phone,
        city: city,
        area: area,
        services: services,
        avatarPath: avatarPath,
      );

      _user = updated;
      await appStorage.saveUserName(updated.name);
      _error = null;

      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } catch (_) {
      _error = 'حدث خطأ غير متوقع';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      await authApi.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } catch (_) {
      _error = 'حدث خطأ غير متوقع';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _saveSession({
    required String token,
    required UserModel user,
  }) async {
    await tokenStorage.clearToken();

    if (token.trim().isNotEmpty) {
      await tokenStorage.saveToken(token.trim());
    }

    await appStorage.saveRole(user.role);
    await appStorage.saveUserId(user.id);
    await appStorage.saveUserName(user.name);
  }

  Future<void> _sendFcmTokenToServer() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken == null || fcmToken.trim().isEmpty) return;

      // الـendpoint الصح على السيرفر هو /api/fcm-token
      await authApi.apiClient.dio.post(
        '/fcm-token',
        data: {'token': fcmToken.trim()},
      );

      if (kDebugMode) debugPrint('[FCM] Token saved to server ✓');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Token save failed: $e');
    }
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
