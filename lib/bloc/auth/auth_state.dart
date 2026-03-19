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
  final String roleName;
  final String accessToken;

  const AuthAuthenticated({
    required this.userId,
    required this.userName,
    required this.roleName,
    required this.accessToken,
  });

  @override
  List<Object?> get props => [userId, userName, roleName, accessToken];
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}
