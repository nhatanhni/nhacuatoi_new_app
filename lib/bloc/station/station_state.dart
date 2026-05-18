import 'package:equatable/equatable.dart';
import 'package:iot_app/core/models/station_from_api.dart';

abstract class StationState extends Equatable {
  const StationState();

  @override
  List<Object?> get props => [];
}

class StationInitial extends StationState {}

class StationLoading extends StationState {}

class StationLoaded extends StationState {
  final List<StationApi> stations;

  const StationLoaded(this.stations);

  @override
  List<Object?> get props => [stations];
}

class StationError extends StationState {
  final String message;

  const StationError(this.message);

  @override
  List<Object?> get props => [message];
}
