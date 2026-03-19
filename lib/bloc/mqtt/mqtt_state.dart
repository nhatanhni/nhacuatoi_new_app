import 'package:equatable/equatable.dart';

abstract class MqttState extends Equatable {
  const MqttState();

  @override
  List<Object?> get props => [];
}

class MqttDisconnected extends MqttState {}

class MqttConnecting extends MqttState {}

class MqttConnected extends MqttState {}

class MqttConnectionFailed extends MqttState {
  final String error;

  const MqttConnectionFailed(this.error);

  @override
  List<Object?> get props => [error];
}
