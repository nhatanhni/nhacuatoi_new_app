import 'package:iot_app/core/services/api_service.dart';

class PumpStationManagementService {
  final _apiService = ApiService();

  Future<Map<String, dynamic>> fetchWaterMeterData(String serial) =>
      _apiService.fetchWaterMeterData(serial);
}
