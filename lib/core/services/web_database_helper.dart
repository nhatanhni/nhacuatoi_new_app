// Web-compatible database helper using shared_preferences for storage
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Create alias for compatibility
typedef DatabaseHelper = WebDatabaseHelper;

class WebDatabaseHelper {
  static final WebDatabaseHelper instance = WebDatabaseHelper._privateConstructor();
  WebDatabaseHelper._privateConstructor();

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  // Device operations
  Future<List<dynamic>> queryAllDevices() async {
    await _ensureInitialized();
    return [];
  }

  Future<dynamic> queryDeviceBySerial(String serial) async {
    await _ensureInitialized();
    return null;
  }

  Future<List<dynamic>> queryDevicesByType(String deviceType) async {
    await _ensureInitialized();
    return [];
  }

  Future<int> insertDevice(dynamic device) async {
    await _ensureInitialized();
    return 1;
  }

  Future<int> updateDevice(dynamic device) async {
    await _ensureInitialized();
    return 1;
  }

  Future<int> updateDeviceStatus(dynamic id, bool status) async {
    await _ensureInitialized();
    return 1;
  }

  Future<int> updateDeviceConnectionStatus(String deviceSerial, String status) async {
    await _ensureInitialized();
    return 1;
  }

  Future<int> deleteDevice(String deviceSerial) async {
    await _ensureInitialized();
    return 1;
  }

  Future<int> deleteAllDevices() async {
    await _ensureInitialized();
    return 1;
  }

  // Sub devices operations
  Future<List<dynamic>> querySubDevicesByType(String parentSerial, String subDeviceType) async {
    await _ensureInitialized();
    return [];
  }

  Future<List<dynamic>> querySubDevicesByParentId(int parentId) async {
    await _ensureInitialized();
    return [];
  }

  Future<int> insertSubDevice(dynamic subDevice) async {
    await _ensureInitialized();
    return 1;
  }

  Future<int> updateSubDeviceInfo(dynamic id, String name, String description) async {
    await _ensureInitialized();
    return 1;
  }

  Future<int> deleteSubDevice(int id) async {
    await _ensureInitialized();
    return 1;
  }

  Future<void> createDefaultPumpStationSubDevices(int deviceId) async {
    await _ensureInitialized();
    // Do nothing for web compatibility
  }

  // Water level sensors
  Future<List<dynamic>> queryWaterLevelSensorsByParentId(int parentId) async {
    await _ensureInitialized();
    return [];
  }

  Future<List<dynamic>> queryAllWaterLevelSensors(String parentSerial) async {
    await _ensureInitialized();
    return [];
  }

  Future<int> insertWaterLevelSensor(dynamic sensor) async {
    await _ensureInitialized();
    return 1;
  }

  Future<int> updateWaterLevelSensor(dynamic sensor) async {
    await _ensureInitialized();
    return 1;
  }

  Future<int> deleteWaterLevelSensor(int id) async {
    await _ensureInitialized();
    return 1;
  }

  // Switch events
  Future<List<dynamic>> querySwitchEventsBySerial(String serial) async {
    await _ensureInitialized();
    return [];
  }

  Future<List<dynamic>> querySwitchEventsByDeviceId(int deviceId) async {
    await _ensureInitialized();
    return [];
  }

  Future<int> insertSwitchEvent(dynamic event) async {
    await _ensureInitialized();
    return 1;
  }

  Future<int> deleteSwitchEvents(int deviceId) async {
    await _ensureInitialized();
    return 1;
  }

  // Relay state operations
  Future<void> saveRelayState(String deviceSerial, int deviceNumber, int relayNumber, bool state) async {
    await _ensureInitialized();
    final key = 'relay_${deviceSerial}_${deviceNumber}_$relayNumber';
    await _prefs.setBool(key, state);
    await _prefs.setInt('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool?> getRelayState(String deviceSerial, int deviceNumber, int relayNumber) async {
    await _ensureInitialized();
    final key = 'relay_${deviceSerial}_${deviceNumber}_$relayNumber';
    return _prefs.getBool(key);
  }

  Future<DateTime?> getRelayTimestamp(String deviceSerial, int deviceNumber, int relayNumber) async {
    await _ensureInitialized();
    final key = 'relay_${deviceSerial}_${deviceNumber}_$relayNumber';
    final timestamp = _prefs.getInt('${key}_timestamp');
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  Future<Map<String, dynamic>?> getRelayStateWithTimestamp(String deviceSerial, int deviceNumber, int relayNumber, bool expectedState) async {
    await _ensureInitialized();
    final state = await getRelayState(deviceSerial, deviceNumber, relayNumber);
    final timestamp = await getRelayTimestamp(deviceSerial, deviceNumber, relayNumber);
    
    if (state == expectedState && timestamp != null) {
      return {
        'state': state,
        'timestamp': timestamp,
      };
    }
    return null;
  }

  // Database compatibility
  Future<dynamic> get database async => null;

  // Close method for compatibility
  Future<void> close() async {
    // Nothing to close for SharedPreferences
  }
}
