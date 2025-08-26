// ignore_for_file: prefer_const_declarations

import 'package:iot_app/models/device.dart';
import 'package:iot_app/models/switch_event.dart';
import 'package:iot_app/models/violation_report.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final _databaseName = "iotapp.db";
  static final _databaseVersion = 9;

  static final tableDevices = 'smart_device';
  static final tableSwitchEvents = 'switchEvents';
  static final tableViolationReports = 'violation_reports';
  static final tablePumpHistory = 'pump_history';
  static final tableGateHistory = 'gate_history';
  static final tableSubDevices = 'sub_devices';
  static final tableWaterLevelSensors = 'water_level_sensors';
  static final tableRelayStates = 'relay_states';

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

  // Sub device columns
  static final columnParentDeviceId = 'parentDeviceId';
  static final columnSubDeviceType = 'subDeviceType';
  static final columnSubDeviceNumber = 'subDeviceNumber';
  static final columnSubDeviceStatus = 'subDeviceStatus';

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
    if (oldVersion < 2) {
      await db.execute('''
      ALTER TABLE $tableDevices ADD COLUMN $columnDeviceStatus BOOLEAN NOT NULL DEFAULT 0
    ''');
    }
    if (oldVersion < 3) {
          await db.execute('''
      CREATE TABLE $tableViolationReports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deviceSerial TEXT NOT NULL,
        deviceName TEXT NOT NULL,
        parameterName TEXT NOT NULL,
        violationValue REAL NOT NULL,
        violationTime TEXT NOT NULL,
        thresholdValue TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tablePumpHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deviceSerial TEXT NOT NULL,
        pumpNumber INTEGER NOT NULL,
        isRunning INTEGER NOT NULL,
        hasWater INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        action TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableGateHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deviceSerial TEXT NOT NULL,
        gateNumber INTEGER NOT NULL,
        isOpen INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        action TEXT NOT NULL
      )
    ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE $tablePumpHistory (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          deviceSerial TEXT NOT NULL,
          pumpNumber INTEGER NOT NULL,
          isRunning INTEGER NOT NULL,
          hasWater INTEGER NOT NULL,
          timestamp TEXT NOT NULL,
          action TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE $tableGateHistory (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          deviceSerial TEXT NOT NULL,
          gateNumber INTEGER NOT NULL,
          isOpen INTEGER NOT NULL,
          timestamp TEXT NOT NULL,
          action TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      // Tạo bảng thiết bị con
      await db.execute('''
        CREATE TABLE $tableSubDevices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          $columnParentDeviceId INTEGER NOT NULL,
          $columnSubDeviceType TEXT NOT NULL,
          $columnSubDeviceNumber INTEGER NOT NULL,
          $columnSubDeviceStatus INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY ($columnParentDeviceId) REFERENCES $tableDevices ($columnId)
        )
      ''');
      
      // Tạo bảng sensor mực nước
      await db.execute('''
        CREATE TABLE $tableWaterLevelSensors (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          deviceSerial TEXT NOT NULL,
          deviceName TEXT NOT NULL,
          waterLevel REAL NOT NULL DEFAULT 0.0,
          maxCapacity REAL NOT NULL DEFAULT 100.0,
          minThreshold REAL NOT NULL DEFAULT 10.0,
          maxThreshold REAL NOT NULL DEFAULT 90.0,
          lastUpdate TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 6) {
      // Thêm cột deviceSerial và deviceName vào bảng sub_devices
      await db.execute('ALTER TABLE $tableSubDevices ADD COLUMN deviceSerial TEXT');
      await db.execute('ALTER TABLE $tableSubDevices ADD COLUMN deviceName TEXT');
    }
    if (oldVersion < 7) {
      // Thêm cột parentDeviceId vào bảng water_level_sensors
      await db.execute('ALTER TABLE $tableWaterLevelSensors ADD COLUMN parentDeviceId INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 8) {
      // Tạo bảng relay_states để lưu trạng thái relay
      await db.execute('''
        CREATE TABLE $tableRelayStates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_serial TEXT NOT NULL,
          device_order INTEGER NOT NULL,
          relay_number INTEGER NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 0,
          last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(device_serial, device_order, relay_number)
        )
      ''');
    }
    if (oldVersion < 9) {
      // Đảm bảo tất cả bảng cần thiết được tạo cho version 9
      // Kiểm tra và tạo các bảng còn thiếu nếu cần
      var tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      var tableNames = tables.map((t) => t['name']).toSet();
      
      if (!tableNames.contains(tableSubDevices)) {
        await db.execute('''
          CREATE TABLE $tableSubDevices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnParentDeviceId INTEGER NOT NULL,
            $columnSubDeviceType TEXT NOT NULL,
            $columnSubDeviceNumber INTEGER NOT NULL,
            $columnSubDeviceStatus INTEGER NOT NULL DEFAULT 0,
            deviceSerial TEXT,
            deviceName TEXT,
            FOREIGN KEY ($columnParentDeviceId) REFERENCES $tableDevices ($columnId)
          )
        ''');
      }
      
      if (!tableNames.contains(tableWaterLevelSensors)) {
        await db.execute('''
          CREATE TABLE $tableWaterLevelSensors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            deviceSerial TEXT NOT NULL,
            deviceName TEXT NOT NULL,
            waterLevel REAL NOT NULL DEFAULT 0.0,
            maxCapacity REAL NOT NULL DEFAULT 100.0,
            minThreshold REAL NOT NULL DEFAULT 10.0,
            maxThreshold REAL NOT NULL DEFAULT 90.0,
            lastUpdate TEXT NOT NULL,
            isActive INTEGER NOT NULL DEFAULT 1,
            parentDeviceId INTEGER NOT NULL DEFAULT 0
          )
        ''');
      }
      
      if (!tableNames.contains(tableRelayStates)) {
        await db.execute('''
          CREATE TABLE $tableRelayStates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_serial TEXT NOT NULL,
            device_order INTEGER NOT NULL,
            relay_number INTEGER NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 0,
            last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(device_serial, device_order, relay_number)
          )
        ''');
      }
      
      if (!tableNames.contains(tablePumpHistory)) {
        await db.execute('''
          CREATE TABLE $tablePumpHistory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            deviceSerial TEXT NOT NULL,
            pumpNumber INTEGER NOT NULL,
            isRunning INTEGER NOT NULL,
            hasWater INTEGER NOT NULL,
            timestamp TEXT NOT NULL,
            action TEXT NOT NULL
          )
        ''');
      }
      
      if (!tableNames.contains(tableGateHistory)) {
        await db.execute('''
          CREATE TABLE $tableGateHistory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            deviceSerial TEXT NOT NULL,
            gateNumber INTEGER NOT NULL,
            isOpen INTEGER NOT NULL,
            timestamp TEXT NOT NULL,
            action TEXT NOT NULL
          )
        ''');
      }
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
    await db.execute('''
      CREATE TABLE $tableViolationReports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deviceSerial TEXT NOT NULL,
        deviceName TEXT NOT NULL,
        parameterName TEXT NOT NULL,
        violationValue REAL NOT NULL,
        violationTime TEXT NOT NULL,
        thresholdValue TEXT NOT NULL
      )
    ''');
    
    // Tạo bảng thiết bị con
    await db.execute('''
      CREATE TABLE $tableSubDevices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnParentDeviceId INTEGER NOT NULL,
        $columnSubDeviceType TEXT NOT NULL,
        $columnSubDeviceNumber INTEGER NOT NULL,
        $columnSubDeviceStatus INTEGER NOT NULL DEFAULT 0,
        deviceSerial TEXT,
        deviceName TEXT,
        FOREIGN KEY ($columnParentDeviceId) REFERENCES $tableDevices ($columnId)
      )
    ''');
    
    // Tạo bảng sensor mực nước
    await db.execute('''
      CREATE TABLE $tableWaterLevelSensors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deviceSerial TEXT NOT NULL,
        deviceName TEXT NOT NULL,
        waterLevel REAL NOT NULL DEFAULT 0.0,
        maxCapacity REAL NOT NULL DEFAULT 100.0,
        minThreshold REAL NOT NULL DEFAULT 10.0,
        maxThreshold REAL NOT NULL DEFAULT 90.0,
        lastUpdate TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        parentDeviceId INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    // Tạo bảng lưu trạng thái relay để giữ trạng thái bật/tắt của thiết bị con
    await db.execute('''
      CREATE TABLE $tableRelayStates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_serial TEXT NOT NULL,
        device_order INTEGER NOT NULL,
        relay_number INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0,
        last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(device_serial, device_order, relay_number)
      )
    ''');
    
    // Tạo bảng lịch sử máy bơm
    await db.execute('''
      CREATE TABLE $tablePumpHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deviceSerial TEXT NOT NULL,
        pumpNumber INTEGER NOT NULL,
        isRunning INTEGER NOT NULL,
        hasWater INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        action TEXT NOT NULL
      )
    ''');
    
    // Tạo bảng lịch sử cổng phai
    await db.execute('''
      CREATE TABLE $tableGateHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deviceSerial TEXT NOT NULL,
        gateNumber INTEGER NOT NULL,
        isOpen INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        action TEXT NOT NULL
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

  // Insert a ViolationReport into the database.
  Future<int> insertViolationReport(ViolationReport report) async {
    Database db = await instance.database;
    return await db.insert(tableViolationReports, report.toMap());
  }

  // Get all violation reports
  Future<List<ViolationReport>> queryAllViolationReports() async {
    Database db = await instance.database;
    var res = await db.query(tableViolationReports, orderBy: 'violationTime DESC');
    List<ViolationReport> list =
        res.isNotEmpty ? res.map((c) => ViolationReport.fromMap(c)).toList() : [];
    return list;
  }

  // Get violation reports by date range
  Future<List<ViolationReport>> queryViolationReportsByDateRange(DateTime startDate, DateTime endDate) async {
    Database db = await instance.database;
    var res = await db.query(
      tableViolationReports,
      where: 'violationTime BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'violationTime DESC'
    );
    List<ViolationReport> list =
        res.isNotEmpty ? res.map((c) => ViolationReport.fromMap(c)).toList() : [];
    return list;
  }

  // Get violation reports by device serial
  Future<List<ViolationReport>> queryViolationReportsByDeviceSerial(String deviceSerial) async {
    Database db = await instance.database;
    var res = await db.query(
      tableViolationReports,
      where: 'deviceSerial = ?',
      whereArgs: [deviceSerial],
      orderBy: 'violationTime DESC'
    );
    List<ViolationReport> list =
        res.isNotEmpty ? res.map((c) => ViolationReport.fromMap(c)).toList() : [];
    return list;
  }

  // Delete violation reports by device serial
  Future<int> deleteViolationReportsByDeviceSerial(String deviceSerial) async {
    Database db = await instance.database;
    return await db.delete(
      tableViolationReports,
      where: 'deviceSerial = ?',
      whereArgs: [deviceSerial]
    );
  }

  // Pump History Methods
  Future<int> insertPumpHistory(PumpHistory history) async {
    Database db = await instance.database;
    return await db.insert(tablePumpHistory, history.toMap());
  }

  Future<List<PumpHistory>> queryPumpHistoryByDeviceSerial(String deviceSerial) async {
    Database db = await instance.database;
    var res = await db.query(
      tablePumpHistory,
      where: 'deviceSerial = ?',
      whereArgs: [deviceSerial],
      orderBy: 'timestamp DESC'
    );
    List<PumpHistory> list =
        res.isNotEmpty ? res.map((c) => PumpHistory.fromMap(c)).toList() : [];
    return list;
  }

  Future<List<PumpHistory>> queryPumpHistoryByPumpNumber(String deviceSerial, int pumpNumber) async {
    Database db = await instance.database;
    var res = await db.query(
      tablePumpHistory,
      where: 'deviceSerial = ? AND pumpNumber = ?',
      whereArgs: [deviceSerial, pumpNumber],
      orderBy: 'timestamp DESC'
    );
    List<PumpHistory> list =
        res.isNotEmpty ? res.map((c) => PumpHistory.fromMap(c)).toList() : [];
    return list;
  }

  Future<List<PumpHistory>> queryAllPumpHistory() async {
    Database db = await instance.database;
    var res = await db.query(tablePumpHistory, orderBy: 'timestamp DESC');
    List<PumpHistory> list =
        res.isNotEmpty ? res.map((c) => PumpHistory.fromMap(c)).toList() : [];
    return list;
  }

  // Gate History Methods
  Future<int> insertGateHistory(GateHistory history) async {
    Database db = await instance.database;
    return await db.insert(tableGateHistory, history.toMap());
  }

  Future<List<GateHistory>> queryGateHistoryByDeviceSerial(String deviceSerial) async {
    Database db = await instance.database;
    var res = await db.query(
      tableGateHistory,
      where: 'deviceSerial = ?',
      whereArgs: [deviceSerial],
      orderBy: 'timestamp DESC'
    );
    List<GateHistory> list =
        res.isNotEmpty ? res.map((c) => GateHistory.fromMap(c)).toList() : [];
    return list;
  }

  Future<List<GateHistory>> queryGateHistoryByGateNumber(String deviceSerial, int gateNumber) async {
    Database db = await instance.database;
    var res = await db.query(
      tableGateHistory,
      where: 'deviceSerial = ? AND gateNumber = ?',
      whereArgs: [deviceSerial, gateNumber],
      orderBy: 'timestamp DESC'
    );
    List<GateHistory> list =
        res.isNotEmpty ? res.map((c) => GateHistory.fromMap(c)).toList() : [];
    return list;
  }

  Future<List<GateHistory>> queryAllGateHistory() async {
    Database db = await instance.database;
    var res = await db.query(tableGateHistory, orderBy: 'timestamp DESC');
    List<GateHistory> list =
        res.isNotEmpty ? res.map((c) => GateHistory.fromMap(c)).toList() : [];
    return list;
  }

  // Delete history methods
  Future<int> deletePumpHistoryByDeviceSerial(String deviceSerial) async {
    Database db = await instance.database;
    return await db.delete(
      tablePumpHistory,
      where: 'deviceSerial = ?',
      whereArgs: [deviceSerial]
    );
  }

  Future<int> deleteGateHistoryByDeviceSerial(String deviceSerial) async {
    Database db = await instance.database;
    return await db.delete(
      tableGateHistory,
      where: 'deviceSerial = ?',
      whereArgs: [deviceSerial]
    );
  }

  Future<int> deleteAllPumpHistory() async {
    Database db = await instance.database;
    return await db.delete(tablePumpHistory);
  }

  Future<int> deleteAllGateHistory() async {
    Database db = await instance.database;
    return await db.delete(tableGateHistory);
  }

  // Sub Device Methods
  Future<int> insertSubDevice(int parentDeviceId, String subDeviceType, int subDeviceNumber) async {
    Database db = await instance.database;
    final data = {
      columnParentDeviceId: parentDeviceId,
      columnSubDeviceType: subDeviceType,
      columnSubDeviceNumber: subDeviceNumber,
      columnSubDeviceStatus: 0, // Default inactive
      'deviceSerial': '', // Default empty serial
      'deviceName': '', // Default empty name
    };
    
    print('🔧 Inserting sub device: $data');
    final id = await db.insert(tableSubDevices, data);
    print('✅ Inserted sub device with ID: $id');
    return id;
  }

  Future<List<SubDevice>> querySubDevicesByParentId(int parentDeviceId) async {
    Database db = await instance.database;
    var res = await db.query(
      tableSubDevices,
      where: '$columnParentDeviceId = ?',
      whereArgs: [parentDeviceId],
      orderBy: '$columnSubDeviceType, $columnSubDeviceNumber'
    );
    return res.map((c) => SubDevice.fromMap(c)).toList();
  }

  Future<List<SubDevice>> querySubDevicesByType(int parentDeviceId, String subDeviceType) async {
    Database db = await instance.database;
    var res = await db.query(
      tableSubDevices,
      where: '$columnParentDeviceId = ? AND $columnSubDeviceType = ?',
      whereArgs: [parentDeviceId, subDeviceType],
      orderBy: '$columnSubDeviceNumber'
    );
    return res.map((c) => SubDevice.fromMap(c)).toList();
  }

  Future<int> updateSubDeviceStatus(int subDeviceId, int status) async {
    Database db = await instance.database;
    return await db.update(
      tableSubDevices,
      {columnSubDeviceStatus: status},
      where: 'id = ?',
      whereArgs: [subDeviceId]
    );
  }

  Future<int> updateSubDeviceInfo(int subDeviceId, String serial, String name) async {
    Database db = await instance.database;
    final data = {
      'deviceSerial': serial,
      'deviceName': name,
    };
    
    print('🔧 Updating sub device ID $subDeviceId with: $data');
    final result = await db.update(
      tableSubDevices,
      data,
      where: 'id = ?',
      whereArgs: [subDeviceId]
    );
    print('✅ Updated $result rows for sub device ID: $subDeviceId');
    return result;
  }

  Future<int> deleteSubDevice(int subDeviceId) async {
    Database db = await instance.database;
    return await db.delete(
      tableSubDevices,
      where: 'id = ?',
      whereArgs: [subDeviceId]
    );
  }

  Future<int> deleteAllSubDevicesByParentId(int parentDeviceId) async {
    Database db = await instance.database;
    return await db.delete(
      tableSubDevices,
      where: '$columnParentDeviceId = ?',
      whereArgs: [parentDeviceId]
    );
  }



  // Water Level Sensor Methods
  Future<int> insertWaterLevelSensor(WaterLevelSensor sensor) async {
    Database db = await instance.database;
    return await db.insert(tableWaterLevelSensors, sensor.toMap());
  }

  Future<WaterLevelSensor?> queryWaterLevelSensorBySerial(String deviceSerial) async {
    Database db = await instance.database;
    var res = await db.query(
      tableWaterLevelSensors,
      where: 'deviceSerial = ?',
      whereArgs: [deviceSerial],
      limit: 1
    );
    
    if (res.isNotEmpty) {
      return WaterLevelSensor.fromMap(res.first);
    }
    return null;
  }

  Future<List<WaterLevelSensor>> queryAllWaterLevelSensors() async {
    Database db = await instance.database;
    var res = await db.query(tableWaterLevelSensors, orderBy: 'lastUpdate DESC');
    return res.map((c) => WaterLevelSensor.fromMap(c)).toList();
  }

  Future<int> updateWaterLevelSensor(WaterLevelSensor sensor) async {
    Database db = await instance.database;
    return await db.update(
      tableWaterLevelSensors,
      sensor.toMap(),
      where: 'deviceSerial = ?',
      whereArgs: [sensor.deviceSerial]
    );
  }

  Future<int> deleteWaterLevelSensor(int sensorId) async {
    Database db = await instance.database;
    return await db.delete(
      tableWaterLevelSensors,
      where: 'id = ?',
      whereArgs: [sensorId]
    );
  }

  Future<List<WaterLevelSensor>> queryWaterLevelSensorsByParentId(int parentDeviceId) async {
    Database db = await instance.database;
    var res = await db.query(
      tableWaterLevelSensors,
      where: 'parentDeviceId = ?',
      whereArgs: [parentDeviceId],
      orderBy: 'lastUpdate DESC'
    );
    return res.map((c) => WaterLevelSensor.fromMap(c)).toList();
  }

  // Helper method để tạo thiết bị con mặc định cho trạm bơm
  Future<void> createDefaultPumpStationSubDevices(int parentDeviceId) async {
    print('🔧 Creating default sub devices for pump station ID: $parentDeviceId');
    
    // Tạo 2 máy bơm
    for (int i = 1; i <= 2; i++) {
      final pumpId = await insertSubDevice(parentDeviceId, 'pump', i);
      print('   Created pump $i with ID: $pumpId');
    }
    
    // Tạo 2 cổng phai
    for (int i = 1; i <= 2; i++) {
      final gateId = await insertSubDevice(parentDeviceId, 'gate', i);
      print('   Created gate $i with ID: $gateId');
    }
    
    // Tạo 2 cảm biến mực nước
    for (int i = 1; i <= 2; i++) {
      final sensorId = await insertSubDevice(parentDeviceId, 'water_sensor', i);
      print('   Created water sensor $i with ID: $sensorId');
      
      // Tạo water level sensor record
      final waterSensor = WaterLevelSensor(
        id: 0, // Will be auto-generated
        deviceSerial: 'WS_${parentDeviceId}_$i',
        deviceName: 'hố nước $i',
        waterLevel: 0.0,
        maxCapacity: 100.0,
        minThreshold: 10.0,
        maxThreshold: 90.0,
        lastUpdate: DateTime.now(),
        isActive: true,
        parentDeviceId: parentDeviceId,
      );
      final waterSensorId = await insertWaterLevelSensor(waterSensor);
      print('   Created water level sensor $i with ID: $waterSensorId');
    }
    
    print('✅ Finished creating default sub devices');
  }

  // Clear all sub devices and water level sensors
  Future<void> clearAllSubDevices() async {
    Database db = await instance.database;
    
    // Clear sub devices table
    await db.delete(tableSubDevices);
    print('🗑️ Cleared all sub devices');
    
    // Clear water level sensors table
    await db.delete(tableWaterLevelSensors);
    print('🗑️ Cleared all water level sensors');
  }

  // Clear sub devices for specific parent device
  Future<void> clearSubDevicesByParentId(int parentDeviceId) async {
    Database db = await instance.database;
    
    // Clear sub devices for this parent
    await db.delete(
      tableSubDevices,
      where: '$columnParentDeviceId = ?',
      whereArgs: [parentDeviceId]
    );
    print('🗑️ Cleared sub devices for parent ID: $parentDeviceId');
    
    // Clear water level sensors for this parent
    await db.delete(
      tableWaterLevelSensors,
      where: 'parentDeviceId = ?',
      whereArgs: [parentDeviceId]
    );
    print('🗑️ Cleared water level sensors for parent ID: $parentDeviceId');
  }

  // ========== RELAY STATES MANAGEMENT ==========
  
  // Lưu hoặc cập nhật trạng thái relay
  Future<void> saveRelayState(String deviceSerial, int deviceOrder, int relayNumber, bool isActive) async {
    Database db = await instance.database;
    
    final data = {
      'device_serial': deviceSerial,
      'device_order': deviceOrder,
      'relay_number': relayNumber,
      'is_active': isActive ? 1 : 0,
      'last_updated': DateTime.now().toIso8601String(),
    };
    
    // Sử dụng INSERT OR REPLACE để upsert
    await db.insert(
      tableRelayStates,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('💾 Saved relay state: $deviceSerial, order: $deviceOrder, relay: $relayNumber, active: $isActive');
  }
  
  // Lấy trạng thái relay
  Future<bool?> getRelayState(String deviceSerial, int deviceOrder, int relayNumber) async {
    Database db = await instance.database;
    
    var res = await db.query(
      tableRelayStates,
      where: 'device_serial = ? AND device_order = ? AND relay_number = ?',
      whereArgs: [deviceSerial, deviceOrder, relayNumber],
      limit: 1,
    );
    
    if (res.isNotEmpty) {
      final isActive = res.first['is_active'] == 1;
      print('📖 Loaded relay state: $deviceSerial, order: $deviceOrder, relay: $relayNumber, active: $isActive');
      return isActive;
    }
    
    print('📖 No relay state found for: $deviceSerial, order: $deviceOrder, relay: $relayNumber');
    return null;
  }
  
  // Lấy trạng thái relay kèm timestamp
  Future<Map<String, dynamic>?> getRelayStateWithTimestamp(String deviceSerial, int deviceOrder, int relayNumber) async {
    Database db = await instance.database;
    
    var res = await db.query(
      tableRelayStates,
      where: 'device_serial = ? AND device_order = ? AND relay_number = ?',
      whereArgs: [deviceSerial, deviceOrder, relayNumber],
      limit: 1,
    );
    
    if (res.isNotEmpty) {
      final row = res.first;
      final isActive = row['is_active'] == 1;
      final lastUpdated = DateTime.parse(row['last_updated'] as String);
      print('📖 Loaded relay state with timestamp: $deviceSerial, order: $deviceOrder, relay: $relayNumber, active: $isActive, time: $lastUpdated');
      return {
        'isActive': isActive,
        'lastUpdated': lastUpdated,
      };
    }
    
    print('📖 No relay state found for: $deviceSerial, order: $deviceOrder, relay: $relayNumber');
    return null;
  }
  
  // Lấy tất cả trạng thái relay cho một thiết bị
  Future<Map<String, bool>> getAllRelayStatesForDevice(String deviceSerial) async {
    Database db = await instance.database;
    
    var res = await db.query(
      tableRelayStates,
      where: 'device_serial = ?',
      whereArgs: [deviceSerial],
    );
    
    Map<String, bool> states = {};
    for (var row in res) {
      final key = '${row['device_order']}_${row['relay_number']}';
      final isActive = row['is_active'] == 1;
      states[key] = isActive;
    }
    
    print('📖 Loaded ${states.length} relay states for device: $deviceSerial');
    return states;
  }
  
  // Xóa trạng thái relay cho một thiết bị
  Future<void> clearRelayStatesForDevice(String deviceSerial) async {
    Database db = await instance.database;
    
    await db.delete(
      tableRelayStates,
      where: 'device_serial = ?',
      whereArgs: [deviceSerial],
    );
    
    print('🗑️ Cleared relay states for device: $deviceSerial');
  }
}
