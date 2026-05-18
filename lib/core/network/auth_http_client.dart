import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iot_app/core/config/app_config.dart';
import 'package:iot_app/core/services/user_repository.dart';

typedef SessionExpiredCallback = void Function();
typedef TokenRefreshedCallback = void Function(String newAccessToken, String newRefreshToken);

/// Centralized authenticated HTTP client.
/// Injects Bearer token on every request.
/// On 401 Unauthorized: attempts token refresh once, retries request.
/// If refresh fails: clears tokens and calls [onSessionExpired].
class AuthHttpClient {
  final UserRepository _userRepository;
  final SessionExpiredCallback? onSessionExpired;
  /// Gọi sau mỗi lần refresh token thành công — dùng để đồng bộ Secure Storage.
  final TokenRefreshedCallback? onTokenRefreshed;
  final http.Client _inner;

  // Guards against concurrent refresh attempts.
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  AuthHttpClient({
    required UserRepository userRepository,
    this.onSessionExpired,
    this.onTokenRefreshed,
    http.Client? inner,
  })  : _userRepository = userRepository,
        _inner = inner ?? http.Client();

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    return _withTokenRefresh(
      (token) => _inner.get(url, headers: _buildHeaders(token, headers)),
    );
  }

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _withTokenRefresh(
      (token) => _inner.post(
        url,
        headers: _buildHeaders(token, headers),
        body: body,
        encoding: encoding,
      ),
    );
  }

  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _withTokenRefresh(
      (token) => _inner.put(
        url,
        headers: _buildHeaders(token, headers),
        body: body,
        encoding: encoding,
      ),
    );
  }

  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _withTokenRefresh(
      (token) => _inner.delete(
        url,
        headers: _buildHeaders(token, headers),
        body: body,
      ),
    );
  }

  Map<String, String> _buildHeaders(
    String token,
    Map<String, String>? extra,
  ) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  Future<http.Response> _withTokenRefresh(
    Future<http.Response> Function(String token) request,
  ) async {
    final token = await _userRepository.getAccessToken();
    final response = await request(token);

    if (response.statusCode != 401) {
      return response;
    }

    // ── 401 received ──────────────────────────────────────────────────────
    if (_isRefreshing) {
      // Another refresh is in progress – wait for its result.
      final newToken = await _refreshCompleter!.future;
      if (newToken != null) {
        return await request(newToken);
      }
      return response;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    final newToken = await _tryRefreshToken();

    _isRefreshing = false;
    _refreshCompleter!.complete(newToken);
    _refreshCompleter = null;

    if (newToken != null) {
      return await request(newToken);
    }

    // Refresh failed: clear tokens only, navigate to login.
    // Do NOT call logout API here (token is invalid).
    await _userRepository.clearTokens();
    onSessionExpired?.call();
    return response;
  }

  /// Calls /api/Sys_Account/RefreshToken directly via plain http (no recursion).
  Future<String?> _tryRefreshToken() async {
    try {
      final accessToken = await _userRepository.getAccessToken();
      final refreshToken = await _userRepository.getRefreshToken();

      if (refreshToken.isEmpty) return null;

      final response = await _inner.post(
        Uri.parse(
          '${AppConfig.apiBaseUrl}/api/Sys_Account/RefreshToken',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['Success'] == true) {
          final data = body['Data'] as Map<String, dynamic>;
          final newAccess = data['AccessToken'] as String;
          final newRefresh = data['RefreshToken'] as String;
          await _userRepository.saveTokens(
            accessToken: newAccess,
            refreshToken: newRefresh,
          );
          onTokenRefreshed?.call(newAccess, newRefresh);
          return newAccess;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
