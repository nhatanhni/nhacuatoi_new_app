import 'package:iot_app/core/services/api_service.dart';
import 'package:iot_app/core/services/user_repository.dart';
import 'package:iot_app/main.dart';

class LoginService {
  ApiService get _apiService => MyApp.apiService;
  final _userRepository = UserRepository();

  Future<void> login(String username, String password) async {
    final userInfo = await _apiService.login(username, password);
    await _userRepository.saveUserInfo(userInfo);
    await _userRepository.saveLoginStatus(true);
  }
}
