import 'package:flutter/material.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/repository/mqtt_manager.dart';
import 'package:iot_app/database/database_helper.dart' if (dart.library.html) 'package:iot_app/database/web_database_helper.dart';
import 'package:iot_app/screens/pump_station_management_screen.dart';
import 'package:iot_app/widgets/device_detail_button_widget.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';

class PumpStationScreen extends StatefulWidget {
  final Device device;

  const PumpStationScreen({Key? key, required this.device}) : super(key: key);

  @override
  _PumpStationScreenState createState() => _PumpStationScreenState();
}

class _PumpStationScreenState extends State<PumpStationScreen> {
  late MQTTManager _mqttManager;
  late PumpStationDevice _pumpStation;
  List<WaterLevelSensor> _waterSensors = [];
  bool _isLoading = true;
  
  // Biến theo dõi thời gian bấm nút để tránh bấm liên tục
  Map<int, DateTime> _lastPumpButtonPress = {};
  Map<int, DateTime> _lastGateButtonPress = {};
  static const Duration _buttonCooldown = Duration(seconds: 3);
  
  // Biến theo dõi thời gian hiển thị cooldown (3 giây)
  Map<int, DateTime> _pumpCooldownEndTime = {};
  Map<int, DateTime> _gateCooldownEndTime = {};
  static const Duration _cooldownDelay = Duration(seconds: 3);
  
  // Timer để kiểm tra cooldown
  Timer? _cooldownTimer;
  
  // Timer để cập nhật trạng thái liên tục
  Timer? _statusUpdateTimer;

  @override
  void initState() {
    super.initState();
    _mqttManager = MQTTManager();
    _pumpStation = PumpStationDevice.createDefault(widget.device.deviceSerial, widget.device.deviceName);
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _mqttManager.connect();
    await _loadSubDevices();
    _subscribeToTopics();
    _startCooldownTimer();
    _startStatusUpdateTimer();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadSubDevices() async {
    try {
      print('🔄 Loading sub-devices for parent ID: ${widget.device.id}');
      
      // Load pumps
      final pumps = await DatabaseHelper.instance.querySubDevicesByType(
        widget.device.id!,
        'pump',
      );
      
      // Load gates
      final gates = await DatabaseHelper.instance.querySubDevicesByType(
        widget.device.id!,
        'gate',
      );
      
      // Load water level sensors
      final waterSensors = await DatabaseHelper.instance.queryWaterLevelSensorsByParentId(
        widget.device.id!,
      );

      print('📊 Loaded sub-devices:');
      print('   Pumps: ${pumps.length}');
      for (var pump in pumps) {
        print('     - Pump: ID=${pump.id}, Number=${pump.subDeviceNumber}, Name=${pump.deviceName}');
      }
      
      print('   Gates: ${gates.length}');
      for (var gate in gates) {
        print('     - Gate: ID=${gate.id}, Number=${gate.subDeviceNumber}, Name=${gate.deviceName}');
      }
      
      print('   Water Sensors: ${waterSensors.length}');
      for (var sensor in waterSensors) {
        print('     - Water Sensor: ID=${sensor.id}, Name=${sensor.name}, Serial=${sensor.serial}, Level=${sensor.currentWaterLevel}');
      }

      setState(() {
        _pumpStation = _pumpStation.copyWith(
          pumps: pumps.map((pump) => PumpStatus(
            id: pump.id!,
            number: pump.subDeviceNumber,
            isActive: pump.subDeviceStatus == 1,
            hasWater: false, // Will be updated via MQTT
            serial: pump.deviceSerial ?? '',
            name: pump.deviceName ?? '',
            connectionStatus: 'unknown', // Default status, will be updated via MQTT
          )).toList(),
          gates: gates.map((gate) => GateStatus(
            id: gate.id!,
            number: gate.subDeviceNumber,
            isOpen: gate.subDeviceStatus == 1,
            serial: gate.deviceSerial ?? '',
            name: gate.deviceName ?? '',
            connectionStatus: 'unknown', // Default status, will be updated via MQTT
          )).toList(),
        );
        _waterSensors = waterSensors;
      });

      print('✅ Final state:');
      print('   Pumps: ${_pumpStation.pumps.length}');
      for (int i = 0; i < _pumpStation.pumps.length; i++) {
        final pump = _pumpStation.pumps[i];
        print('     Pump ${i + 1}: serial=${pump.serial}, number=${pump.number}, name=${pump.name}');
      }
      print('   Gates: ${_pumpStation.gates.length}');
      for (int i = 0; i < _pumpStation.gates.length; i++) {
        final gate = _pumpStation.gates[i];
        print('     Gate ${i + 1}: serial=${gate.serial}, number=${gate.number}, name=${gate.name}');
      }
      print('   Water Sensors: ${_waterSensors.length}');
      for (int i = 0; i < _waterSensors.length; i++) {
        final sensor = _waterSensors[i];
        print('     Water Sensor ${i + 1}: serial=${sensor.deviceSerial}, name=${sensor.deviceName}');
      }
      
      // Load trạng thái relay từ database sau khi đã load sub devices
      print('🚀 About to load relay states from database...');
      await _loadRelayStatesFromDatabase();
      print('🚀 Finished loading relay states from database');
    } catch (e) {
      print('❌ Error loading sub-devices: $e');
    }
  }
  
  // Load trạng thái relay từ database
  Future<void> _loadRelayStatesFromDatabase() async {
    try {
      print('🔄 Loading relay states from database...');
      print('🔄 Number of pumps to check: ${_pumpStation.pumps.length}');
      
      // Load trạng thái cho từng máy bơm
      for (int i = 0; i < _pumpStation.pumps.length; i++) {
        final pump = _pumpStation.pumps[i];
        
        print('🔄 Loading state for pump ${i + 1}: serial=${pump.serial}, order=${pump.number}');
        
        bool? finalStatus;
        
        if (pump.number == 1 || pump.number == 2) {
          // Máy 1 & 2: có 2 relay riêng biệt cho bật/tắt
          int onRelayNumber = pump.number == 1 ? 1 : 3;  // relay 1 hoặc 3 để bật
          int offRelayNumber = pump.number == 1 ? 2 : 4; // relay 2 hoặc 4 để tắt
          
          // Kiểm tra trạng thái nút BẬT với timestamp
          final onData = await DatabaseHelper.instance.getRelayStateWithTimestamp(
            pump.serial,
            pump.number,
            onRelayNumber,
          );
          
          // Kiểm tra trạng thái nút TẮT với timestamp
          final offData = await DatabaseHelper.instance.getRelayStateWithTimestamp(
            pump.serial,
            pump.number,
            offRelayNumber,
          );
          
          print('🔄 Pump ${i + 1}: ON relay($onRelayNumber)=${onData?['isActive']} at ${onData?['lastUpdated']}');
          print('🔄 Pump ${i + 1}: OFF relay($offRelayNumber)=${offData?['isActive']} at ${offData?['lastUpdated']}');
          
          // Xác định trạng thái cuối dựa trên nút nào được bấm gần đây nhất
          if (onData != null && offData != null) {
            // Cả 2 nút đều có dữ liệu, so sánh timestamp
            DateTime onTime = onData['lastUpdated'];
            DateTime offTime = offData['lastUpdated'];
            
            if (onTime.isAfter(offTime) && onData['isActive'] == true) {
              finalStatus = true; // Nút BẬT được bấm gần đây hơn
            } else if (offTime.isAfter(onTime) && offData['isActive'] == true) {
              finalStatus = false; // Nút TẮT được bấm gần đây hơn
            } else if (onTime.isAtSameMomentAs(offTime)) {
              // Cùng thời gian, ưu tiên trạng thái tắt để an toàn
              finalStatus = false;
            }
          } else if (onData != null && onData['isActive'] == true) {
            finalStatus = true; // Chỉ có nút BẬT được bấm
          } else if (offData != null && offData['isActive'] == true) {
            finalStatus = false; // Chỉ có nút TẮT được bấm
          }
        } else {
          // Máy 3+: kiểm tra trạng thái thực tế được lưu với relay 0
          final state = await DatabaseHelper.instance.getRelayState(
            pump.serial,
            pump.number,
            0, // Relay 0 là flag đặc biệt lưu trạng thái thực tế của máy
          );
          
          print('🔄 Pump ${i + 1}: Machine state (relay 0)=$state');
          
          if (state != null) {
            finalStatus = state; // Lấy trạng thái thực tế của máy
          }
        }
        
        if (finalStatus != null) {
          // Cập nhật trạng thái nếu có dữ liệu trong database
          setState(() {
            _pumpStation = _pumpStation.updatePumpStatus(i + 1, finalStatus!);
          });
          print('📖 Restored pump ${i + 1} (${pump.serial}, order: ${pump.number}) status: ${finalStatus! ? "ON" : "OFF"}');
        } else {
          print('📖 No state found for pump ${i + 1}, keeping default OFF');
        }
      }

      // ====== KHÔI PHỤC TRẠNG THÁI CỐNG PHAI ======
      print('🔄 Loading gate states from database...');
      for (int i = 0; i < _pumpStation.gates.length; i++) {
        final gate = _pumpStation.gates[i];
        bool? finalStatus; // null = không có data, true = mở, false = đóng
        
        print('🔄 Checking gate ${i + 1}: serial=${gate.serial}, number=${gate.number}');
        
        if (gate.number <= 2) {
          // Cống 1 & 2: có 2 relay riêng biệt cho mở/đóng
          int openRelayNumber = gate.number == 1 ? 1 : 3;  // relay 1 hoặc 3 để mở
          int closeRelayNumber = gate.number == 1 ? 2 : 4; // relay 2 hoặc 4 để đóng
          
          // Kiểm tra trạng thái nút MỞ với timestamp
          final openData = await DatabaseHelper.instance.getRelayStateWithTimestamp(
            gate.serial,
            gate.number,
            openRelayNumber,
          );
          
          // Kiểm tra trạng thái nút ĐÓNG với timestamp
          final closeData = await DatabaseHelper.instance.getRelayStateWithTimestamp(
            gate.serial,
            gate.number,
            closeRelayNumber,
          );
          
          print('🔄 Gate ${i + 1}: OPEN relay($openRelayNumber)=${openData?['isActive']} at ${openData?['lastUpdated']}');
          print('🔄 Gate ${i + 1}: CLOSE relay($closeRelayNumber)=${closeData?['isActive']} at ${closeData?['lastUpdated']}');
          
          // Xác định trạng thái cuối dựa trên nút nào được bấm gần đây nhất
          if (openData != null && closeData != null) {
            // Cả 2 nút đều có dữ liệu, so sánh timestamp
            DateTime openTime = openData['lastUpdated'];
            DateTime closeTime = closeData['lastUpdated'];
            
            if (openTime.isAfter(closeTime) && openData['isActive'] == true) {
              finalStatus = true; // Nút MỞ được bấm gần đây hơn
            } else if (closeTime.isAfter(openTime) && closeData['isActive'] == true) {
              finalStatus = false; // Nút ĐÓNG được bấm gần đây hơn
            } else if (openTime.isAtSameMomentAs(closeTime)) {
              // Cùng thời gian, ưu tiên trạng thái đóng để an toàn
              finalStatus = false;
            }
          } else if (openData != null && openData['isActive'] == true) {
            finalStatus = true; // Chỉ có nút MỞ được bấm
          } else if (closeData != null && closeData['isActive'] == true) {
            finalStatus = false; // Chỉ có nút ĐÓNG được bấm
          }
        } else {
          // Cống 3+: kiểm tra trạng thái thực tế được lưu với relay 0
          final state = await DatabaseHelper.instance.getRelayState(
            gate.serial,
            gate.number,
            0, // Relay 0 là flag đặc biệt lưu trạng thái thực tế của cống
          );
          
          print('🔄 Gate ${i + 1}: Gate state (relay 0)=$state');
          
          if (state != null) {
            finalStatus = state; // Lấy trạng thái thực tế của cống
          }
        }
        
        if (finalStatus != null) {
          // Cập nhật trạng thái nếu có dữ liệu trong database
          setState(() {
            _pumpStation = _pumpStation.updateGateStatus(i + 1, finalStatus!);
          });
          print('📖 Restored gate ${i + 1} (${gate.serial}, order: ${gate.number}) status: ${finalStatus! ? "OPEN" : "CLOSED"}');
        } else {
          print('📖 No state found for gate ${i + 1}, keeping default CLOSED');
        }
      }
      
      print('✅ Finished loading relay states from database');
    } catch (e) {
      print('❌ Error loading relay states: $e');
    }
  }

  void _subscribeToTopics() {
    print('🔌 Subscribing to MQTT topics for device: ${widget.device.deviceSerial}');
    
    // Subscribe to relay control topics theo cấu trúc firmware: NhaCuaToi_serial_relay_number
    for (int i = 0; i < _pumpStation.pumps.length; i++) {
      final pump = _pumpStation.pumps[i];
      // Mỗi máy bơm cần subscribe 2 relay: 1 để bật, 1 để tắt
      if (pump.number == 1) {
        // Máy 1: relay 1 (bật) và relay 2 (tắt)
        final relayTopic1 = 'NhaCuaToi_${pump.serial}_relay_1';
        final relayTopic2 = 'NhaCuaToi_${pump.serial}_relay_2';
        print('   Subscribing to pump ${i + 1} (number ${pump.number}) relay topics: $relayTopic1, $relayTopic2');
        _mqttManager.subscribe(relayTopic1);
        _mqttManager.subscribe(relayTopic2);
      } else if (pump.number == 2) {
        // Máy 2: relay 3 (bật) và relay 4 (tắt)
        final relayTopic3 = 'NhaCuaToi_${pump.serial}_relay_3';
        final relayTopic4 = 'NhaCuaToi_${pump.serial}_relay_4';
        print('   Subscribing to pump ${i + 1} (number ${pump.number}) relay topics: $relayTopic3, $relayTopic4');
        _mqttManager.subscribe(relayTopic3);
        _mqttManager.subscribe(relayTopic4);
      } else {
        // Các máy khác
        final relayTopic = 'NhaCuaToi_${pump.serial}_relay_${pump.number}';
        print('   Subscribing to pump ${i + 1} (number ${pump.number}) relay topic: $relayTopic');
        _mqttManager.subscribe(relayTopic);
      }
    }
    
    // Subscribe to gate relay topics theo logic mở/đóng
    for (int i = 0; i < _pumpStation.gates.length; i++) {
      final gate = _pumpStation.gates[i];
      
      // Subscribe cho relay mở/đóng tương ứng với từng cổng phai
      if (gate.number == 1) {
        // Cổng phai 1: relay 1 (mở) và relay 2 (đóng)
        final relayTopic1 = 'NhaCuaToi_${gate.serial}_relay_1';
        final relayTopic2 = 'NhaCuaToi_${gate.serial}_relay_2';
        print('   Subscribing to gate ${i + 1} (number ${gate.number}) relay topics: $relayTopic1, $relayTopic2');
        _mqttManager.subscribe(relayTopic1);
        _mqttManager.subscribe(relayTopic2);
      } else if (gate.number == 2) {
        // Cổng phai 2: relay 3 (mở) và relay 4 (đóng)
        final relayTopic3 = 'NhaCuaToi_${gate.serial}_relay_3';
        final relayTopic4 = 'NhaCuaToi_${gate.serial}_relay_4';
        print('   Subscribing to gate ${i + 1} (number ${gate.number}) relay topics: $relayTopic3, $relayTopic4');
        _mqttManager.subscribe(relayTopic3);
        _mqttManager.subscribe(relayTopic4);
      } else {
        // Cổng phai khác: chỉ subscribe theo number
        final relayTopic = 'NhaCuaToi_${gate.serial}_relay_${gate.number}';
        print('   Subscribing to gate ${i + 1} (number ${gate.number}) relay topic: $relayTopic');
        _mqttManager.subscribe(relayTopic);
      }
    }

    // Subscribe to water level sensor topics theo cấu trúc firmware: NhaCuaToi_serial_water_level_X
    if (_waterSensors.isNotEmpty) {
      for (int i = 0; i < _waterSensors.length; i++) {
        final sensor = _waterSensors[i];
        final topic = 'NhaCuaToi_${sensor.deviceSerial}_mucnuoc';
        print('   Subscribing to water level topic: $topic');
        _mqttManager.subscribe(topic);
      }
    }

    // Subscribe to flow sensor topics theo cấu trúc firmware: NhaCuaToi_${pump.serial}_flow_status
    for (int i = 0; i < _pumpStation.pumps.length; i++) {
      final pump = _pumpStation.pumps[i];
      final flowTopic = 'NhaCuaToi_${pump.serial}_flow_status';
      print('   Subscribing to flow status topic: $flowTopic');
      _mqttManager.subscribe(flowTopic);
    }
    
    // Subscribe to water level sensor topic
    final waterLevelTopic = 'NhaCuaToi_9249022931_mucnuoc';
    print('   Subscribing to water level topic: $waterLevelTopic');
    _mqttManager.subscribe(waterLevelTopic);

    // Subscribe to magnetic switch topics theo cấu trúc firmware: NhaCuaToi_serial_magnetic_X
    for (int i = 0; i < _pumpStation.pumps.length; i++) {
      final pump = _pumpStation.pumps[i];
      final magneticTopic = 'NhaCuaToi_${pump.serial}_magnetic';
      print('   Subscribing to magnetic topic: $magneticTopic');
      _mqttManager.subscribe(magneticTopic);
    }

    // Subscribe to device status topic
    final statusTopic = 'NhaCuaToi_${widget.device.deviceSerial}_status';
    print('   Subscribing to device status topic: $statusTopic');
    _mqttManager.subscribe(statusTopic);

    // Subscribe to sub-device status topics
    print('🔌 Subscribing to sub-device status topics...');
    
    // Subscribe to pump status topics using correct pump serials
    final pumpSerials = ['9249022997', '9249022998']; // Serial numbers for pump 1 and 2
    for (int i = 0; i < _pumpStation.pumps.length && i < pumpSerials.length; i++) {
      final pumpSerial = pumpSerials[i];
      final pumpStatusTopic = 'NhaCuaToi_${pumpSerial}_status';
      print('   Subscribing to pump ${i + 1} status topic: $pumpStatusTopic');
      _mqttManager.subscribe(pumpStatusTopic);
    }
    
    // Subscribe to gate status topics using pump serials for gates
    for (int i = 0; i < _pumpStation.gates.length && i < pumpSerials.length; i++) {
      final gateSerial = pumpSerials[i]; // Gates use same serials as pumps
      final gateStatusTopic = 'NhaCuaToi_${gateSerial}_status';
      print('   Subscribing to gate ${i + 1} status topic: $gateStatusTopic');
      _mqttManager.subscribe(gateStatusTopic);
    }
    
    // Subscribe to water sensor status topics
    for (int i = 0; i < _waterSensors.length; i++) {
      final sensor = _waterSensors[i];
      final sensorStatusTopic = 'NhaCuaToi_${sensor.deviceSerial}_status';
      print('   Subscribing to water sensor ${i + 1} status topic: $sensorStatusTopic');
      _mqttManager.subscribe(sensorStatusTopic);
    }

    // Listen for MQTT messages
    _mqttManager.messageStream.listen((mqttMessage) {
      final MqttPublishMessage recMess = mqttMessage.payload as MqttPublishMessage;
      final String message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final String topic = mqttMessage.topic;
      _handleMQTTMessage(topic, message);
    });
  }

  void _handleMQTTMessage(String topic, String message) async {
    print('📨 Received MQTT message: $topic = $message');
    print('🔍 DEBUG: Processing topic: $topic');
    
    // Check if it's a status topic first
    if (topic.endsWith('_status')) {
      print('🔔 STATUS TOPIC DETECTED: $topic');
      print('🔔 Message content: $message');
    }
    
    // Handle relay control topics theo cấu trúc firmware: NhaCuaToi_serial_relay_number
    for (int i = 0; i < _pumpStation.pumps.length; i++) {
      final pump = _pumpStation.pumps[i];
      final relayTopicPattern = 'NhaCuaToi_${pump.serial}_relay_';
      print('🔍 Checking topic: $topic against pattern: $relayTopicPattern');
      
      if (topic.startsWith(relayTopicPattern)) {
        final relayNumberStr = topic.substring(relayTopicPattern.length);
        final relayNumber = int.tryParse(relayNumberStr);
        
        print('🔍 Found matching pump ${i + 1}, relay number: $relayNumber, message: $message');
        
        if (relayNumber != null) {
          final status = message == 'on';
          
          // Logic cập nhật trạng thái máy bơm theo relay
          // Mỗi máy bơm có 2 relay: 1 để bật, 1 để tắt
          bool? newStatus;
          if (pump.number == 1) {
            if (relayNumber == 1) {
              // Relay 1 → Máy 1 bật
              newStatus = true;
            } else if (relayNumber == 2) {
              // Relay 2 → Máy 1 tắt
              newStatus = false;
            }
          } else if (pump.number == 2) {
            if (relayNumber == 3) {
              // Relay 3 → Máy 2 bật
              newStatus = true;
            } else if (relayNumber == 4) {
              // Relay 4 → Máy 2 tắt
              newStatus = false;
            }
          }
          
          if (newStatus != null) {
            // Cập nhật database - lưu theo topic của nút bật/tắt
            await DatabaseHelper.instance.saveRelayState(
              pump.serial,
              pump.number,
              relayNumber, // Sử dụng relayNumber để phân biệt từng nút bật/tắt
              newStatus,
            );
            
            // Cập nhật UI
            setState(() {
              _pumpStation = _pumpStation.updatePumpStatus(i + 1, newStatus!);
            });
            print('🔧 Updated pump ${i + 1} (number ${pump.number}) status: ${newStatus ? "ON" : "OFF"} (relay $relayNumber)');
          }
          return;
        }
      }
    }
    
    // Handle gate relay control topics
    for (int i = 0; i < _pumpStation.gates.length; i++) {
      final gate = _pumpStation.gates[i];
      
      // Xử lý relay theo logic mở/đóng
      if (gate.number == 1) {
        // Cổng phai 1: relay 1 (mở) và relay 2 (đóng)
        if (topic == 'NhaCuaToi_${gate.serial}_relay_1') {
          // Relay 1 = mở cổng phai 1
          final status = message == 'on';
          setState(() {
            _pumpStation = _pumpStation.updateGateStatus(i + 1, status); // true = mở
          });
          print('🔧 Updated gate ${gate.name} (relay 1 - OPEN) status: ${status ? "OPEN" : "CLOSE"}');
          return;
        } else if (topic == 'NhaCuaToi_${gate.serial}_relay_2') {
          // Relay 2 = đóng cổng phai 1
          final status = message == 'on';
          setState(() {
            _pumpStation = _pumpStation.updateGateStatus(i + 1, !status); // false = đóng
          });
          print('🔧 Updated gate ${gate.name} (relay 2 - CLOSE) status: ${!status ? "CLOSE" : "OPEN"}');
          return;
        }
      } else if (gate.number == 2) {
        // Cổng phai 2: relay 3 (mở) và relay 4 (đóng)
        if (topic == 'NhaCuaToi_${gate.serial}_relay_3') {
          // Relay 3 = mở cổng phai 2
          final status = message == 'on';
          setState(() {
            _pumpStation = _pumpStation.updateGateStatus(i + 1, status); // true = mở
          });
          print('🔧 Updated gate ${gate.name} (relay 3 - OPEN) status: ${status ? "OPEN" : "CLOSE"}');
          return;
        } else if (topic == 'NhaCuaToi_${gate.serial}_relay_4') {
          // Relay 4 = đóng cổng phai 2
          final status = message == 'on';
          setState(() {
            _pumpStation = _pumpStation.updateGateStatus(i + 1, !status); // false = đóng
          });
          print('🔧 Updated gate ${gate.name} (relay 4 - CLOSE) status: ${!status ? "CLOSE" : "OPEN"}');
          return;
        }
      } else {
        // Cổng phai khác: xử lý theo number ban đầu
        final relayTopic = 'NhaCuaToi_${gate.serial}_relay_${gate.number}';
        if (topic == relayTopic) {
          final status = message == 'on';
          setState(() {
            _pumpStation = _pumpStation.updateGateStatus(i + 1, status);
          });
          print('🔧 Updated gate ${gate.name} (relay ${gate.number}) status: $status');
          return;
        }
      }
    }

    // Handle water level sensor updates theo cấu trúc firmware: NhaCuaToi_serial_mucnuoc
    for (int i = 0; i < _waterSensors.length; i++) {
      final sensor = _waterSensors[i];
      final waterLevelTopic = 'NhaCuaToi_${sensor.deviceSerial}_mucnuoc';
      print('🔍 Checking water level topic: $topic against expected: $waterLevelTopic');
      if (topic == waterLevelTopic) {
        try {
          double waterLevel = 0.0;
          
          // Try parsing as JSON first
          try {
            final Map<String, dynamic> data = json.decode(message);
            waterLevel = data['water_level']?.toDouble() ?? double.parse(message);
            print('💧 Parsed JSON water level: $waterLevel from: $data');
          } catch (e) {
            // If not JSON, parse as simple number
            waterLevel = double.tryParse(message) ?? 0.0;
            print('💧 Parsed simple water level: $waterLevel from: $message');
          }
          
          print('💧 Processing water level for sensor ${sensor.deviceName}: message=$message, waterLevel=$waterLevel');
          // Update water level cho sensor cụ thể
          setState(() {
            final updatedSensors = List<WaterLevelSensor>.from(_waterSensors);
            updatedSensors[i] = WaterLevelSensor(
              id: updatedSensors[i].id,
              deviceSerial: updatedSensors[i].deviceSerial,
              deviceName: updatedSensors[i].deviceName,
              waterLevel: waterLevel,
              maxCapacity: updatedSensors[i].maxCapacity,
              minThreshold: updatedSensors[i].minThreshold,
              maxThreshold: updatedSensors[i].maxThreshold,
              isActive: updatedSensors[i].isActive,
              lastUpdate: DateTime.now(),
            );
            _waterSensors = updatedSensors;
          });
          print('💧 Updated water level for sensor ${sensor.deviceName}: ${waterLevel.toStringAsFixed(2)} cm');
        } catch (e) {
          print('❌ Error parsing water level for sensor ${sensor.deviceName}: $e');
        }
        return;
      }
    }

    // Handle flow sensor data theo cấu trúc firmware: NhaCuaToi_${pump.serial}_flow_status
    for (int i = 0; i < _pumpStation.pumps.length; i++) {
      final pump = _pumpStation.pumps[i];
      final flowTopic = 'NhaCuaToi_${pump.serial}_flow_status';
      if (topic == flowTopic) {
        try {
          // Firmware gửi "1" hoặc "0" thay vì số thập phân
          final hasFlow = message == '1';
          // Update pump water status based on flow status
          setState(() {
            final updatedPumps = List<PumpStatus>.from(_pumpStation.pumps);
            updatedPumps[i] = PumpStatus(
              id: updatedPumps[i].id,
              number: updatedPumps[i].number,
              isActive: updatedPumps[i].isActive,
              hasWater: hasFlow,
              serial: updatedPumps[i].serial,
              name: updatedPumps[i].name,
            );
            _pumpStation = _pumpStation.copyWith(pumps: updatedPumps);
          });
          print('🌊 Updated flow status for pump ${pump.name}: ${hasFlow ? "CÓ NƯỚC" : "KHÔNG NƯỚC"}');
        } catch (e) {
          print('❌ Error parsing flow status: $e');
        }
        return;
      }
    }

    // Handle magnetic switch data theo cấu trúc firmware: NhaCuaToi_9249022931_magnetic
    final magneticTopic = 'NhaCuaToi_9249022931_magnetic';
    print('🔍 Checking magnetic topic: $topic against expected: $magneticTopic');
    if (topic == magneticTopic) {
      try {
        final isClosed = message == '1';
        print('🔒 Processing magnetic switch: message=$message, isClosed=$isClosed');
        // Update tất cả gates với cùng trạng thái magnetic switch
        setState(() {
          final updatedGates = List<GateStatus>.from(_pumpStation.gates);
          for (int i = 0; i < updatedGates.length; i++) {
            updatedGates[i] = GateStatus(
              id: updatedGates[i].id,
              number: updatedGates[i].number,
              isOpen: updatedGates[i].isOpen,
              isClosed: isClosed,
              serial: updatedGates[i].serial,
              name: updatedGates[i].name,
              connectionStatus: updatedGates[i].connectionStatus,
            );
          }
          _pumpStation = _pumpStation.copyWith(gates: updatedGates);
        });
        print('🔒 Updated magnetic status for all gates: ${isClosed ? "ĐÓNG" : "MỞ"}');
      } catch (e) {
        print('❌ Error parsing magnetic status: $e');
      }
      return;
    }
    
    // Handle device status messages
    if (topic.endsWith('_status')) {
      try {
        print('🔔 Processing status message: $message');
        final data = jsonDecode(message);
        final serial = data['serial'];
        final status = data['status'];
        
        print('🔔 Parsed data: serial=$serial, status=$status');
        
        if (serial != null && status != null) {
          // Extract device serial from the full serial (remove "NhaCuaToi_" prefix)
          String deviceSerial = serial.toString().replaceFirst('NhaCuaToi_', '');
          
          print('🔔 Looking for device with serial: $deviceSerial');
          
          // Update device connection status in database
          DatabaseHelper.instance.updateDeviceConnectionStatus(deviceSerial, status);
          
          print('📡 Updated device connection status in database: $deviceSerial -> $status');
          
          // Define mapping between actual serials and pump/gate indices
          final pumpSerials = ['9249022997', '9249022998']; // Serial numbers for pump 1 and 2
          
          // Update UI for sub-devices
          bool foundDevice = false;
          setState(() {
            // Update pump connection status based on serial mapping
            final updatedPumps = <PumpStatus>[];
            for (int i = 0; i < _pumpStation.pumps.length; i++) {
              final pump = _pumpStation.pumps[i];
              final expectedSerial = i < pumpSerials.length ? pumpSerials[i] : pump.serial;
              print('🔧 Checking pump ${i + 1}: expectedSerial=$expectedSerial vs deviceSerial=$deviceSerial');
              if (expectedSerial == deviceSerial) {
                updatedPumps.add(PumpStatus(
                  id: pump.id,
                  number: pump.number,
                  isActive: pump.isActive,
                  hasWater: pump.hasWater,
                  serial: pump.serial,
                  name: pump.name,
                  connectionStatus: status,
                ));
                print('🔧 Updated pump ${i + 1} connection status: $status');
                foundDevice = true;
              } else {
                updatedPumps.add(pump);
              }
            }
            
            // Update gate connection status based on serial mapping (gates use same serials as pumps)
            final updatedGates = <GateStatus>[];
            for (int i = 0; i < _pumpStation.gates.length; i++) {
              final gate = _pumpStation.gates[i];
              final expectedSerial = i < pumpSerials.length ? pumpSerials[i] : gate.serial;
              print('🚪 Checking gate ${i + 1}: expectedSerial=$expectedSerial vs deviceSerial=$deviceSerial');
              if (expectedSerial == deviceSerial) {
                updatedGates.add(GateStatus(
                  id: gate.id,
                  number: gate.number,
                  isOpen: gate.isOpen,
                  isClosed: gate.isClosed,
                  serial: gate.serial,
                  name: gate.name,
                  connectionStatus: status,
                ));
                print('🚪 Updated gate ${i + 1} connection status: $status');
                foundDevice = true;
              } else {
                updatedGates.add(gate);
              }
            }
            
            // Update water sensor connection status
            for (int i = 0; i < _waterSensors.length; i++) {
              print('💧 Checking water sensor ${i + 1}: serial=${_waterSensors[i].deviceSerial} vs deviceSerial=$deviceSerial');
              if (_waterSensors[i].deviceSerial == deviceSerial) {
                _waterSensors[i] = _waterSensors[i].copyWith(connectionStatus: status);
                print('💧 Updated water sensor ${i + 1} connection status: $status');
                foundDevice = true;
                break;
              }
            }
            
            _pumpStation = _pumpStation.copyWith(pumps: updatedPumps, gates: updatedGates);
            
            if (foundDevice) {
              print('✅ Successfully updated device status: $deviceSerial -> $status');
            } else {
              print('⚠️ No matching device found for serial: $deviceSerial');
            }
          });
        }
      } catch (e) {
        print('❌ Error parsing status message: $e');
      }
      return;
    }

  }
  
  // Hàm kiểm tra xem có thể bấm nút không (cooldown 3 giây)
  bool _canPressButton(int index, Map<int, DateTime> lastPressMap) {
    final now = DateTime.now();
    final lastPress = lastPressMap[index];
    
    if (lastPress == null) {
      return true; // Chưa bấm lần nào
    }
    
    final timeSinceLastPress = now.difference(lastPress);
    return timeSinceLastPress >= _buttonCooldown;
  }
  
  // Hàm kiểm tra xem nút có đang trong cooldown không
  bool _isInCooldown(int index, Map<int, DateTime> cooldownMap) {
    final cooldownEndTime = cooldownMap[index];
    if (cooldownEndTime == null) {
      return false;
    }
    return DateTime.now().isBefore(cooldownEndTime);
  }
  
  // Hàm cập nhật thời gian bấm nút
  void _updateButtonPressTime(int index, Map<int, DateTime> lastPressMap) {
    lastPressMap[index] = DateTime.now();
  }
  
  // Hàm bắt đầu Timer để kiểm tra cooldown
  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      _checkCooldown();
    });
  }
  
  // Hàm kiểm tra cooldown và cập nhật UI
  void _checkCooldown() {
    final now = DateTime.now();
    bool needsUpdate = false;
    
    // Kiểm tra cooldown cho pumps
    for (int i = 0; i < _pumpStation.pumps.length; i++) {
      final cooldownEndTime = _pumpCooldownEndTime[i];
      if (cooldownEndTime != null && now.isAfter(cooldownEndTime)) {
        _pumpCooldownEndTime.remove(i);
        needsUpdate = true;
      }
    }
    
    // Kiểm tra cooldown cho gates
    for (int i = 0; i < _pumpStation.gates.length; i++) {
      final cooldownEndTime = _gateCooldownEndTime[i];
      if (cooldownEndTime != null && now.isAfter(cooldownEndTime)) {
        _gateCooldownEndTime.remove(i);
        needsUpdate = true;
      }
    }
    
    // Cập nhật UI nếu cần
    if (needsUpdate) {
      setState(() {});
    }
  }
  
  // Hàm bắt đầu Timer để cập nhật trạng thái liên tục
  void _startStatusUpdateTimer() {
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateStatusFromMQTT();
    });
  }
  
  // Hàm cập nhật trạng thái từ MQTT
  void _updateStatusFromMQTT() {
    // Timer để đảm bảo app liên tục đọc trạng thái từ MQTT
    print('📡 MQTT Status Update Timer: Monitoring for real-time updates...');
  }

  void _togglePump(int index) async {
    // Kiểm tra cooldown trước khi cho phép bấm
    if (!_canPressButton(index, _lastPumpButtonPress)) {
      final remainingTime = _buttonCooldown - DateTime.now().difference(_lastPumpButtonPress[index]!);
      print('⏰ Pump ${index + 1} button cooldown: ${remainingTime.inSeconds} seconds remaining');
      return;
    }
    
    // Cập nhật thời gian bấm nút
    _updateButtonPressTime(index, _lastPumpButtonPress);
    
    final pump = _pumpStation.pumps[index];
    final newStatus = !pump.isActive;
    
    print('🔧 Toggle pump ${index + 1}: current status = ${pump.isActive}, new status = $newStatus');
    print('🔧 Pump ${index + 1} serial: ${pump.serial}, number: ${pump.number}');
    
    // Logic điều khiển relay theo máy bơm
    int relayNumber;
    String command;
    
    // Mỗi máy bơm có 2 relay: 1 để bật, 1 để tắt
    // THAY ĐỔI LOGIC: Khi nút hiển thị "BẬT" gửi "OFF", khi nút "TẮT" gửi "ON"
    if (newStatus) {
      // Máy sẽ bật (nút hiện tại hiển thị "BẬT") → gửi lệnh OFF
      if (pump.number == 1) {
        relayNumber = 1; // Máy 1 bật → relay 1
      } else if (pump.number == 2) {
        relayNumber = 3; // Máy 2 bật → relay 3
      } else {
        relayNumber = pump.number; // Các máy khác
      }
      command = 'off'; // Gửi 'off' khi nút hiển thị "BẬT"
    } else {
      // Máy sẽ tắt (nút hiện tại hiển thị "TẮT") → gửi lệnh ON
      if (pump.number == 1) {
        relayNumber = 2; // Máy 1 tắt → relay 2
      } else if (pump.number == 2) {
        relayNumber = 4; // Máy 2 tắt → relay 4
      } else {
        relayNumber = pump.number; // Các máy khác
      }
      command = 'on'; // Gửi 'on' khi nút hiển thị "TẮT"
    }
    
    // Topic sử dụng serial + relay: NhaCuaToi_serial_relay_number
    final topic = 'NhaCuaToi_${pump.serial}_relay_$relayNumber';
    
    print('🔧 Sending pump ${index + 1} command: $topic = $command (relay $relayNumber)');
    _mqttManager.publish(topic, command);
    
    // Lưu trạng thái vào database - lưu theo topic của nút bật/tắt
    await DatabaseHelper.instance.saveRelayState(
      pump.serial,
      pump.number,
      relayNumber, // Sử dụng relayNumber để phân biệt từng nút bật/tắt
      command == 'on', // Lưu true nếu command là 'on', false nếu command là 'off'
    );
    
    // Riêng với máy 3+, ta cần lưu thêm trạng thái thực tế của máy
    if (pump.number > 2) {
      // Lưu trạng thái thực tế của máy bơm để khôi phục
      await DatabaseHelper.instance.saveRelayState(
        pump.serial,
        pump.number,
        0, // Sử dụng relay 0 như một flag đặc biệt để lưu trạng thái máy
        newStatus, // Trạng thái thực tế ON/OFF của máy
      );
    }
    
    setState(() {
      _pumpStation = _pumpStation.updatePumpStatus(index + 1, newStatus);
    });
    
    // Set cooldown cho 3 giây
    _pumpCooldownEndTime[index] = DateTime.now().add(_cooldownDelay);
    print('⏰ Set cooldown for pump ${index + 1} for 3 seconds');
  }

  void _toggleGate(int index) async {
    // Kiểm tra cooldown trước khi cho phép bấm
    if (!_canPressButton(index, _lastGateButtonPress)) {
      final remainingTime = _buttonCooldown - DateTime.now().difference(_lastGateButtonPress[index]!);
      print('⏰ Gate ${index + 1} button cooldown: ${remainingTime.inSeconds} seconds remaining');
      return;
    }
    
    // Cập nhật thời gian bấm nút
    _updateButtonPressTime(index, _lastGateButtonPress);
    
    final gate = _pumpStation.gates[index];
    final newStatus = !gate.isOpen;
    
    print('🔧 Toggle gate ${index + 1}: current status = ${gate.isOpen}, new status = $newStatus');
    print('🔧 Gate ${index + 1} serial: ${gate.serial}, number: ${gate.number}');
    
    // Logic điều khiển relay theo cống phai - tương tự máy bơm
    int relayNumber;
    String command;
    
    // Mỗi cống phai có 2 relay: 1 để mở, 1 để đóng
    // THAY ĐỔI LOGIC: Khi nút hiển thị "MỞ" gửi "OFF", khi nút "ĐÓNG" gửi "ON"
    if (newStatus) {
      // Cống sẽ mở (nút hiện tại hiển thị "MỞ") → gửi lệnh OFF
      if (gate.number == 1) {
        relayNumber = 1; // Cống 1 mở → relay 1
      } else if (gate.number == 2) {
        relayNumber = 3; // Cống 2 mở → relay 3
      } else {
        relayNumber = gate.number; // Các cống khác
      }
      command = 'off'; // Gửi 'off' khi nút hiển thị "MỞ"
    } else {
      // Cống sẽ đóng (nút hiện tại hiển thị "ĐÓNG") → gửi lệnh ON
      if (gate.number == 1) {
        relayNumber = 2; // Cống 1 đóng → relay 2
      } else if (gate.number == 2) {
        relayNumber = 4; // Cống 2 đóng → relay 4
      } else {
        relayNumber = gate.number; // Các cống khác
      }
      command = 'on'; // Gửi 'on' khi nút hiển thị "ĐÓNG"
    }
    
    // Topic sử dụng serial + relay: NhaCuaToi_serial_relay_number
    final topic = 'NhaCuaToi_${gate.serial}_relay_$relayNumber';
    
    print('🔧 Sending gate ${index + 1} command: $topic = $command (relay $relayNumber)');
    _mqttManager.publish(topic, command);
    
    // Lưu trạng thái vào database - lưu theo topic của nút mở/đóng
    await DatabaseHelper.instance.saveRelayState(
      gate.serial,
      gate.number,
      relayNumber, // Sử dụng relayNumber để phân biệt từng nút mở/đóng
      command == 'on', // Lưu true nếu command là 'on', false nếu command là 'off'
    );
    
    // Riêng với cống 3+, ta cần lưu thêm trạng thái thực tế của cống
    if (gate.number > 2) {
      // Lưu trạng thái thực tế của cống phai để khôi phục
      await DatabaseHelper.instance.saveRelayState(
        gate.serial,
        gate.number,
        0, // Sử dụng relay 0 như một flag đặc biệt để lưu trạng thái cống
        newStatus, // Trạng thái thực tế MỞ/ĐÓNG của cống
      );
    }
    
    setState(() {
      _pumpStation = _pumpStation.updateGateStatus(index + 1, newStatus); // Index + 1 vì updateGateStatus tính từ 1
    });
    
    // Set cooldown cho 3 giây
    _gateCooldownEndTime[index] = DateTime.now().add(_cooldownDelay);
    print('⏰ Set cooldown for gate ${index + 1} for 3 seconds');
  }

  // Helper methods for connection status
  Color _getConnectionStatusColor(String status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getConnectionStatusIcon(String status) {
    switch (status) {
      case 'online':
        return Icons.wifi;
      case 'offline':
        return Icons.wifi_off;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trạm Bơm ${widget.device.deviceName}',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () async {
              print('🔧 Opening management screen...');
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PumpStationManagementScreen(
                    pumpStation: _pumpStation,
                    parentDevice: widget.device,
                  ),
                ),
              );
              print('🔧 Returned from management screen, reloading sub-devices...');
              // Reload sub-devices after returning
              await _loadSubDevices();
              print('🔧 Sub-devices reloaded');
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              print('🔄 Manual refresh triggered');
              await _loadSubDevices();
            },
          ),
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              // TODO: Navigate to history screen
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pump Control Section
                  _buildSectionHeader('Điều Khiển Máy Bơm (${_pumpStation.pumps.length})'),
                  SizedBox(height: 12),
                  if (_pumpStation.pumps.isNotEmpty) ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2, // Giảm tỷ lệ để tăng chiều cao
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _pumpStation.pumps.length,
                      itemBuilder: (context, index) {
                        final pump = _pumpStation.pumps[index];
                        return _buildPumpCard(pump, index);
                      },
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Chưa có máy bơm nào. Hãy thêm thiết bị con trong màn hình quản lý.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 16), // Giảm spacing giữa sections
                  
                  // Gate Control Section
                  _buildSectionHeader('Điều Khiển Cổng Phai (${_pumpStation.gates.length})'),
                  SizedBox(height: 12),
                  if (_pumpStation.gates.isNotEmpty) ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2, // Giảm tỷ lệ để tăng chiều cao
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _pumpStation.gates.length,
                      itemBuilder: (context, index) {
                        final gate = _pumpStation.gates[index];
                        return _buildGateCard(gate, index);
                      },
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Chưa có cổng phai nào. Hãy thêm thiết bị con trong màn hình quản lý.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 16), // Giảm spacing giữa sections
                  
                  // Water Level Sensor Section
                  _buildSectionHeader('Cảm Biến Mực Nước (${_waterSensors.length})'),
                  SizedBox(height: 12),
                  if (_waterSensors.isNotEmpty) ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.9, // Giảm thêm tỷ lệ để tăng chiều cao cho cảm biến mực nước
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _waterSensors.length,
                      itemBuilder: (context, index) {
                        return _buildWaterLevelSensorCard(_waterSensors[index]);
                      },
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Chưa có cảm biến mực nước nào. Hãy thêm thiết bị con trong màn hình quản lý.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 16), // Giảm spacing cuối
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue[600],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
  


  Widget _buildPumpCard(PumpStatus pump, int index) {
    return Column(
      children: [
        // Main card with information
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            padding: EdgeInsets.all(12), // Giảm padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header with icon and name
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Main info section
                    Row(
                      children: [
                        Icon(
                          Icons.waves,
                          size: 18, // Giảm icon size
                          color: Colors.blue[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          pump.name.isNotEmpty ? pump.name : 'Máy Bơm ${pump.number}',
                          style: TextStyle(
                            fontSize: 13, // Giảm font size
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    // Connection status indicator
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _getConnectionStatusColor(pump.connectionStatus),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _getConnectionStatusIcon(pump.connectionStatus),
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8), // Giảm spacing
                
                // Status text
                Text(
                  pump.isActive ? 'ĐANG HOẠT ĐỘNG' : 'ĐÃ TẮT',
                  style: TextStyle(
                    fontSize: 11, // Giảm font size
                    fontWeight: FontWeight.bold,
                    color: pump.isActive ? Colors.green[700] : Colors.grey[600],
                  ),
                ),
                SizedBox(height: 6), // Giảm spacing
                
                // Water status
                Text(
                  pump.hasWater ? 'CÓ NƯỚC' : 'KHÔNG NƯỚC',
                  style: TextStyle(
                    fontSize: 11, // Giảm font size
                    color: pump.hasWater ? Colors.blue[600] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8), // Spacing giữa card và button
        
        // Control button outside the card
        Container(
          width: 80,
          height: 32,
          child: ElevatedButton(
            onPressed: _canPressButton(index, _lastPumpButtonPress) ? () => _togglePump(index) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isInCooldown(index, _pumpCooldownEndTime)
                ? Colors.grey[400]
                : (pump.isActive ? Colors.red[500] : Colors.green[500]),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: Text(
              _isInCooldown(index, _pumpCooldownEndTime)
                ? '⏰'
                : (pump.isActive ? 'TẮT' : 'BẬT'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGateCard(GateStatus gate, int index) {
    return Column(
      children: [
        // Main card with information
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            padding: EdgeInsets.all(12), // Giảm padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header with icon and name
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Main info section
                    Row(
                      children: [
                        Icon(
                          Icons.door_front_door,
                          size: 18, // Giảm icon size
                          color: Colors.orange[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          gate.name.isNotEmpty ? gate.name : 'Cổng Phai ${gate.number}',
                          style: TextStyle(
                            fontSize: 13, // Giảm font size
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    // Connection status indicator
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _getConnectionStatusColor(gate.connectionStatus),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _getConnectionStatusIcon(gate.connectionStatus),
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8), // Giảm spacing
                
                // Status text
                Text(
                  gate.isOpen ? 'ĐÃ MỞ' : 'ĐÃ ĐÓNG',
                  style: TextStyle(
                    fontSize: 11, // Giảm font size
                    fontWeight: FontWeight.bold,
                    color: gate.isOpen ? Colors.orange[700] : Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                // Magnetic switch status
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sensor_door,
                      size: 12,
                      color: gate.isClosed ? Colors.red[600] : Colors.green[600],
                    ),
                    SizedBox(width: 2),
                    Text(
                      gate.isClosed ? 'CỔNG ĐÓNG' : 'CỔNG MỞ',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: gate.isClosed ? Colors.red[600] : Colors.green[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8), // Spacing giữa card và button
        
        // Control button outside the card
        Container(
          width: 80,
          height: 32,
          child: ElevatedButton(
            onPressed: _canPressButton(index, _lastGateButtonPress) ? () => _toggleGate(index) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isInCooldown(index, _gateCooldownEndTime)
                ? Colors.grey[400]
                : (gate.isOpen ? Colors.red[500] : Colors.orange[500]),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: Text(
              _isInCooldown(index, _gateCooldownEndTime)
                ? '⏰'
                : (gate.isOpen ? 'ĐÓNG' : 'MỞ'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaterLevelSensorCard(WaterLevelSensor sensor) {
    final waterLevel = sensor.currentWaterLevel;
    final percentage = (waterLevel / sensor.maxCapacity * 100).clamp(0.0, 100.0);
    
    Color levelColor;
    String statusText;
    if (percentage < 30) {
      levelColor = Colors.red;
      statusText = 'Thấp';
    } else if (percentage < 70) {
      levelColor = Colors.orange;
      statusText = 'Trung bình';
    } else {
      levelColor = Colors.green;
      statusText = 'Cao';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.red, width: 1),
      ),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Header with icon and name
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.water_drop,
                  size: 20,
                  color: levelColor,
                ),
                SizedBox(width: 4),
                Text(
                  sensor.name.isNotEmpty ? sensor.name : 'hố nước ${sensor.id}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            
            // Water level display
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${waterLevel.toStringAsFixed(1)}m',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: levelColor,
                ),
              ),
            ),
            SizedBox(height: 8),
            
            // Percentage and status row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: levelColor,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: levelColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            
            // Update timestamp
            Text(
              'Cập nhật: ${DateFormat('HH:mm').format(sensor.lastUpdate)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _statusUpdateTimer?.cancel();
    _mqttManager.dispose();
    super.dispose();
  }
}
