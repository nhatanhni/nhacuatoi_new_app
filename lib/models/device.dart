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

// Model cho thiết bị quan trắc nước thải
class WastewaterMonitoringData {
  final double flowRate; // Lưu lượng (m³/h)
  final double temperature; // Nhiệt độ (°C)
  final double ph; // Độ PH
  final double tss; // TSS (mg/L)
  final double cod; // COD (mg/L)
  final double ammonia; // Amoni (mg/L)
  final DateTime timestamp;

  WastewaterMonitoringData({
    required this.flowRate,
    required this.temperature,
    required this.ph,
    required this.tss,
    required this.cod,
    required this.ammonia,
    required this.timestamp,
  });

  // Tạo dữ liệu demo ngẫu nhiên
  factory WastewaterMonitoringData.generateDemo() {
    return WastewaterMonitoringData(
      flowRate: 50 + (DateTime.now().millisecondsSinceEpoch % 100) * 0.1, // 50-60 m³/h
      temperature: 20 + (DateTime.now().millisecondsSinceEpoch % 15) * 0.1, // 20-21.5°C
      ph: 6.5 + (DateTime.now().millisecondsSinceEpoch % 30) * 0.01, // 6.5-6.8
      tss: 80 + (DateTime.now().millisecondsSinceEpoch % 40), // 80-120 mg/L
      cod: 150 + (DateTime.now().millisecondsSinceEpoch % 100), // 150-250 mg/L
      ammonia: 5 + (DateTime.now().millisecondsSinceEpoch % 15) * 0.1, // 5-6.5 mg/L
      timestamp: DateTime.now(),
    );
  }

  // Kiểm tra trạng thái cảnh báo
  Map<String, Map<String, dynamic>> getAlertStatus() {
    Map<String, Map<String, dynamic>> alerts = {};
    
    if (flowRate > 55) alerts['Lưu lượng'] = {
      'value': flowRate,
      'threshold': 55,
      'unit': 'm³/h',
      'status': 'Cao'
    };
    if (temperature > 21) alerts['Nhiệt độ'] = {
      'value': temperature,
      'threshold': 21,
      'unit': '°C',
      'status': 'Cao'
    };
    if (ph < 6.0 || ph > 8.5) alerts['Độ PH'] = {
      'value': ph,
      'threshold': ph < 6.0 ? 6.0 : 8.5,
      'unit': '',
      'status': 'Bất thường'
    };
    if (tss > 100) alerts['TSS'] = {
      'value': tss,
      'threshold': 100,
      'unit': 'mg/L',
      'status': 'Cao'
    };
    if (cod > 200) alerts['COD'] = {
      'value': cod,
      'threshold': 200,
      'unit': 'mg/L',
      'status': 'Cao'
    };
    if (ammonia > 6) alerts['Amoni'] = {
      'value': ammonia,
      'threshold': 6,
      'unit': 'mg/L',
      'status': 'Cao'
    };
    
    return alerts;
  }

  // Đánh giá chất lượng nước
  String getWaterQuality() {
    int goodCount = 0;
    int totalCount = 6;
    
    if (flowRate <= 55) goodCount++;
    if (temperature <= 21) goodCount++;
    if (ph >= 6.0 && ph <= 8.5) goodCount++;
    if (tss <= 100) goodCount++;
    if (cod <= 200) goodCount++;
    if (ammonia <= 6) goodCount++;
    
    double percentage = goodCount / totalCount * 100;
    
    if (percentage >= 80) return 'Tốt';
    if (percentage >= 60) return 'Trung bình';
    return 'Kém';
  }
}
