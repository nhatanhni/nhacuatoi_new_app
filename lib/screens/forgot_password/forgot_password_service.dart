import 'package:iot_app/core/services/api_service.dart';

class ForgotPasswordService {
  final _apiService = ApiService();

  /// Kiểm tra email/username có tồn tại trên hệ thống không
  Future<bool> findAccount(String emailOrUsername) async {
    try {
      // Gọi API kiểm tra tài khoản tồn tại
      // Tạm thời giả lập: kiểm tra định dạng email/username hợp lệ
      if (emailOrUsername.trim().isEmpty) {
        throw Exception('Vui lòng nhập email hoặc tên người dùng.');
      }
      // TODO: Thay bằng API thực tế khi backend hỗ trợ
      // await _apiService.findAccount(emailOrUsername);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Đổi mật khẩu (cần mật khẩu hiện tại)
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (currentPassword.trim().isEmpty ||
          newPassword.trim().isEmpty) {
        throw Exception('Vui lòng điền đầy đủ thông tin.');
      }
      if (newPassword.length < 8) {
        throw Exception('Mật khẩu mới phải có ít nhất 8 ký tự.');
      }
      // TODO: Thay bằng API thực tế khi backend hỗ trợ
      // await _apiService.changePassword(currentPassword, newPassword);
    } catch (e) {
      rethrow;
    }
  }
}
