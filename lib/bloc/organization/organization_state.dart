import 'package:equatable/equatable.dart';
import 'package:iot_app/core/models/organization_unit.dart';

abstract class OrganizationState extends Equatable {
  const OrganizationState();

  @override
  List<Object?> get props => [];
}

class OrganizationInitial extends OrganizationState {}

class OrganizationLoading extends OrganizationState {}

class OrganizationLoaded extends OrganizationState {
  final List<OrganizationUnit> units;

  const OrganizationLoaded(this.units);

  @override
  List<Object?> get props => [units];
}

class OrganizationError extends OrganizationState {
  final String message;

  const OrganizationError(this.message);

  @override
  List<Object?> get props => [message];
}
