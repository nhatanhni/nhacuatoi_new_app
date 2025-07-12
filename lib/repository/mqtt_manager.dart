import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTManager {
  late MqttServerClient client;
  final _controllers = <String, StreamController<String>>{};
  Stream<String> updates(String topic) {
    return _controllers[topic]!.stream;
  }

  // Expose a stream for all incoming messages
  final _messageStreamController = StreamController<MqttReceivedMessage<MqttMessage>>.broadcast();

  Stream<MqttReceivedMessage<MqttMessage>> get messageStream => _messageStreamController.stream;

  // Default constructor
  MQTTManager() {
    client = MqttServerClient.withPort('nhacuatoi.com.vn', 'flutter_client', 8004);
    client.logging(on: false);
    client.keepAlivePeriod = 60;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;
  }

  // Constructor with parameters
  MQTTManager.withParams(String server, String clientId) {
    client = MqttServerClient.withPort(server, clientId, 8004); // Updated port to 8004
    client.logging(on: false);
    client.keepAlivePeriod = 60;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;
  }

  Future<void> connect() async {
    client.logging(on: true);
    client.keepAlivePeriod = 20;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;
    client.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('MqttFlutterClient')
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
      return; // Return early if connection fails
    }

    if (client.updates != null) {
      client.updates!.listen(_onMessage);
    }
  }

  void _onDisconnected() {
    print('Disconnected');
  }

  void _onConnected() {
    print('Connected');
  }

  void _onSubscribed(String topic) {
    print('Subscribed topic: $topic');
  }

  Future<void> publish(String topic, String message) async {
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      print('MQTT client is not connected, attempting to reconnect...');
      await connect();
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      print('Published message to topic: $topic');
    } else {
      print('MQTT client is not connected, cannot publish message');
    }
  }

  static Future<void> connectAndPublish(
      String server, String clientId, String topic, String message) async {
    final mqttManager = MQTTManager.withParams(server, clientId);

    await mqttManager.connect();

    if (mqttManager.client.connectionStatus?.state ==
        MqttConnectionState.connected) {
      print('Publishing message to topic: $topic');
      mqttManager.publish(topic, message);
      await Future.delayed(const Duration(seconds: 2));
      mqttManager.dispose();
    } else {
      print('MQTT client is not connected, cannot publish message');
    }
  }

  // Connection callback
  void onConnected() {
    print('Connected');
  }

  // Disconnected callback
  void onDisconnected() {
    print('Disconnected');
  }

  // Subscribed callback
  void onSubscribed(String topic) {
    print('Subscribed topic: $topic');
  }

  // Subscribe to a topic
  void subscribe(String topic) {
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      throw Exception(
          'MQTT client is not connected, cannot subscribe to topic');
    }

    client.subscribe(topic, MqttQos.atLeastOnce);

    _controllers[topic] = StreamController<String>.broadcast();

    if (client.updates != null) {
      client.updates!.listen(
            (List<MqttReceivedMessage<MqttMessage>> c) {
          final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
          final String message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

          // Check if the message is for the correct topic
          if (c[0].topic == topic) {
            print("Received message: $message from topic: $topic");
            _controllers[topic]!.add(message);
            _messageStreamController.add(c[0]);
          }
        },
        onError: (e) {
          print('Error when receiving message: $e');
        },
      );
    }
  }

  // Dispose resources
  void dispose() {
    _controllers.values.forEach((controller) => controller.close());
    _messageStreamController.close();
    client.disconnect();
  }

  // Handle incoming messages
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> event) {
    final MqttPublishMessage recMess = event[0].payload as MqttPublishMessage;
    final String message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

    String topic = event[0].topic;
    print('Received message: $message from topic: $topic');
    
    // Chỉ log message, không xử lý notification ở đây
    // Notification sẽ được xử lý trong main.dart
  }
}
