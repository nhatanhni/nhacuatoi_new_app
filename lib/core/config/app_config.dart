import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized configuration loaded from .env file.
/// All sensitive values (API URLs, MQTT credentials) are accessed through this class.
class AppConfig {
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';
  static String get mqttServer => dotenv.env['MQTT_SERVER'] ?? '';
  static int get mqttPort => int.tryParse(dotenv.env['MQTT_PORT'] ?? '') ?? 8004;
  static String get mqttUsername => dotenv.env['MQTT_USERNAME'] ?? '';
  static String get mqttPassword => dotenv.env['MQTT_PASSWORD'] ?? '';
  static String get privacyPolicyUrl => dotenv.env['PRIVACY_POLICY_URL'] ?? '';
}
