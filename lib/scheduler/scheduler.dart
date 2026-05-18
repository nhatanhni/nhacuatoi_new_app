// ignore_for_file: avoid_print

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:iot_app/core/services/database_helper.dart';
import 'package:iot_app/core/services/mqtt_manager.dart';

void deviceScheduler(int deviceId, Map<String, dynamic> params) async {
  final duration = params['duration'] as int;
  final repeat = params['repeat'] as bool;
  final deviceSerial = params['deviceSerial'] as String;

  final mqttManager = MQTTManager.instance;
  await mqttManager.ensureConnected();
  await mqttManager.publish('NhaCuaToi_$deviceSerial', 'ON');

  // Turn on the device
  await DatabaseHelper.updateDeviceStatusAndLogEvent(deviceId, 1);
  print("Device $deviceId is turned on for $duration seconds");

  // Wait for the specified duration
  await Future.delayed(Duration(seconds: duration));

  // Turn off the device
  await DatabaseHelper.updateDeviceStatusAndLogEvent(deviceId, 0);

  // Publish a message to turn off the device
  await mqttManager.publish('NhaCuaToi_$deviceSerial', 'OFF');

  // If the repeat option is set to 'Hằng ngày', schedule the next alarm
  if (repeat) {
    print("Rescheduling device $deviceId");
    AndroidAlarmManager.oneShot(
      const Duration(days: 1),
      deviceId,
      deviceScheduler,
      exact: true,
      wakeup: true,
      alarmClock: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
      params: params,
    );
  } else {
    print("Device $deviceId is not rescheduled");
  }
}
