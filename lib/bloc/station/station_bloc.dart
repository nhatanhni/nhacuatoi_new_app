import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot_app/bloc/station/station_event.dart';
import 'package:iot_app/bloc/station/station_state.dart';
import 'package:iot_app/core/models/station_from_api.dart';
import 'package:iot_app/core/services/api_service.dart';

class StationBloc extends Bloc<StationEvent, StationState> {
  final ApiService apiService;

  StationBloc({required this.apiService}) : super(StationInitial()) {
    on<StationLoadAll>(_onLoadAll);
  }

  Future<void> _onLoadAll(
    StationLoadAll event,
    Emitter<StationState> emit,
  ) async {
    emit(StationLoading());
    try {
      final stations = await apiService.fetchStations();
      final stationList = stations.map((s) => StationApi.fromJson(s)).toList();
      emit(StationLoaded(stationList));
    } catch (e) {
      emit(StationError(e.toString()));
    }
  }
}
