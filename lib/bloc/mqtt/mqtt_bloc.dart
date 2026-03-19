import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'package:iot_app/bloc/mqtt/mqtt_event.dart';
import 'package:iot_app/bloc/mqtt/mqtt_state.dart';
import 'package:iot_app/repository/mqtt_manager.dart';
import 'package:iot_app/widgets/notification_service.dart';

class MqttBloc extends Bloc<MqttEvent, MqttState> {
  final MQTTManager mqttManager;
  final NotificationService notificationService;
  StreamSubscription? _messageSubscription;

  MqttBloc({
    required this.mqttManager,
    required this.notificationService,
  }) : super(MqttDisconnected()) {
    on<MqttConnectRequested>(_onConnectRequested);
    on<MqttSubscribeAlarms>(_onSubscribeAlarms);
    on<MqttSubscribeStatus>(_onSubscribeStatus);
    on<MqttPublishMessage>(_onPublishMessage);
    on<MqttMessageReceived>(_onMessageReceived);
  }

  Future<void> _onConnectRequested(
    MqttConnectRequested event,
    Emitter<MqttState> emit,
  ) async {
    emit(MqttConnecting());
    try {
      await mqttManager.connect();
      if (mqttManager.isConnected) {
        _listenToMessages();
        emit(MqttConnected());
      } else {
        emit(const MqttConnectionFailed('Không thể kết nối MQTT'));
      }
    } catch (e) {
      emit(MqttConnectionFailed(e.toString()));
    }
  }

  void _listenToMessages() {
    _messageSubscription?.cancel();
    _messageSubscription = mqttManager.messageStream.listen((mqttMessage) {
      final mqtt.MqttPublishMessage recMess = mqttMessage.payload as mqtt.MqttPublishMessage;
      final String message = mqtt.MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      add(MqttMessageReceived(topic: mqttMessage.topic, message: message));
    });
  }

  Future<void> _onSubscribeAlarms(
    MqttSubscribeAlarms event,
    Emitter<MqttState> emit,
  ) async {
    await mqttManager.ensureConnected();
    for (final serial in event.deviceSerials) {
      mqttManager.subscribe('NhaCuaToi_${serial}_alarm');
    }
  }

  Future<void> _onSubscribeStatus(
    MqttSubscribeStatus event,
    Emitter<MqttState> emit,
  ) async {
    await mqttManager.ensureConnected();
    for (final serial in event.deviceSerials) {
      mqttManager.subscribe('NhaCuaToi_${serial}_status');
    }
  }

  Future<void> _onPublishMessage(
    MqttPublishMessage event,
    Emitter<MqttState> emit,
  ) async {
    await mqttManager.publish(event.topic, event.message);
  }

  void _onMessageReceived(
    MqttMessageReceived event,
    Emitter<MqttState> emit,
  ) {
    // Handle alarm notifications
    if (event.topic.contains('_alarm')) {
      try {
        final alarmData = jsonDecode(event.message) as Map<String, dynamic>;
        final alert = alarmData['alert'];
        final deviceSerial = alarmData['serial'] ?? alarmData['id'];

        if (alert != null && deviceSerial != null) {
          notificationService.showNotification('Thông báo', event.message);
        }
      } catch (e) {
        print('Error processing alarm message: $e');
      }
    }
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    return super.close();
  }
}
