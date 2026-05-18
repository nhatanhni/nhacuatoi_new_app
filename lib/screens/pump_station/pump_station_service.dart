import 'package:iot_app/core/services/api_service.dart';
import 'package:iot_app/main.dart';

class PumpStationService {
  ApiService get _apiService => MyApp.apiService;

  Future<Map<String, dynamic>> fetchWaterMeterData(String serial) =>
      _apiService.fetchWaterMeterData(serial);
}
