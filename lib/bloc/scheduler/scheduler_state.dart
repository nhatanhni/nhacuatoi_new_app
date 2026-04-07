import 'package:equatable/equatable.dart';

abstract class SchedulerState extends Equatable {
  const SchedulerState();

  @override
  List<Object?> get props => [];
}

class SchedulerInitial extends SchedulerState {}

class SchedulerLoadInProgress extends SchedulerState {}

class SchedulerLoadSuccess extends SchedulerState {
  final List<Map<String, dynamic>> schedules;

  const SchedulerLoadSuccess(this.schedules);

  @override
  List<Object?> get props => [schedules];
}

class SchedulerLoadFailure extends SchedulerState {
  final String message;

  const SchedulerLoadFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class SchedulerActionInProgress extends SchedulerState {
  final List<Map<String, dynamic>> schedules;

  const SchedulerActionInProgress(this.schedules);

  @override
  List<Object?> get props => [schedules];
}

class SchedulerActionSuccess extends SchedulerState {
  final List<Map<String, dynamic>> schedules;
  final String message;

  const SchedulerActionSuccess({
    required this.schedules,
    required this.message,
  });

  @override
  List<Object?> get props => [schedules, message];
}

class SchedulerActionFailure extends SchedulerState {
  final List<Map<String, dynamic>> schedules;
  final String message;

  const SchedulerActionFailure({
    required this.schedules,
    required this.message,
  });

  @override
  List<Object?> get props => [schedules, message];
}
