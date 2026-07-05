import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

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

  AuthProvider({
    required this.tokenStorage,
    required ApiClient apiClient,
    required this.appStorage,
  }) {
    authApi = AuthApi(apiClient);
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
    } catch (_) {
      await logout();
    } finally {
      _setLoading(false);
    }
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

      debugPrint('[FCM] Token saved to server ✓');
    } catch (e) {
      debugPrint('[FCM] Token save failed: $e');
    }
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
