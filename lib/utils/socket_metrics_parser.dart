import 'dart:convert';

class SocketMetricsParseResult {
  final Map<String, dynamic>? data;
  final String? prettyJson;
  final String? error;

  const SocketMetricsParseResult({
    required this.data,
    required this.prettyJson,
    required this.error,
  });

  bool get hasData => data != null && data!.isNotEmpty;
}

class SocketMetricsParser {
  const SocketMetricsParser._();

  static SocketMetricsParseResult parse(String message) {
    try {
      final dynamic decoded = jsonDecode(message);
      final payload = _extractPayload(decoded);

      if (payload == null) {
        return SocketMetricsParseResult(
          data: null,
          prettyJson: message,
          error: 'Payload socket khong dung dinh dang object JSON.',
        );
      }

      return SocketMetricsParseResult(
        data: payload,
        prettyJson: const JsonEncoder.withIndent('  ').convert(payload),
        error: null,
      );
    } catch (e) {
      return SocketMetricsParseResult(
        data: null,
        prettyJson: message,
        error: 'Khong parse duoc JSON tu socket: $e',
      );
    }
  }

  static Map<String, dynamic>? _extractPayload(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded['data'] as Map<String, dynamic>);
      }
      return Map<String, dynamic>.from(decoded);
    }

    if (decoded is String) {
      final dynamic nested = jsonDecode(decoded);
      if (nested is Map<String, dynamic>) {
        if (nested['data'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(nested['data'] as Map<String, dynamic>);
        }
        return Map<String, dynamic>.from(nested);
      }
    }

    return null;
  }
}
