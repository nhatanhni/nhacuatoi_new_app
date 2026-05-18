import 'package:iot_app/core/models/device.dart';
import 'package:iot_app/core/services/database_helper.dart';
import 'package:iot_app/core/services/api_service.dart';
import 'package:iot_app/main.dart';

class DeviceListService {
  ApiService get _apiService => MyApp.apiService;

  Future<List<Device>> getDevices() => DatabaseHelper.instance.queryAllDevices();

  Future<Map<String, dynamic>> fetchWaterMeterData(String serial) =>
      _apiService.fetchWaterMeterData(serial);
}
