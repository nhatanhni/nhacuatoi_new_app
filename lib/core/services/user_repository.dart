import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserRepository {
  // ─── Token storage ────────────────────────────────────────────────────────

  /// Saves access + refresh tokens from the login response.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', accessToken);
    await prefs.setString('refreshToken', refreshToken);
  }

  Future<String> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken') ?? '';
  }

  Future<String> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken') ?? '';
  }

  // ─── User info storage (from /me response) ────────────────────────────────

  /// Persists all fields from the /api/Sys_Account/me response Data object.
  Future<void> saveUserInfo(Map<String, dynamic> meData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', meData['Id']?.toString() ?? '');
    await prefs.setString('userName', meData['UserName']?.toString() ?? '');
    await prefs.setString('fullName', meData['FullName']?.toString() ?? '');
    await prefs.setString('email', meData['Email']?.toString() ?? '');
    await prefs.setString(
      'roles',
      jsonEncode(meData['Roles'] ?? []),
    );
    await prefs.setString(
      'menus',
      jsonEncode(meData['Menus'] ?? []),
    );
    await prefs.setString(
      'permissions',
      jsonEncode(meData['Permissions'] ?? []),
    );
  }

  /// Loads all stored user info. Returns null if no user info is saved.
  Future<Map<String, dynamic>?> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    if (userId.isEmpty) return null;

    return {
      'userId': userId,
      'userName': prefs.getString('userName') ?? '',
      'fullName': prefs.getString('fullName') ?? '',
      'email': prefs.getString('email') ?? '',
      'accessToken': prefs.getString('accessToken') ?? '',
      'roles': jsonDecode(prefs.getString('roles') ?? '[]'),
      'menus': jsonDecode(prefs.getString('menus') ?? '[]'),
      'permissions': jsonDecode(prefs.getString('permissions') ?? '[]'),
    };
  }

  // ─── Login status ─────────────────────────────────────────────────────────

  Future<void> saveLoginStatus(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
  }

  Future<bool> getLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // ─── Convenience ─────────────────────────────────────────────────────────

  Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userName') ?? '';
  }

  // ─── Clearing ─────────────────────────────────────────────────────────────

  /// Clears only auth tokens and login flag.
  /// Used when token refresh fails (session expired).
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.setBool('isLoggedIn', false);
  }

  /// Clears everything (full logout).
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ─── Legacy aliases (kept for backward compatibility) ─────────────────────

  @Deprecated('Use clearAllData()')
  Future<void> clearUserData() => clearAllData();

  @Deprecated('Use saveLoginStatus(false) or clearTokens()')
  Future<void> clearLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
  }

  @Deprecated('Use loadUserInfo()')
  Future<Map<String, String>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString('userId') ?? '',
      'userName': prefs.getString('userName') ?? '',
      'fullName': prefs.getString('fullName') ?? '',
      'accessToken': prefs.getString('accessToken') ?? '',
    };
  }
}
