import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String username;
  final String password;

  const AuthLoginRequested({required this.username, required this.password});

  @override
  List<Object?> get props => [username, password];
}

class AuthLogoutRequested extends AuthEvent {}

/// Kích hoạt biometrics sau khi user xác nhận muốn dùng vân tay.
/// AuthBloc sẽ đọc refreshToken từ UserRepository, gọi API Enable,
/// rồi lưu token vào Secure Storage.
class AuthBiometricEnableRequested extends AuthEvent {}

/// Tắt biometrics cho thiết bị hiện tại.
class AuthBiometricDisableRequested extends AuthEvent {}

/// Luồng đăng nhập bằng vân tay:
/// 1. local_auth.authenticate()
/// 2. Đọc refreshToken từ Secure Storage
/// 3. POST /RefreshToken → lấy accessToken mới
/// 4. POST /me → load profile → emit AuthAuthenticated
class AuthBiometricLoginRequested extends AuthEvent {}
