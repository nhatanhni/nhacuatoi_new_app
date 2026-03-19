import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot_app/bloc/auth/auth_event.dart';
import 'package:iot_app/bloc/auth/auth_state.dart';
import 'package:iot_app/repository/api_service.dart';
import 'package:iot_app/repository/user_repository.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService apiService;
  final UserRepository userRepository;

  AuthBloc({
    required this.apiService,
    required this.userRepository,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final isLoggedIn = await userRepository.getLoginStatus();
    if (isLoggedIn) {
      final userData = await userRepository.getUserData();
      emit(AuthAuthenticated(
        userId: userData['userId'] ?? '',
        userName: userData['userName'] ?? '',
        roleName: userData['roleName'] ?? '',
        accessToken: userData['accessToken'] ?? '',
      ));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await apiService.login(event.username, event.password);
      final data = result['Data'];

      if (data != null) {
        await userRepository.saveUserData(data);
        await userRepository.saveLoginStatus(true);

        emit(AuthAuthenticated(
          userId: data['UserId'] ?? '',
          userName: data['UserName'] ?? '',
          roleName: data['RoleName'] ?? '',
          accessToken: data['AccessToken'] ?? '',
        ));
      } else {
        emit(const AuthFailure('Dữ liệu trả về không hợp lệ.'));
      }
    } catch (e) {
      emit(AuthFailure(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await userRepository.clearUserData();
    await userRepository.clearLoginStatus();
    emit(AuthUnauthenticated());
  }
}
