import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String userId;
  final String userName;
  final String fullName;
  final String email;
  final String accessToken;
  final List<dynamic> roles;
  final List<dynamic> menus;

  const AuthAuthenticated({
    required this.userId,
    required this.userName,
    required this.fullName,
    required this.email,
    required this.accessToken,
    required this.roles,
    required this.menus,
  });

  @override
  List<Object?> get props => [
        userId,
        userName,
        fullName,
        email,
        accessToken,
        roles,
        menus,
      ];
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Phát ra sau khi đăng nhập thành công bằng user/pass, và thiết bị hỗ trợ
/// biometrics nhưng chưa kích hoạt. UI dùng state này để hỏi user.
class AuthPromptBiometricEnable extends AuthState {}

/// Biometrics đã kích hoạt thành công.
class AuthBiometricEnabled extends AuthState {}

/// Biometrics đã tắt thành công.
class AuthBiometricDisabled extends AuthState {}
