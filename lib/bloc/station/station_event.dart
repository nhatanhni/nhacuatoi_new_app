import 'package:equatable/equatable.dart';

abstract class StationEvent extends Equatable {
  const StationEvent();

  @override
  List<Object?> get props => [];
}

class StationLoadAll extends StationEvent {}
