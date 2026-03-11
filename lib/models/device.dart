import 'package:flutter/material.dart';

class Device {
  int? id;
  String deviceType;
  String deviceSerial;
  String deviceName;
  String? sensorType; // temperature or humidity
  int? sensorThreshold; // threshold for sensor
  int deviceStatus;
  String connectionStatus; // "online", "offline", "unknown"
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
    this.connectionStatus = "unknown",
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
      'connectionStatus': connectionStatus,
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
        connectionStatus = map['connectionStatus'] ?? "unknown",
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

// Model cho sensor mực nước
class WaterLevelSensor {
  final int? id;
  final String deviceSerial;
  final String deviceName;
  final double waterLevel; // Mực nước (cm)
  final double maxCapacity; // Dung tích tối đa (cm)
  final double minThreshold; // Ngưỡng cảnh báo thấp (cm)
  final double maxThreshold; // Ngưỡng cảnh báo cao (cm)
  final DateTime lastUpdate;
  final bool isActive;
  final int? parentDeviceId;
  final String connectionStatus; // "online", "offline", "unknown"

  WaterLevelSensor({
    this.id,
    required this.deviceSerial,
    required this.deviceName,
    required this.waterLevel,
    required this.maxCapacity,
    required this.minThreshold,
    required this.maxThreshold,
    required this.lastUpdate,
    required this.isActive,
    this.parentDeviceId,
    this.connectionStatus = 'unknown',
  });

  // Tạo sensor mực nước mặc định
  factory WaterLevelSensor.createDefault(String serial, String name, {int? parentDeviceId}) {
    return WaterLevelSensor(
      deviceSerial: serial,
      deviceName: name,
      waterLevel: 0.0,
      maxCapacity: 100.0,
      minThreshold: 10.0,
      maxThreshold: 90.0,
      lastUpdate: DateTime.now(),
      isActive: true,
      parentDeviceId: parentDeviceId,
      connectionStatus: 'unknown',
    );
  }

  // Getter cho mực nước hiện tại
  double get currentWaterLevel => waterLevel;

  // Getter cho serial
  String get serial => deviceSerial;

  // Getter cho name
  String get name => deviceName;

  // Tính phần trăm mực nước
  double get waterLevelPercentage {
    return (waterLevel / maxCapacity) * 100;
  }

  // Kiểm tra trạng thái cảnh báo
  String get alertStatus {
    if (waterLevel <= minThreshold) return 'Thấp';
    if (waterLevel >= maxThreshold) return 'Cao';
    return 'Bình thường';
  }

  // Màu sắc dựa trên mực nước
  Color get waterLevelColor {
    if (waterLevel <= minThreshold) return Colors.red;
    if (waterLevel >= maxThreshold) return Colors.orange;
    return Colors.green;
  }

  // Cập nhật mực nước
  WaterLevelSensor updateWaterLevel(double newWaterLevel) {
    return WaterLevelSensor(
      id: id,
      deviceSerial: deviceSerial,
      deviceName: deviceName,
      waterLevel: newWaterLevel,
      maxCapacity: maxCapacity,
      minThreshold: minThreshold,
      maxThreshold: maxThreshold,
      lastUpdate: DateTime.now(),
      isActive: isActive,
      parentDeviceId: parentDeviceId,
      connectionStatus: connectionStatus,
    );
  }

  // Copy with method
  WaterLevelSensor copyWith({
    int? id,
    String? deviceSerial,
    String? deviceName,
    double? waterLevel,
    double? maxCapacity,
    double? minThreshold,
    double? maxThreshold,
    DateTime? lastUpdate,
    bool? isActive,
    int? parentDeviceId,
    String? connectionStatus,
  }) {
    return WaterLevelSensor(
      id: id ?? this.id,
      deviceSerial: deviceSerial ?? this.deviceSerial,
      deviceName: deviceName ?? this.deviceName,
      waterLevel: waterLevel ?? this.waterLevel,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      minThreshold: minThreshold ?? this.minThreshold,
      maxThreshold: maxThreshold ?? this.maxThreshold,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      isActive: isActive ?? this.isActive,
      parentDeviceId: parentDeviceId ?? this.parentDeviceId,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deviceSerial': deviceSerial,
      'deviceName': deviceName,
      'waterLevel': waterLevel,
      'maxCapacity': maxCapacity,
      'minThreshold': minThreshold,
      'maxThreshold': maxThreshold,
      'lastUpdate': lastUpdate.toIso8601String(),
      'isActive': isActive ? 1 : 0, // Convert bool to int for database
      'parentDeviceId': parentDeviceId,
    };
  }

  factory WaterLevelSensor.fromMap(Map<String, dynamic> map) {
    return WaterLevelSensor(
      id: map['id'],
      deviceSerial: map['deviceSerial'],
      deviceName: map['deviceName'],
      waterLevel: map['waterLevel'].toDouble(),
      maxCapacity: map['maxCapacity'].toDouble(),
      minThreshold: map['minThreshold'].toDouble(),
      maxThreshold: map['maxThreshold'].toDouble(),
      lastUpdate: DateTime.parse(map['lastUpdate']),
      isActive: map['isActive'] == 1, // Convert int to bool from database
      parentDeviceId: map['parentDeviceId'],
    );
  }
}

// Model cho thiết bị con
class SubDevice {
  final int? id;
  final int parentDeviceId;
  final String subDeviceType; // pump, gate, water_sensor
  final int subDeviceNumber;
  final int subDeviceStatus; // 0: inactive, 1: active
  final String? deviceSerial;
  final String? deviceName;

  SubDevice({
    this.id,
    required this.parentDeviceId,
    required this.subDeviceType,
    required this.subDeviceNumber,
    required this.subDeviceStatus,
    this.deviceSerial,
    this.deviceName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parentDeviceId': parentDeviceId,
      'subDeviceType': subDeviceType,
      'subDeviceNumber': subDeviceNumber,
      'subDeviceStatus': subDeviceStatus,
      'deviceSerial': deviceSerial,
      'deviceName': deviceName,
    };
  }

  factory SubDevice.fromMap(Map<String, dynamic> map) {
    return SubDevice(
      id: map['id'],
      parentDeviceId: map['parentDeviceId'],
      subDeviceType: map['subDeviceType'],
      subDeviceNumber: map['subDeviceNumber'],
      subDeviceStatus: map['subDeviceStatus'],
      deviceSerial: map['deviceSerial'],
      deviceName: map['deviceName'],
    );
  }

  // Tạo tên hiển thị cho thiết bị con
  String get displayName {
    switch (subDeviceType) {
      case 'pump':
        return 'Máy Bơm $subDeviceNumber';
      case 'gate':
        return 'Cổng Phai $subDeviceNumber';
      case 'water_sensor':
        return 'Cảm Biến Mực Nước $subDeviceNumber';
      default:
        return 'Thiết Bị $subDeviceNumber';
    }
  }

  // Tạo serial number cho thiết bị con
  String generateSerial(String parentSerial) {
    return '${parentSerial}_${subDeviceType}_$subDeviceNumber';
  }
}

// Model cho thiết bị trạm bơm
class PumpStationDevice {
  final String deviceSerial;
  final String deviceName;
  final List<PumpStatus> pumps;
  final List<GateStatus> gates;
  final double waterLevel; // Mực nước từ cảm biến
  final DateTime lastUpdate;

  PumpStationDevice({
    required this.deviceSerial,
    required this.deviceName,
    required this.pumps,
    required this.gates,
    this.waterLevel = 0.0,
    required this.lastUpdate,
  });

  // Tạo thiết bị trạm bơm mặc định
  factory PumpStationDevice.createDefault(String serial, String name) {
    return PumpStationDevice(
      deviceSerial: serial,
      deviceName: name,
      pumps: [],
      gates: [],
      waterLevel: 0.0,
      lastUpdate: DateTime.now(),
    );
  }

  // Copy with method
  PumpStationDevice copyWith({
    String? deviceSerial,
    String? deviceName,
    List<PumpStatus>? pumps,
    List<GateStatus>? gates,
    double? waterLevel,
    DateTime? lastUpdate,
  }) {
    return PumpStationDevice(
      deviceSerial: deviceSerial ?? this.deviceSerial,
      deviceName: deviceName ?? this.deviceName,
      pumps: pumps ?? this.pumps,
      gates: gates ?? this.gates,
      waterLevel: waterLevel ?? this.waterLevel,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  // Cập nhật trạng thái máy bơm
  PumpStationDevice updatePumpStatus(int pumpIndex, bool isActive) {
    if (pumpIndex > 0 && pumpIndex <= pumps.length) {
      List<PumpStatus> updatedPumps = List.from(pumps);
      updatedPumps[pumpIndex - 1] = PumpStatus(
        id: updatedPumps[pumpIndex - 1].id,
        number: updatedPumps[pumpIndex - 1].number,
        isActive: isActive,
        hasWater: updatedPumps[pumpIndex - 1].hasWater,
        serial: updatedPumps[pumpIndex - 1].serial,
        name: updatedPumps[pumpIndex - 1].name,
      );

      return copyWith(pumps: updatedPumps);
    }
    return this;
  }

  // Cập nhật trạng thái cổng phai
  PumpStationDevice updateGateStatus(int gateIndex, bool isOpen) {
    if (gateIndex > 0 && gateIndex <= gates.length) {
      List<GateStatus> updatedGates = List.from(gates);
      updatedGates[gateIndex - 1] = GateStatus(
        id: updatedGates[gateIndex - 1].id,
        number: updatedGates[gateIndex - 1].number,
        isOpen: isOpen,
        serial: updatedGates[gateIndex - 1].serial,
        name: updatedGates[gateIndex - 1].name,
      );

      return copyWith(gates: updatedGates);
    }
    return this;
  }

  // Chuyển đổi thành Map để lưu vào database
  Map<String, dynamic> toMap() {
    return {
      'deviceSerial': deviceSerial,
      'deviceName': deviceName,
      'pumps': pumps.map((pump) => pump.toMap()).toList(),
      'gates': gates.map((gate) => gate.toMap()).toList(),
      'waterLevel': waterLevel,
      'lastUpdate': lastUpdate.toIso8601String(),
    };
  }

  // Tạo từ Map
  factory PumpStationDevice.fromMap(Map<String, dynamic> map) {
    return PumpStationDevice(
      deviceSerial: map['deviceSerial'],
      deviceName: map['deviceName'],
      pumps: (map['pumps'] as List)
          .map((pumpMap) => PumpStatus.fromMap(pumpMap))
          .toList(),
      gates: (map['gates'] as List)
          .map((gateMap) => GateStatus.fromMap(gateMap))
          .toList(),
      waterLevel: (map['waterLevel'] as num?)?.toDouble() ?? 0.0,
      lastUpdate: DateTime.parse(map['lastUpdate']),
    );
  }
}

// Model cho trạng thái máy bơm
class PumpStatus {
  final int? id;
  final int number;
  final bool isActive;
  final bool hasWater;
  final String serial;
  final String name;
  final String connectionStatus; // "online", "offline", "unknown"

  PumpStatus({
    this.id,
    required this.number,
    required this.isActive,
    required this.hasWater,
    this.serial = '',
    this.name = '',
    this.connectionStatus = 'unknown',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'isActive': isActive,
      'hasWater': hasWater,
      'serial': serial,
      'name': name,
      'connectionStatus': connectionStatus,
    };
  }

  factory PumpStatus.fromMap(Map<String, dynamic> map) {
    return PumpStatus(
      id: map['id'],
      number: map['number'],
      isActive: map['isActive'],
      hasWater: map['hasWater'],
      serial: map['serial'] ?? '',
      name: map['name'] ?? '',
      connectionStatus: map['connectionStatus'] ?? 'unknown',
    );
  }
}

// Model cho trạng thái cổng phai
class GateStatus {
  final int? id;
  final int number;
  final bool isOpen;
  final bool isClosed; // Trạng thái magnetic switch
  final String serial;
  final String name;
  final String connectionStatus; // "online", "offline", "unknown"

  GateStatus({
    this.id,
    required this.number,
    required this.isOpen,
    this.isClosed = false,
    this.serial = '',
    this.name = '',
    this.connectionStatus = 'unknown',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'isOpen': isOpen,
      'isClosed': isClosed,
      'serial': serial,
      'name': name,
      'connectionStatus': connectionStatus,
    };
  }

  factory GateStatus.fromMap(Map<String, dynamic> map) {
    return GateStatus(
      id: map['id'],
      number: map['number'],
      isOpen: map['isOpen'],
      isClosed: map['isClosed'] ?? false,
      serial: map['serial'] ?? '',
      name: map['name'] ?? '',
      connectionStatus: map['connectionStatus'] ?? 'unknown',
    );
  }
}

// Model cho lịch sử máy bơm
class PumpHistory {
  final int? id;
  final String deviceSerial;
  final int pumpNumber;
  final bool isRunning;
  final bool hasWater;
  final DateTime timestamp;
  final String action; // 'BẬT', 'TẮT'

  PumpHistory({
    this.id,
    required this.deviceSerial,
    required this.pumpNumber,
    required this.isRunning,
    required this.hasWater,
    required this.timestamp,
    required this.action,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deviceSerial': deviceSerial,
      'pumpNumber': pumpNumber,
      'isRunning': isRunning ? 1 : 0,
      'hasWater': hasWater ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
      'action': action,
    };
  }

  factory PumpHistory.fromMap(Map<String, dynamic> map) {
    return PumpHistory(
      id: map['id'],
      deviceSerial: map['deviceSerial'],
      pumpNumber: map['pumpNumber'],
      isRunning: map['isRunning'] == 1,
      hasWater: map['hasWater'] == 1,
      timestamp: DateTime.parse(map['timestamp']),
      action: map['action'],
    );
  }
}

// Model cho lịch sử cổng phai
class GateHistory {
  final int? id;
  final String deviceSerial;
  final int gateNumber;
  final bool isOpen;
  final DateTime timestamp;
  final String action; // 'MỞ', 'ĐÓNG'

  GateHistory({
    this.id,
    required this.deviceSerial,
    required this.gateNumber,
    required this.isOpen,
    required this.timestamp,
    required this.action,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deviceSerial': deviceSerial,
      'gateNumber': gateNumber,
      'isOpen': isOpen ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
      'action': action,
    };
  }

  factory GateHistory.fromMap(Map<String, dynamic> map) {
    return GateHistory(
      id: map['id'],
      deviceSerial: map['deviceSerial'],
      gateNumber: map['gateNumber'],
      isOpen: map['isOpen'] == 1,
      timestamp: DateTime.parse(map['timestamp']),
      action: map['action'],
    );
  }
}
