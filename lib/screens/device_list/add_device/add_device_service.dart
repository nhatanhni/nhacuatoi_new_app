import 'package:iot_app/core/models/device.dart';
import 'package:iot_app/core/services/database_helper.dart';

class AddDeviceService {
  Future<int> insertDevice(Device device) =>
      DatabaseHelper.instance.insertDevice(device);
}
