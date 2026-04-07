import 'package:equatable/equatable.dart';

abstract class SchedulerEvent extends Equatable {
  const SchedulerEvent();

  @override
  List<Object?> get props => [];
}

class SchedulerLoadRequested extends SchedulerEvent {
  final String serial;

  const SchedulerLoadRequested(this.serial);

  @override
  List<Object?> get props => [serial];
}

class SchedulerCreateRequested extends SchedulerEvent {
  final String serial;
  final String deviceName;
  final int hour;
  final int minute;
  final int duration;
  final int repeat;

  const SchedulerCreateRequested({
    required this.serial,
    required this.deviceName,
    required this.hour,
    required this.minute,
    required this.duration,
    required this.repeat,
  });

  @override
  List<Object?> get props =>
      [serial, deviceName, hour, minute, duration, repeat];
}

class SchedulerUpdateRequested extends SchedulerEvent {
  final String id;
  final Map<String, dynamic> updates;
  final String serial;

  const SchedulerUpdateRequested({
    required this.id,
    required this.updates,
    required this.serial,
  });

  @override
  List<Object?> get props => [id, updates, serial];
}

class SchedulerDeleteRequested extends SchedulerEvent {
  final String id;
  final String serial;

  const SchedulerDeleteRequested({required this.id, required this.serial});

  @override
  List<Object?> get props => [id, serial];
}
