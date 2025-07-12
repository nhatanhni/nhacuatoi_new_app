// ignore_for_file: prefer_const_declarations

import 'package:iot_app/models/device.dart';
import 'package:iot_app/models/switch_event.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final _databaseName = "iotapp.db";
  static final _databaseVersion = 2;

  static final tableDevices = 'smart_device';
  static final tableSwitchEvents = 'switchEvents';

  static final columnId = 'id';
  static final columnDeviceType = 'deviceType';
  static final columnDeviceSerial = 'deviceSerial';
  static final columnDeviceName = 'deviceName';
  static final columnSensorType = 'sensorType';
  static final columnSensorThreshold = 'sensorThreshold';
  static final columnDeviceStatus = 'deviceStatus';
  static final columnHasSchedule = 'hasSchedule';
  static final columnScheduleTime = 'scheduleTime';
  static final columnScheduleDuration = 'scheduleDuration';
  static final columnScheduleDaily = 'scheduleDaily';

  static final columnTimestamp = 'timestamp';
  static final columnIsSwitched = 'isSwitched';
  static final columnDeviceId = 'deviceId';

  // Make this a singleton class.
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Only have a single app-wide reference to the database.
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Open the database and create it if it doesn't exist.
  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      await db.execute('''
      ALTER TABLE $tableDevices ADD COLUMN $columnDeviceStatus BOOLEAN NOT NULL DEFAULT 0
    ''');
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $tableDevices (
            $columnId INTEGER PRIMARY KEY,
            $columnDeviceType TEXT NOT NULL,
            $columnDeviceSerial TEXT NOT NULL,
            $columnDeviceName TEXT NOT NULL,
            $columnSensorType TEXT,
            $columnSensorThreshold INTEGER,
            $columnDeviceStatus BOOLEAN NOT NULL,
            $columnHasSchedule BOOLEAN NOT NULL DEFAULT 0,
            $columnScheduleTime TEXT,
            $columnScheduleDuration INTEGER,
            $columnScheduleDaily INTEGER
          )
          ''');
    await db.execute('''
      CREATE TABLE $tableSwitchEvents (
        $columnId INTEGER PRIMARY KEY,
        $columnDeviceId INTEGER NOT NULL,
        $columnTimestamp TEXT NOT NULL,
        $columnIsSwitched INTEGER NOT NULL,
        FOREIGN KEY ($columnDeviceId) REFERENCES $tableDevices ($columnId)
      )
    ''');
  }

  // Insert a SmartDevice into the database.
  Future<int> insertDevice(Device device) async {
    Database db = await instance.database;
    var res = await db.insert(tableDevices, device.toMap());
    return res;
  }

  // Insert a SwitchEvent into the database.
  Future<int> insertSwitchEvent(SwitchEvent event, int deviceId) async {
    Database db = await instance.database;
    return await db.insert(
      tableSwitchEvents,
      {
        columnDeviceId: deviceId,
        columnTimestamp: event.timestamp.toIso8601String(),
        columnIsSwitched: event.isSwitched ? 1 : 0,
      },
    );
  }

  // update schedule time, duration and daily for a device
  Future<int> updateDeviceSchedule(
      int id, String time, int duration, int daily) async {
    Database db = await instance.database;
    return await db.update(
      tableDevices,
      {
        columnScheduleTime: time,
        columnScheduleDuration: duration,
        columnScheduleDaily: daily,
      },
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // query switch events by device id
  Future<List<SwitchEvent>> querySwitchEventsByDeviceId(int deviceId) async {
    Database db = await instance.database;
    var res = await db.query(tableSwitchEvents,
        where: '$columnDeviceId = ?', whereArgs: [deviceId]);
    List<SwitchEvent> list =
        res.isNotEmpty ? res.map((c) => SwitchEvent.fromMap(c)).toList() : [];
    return list;
  }

  // delete switch events by device id
  Future<int> deleteSwitchEvents(int deviceId) async {
    Database db = await instance.database;
    return await db.delete(tableSwitchEvents,
        where: '$columnDeviceId = ?', whereArgs: [deviceId]);
  }

  // return all devices
  Future<List<Device>> queryAllDevices() async {
    Database db = await instance.database;
    var res = await db.query(tableDevices);
    List<Device> list =
        res.isNotEmpty ? res.map((c) => Device.fromMap(c)).toList() : [];
    return list;
  }
  Future<Device?> queryDeviceBySerial(String deviceSerial) async {
    Database db = await instance.database;
    var res = await db.query(tableDevices,
        where: '$columnDeviceSerial = ?', whereArgs: [deviceSerial], limit: 1);
    return res.isNotEmpty ? Device.fromMap(res.first) : null;
  }
  // query a device by id
  Future<Device?> queryDeviceById(int id) async {
    Database db = await instance.database;
    var res = await db.query(tableDevices,
        where: '$columnId = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? Device.fromMap(res.first) : null;
  }

  // query a device by deviceType
  Future<List<Device>> queryDevicesByType(String deviceType) async {
    Database db = await instance.database;
    var res = await db.query(tableDevices,
        where: '$columnDeviceType = ?', whereArgs: [deviceType]);
    List<Device> list =
        res.isNotEmpty ? res.map((c) => Device.fromMap(c)).toList() : [];
    return list;
  }

  // delete a device
  Future<int> deleteDevice(int id) async {
    Database db = await instance.database;
    return await db
        .delete(tableDevices, where: '$columnId = ?', whereArgs: [id]);
  }

  // delete all devices
  Future<int> deleteAllDevices() async {
    Database db = await instance.database;
    return await db.delete(tableDevices);
  }

  // update a device's status given its id
  Future<int> updateDeviceStatus(int id, int status) async {
    Database db = await instance.database;

    // Get the current device status
    List<Map<String, dynamic>> queryResult =
        await db.query(tableDevices, where: '$columnId = ?', whereArgs: [id]);

    Map<String, dynamic> currentDevice = queryResult.first;

    // Update the device status
    int result = await db.update(tableDevices, {'deviceStatus': status},
        where: '$columnId = ?', whereArgs: [id]);

    // If the update was successful and the status has changed, log the switch event
    if (result != 0 && currentDevice['deviceStatus'] != status) {
      SwitchEvent event = SwitchEvent(
        DateTime.now(),
        status == 1,
      );

      await insertSwitchEvent(event, id);
    }

    return result;
  }

  static Future<int> updateDeviceStatusAndLogEvent(int id, int status) async {
  // Get a new instance of the database
  Database db = await DatabaseHelper.instance.database;

  // Get the current device status
  List<Map<String, dynamic>> queryResult =
      await db.query(tableDevices, where: '$columnId = ?', whereArgs: [id]);

  Map<String, dynamic> currentDevice = queryResult.first;

  // Update the device status
  int result = await db.update(tableDevices, {'deviceStatus': status},
      where: '$columnId = ?', whereArgs: [id]);

  // If the update was successful and the status has changed, log the switch event
  if (result != 0 && currentDevice['deviceStatus'] != status) {
    SwitchEvent event = SwitchEvent(
      DateTime.now(),
      status == 1,
    );

    await DatabaseHelper.instance.insertSwitchEvent(event, id);
  }

  return result;
}

  // update device has schedule
  Future<int> updateDeviceHasSchedule(int id, int hasSchedule) async {
    Database db = await instance.database;
    return await db.update(tableDevices, {'hasSchedule': hasSchedule},
        where: '$columnId = ?', whereArgs: [id]);
  }

  // Other database helper methods go here...
}
