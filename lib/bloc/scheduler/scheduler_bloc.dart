import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot_app/bloc/scheduler/scheduler_event.dart';
import 'package:iot_app/bloc/scheduler/scheduler_state.dart';
import 'package:iot_app/core/services/scheduler_repository.dart';

class SchedulerBloc extends Bloc<SchedulerEvent, SchedulerState> {
  final SchedulerRepository schedulerRepository;

  // Keep a local copy of schedules to pass alongside action states
  List<Map<String, dynamic>> _schedules = [];

  SchedulerBloc({required this.schedulerRepository})
      : super(SchedulerInitial()) {
    on<SchedulerLoadRequested>(_onLoadRequested);
    on<SchedulerCreateRequested>(_onCreateRequested);
    on<SchedulerUpdateRequested>(_onUpdateRequested);
    on<SchedulerDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(
    SchedulerLoadRequested event,
    Emitter<SchedulerState> emit,
  ) async {
    emit(SchedulerLoadInProgress());
    try {
      final schedules =
          await schedulerRepository.getScheduleBySerial(event.serial);
      _schedules = schedules;
      emit(SchedulerLoadSuccess(List.unmodifiable(_schedules)));
    } catch (e) {
      emit(SchedulerLoadFailure('Không thể tải lịch hẹn giờ. Vui lòng thử lại.'));
    }
  }

  Future<void> _onCreateRequested(
    SchedulerCreateRequested event,
    Emitter<SchedulerState> emit,
  ) async {
    emit(SchedulerActionInProgress(List.unmodifiable(_schedules)));
    try {
      final schedule = {
        "serial": event.serial,
        "nameDevice": event.deviceName,
        "Date_Type": "1",
        "repeat": event.repeat,
        "time":
            "${event.hour.toString().padLeft(2, '0')}:${event.minute.toString().padLeft(2, '0')}",
        "numberTime": event.duration,
        "status": 1,
        "topic": "NhaCuaToi_${event.serial}",
        "messenger": "ON",
        "updateTime": DateTime.now().toIso8601String(),
      };
      await schedulerRepository.createSchedule(schedule);
      final updated =
          await schedulerRepository.getScheduleBySerial(event.serial);
      _schedules = updated;
      emit(SchedulerActionSuccess(
        schedules: List.unmodifiable(_schedules),
        message: 'Thêm hẹn giờ thành công!',
      ));
    } catch (e) {
      emit(SchedulerActionFailure(
        schedules: List.unmodifiable(_schedules),
        message: 'Thêm hẹn giờ thất bại. Vui lòng thử lại.',
      ));
    }
  }

  Future<void> _onUpdateRequested(
    SchedulerUpdateRequested event,
    Emitter<SchedulerState> emit,
  ) async {
    emit(SchedulerActionInProgress(List.unmodifiable(_schedules)));
    try {
      await schedulerRepository.updateSchedule(event.id, event.updates);
      final updated =
          await schedulerRepository.getScheduleBySerial(event.serial);
      _schedules = updated;
      emit(SchedulerActionSuccess(
        schedules: List.unmodifiable(_schedules),
        message: 'Sửa hẹn giờ thành công!',
      ));
    } catch (e) {
      emit(SchedulerActionFailure(
        schedules: List.unmodifiable(_schedules),
        message: 'Sửa hẹn giờ thất bại. Vui lòng thử lại.',
      ));
    }
  }

  Future<void> _onDeleteRequested(
    SchedulerDeleteRequested event,
    Emitter<SchedulerState> emit,
  ) async {
    emit(SchedulerActionInProgress(List.unmodifiable(_schedules)));
    try {
      await schedulerRepository.deleteSchedule(event.id);
      final updated =
          await schedulerRepository.getScheduleBySerial(event.serial);
      _schedules = updated;
      emit(SchedulerActionSuccess(
        schedules: List.unmodifiable(_schedules),
        message: 'Xoá hẹn giờ thành công!',
      ));
    } catch (e) {
      emit(SchedulerActionFailure(
        schedules: List.unmodifiable(_schedules),
        message: 'Xoá hẹn giờ thất bại. Vui lòng thử lại.',
      ));
    }
  }
}
