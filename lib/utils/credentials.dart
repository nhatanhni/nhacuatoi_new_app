// ignore for file: constant_identifier_name
// DEPRECATED: Use AppConfig.mqttUsername and AppConfig.mqttPassword instead.
// Credentials are now loaded from .env file via AppConfig.

import 'package:iot_app/core/config/app_config.dart';

String get MQTT_USERNAME => AppConfig.mqttUsername;
String get MQTT_PASSWORD => AppConfig.mqttPassword;