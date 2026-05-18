import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:iot_app/core/models/device.dart';

abstract class DeviceEvent extends Equatable {
  const DeviceEvent();

  @override
  List<Object?> get props => [];
}

class DeviceLoadAll extends DeviceEvent {}

class DeviceLoadManageList extends DeviceEvent {}

class DeviceLoadManageNextPage extends DeviceEvent {}

class DeviceDetailRequested extends DeviceEvent {
  final String deviceId;

  const DeviceDetailRequested(this.deviceId);

  @override
  List<Object?> get props => [deviceId];
}

class DeviceLoadByType extends DeviceEvent {
  final String deviceType;

  const DeviceLoadByType(this.deviceType);

  @override
  List<Object?> get props => [deviceType];
}

class DeviceStatusUpdated extends DeviceEvent {
  final int deviceId;
  final int status;

  const DeviceStatusUpdated({required this.deviceId, required this.status});

  @override
  List<Object?> get props => [deviceId, status];
}

class DeviceConnectionStatusUpdated extends DeviceEvent {
  final String serial;
  final String connectionStatus;

  const DeviceConnectionStatusUpdated({
    required this.serial,
    required this.connectionStatus,
  });

  @override
  List<Object?> get props => [serial, connectionStatus];
}

class DeviceAdded extends DeviceEvent {
  final Device device;

  const DeviceAdded(this.device);

  @override
  List<Object?> get props => [device];
}

class DeviceDeleted extends DeviceEvent {
  final String deviceId;
  final Completer<void>? completer;

  const DeviceDeleted({required this.deviceId, this.completer});

  @override
  List<Object?> get props => [deviceId];
}

class DeviceSwitchHistorySaved extends DeviceEvent {
  final String deviceId;
  final int isSwitched;
  final Completer<void>? completer;

  const DeviceSwitchHistorySaved({
    required this.deviceId,
    required this.isSwitched,
    this.completer,
  });

  @override
  List<Object?> get props => [deviceId, isSwitched];
}

class DeviceCreateOnServerRequested extends DeviceEvent {
  final Map<String, dynamic> payload;
  final Completer<void>? completer;

  const DeviceCreateOnServerRequested({required this.payload, this.completer});

  @override
  List<Object?> get props => [payload];
}
