import 'package:iot_app/core/models/device.dart';
import 'package:iot_app/core/services/database_helper.dart';
import 'package:iot_app/core/services/api_service.dart';

class DeviceListService {
  final _apiService = ApiService();

  Future<List<Device>> getDevices() => DatabaseHelper.instance.queryAllDevices();

  Future<Map<String, dynamic>> fetchWaterMeterData(String serial) =>
      _apiService.fetchWaterMeterData(serial);
}
