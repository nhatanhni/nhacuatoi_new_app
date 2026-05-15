import 'package:iot_app/core/models/device.dart';
import 'package:iot_app/core/services/database_helper.dart';

class ManageDeviceService {
  Future<List<Device>> getDevices() => DatabaseHelper.instance.queryAllDevices();

  Future<int> deleteDevice(int id) => DatabaseHelper.instance.deleteDevice(id);
}
