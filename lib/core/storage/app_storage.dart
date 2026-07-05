import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  static const String _roleKey = 'sallehly_role';
  static const String _userIdKey = 'sallehly_user_id';
  static const String _userNameKey = 'sallehly_user_name';

  Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _roleKey,
      role,
    );
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_roleKey);
  }

  Future<void> saveUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(
      _userIdKey,
      id,
    );
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(_userIdKey);
  }

  Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _userNameKey,
      name,
    );
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_userNameKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_roleKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
  }
}