import 'package:iot_app/core/services/api_service.dart';
import 'package:iot_app/core/services/user_repository.dart';

class LoginService {
  final _apiService = ApiService();
  final _userRepository = UserRepository();

  Future<void> login(String username, String password) async {
    final userInfo = await _apiService.login(username, password);
    await _userRepository.saveUserData(userInfo);
    await _userRepository.saveLoginStatus(true);
  }
}
