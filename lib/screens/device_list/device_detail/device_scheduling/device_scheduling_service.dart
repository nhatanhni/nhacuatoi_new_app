import 'package:iot_app/core/services/scheduler_repository.dart';

class DeviceSchedulingService {
  final _schedulerRepo = SchedulerRepository();

  Future<List<Map<String, dynamic>>> getSchedules(String deviceSerial) =>
      _schedulerRepo.getScheduleBySerial(deviceSerial);

  Future<void> createSchedule(Map<String, dynamic> schedule) =>
      _schedulerRepo.createSchedule(schedule);

  Future<void> updateSchedule(String id, Map<String, dynamic> updates) =>
      _schedulerRepo.updateSchedule(id, updates);

  Future<void> deleteSchedule(String id) =>
      _schedulerRepo.deleteSchedule(id);
}
