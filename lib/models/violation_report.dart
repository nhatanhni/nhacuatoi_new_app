class ViolationReport {
  final int? id;
  final String deviceSerial;
  final String deviceName;
  final String parameterName;
  final double violationValue;
  final DateTime violationTime;
  final String thresholdValue;

  ViolationReport({
    this.id,
    required this.deviceSerial,
    required this.deviceName,
    required this.parameterName,
    required this.violationValue,
    required this.violationTime,
    required this.thresholdValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deviceSerial': deviceSerial,
      'deviceName': deviceName,
      'parameterName': parameterName,
      'violationValue': violationValue,
      'violationTime': violationTime.toIso8601String(),
      'thresholdValue': thresholdValue,
    };
  }

  factory ViolationReport.fromMap(Map<String, dynamic> map) {
    return ViolationReport(
      id: map['id'],
      deviceSerial: map['deviceSerial'],
      deviceName: map['deviceName'],
      parameterName: map['parameterName'],
      violationValue: map['violationValue'],
      violationTime: DateTime.parse(map['violationTime']),
      thresholdValue: map['thresholdValue'],
    );
  }
} 