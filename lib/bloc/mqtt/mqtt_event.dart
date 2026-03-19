import 'package:equatable/equatable.dart';

abstract class MqttEvent extends Equatable {
  const MqttEvent();

  @override
  List<Object?> get props => [];
}

class MqttConnectRequested extends MqttEvent {}

class MqttSubscribeAlarms extends MqttEvent {
  final List<String> deviceSerials;

  const MqttSubscribeAlarms(this.deviceSerials);

  @override
  List<Object?> get props => [deviceSerials];
}

class MqttSubscribeStatus extends MqttEvent {
  final List<String> deviceSerials;

  const MqttSubscribeStatus(this.deviceSerials);

  @override
  List<Object?> get props => [deviceSerials];
}

class MqttPublishMessage extends MqttEvent {
  final String topic;
  final String message;

  const MqttPublishMessage({required this.topic, required this.message});

  @override
  List<Object?> get props => [topic, message];
}

class MqttMessageReceived extends MqttEvent {
  final String topic;
  final String message;

  const MqttMessageReceived({required this.topic, required this.message});

  @override
  List<Object?> get props => [topic, message];
}
