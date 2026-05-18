import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot_app/bloc/organization/organization_event.dart';
import 'package:iot_app/bloc/organization/organization_state.dart';
import 'package:iot_app/core/models/organization_unit.dart';
import 'package:iot_app/core/services/api_service.dart';

class OrganizationBloc extends Bloc<OrganizationEvent, OrganizationState> {
  final ApiService apiService;

  OrganizationBloc({required this.apiService}) : super(OrganizationInitial()) {
    on<OrganizationLoadAll>(_onLoadAll);
  }

  Future<void> _onLoadAll(
    OrganizationLoadAll event,
    Emitter<OrganizationState> emit,
  ) async {
    emit(OrganizationLoading());
    try {
      final units = await apiService.fetchOrganizationUnits();
      final unitList = units
          .map((u) => OrganizationUnit.fromJson(u as Map<String, dynamic>))
          .toList();
      emit(OrganizationLoaded(unitList));
    } catch (e) {
      emit(OrganizationError(e.toString()));
    }
  }
}
