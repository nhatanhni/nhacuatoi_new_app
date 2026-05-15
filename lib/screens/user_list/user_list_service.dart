import 'package:iot_app/core/services/api_service.dart';
import 'package:iot_app/core/services/user_repository.dart';

class UserListService {
  final _apiService = ApiService();
  final _userRepository = UserRepository();

  Future<String> getToken() async {
    final data = await _userRepository.getUserData();
    return data['accessToken'] ?? '';
  }

  Future<void> deleteUser(String id, String token) =>
      _apiService.deleteUserById(id, token);
}
