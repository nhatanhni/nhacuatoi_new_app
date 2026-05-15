import 'package:shared_preferences/shared_preferences.dart';

class UserRepository {
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('userId', userData['UserId']);
    await prefs.setString('userName', userData['UserName']);
    await prefs.setString('roleName', userData['RoleName']);
    await prefs.setString('accessToken', userData['AccessToken']);
  }

  Future<Map<String, String>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'userId': prefs.getString('userId') ?? '',
      'userName': prefs.getString('userName') ?? '',
      'roleName': prefs.getString('roleName') ?? '',
      'accessToken': prefs.getString('accessToken') ?? '',
    };
  }

  Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userName') ?? '';
  }

  Future<void> saveLoginStatus(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
  }

  Future<bool> getLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> clearLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
  }
}
