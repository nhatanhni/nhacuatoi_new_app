import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iot_app/core/config/app_config.dart';
import 'package:iot_app/core/network/auth_http_client.dart';

class ApiService {
  final String _baseUrl = AppConfig.apiBaseUrl;
  final AuthHttpClient _authClient;

  ApiService({required AuthHttpClient authClient}) : _authClient = authClient;

  // Register (unauthenticated)
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

  // Login (unauthenticated)
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/Sys_Account/Login'),
      body: jsonEncode({'username': username, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );

    print(Uri.parse('$_baseUrl/api/Sys_Account/Login'));
    print(jsonEncode({'username': username, 'password': password}));

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200 && responseBody['Success']) {
      return responseBody;
    } else {
      throw Exception(responseBody['Message'] ?? 'Đăng nhập thất bại');
    }
  }

  // Get current user profile from /me endpoint
  Future<Map<String, dynamic>> getMe() async {
    final response = await _authClient.get(
      Uri.parse('$_baseUrl/api/Sys_Account/me'),
    );
    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return responseBody['Data'] as Map<String, dynamic>? ?? responseBody;
    }
    throw Exception(responseBody['Message'] ?? 'Lấy thông tin người dùng thất bại');
  }

  // Logout (fail-safe — never throws)
  Future<void> logout({String refreshToken = ''}) async {
    try {
      await _authClient.post(
        Uri.parse('$_baseUrl/api/Sys_Account/Logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
    } catch (_) {
      // Ignore errors; local session will be cleared regardless
    }
  }

  // Get User Info
  Future<Map<String, dynamic>> getUserInfo() async {
    final response = await _authClient.get(
      Uri.parse('$_baseUrl/api/Sys_Account/Info'),
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200 && responseBody['Success']) {
      return responseBody;
    } else {
      throw Exception(
        responseBody['Message'] ?? 'Lấy thông tin người dùng thất bại',
      );
    }
  }

  // Delete User By Id
  Future<void> deleteUserById(String id) async {
    final response = await _authClient.delete(
      Uri.parse('$_baseUrl/api/Sys_User/DeleteById/$id'),
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode != 200 || !responseBody['Success']) {
      throw Exception(responseBody['Message'] ?? 'Xóa người dùng thất bại');
    }
  }

  // Fetch water meter data by serial
  Future<Map<String, dynamic>> fetchWaterMeterData(String serial) async {
    final response = await _authClient.get(
      Uri.parse('$_baseUrl/api/Iot_Metters/GetDataSerial/$serial'),
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
      throw Exception(
        responseBody['Message'] ?? 'Lấy dữ liệu đồng hồ nước thất bại',
      );
    }
  }

  // Get all devices of user
  Future<List<dynamic>> fetchUserDevices() async {
    final response = await _authClient.get(
      Uri.parse('$_baseUrl/api/Iot_DeviceType/1/500/500'),
    );
    if (response.statusCode != 200) {
      throw Exception('Lỗi kết nối server: ${response.statusCode}');
    }
    if (response.body.isEmpty) {
      throw Exception('Không có dữ liệu trả về từ server');
    }
    final responseBody = jsonDecode(response.body);
    if (responseBody['Success'] == true) {
      return responseBody['Data']['Items'] as List<dynamic>;
    } else {
      throw Exception(
        responseBody['Message'] ?? 'Lấy danh sách thiết bị thất bại',
      );
    }
  }

  // Get manage device list of user (paged)
  Future<Map<String, dynamic>> fetchManageDevices({
    int page = 1,
    int pageSize = 10,
    int totalLimitItems = 500,
  }) async {
    final response = await _authClient.get(
      Uri.parse(
        '$_baseUrl/api/Iot_Device/paged',
      ).replace(
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
          'totalLimitItems': totalLimitItems.toString(),
        },
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Lỗi kết nối server: ${response.statusCode}');
    }
    if (response.body.isEmpty) {
      throw Exception('Không có dữ liệu trả về từ server');
    }

    final responseBody = jsonDecode(response.body);
    if (responseBody['Success'] == true) {
      final data = responseBody['Data'];
      if (data is Map<String, dynamic>) {
        final items = data['Items'];
        return {
          'items': items is List<dynamic> ? items : <dynamic>[],
          'totalItems': (data['TotalItems'] ?? 0) as int,
          'pageSize': (data['PageSize'] ?? pageSize) as int,
          'pageIndex': (data['PageIndex'] ?? page) as int,
          'minPage': (data['MinPage'] ?? 1) as int,
          'maxPage': (data['MaxPage'] ?? page) as int,
        };
      }
      return {
        'items': <dynamic>[],
        'totalItems': 0,
        'pageSize': pageSize,
        'pageIndex': page,
        'minPage': 1,
        'maxPage': 1,
      };
    }

    throw Exception(
      responseBody['Message'] ?? 'Lấy danh sách thiết bị thất bại',
    );
  }

  // Get device detail by id
  Future<Map<String, dynamic>> fetchDeviceDetailById(String id) async {
    final response = await _authClient.get(
      Uri.parse('$_baseUrl/api/Iot_Device/detail/$id'),
    );

    if (response.statusCode != 200) {
      throw Exception('Lỗi kết nối server: ${response.statusCode}');
    }
    if (response.body.isEmpty) {
      throw Exception('Không có dữ liệu trả về từ server');
    }

    final responseBody = jsonDecode(response.body);
    if (responseBody['Success'] == true) {
      final data = responseBody['Data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw Exception('Dữ liệu chi tiết thiết bị không hợp lệ');
    }

    throw Exception(
      responseBody['Message'] ?? 'Lấy chi tiết thiết bị thất bại',
    );
  }

  // Create device on server
  Future<Map<String, dynamic>> createDevice(
    Map<String, dynamic> payload,
  ) async {
    final response = await _authClient.post(
      Uri.parse('$_baseUrl/api/Iot_Device'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.body.isEmpty) {
      throw Exception('Khong co du lieu tra ve tu server');
    }

    final responseBody = jsonDecode(response.body);
    if (response.statusCode == 200 && responseBody['Success'] == true) {
      return responseBody as Map<String, dynamic>;
    }

    throw Exception(responseBody['Message'] ?? 'Them thiet bi that bai');
  }

  // Delete device on server by id
  Future<void> deleteDeviceOnServer(String deviceId) async {
    final response = await _authClient.delete(
      Uri.parse('$_baseUrl/api/Iot_Device/$deviceId'),
    );

    if (response.body.isEmpty) {
      throw Exception('Khong co du lieu tra ve tu server');
    }

    final responseBody = jsonDecode(response.body);
    if (response.statusCode == 200 && responseBody['Success'] == true) {
      return;
    }

    throw Exception(responseBody['Message'] ?? 'Xoa thiet bi that bai');
  }

  // Get organization units (flattened tree from /api/Sys_Organization/tree)
  Future<List<dynamic>> fetchOrganizationUnits() async {
    final response = await _authClient.get(
      Uri.parse('$_baseUrl/api/Sys_Organization/tree'),
    );
    if (response.statusCode != 200) {
      throw Exception('Lỗi kết nối server: ${response.statusCode}');
    }
    if (response.body.isEmpty) {
      throw Exception('Không có dữ liệu trả về từ server');
    }
    final responseBody = jsonDecode(response.body);
    if (responseBody['Success'] == true) {
      final tree = responseBody['Data'] as List<dynamic>;
      final flat = <dynamic>[];
      _flattenOrgTree(tree, flat);
      return flat;
    }
    throw Exception(
      responseBody['Message'] ?? 'Lấy danh sách đơn vị thất bại',
    );
  }

  void _flattenOrgTree(List<dynamic> nodes, List<dynamic> result) {
    for (final node in nodes) {
      result.add(node);
      final children =
          (node as Map<String, dynamic>)['Children'] as List<dynamic>?;
      if (children != null && children.isNotEmpty) {
        _flattenOrgTree(children, result);
      }
    }
  }

  // Get all stations
  Future<List<dynamic>> fetchStations() async {
    final response = await _authClient.get(
      Uri.parse('$_baseUrl/api/Iot_Station/get-all'),
    );
    if (response.statusCode != 200) {
      throw Exception('Lỗi kết nối server: ${response.statusCode}');
    }
    if (response.body.isEmpty) {
      throw Exception('Không có dữ liệu trả về từ server');
    }
    final responseBody = jsonDecode(response.body);
    if (responseBody['Success'] == true) {
      return responseBody['Data'] as List<dynamic>;
    } else {
      throw Exception(responseBody['Message'] ?? 'Lấy danh sách trạm thất bại');
    }
  }

  // Save history of switching device
  Future<void> saveSwitchDeviceHistory(String deviceId, int isSwitched) async {
    final response = await _authClient.post(
      Uri.parse('$_baseUrl/api/Iot_HisDevice/switch-history'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'deviceId': deviceId, 'isSwitched': isSwitched}),
    );
    if (response.statusCode != 200) {
      throw Exception('Lỗi kết nối server: ${response.statusCode}');
    }
    final responseBody = jsonDecode(response.body);
    if (responseBody['Success'] != true) {
      throw Exception(
        responseBody['Message'] ?? 'Lưu lịch sử thiết bị thất bại',
      );
    }
  }

  // Fetch device history by deviceId
  Future<List<dynamic>> fetchDeviceHistoryByDeviceId(String deviceId) async {
    final response = await _authClient.get(
      Uri.parse(
        '$_baseUrl/api/Iot_HisDevice/switch-history',
      ).replace(queryParameters: {'deviceId': deviceId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Lỗi kết nối server: ${response.statusCode}');
    }
    if (response.body.isEmpty) {
      throw Exception('Không có dữ liệu trả về từ server');
    }
    final responseBody = jsonDecode(response.body);
    if (responseBody['Success'] == true) {
      return responseBody['Data'] as List<dynamic>;
    } else {
      throw Exception(
        responseBody['Message'] ?? 'Lấy lịch sử thiết bị thất bại',
      );
    }
  }

  // ─── Biometrics ───────────────────────────────────────────────────────────

  /// Kích hoạt biometrics cho thiết bị hiện tại.
  /// Trả về `biometricRefreshToken` — token riêng cho biometric login.
  Future<Map<String, dynamic>> enableBiometric({
    required String refreshToken,
    required String deviceId,
    required String deviceName,
  }) async {
    final response = await _authClient.post(
      Uri.parse('$_baseUrl/api/Sys_Account/Biometrics/Enable'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'RefreshToken': refreshToken,
        'DeviceId': deviceId,
        'DeviceName': deviceName,
      }),
    );
    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || responseBody['Success'] != true) {
      throw Exception(
        responseBody['Message'] ?? 'Kích hoạt vân tay thất bại',
      );
    }
    // Trả về data block để BLoC lấy biometricRefreshToken
    return (responseBody['Data'] as Map<String, dynamic>?) ?? {};
  }

  /// Tắt biometrics cho thiết bị cụ thể.
  Future<void> disableBiometric({required String deviceId}) async {
    final response = await _authClient.post(
      Uri.parse('$_baseUrl/api/Sys_Account/Biometrics/Disable'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'DeviceId': deviceId}),
    );
    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || responseBody['Success'] != true) {
      throw Exception(
        responseBody['Message'] ?? 'Tắt vân tay thất bại',
      );
    }
  }

  /// Đổi refreshToken lấy accessToken mới (dùng cho luồng biometric login).
  /// POST /api/Sys_Account/RefreshToken
  Future<Map<String, dynamic>> refreshToken({
    required String accessToken,
    required String refreshToken,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/Sys_Account/RefreshToken'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      }),
    );
    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && responseBody['Success'] == true) {
      return responseBody;
    }
    throw Exception(
      responseBody['Message'] ?? 'Làm mới phiên đăng nhập thất bại',
    );
  }

  // Forgot Password — sends OTP to email (unauthenticated)
  Future<void> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/Sys_Account/ForgotPassword'),
      body: jsonEncode({'email': email}),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body['Message'] ?? 'Yêu cầu quên mật khẩu thất bại');
  }

  // Verify OTP — returns resetToken (unauthenticated)
  Future<String> verifyForgotPasswordOtp(String email, String otpCode) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/Sys_Account/VerifyForgotPasswordOtp'),
      body: jsonEncode({'email': email, 'otpCode': otpCode}),
      headers: {'Content-Type': 'application/json'},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      final data = (body['data'] ?? body['Data']) as Map<String, dynamic>? ?? {};
      return (data['resetToken'] ?? data['ResetToken'])?.toString() ?? '';
    }
    throw Exception(body['Message'] ?? 'Mã OTP không hợp lệ hoặc đã hết hạn');
  }

  // Reset Password (unauthenticated)
  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/Sys_Account/ResetPassword'),
      body: jsonEncode({
        'email': email,
        'resetToken': resetToken,
        'newPassword': newPassword,
      }),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body['Message'] ?? 'Đặt lại mật khẩu thất bại');
  }
}
