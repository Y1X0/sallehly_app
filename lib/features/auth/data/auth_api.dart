import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../models/review_model.dart';
import '../../../models/user_model.dart';

class AuthApi {
  final ApiClient apiClient;

  AuthApi(this.apiClient);

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.login,
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final data = Map<String, dynamic>.from(response.data);
      final userJson = Map<String, dynamic>.from(data['user']);

      // خذ التوكن من جسم الرد مباشرة (أمتن من الاعتماد على الكوكي).
      // إن لم يوجد في الجسم، استخدم التوكن المحفوظ من الكوكي كاحتياط.
      String token = data['token']?.toString() ?? '';
      if (token.isNotEmpty) {
        await apiClient.tokenStorage.saveToken(token);
      } else {
        token = await apiClient.tokenStorage.getToken() ?? '';
      }

      return AuthResult(
        token: token,
        user: UserModel.fromJson(userJson),
      );
    } catch (e) {
      throw apiClient.handleError(e);
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
    try {
      final map = <String, dynamic>{
        'role': role,
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
      };

      if (city != null && city.trim().isNotEmpty) {
        map['city'] = city.trim();
      }

      if (area != null && area.trim().isNotEmpty) {
        map['area'] = area.trim();
        map['areas'] = area.trim();
      }

      if (nationalNumber != null && nationalNumber.trim().isNotEmpty) {
        map['national_number'] = nationalNumber.trim();
      }

      if (services != null && services.isNotEmpty) {
        map['services'] = services.join(',');
      }

      if (areas != null && areas.isNotEmpty) {
        map['areas'] = areas.join(',');
      }

      if (avatarPath != null && avatarPath.isNotEmpty) {
        map['avatar'] = await MultipartFile.fromFile(avatarPath);
      }

      final response = await apiClient.dio.post(
        ApiEndpoints.register,
        data: FormData.fromMap(map),
      );

      final data = Map<String, dynamic>.from(response.data);

      return RegisterResult(
        ok: data['ok'] == true,
        step: data['step']?.toString() ?? '',
        message: data['message']?.toString() ?? 'تم إرسال كود التحقق',
        email: data['email']?.toString() ?? email.trim(),
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<VerifyOtpResult> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.verifyOtp,
        data: {
          'email': email.trim(),
          'otp': otp.trim(),
        },
      );

      final data = Map<String, dynamic>.from(response.data);

      // خذ التوكن من جسم الرد مباشرة (أمتن من الاعتماد على الكوكي).
      String token = data['token']?.toString() ?? '';
      if (token.isNotEmpty) {
        await apiClient.tokenStorage.saveToken(token);
      } else {
        token = await apiClient.tokenStorage.getToken() ?? '';
      }

      return VerifyOtpResult(
        token: token,
        message: data['message']?.toString() ?? 'تم إنشاء الحساب بنجاح',
        user: UserModel.fromJson(
          Map<String, dynamic>.from(data['user']),
        ),
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<String> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.forgotPassword,
        data: {'email': email.trim()},
      );

      final data = Map<String, dynamic>.from(response.data);
      return data['message']?.toString() ??
          'إذا كان البريد مسجلاً ستصلك رسالة التحقق';
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiEndpoints.resetPassword,
        data: {
          'email': email.trim(),
          'otp': otp.trim(),
          'new_password': newPassword,
        },
      );

      final data = Map<String, dynamic>.from(response.data);
      return data['message']?.toString() ?? 'تم تغيير كلمة السر بنجاح';
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<UserModel> me() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.me);
      final data = response.data;

      final userJson = data is Map<String, dynamic> && data['user'] != null
          ? data['user']
          : data;

      return UserModel.fromJson(
        Map<String, dynamic>.from(userJson),
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> logout() async {
    try {
      await apiClient.dio.post(ApiEndpoints.logout);
    } catch (_) {}
  }

  Future<UserModel> updateProfile({
    required String name,
    required String phone,
    String? city,
    String? area,
    List<String>? services,
    String? avatarPath,
  }) async {
    try {
      final map = <String, dynamic>{
        'name': name.trim(),
        'phone': phone.trim(),
      };

      if (city != null && city.trim().isNotEmpty) {
        map['city'] = city.trim();
      }

      if (area != null && area.trim().isNotEmpty) {
        map['area'] = area.trim();
        map['areas'] = area.trim();
      }

      if (services != null && services.isNotEmpty) {
        map['services'] = services.join(',');
      }

      if (avatarPath != null && avatarPath.isNotEmpty) {
        map['avatar'] = await MultipartFile.fromFile(avatarPath);
      }

      final response = await apiClient.dio.post(
        ApiEndpoints.meProfile,
        data: FormData.fromMap(map),
      );

      final data = Map<String, dynamic>.from(response.data);
      final userJson = data['user'] != null
          ? Map<String, dynamic>.from(data['user'])
          : data;

      return UserModel.fromJson(userJson);
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.mePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }

  Future<List<ReviewModel>> getReviews(int technicianId) async {
    try {
      final response = await apiClient.dio.get(
        ApiEndpoints.technicianProfile(technicianId),
      );
      final data = Map<String, dynamic>.from(response.data);

      return (data['reviews'] as List? ?? [])
          .map((e) => ReviewModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw apiClient.handleError(e);
    }
  }
}

class AuthResult {
  final String token;
  final UserModel user;

  AuthResult({
    required this.token,
    required this.user,
  });
}

class RegisterResult {
  final bool ok;
  final String step;
  final String message;
  final String email;

  RegisterResult({
    required this.ok,
    required this.step,
    required this.message,
    required this.email,
  });
}

class VerifyOtpResult {
  final String token;
  final String message;
  final UserModel user;

  VerifyOtpResult({
    required this.token,
    required this.message,
    required this.user,
  });
}