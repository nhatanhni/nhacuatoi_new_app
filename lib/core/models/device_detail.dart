class DeviceDetail {
  final String id;
  final String serial;
  final String name;
  final String deviceTypeName;
  final String stationName;
  final String adminLevelName;
  final String model;
  final String manufacturer;
  final String address;
  final String positionName;
  final bool startup;
  final bool isDisabled;
  final DateTime? lastHeartbeat;
  final String latitude;
  final String longitude;
  final String description;

  const DeviceDetail({
    required this.id,
    required this.serial,
    required this.name,
    required this.deviceTypeName,
    required this.stationName,
    required this.adminLevelName,
    required this.model,
    required this.manufacturer,
    required this.address,
    required this.positionName,
    required this.startup,
    required this.isDisabled,
    required this.lastHeartbeat,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  factory DeviceDetail.fromJson(Map<String, dynamic> json) {
    String pickString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return '';
    }

    bool pickBool(List<String> keys, {bool defaultValue = false}) {
      for (final key in keys) {
        final value = json[key];
        if (value is bool) return value;
        if (value is num) return value == 1;
        if (value is String) {
          final normalized = value.trim().toLowerCase();
          if (normalized == 'true' || normalized == '1' || normalized == 'on') {
            return true;
          }
          if (normalized == 'false' || normalized == '0' || normalized == 'off') {
            return false;
          }
        }
      }
      return defaultValue;
    }

    DateTime? pickDateTime(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    return DeviceDetail(
      id: pickString(['Id', 'id']),
      serial: pickString(['Serial', 'serial']),
      name: pickString(['Name', 'name']),
      deviceTypeName: pickString(['DeviceTypeName', 'deviceTypeName']),
      stationName: pickString(['StationName', 'stationName']),
      adminLevelName: pickString(['AdminLevelName', 'adminLevelName']),
      model: pickString(['Model', 'model']),
      manufacturer: pickString(['Manufacturer', 'manufacturer']),
      address: pickString(['Address', 'address']),
      positionName: pickString(['PositionName', 'positionName']),
      startup: pickBool(['Startup', 'startup']),
      isDisabled: pickBool(['IsDisabled', 'isDisabled']),
      lastHeartbeat: pickDateTime(['LastHeartbeat', 'lastHeartbeat']),
      latitude: pickString(['Latitude', 'latitude']),
      longitude: pickString(['Longitude', 'longitude']),
      description: pickString(['Description', 'description']),
    );
  }
}
