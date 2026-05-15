import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages biometric authentication state, secure token storage, and
/// device identity resolution.
///
/// Responsibilities:
///   • Check whether biometrics are available on this device.
///   • Trigger the OS biometric prompt via [LocalAuthentication].
///   • Persist/retrieve the biometric-bound refresh token in Secure Storage.
///   • Track whether the user has enabled biometrics (SharedPreferences flag).
///   • Resolve a stable device identifier and human-readable device name.
class BiometricRepository {
  static const _kRefreshTokenKey = 'biometric_refresh_token';
  static const _kAccessTokenKey = 'biometric_access_token';
  static const _kBiometricEnabledKey = 'biometric_enabled';

  final LocalAuthentication _localAuth;
  final FlutterSecureStorage _secureStorage;

  BiometricRepository({
    LocalAuthentication? localAuth,
    FlutterSecureStorage? secureStorage,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  // ─── Biometric availability ───────────────────────────────────────────────

  /// Returns true if the device hardware supports biometrics AND the user
  /// has at least one enrolled biometric (fingerprint / face).
  Future<bool> isBiometricAvailable() async {
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) return false;

      final canAuthenticate = await _localAuth.canCheckBiometrics;
      if (!canAuthenticate) return false;

      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ─── User preference flag ─────────────────────────────────────────────────

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometricEnabledKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricEnabledKey, enabled);
  }

  // ─── Secure token storage ─────────────────────────────────────────────────

  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: _kRefreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: _kRefreshTokenKey);
  }

  Future<void> deleteRefreshToken() async {
    await _secureStorage.delete(key: _kRefreshTokenKey);
  }

  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: _kAccessTokenKey, value: token);
  }

  Future<String?> getAccessToken() async {
    return _secureStorage.read(key: _kAccessTokenKey);
  }

  Future<void> deleteAccessToken() async {
    await _secureStorage.delete(key: _kAccessTokenKey);
  }

  // ─── Biometric prompt ─────────────────────────────────────────────────────

  /// Shows the OS biometric prompt.
  /// Returns true if the user authenticated successfully.
  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Xác thực vân tay để đăng nhập',
        options: const AuthenticationOptions(
          // biometricOnly: false cho phép PIN fallback — cần thiết trên emulator
          // và trên thiết bị thật khi vân tay không nhận diện được
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      // ignore: avoid_print
      print('[BiometricRepository] authenticate error: $e');
      return false;
    }
  }

  // ─── Device identity ──────────────────────────────────────────────────────

  /// Returns a stable device identifier string.
  Future<String> getDeviceId() async {
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return android.id; // Build.ID — stable per device+user
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.identifierForVendor ?? '';
      }
    } catch (_) {}
    return '';
  }

  /// Returns a human-readable device name (e.g. "Pixel 7", "iPhone 15 Pro").
  Future<String> getDeviceName() async {
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return android.model;
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.name;
      }
    } catch (_) {}
    return '${Platform.operatingSystem} device';
  }

  // ─── Full disable cleanup ─────────────────────────────────────────────────

  /// Clears the local biometric state (secure token + flag).
  /// Should be called after the backend Disable API succeeds, or on logout.
  Future<void> clearAll() async {
    await deleteRefreshToken();
    await deleteAccessToken();
    await setBiometricEnabled(false);
  }
}
