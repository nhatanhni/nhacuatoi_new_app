import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot_app/bloc/auth/auth_event.dart';
import 'package:iot_app/bloc/auth/auth_state.dart';
import 'package:iot_app/core/services/api_service.dart';
import 'package:iot_app/core/services/biometric_repository.dart';
import 'package:iot_app/core/services/user_repository.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService apiService;
  final UserRepository userRepository;
  final BiometricRepository biometricRepository;

  AuthBloc({
    required this.apiService,
    required this.userRepository,
    required this.biometricRepository,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthBiometricLoginRequested>(_onBiometricLoginRequested);
    on<AuthBiometricEnableRequested>(_onBiometricEnableRequested);
    on<AuthBiometricDisableRequested>(_onBiometricDisableRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final isLoggedIn = await userRepository.getLoginStatus();
    if (!isLoggedIn) {
      emit(AuthUnauthenticated());
      return;
    }

    final info = await userRepository.loadUserInfo();
    if (info == null || (info['accessToken'] as String).isEmpty) {
      emit(AuthUnauthenticated());
      return;
    }

    emit(AuthAuthenticated(
      userId: info['userId'] as String,
      userName: info['userName'] as String,
      fullName: info['fullName'] as String,
      email: info['email'] as String,
      accessToken: info['accessToken'] as String,
      roles: info['roles'] as List<dynamic>,
      menus: info['menus'] as List<dynamic>,
    ));
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // Step 1: Login → get tokens
      final loginResult = await apiService.login(event.username, event.password);
      final tokenData =
          (loginResult['Data'] as Map<String, dynamic>?) ?? loginResult;
      final accessToken =
          (tokenData['AccessToken'] ?? tokenData['accessToken'])?.toString() ?? '';
      final refreshToken =
          (tokenData['RefreshToken'] ?? tokenData['refreshToken'])?.toString() ?? '';

      await userRepository.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      await userRepository.saveLoginStatus(true);

      // Step 2: Fetch full user profile from /me
      final meData = await apiService.getMe();
      await userRepository.saveUserInfo(meData);

      emit(AuthAuthenticated(
        userId: meData['Id']?.toString() ?? '',
        userName: meData['UserName']?.toString() ?? '',
        fullName: meData['FullName']?.toString() ?? '',
        email: meData['Email']?.toString() ?? '',
        accessToken: accessToken,
        roles: (meData['Roles'] as List<dynamic>?) ?? [],
        menus: (meData['Menus'] as List<dynamic>?) ?? [],
      ));

      // Step 3: Nếu thiết bị hỗ trợ biometrics và user chưa bật → gợi ý kích hoạt
      final isBiometricAvailable = await biometricRepository.isBiometricAvailable();
      final isBiometricEnabled = await biometricRepository.isBiometricEnabled();
      if (isBiometricAvailable && !isBiometricEnabled) {
        emit(AuthPromptBiometricEnable());
      }
    } catch (e) {
      emit(AuthFailure(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Giữ biometric state qua logout để user có thể đăng nhập lại bằng vân tay.
    // Chỉ xóa session data (user info + tokens trong SharedPreferences).
    final wasBiometricEnabled = await biometricRepository.isBiometricEnabled();
    // Đọc refreshToken trước khi clearAllData() xóa nó khỏi SharedPreferences
    final currentRefreshToken = await userRepository.getRefreshToken();

    // Gửi refreshToken để backend chỉ revoke phịiết này, không ảnh hưởng phiết khác
    await apiService.logout(refreshToken: currentRefreshToken);
    await userRepository.clearAllData(); // prefs.clear() xóa luôn biometric_enabled

    // Khôi phục flag sau khi clearAllData() đã wipe SharedPreferences
    if (wasBiometricEnabled) {
      await biometricRepository.setBiometricEnabled(true);
    }

    emit(AuthUnauthenticated());
  }

  // ─── Biometric login flow ─────────────────────────────────────────────────

  Future<void> _onBiometricLoginRequested(
    AuthBiometricLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // 1. Quét vân tay
      final authenticated = await biometricRepository.authenticate();
      if (!authenticated) {
        emit(AuthUnauthenticated());
        return;
      }

      // 2. Đọc refreshToken từ Secure Storage
      final storedRefresh = await biometricRepository.getRefreshToken();
      if (storedRefresh == null || storedRefresh.isEmpty) {
        // Token bị mất → yêu cầu đăng nhập lại bằng user/pass
        await biometricRepository.clearAll();
        emit(const AuthFailure('Phiên vân tay đã hết hạn, vui lòng đăng nhập lại'));
        return;
      }

      // 3. Đọc accessToken từ Secure Storage (tồn tại qua logout)
      final oldAccessToken = await biometricRepository.getAccessToken() ?? '';

      // 4. POST /RefreshToken → nhận token mới
      final refreshResult = await apiService.refreshToken(
        accessToken: oldAccessToken,
        refreshToken: storedRefresh,
      );
      final tokenData =
          (refreshResult['Data'] as Map<String, dynamic>?) ?? refreshResult;
      final newAccessToken =
          (tokenData['AccessToken'] ?? tokenData['accessToken'])?.toString() ?? '';
      final newRefreshToken =
          (tokenData['RefreshToken'] ?? tokenData['refreshToken'])?.toString() ?? '';

      // 5. Lưu token mới
      await userRepository.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
      await userRepository.saveLoginStatus(true);
      // Cập nhật cả hai token bảo mật với giá trị mới
      await biometricRepository.saveRefreshToken(newRefreshToken);
      await biometricRepository.saveAccessToken(newAccessToken);

      // 6. Lấy profile
      final meData = await apiService.getMe();
      await userRepository.saveUserInfo(meData);

      emit(AuthAuthenticated(
        userId: meData['Id']?.toString() ?? '',
        userName: meData['UserName']?.toString() ?? '',
        fullName: meData['FullName']?.toString() ?? '',
        email: meData['Email']?.toString() ?? '',
        accessToken: newAccessToken,
        roles: (meData['Roles'] as List<dynamic>?) ?? [],
        menus: (meData['Menus'] as List<dynamic>?) ?? [],
      ));
    } catch (e) {      // Token hết hạn hoặc bị thu hồi → xóa biometric state,
      // user sẽ thấy link "Thiết lập..." để bật lại sau khi đăng nhập bằng mật khẩu.
      await biometricRepository.clearAll();      emit(AuthFailure(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  // ─── Biometric enable flow ────────────────────────────────────────────────

  Future<void> _onBiometricEnableRequested(
    AuthBiometricEnableRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final refreshToken = await userRepository.getRefreshToken();
      final deviceId = await biometricRepository.getDeviceId();
      final deviceName = await biometricRepository.getDeviceName();

      final data = await apiService.enableBiometric(
        refreshToken: refreshToken,
        deviceId: deviceId,
        deviceName: deviceName,
      );

      // Backend trả về biometricRefreshToken — token riêng dành cho biometric login.
      // Không dùng refreshToken phiến thường để tránh backend revoke toàn bộ phiến.
      final biometricRT =
          (data['BiometricRefreshToken'] ?? data['biometricRefreshToken'])
              ?.toString() ?? '';
      if (biometricRT.isEmpty) {
        throw Exception('Backend không trả về biometricRefreshToken');
      }

      // Lưu biometricRefreshToken + accessToken hiện tại vào Secure Storage
      await biometricRepository.saveRefreshToken(biometricRT);
      final currentAccessToken = await userRepository.getAccessToken();
      await biometricRepository.saveAccessToken(currentAccessToken);
      await biometricRepository.setBiometricEnabled(true);

      emit(AuthBiometricEnabled());
    } catch (e) {
      emit(AuthFailure(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  // ─── Biometric disable flow ───────────────────────────────────────────────

  Future<void> _onBiometricDisableRequested(
    AuthBiometricDisableRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final deviceId = await biometricRepository.getDeviceId();
      await apiService.disableBiometric(deviceId: deviceId);
      await biometricRepository.clearAll();
      emit(AuthBiometricDisabled());
    } catch (e) {
      emit(AuthFailure(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
