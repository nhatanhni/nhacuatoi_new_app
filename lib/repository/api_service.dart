import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String _baseUrl = 'http://nhacuatoi.com.vn:3000';

  // Register
  Future<Map<String, dynamic>> signUp(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/Sys_Account/Signup'),
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200 && responseBody['Success']) {
      return responseBody;
    } else {
      throw Exception(responseBody['Message'] ?? 'Đăng ký thất bại');
    }
  }

  // Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/Sys_Account/Login'),
      body: jsonEncode({'username': username, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200 && responseBody['Success']) {
      return responseBody;
    } else {
      throw Exception(responseBody['Message'] ?? 'Đăng nhập thất bại');
    }
  }

  // Get User Info
  Future<Map<String, dynamic>> getUserInfo(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/Sys_Account/Info'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200 && responseBody['Success']) {
      return responseBody;
    } else {
      throw Exception(responseBody['Message'] ?? 'Lấy thông tin người dùng thất bại');
    }
  }

  // Delete User By Id
  Future<void> deleteUserById(String id, String token) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/Sys_User/DeleteById/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode != 200 || !responseBody['Success']) {
      throw Exception(responseBody['Message'] ?? 'Xóa người dùng thất bại');
    }
  }

  // Fetch water meter data by serial, tự động lấy token từ SharedPreferences
  Future<Map<String, dynamic>> fetchWaterMeterData(String serial) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    final response = await http.get(
      Uri.parse('$_baseUrl/api/Iot_Metters/GetDataSerial/$serial'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Lỗi kết nối server: ${response.statusCode}');
    }
    if (response.body.isEmpty) {
      throw Exception('Không có dữ liệu trả về từ server');
    }
    final responseBody = jsonDecode(response.body);
    if (responseBody['Success'] == true) {
      return responseBody;
    } else {
      throw Exception(responseBody['Message'] ?? 'Lấy dữ liệu đồng hồ nước thất bại');
    }
  }
}
