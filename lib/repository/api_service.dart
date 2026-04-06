import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iot_app/core/config/app_config.dart';

class ApiService {
  final String _baseUrl = AppConfig.apiBaseUrl;

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

    print(Uri.parse('$_baseUrl/api/Sys_Account/Login'));
    print(jsonEncode({'username': username, 'password': password}));

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
      throw Exception(
        responseBody['Message'] ?? 'Lấy thông tin người dùng thất bại',
      );
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
      throw Exception(
        responseBody['Message'] ?? 'Lấy dữ liệu đồng hồ nước thất bại',
      );
    }
  }

  //get all devices of user
  Future<List<dynamic>> fetchUserDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    final response = await http.get(
      Uri.parse('$_baseUrl/api/Iot_DeviceType/1/500/500'),
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
      return responseBody['Data']["Items"] as List<dynamic>;
    } else {
      throw Exception(
        responseBody['Message'] ?? 'Lấy danh sách thiết bị thất bại',
      );
    }
  }

  // get manage device list of user (paged)
  Future<Map<String, dynamic>> fetchManageDevices({
    int page = 1,
    int pageSize = 10,
    int totalLimitItems = 500,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/api/Iot_Device/paged',
      ).replace(
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
          'totalLimitItems': totalLimitItems.toString(),
        },
      ),
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

  // get device detail by id
  Future<Map<String, dynamic>> fetchDeviceDetailById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    final response = await http.get(
      Uri.parse('$_baseUrl/api/Iot_Device/detail/$id'),
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

  // create device on server
  Future<Map<String, dynamic>> createDevice(
    Map<String, dynamic> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    final response = await http.post(
      Uri.parse('$_baseUrl/api/Iot_Device'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
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

  // delete device on server by id
  Future<void> deleteDeviceOnServer(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/Iot_Device/$deviceId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
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

  // get organization units (flattened tree from /api/Sys_Organization/tree)
  Future<List<dynamic>> fetchOrganizationUnits() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    final response = await http.get(
      Uri.parse('$_baseUrl/api/Sys_Organization/tree'),
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

  // get all stations
  Future<List<dynamic>> fetchStations() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    final response = await http.get(
      Uri.parse('$_baseUrl/api/Iot_Station/get-all'),
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
      return responseBody['Data'] as List<dynamic>;
    } else {
      throw Exception(responseBody['Message'] ?? 'Lấy danh sách trạm thất bại');
    }
  }

  // save history of switching device
  Future<void> saveSwitchDeviceHistory(String deviceId, int isSwitched) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    final response = await http.post(
      Uri.parse('$_baseUrl/api/Iot_HisDevice/switch-history'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/api/Iot_HisDevice/switch-history',
      ).replace(queryParameters: {'deviceId': deviceId}),
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
      return responseBody['Data'] as List<dynamic>;
    } else {
      throw Exception(
        responseBody['Message'] ?? 'Lấy lịch sử thiết bị thất bại',
      );
    }
  }
}
