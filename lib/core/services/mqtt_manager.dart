import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:iot_app/core/config/app_config.dart';

/// Singleton MQTT Manager - shared across the entire app.
/// Configured to use MQTTS (MQTT over SSL/TLS) for secure communication.
/// Credentials loaded from .env file via AppConfig.
/// Use MQTTManager.instance to access the global connection.
class MQTTManager {
  // Singleton pattern
  static final MQTTManager _instance = MQTTManager._internal();
  static MQTTManager get instance => _instance;
  factory MQTTManager() => _instance;

  late MqttServerClient client;
  final _controllers = <String, StreamController<String>>{};
  bool _isInitialized = false;

  Stream<String> updates(String topic) {
    if (!_controllers.containsKey(topic)) {
      _controllers[topic] = StreamController<String>.broadcast();
    }
    return _controllers[topic]!.stream;
  }

  // Expose a stream for all incoming messages
  final _messageStreamController = StreamController<MqttReceivedMessage<MqttMessage>>.broadcast();

  Stream<MqttReceivedMessage<MqttMessage>> get messageStream => _messageStreamController.stream;

  bool get isConnected =>
      _isInitialized &&
      client.connectionStatus?.state == MqttConnectionState.connected;

  MQTTManager._internal() {
    _initClient();
  }

  void _initClient() {
    client = MqttServerClient.withPort(
      AppConfig.mqttServer, 'flutter_client', AppConfig.mqttPort,
    );
    // MQTTS Configuration (SSL/TLS enabled)
    // Port 8004 with SSL/TLS encryption
    client.secure = true; // Enable TLS/SSL for secure MQTTS connection
    client.onBadCertificate = (dynamic cert) => true; // Allow self-signed certificates
    client.logging(on: false);
    client.keepAlivePeriod = 60;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;
    client.onSubscribed = _onSubscribed;
    _isInitialized = true;
  }

  Future<void> connect() async {
    // Skip if already connected
    if (isConnected) {
      print('MQTT already connected, skipping...');
      return;
    }

    print("connect: ${AppConfig.mqttUsername}, ${AppConfig.mqttPassword}");

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('MqttFlutterClient')
        .authenticateAs(AppConfig.mqttUsername, AppConfig.mqttPassword)
        .withWillTopic('willtopic')
        .withWillMessage('My Will message')
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    client.connectionMessage = connMessage;

    try {
      print('Connecting to MQTT broker...');
      await client.connect();
      print('Connected to MQTT broker');
    } catch (e) {
      print('Connection failed: $e');
      client.disconnect();
      return;
    }

    if (client.updates != null) {
      client.updates!.listen(_onMessage);
    }
  }

  Future<void> ensureConnected() async {
    if (!isConnected) {
      await connect();
    }
  }

  void _onDisconnected() {
    print('MQTT Disconnected');
  }

  void _onConnected() {
    print('MQTT Connected');
  }

  void _onSubscribed(String topic) {
    print('MQTT Subscribed topic: $topic');
  }

  Future<void> publish(String topic, String message) async {
    await ensureConnected();

    if (isConnected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      print('📤 Published to $topic: $message');
    } else {
      print('❌ MQTT not connected, cannot publish to $topic');
    }
  }

  void subscribe(String topic) {
    if (!isConnected) {
      print('MQTT not connected, cannot subscribe to: $topic');
      return;
    }

    print('Subscribing to topic: $topic');
    client.subscribe(topic, MqttQos.atLeastOnce);

    if (!_controllers.containsKey(topic)) {
      _controllers[topic] = StreamController<String>.broadcast();
    }
  }

  /// Unsubscribe from a topic and close its controller.
  void unsubscribe(String topic) {
    if (isConnected) {
      client.unsubscribe(topic);
    }
    if (_controllers.containsKey(topic)) {
      _controllers[topic]!.close();
      _controllers.remove(topic);
    }
  }

  /// Disconnect and clean up all resources. 
  /// Only call this on app shutdown, not on screen dispose.
  void dispose() {
    _controllers.values.forEach((controller) => controller.close());
    _controllers.clear();
    _messageStreamController.close();
    client.disconnect();
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> event) {
    for (MqttReceivedMessage<MqttMessage> message in event) {
      final MqttPublishMessage recMess = message.payload as MqttPublishMessage;
      final String messageString = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final String topic = message.topic;
      
      print('📨 MQTT RECEIVED: Topic: $topic, Message: $messageString');
      
      _messageStreamController.add(message);
      
      if (_controllers.containsKey(topic)) {
        _controllers[topic]!.add(messageString);
      }
    }
  }
}
