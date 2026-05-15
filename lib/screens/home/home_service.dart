import 'package:iot_app/core/services/user_repository.dart';
import 'package:iot_app/core/models/device.dart';
import 'package:iot_app/core/services/database_helper.dart';

class HomeService {
  final _userRepository = UserRepository();

  Future<Map<String, String>> getUserData() => _userRepository.getUserData();

  Future<List<Device>> getDevices() => DatabaseHelper.instance.queryAllDevices();
}
