class Device {
  int? id;
  String deviceType;
  String deviceSerial;
  String deviceName;
  String? sensorType; // temperature or humidity
  int? sensorThreshold; // threshold for sensor
  int deviceStatus;
  int hasSchedule = 0;
  DateTime? scheduleTime;
  int? scheduleDuration;
  int? scheduleDaily;
  Device({
    this.id,
    required this.deviceType,
    required this.deviceSerial,
    required this.deviceName,
    this.sensorType,
    this.sensorThreshold,
    required this.deviceStatus,
    this.hasSchedule = 0,
    this.scheduleTime,
    this.scheduleDuration,
    this.scheduleDaily,
  });

  // Convert a SmartDevice into a Map. The keys must correspond to the names of the
  // columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deviceType': deviceType,
      'deviceSerial': deviceSerial,
      'deviceName': deviceName,
      'sensorType': sensorType,
      'sensorThreshold': sensorThreshold,
      'deviceStatus': deviceStatus,
      'hasSchedule': hasSchedule,
      'scheduleTime': scheduleTime?.toIso8601String(),
      'scheduleDuration': scheduleDuration,
      'scheduleDaily': scheduleDaily,
    };
  }

  // Extract a Device object from a Map object.
  Device.fromMap(Map<String, dynamic> map)
      : id = map['id'],
        deviceType = map['deviceType'],
        deviceSerial = map['deviceSerial'],
        deviceName = map['deviceName'],
        sensorType = map['sensorType'],
        sensorThreshold = map['sensorThreshold'],
        deviceStatus = map['deviceStatus'],
        hasSchedule = map['hasSchedule'],
        scheduleTime = map['scheduleTime'] != null
            ? DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
                int.parse(map['scheduleTime'].split(':')[0]),
                int.parse(map['scheduleTime'].split(':')[1]),
              )
            : null,
        scheduleDuration = map['scheduleDuration'],
        scheduleDaily = map['scheduleDaily'];
}
