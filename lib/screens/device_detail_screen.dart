import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:iot_app/bloc/device/device_bloc.dart';
import 'package:iot_app/bloc/device/device_event.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/models/switch_event.dart';
import 'package:iot_app/database/database_helper.dart'
    if (dart.library.html) 'package:iot_app/database/web_database_helper.dart';
import 'package:iot_app/repository/mqtt_manager.dart';
import 'package:iot_app/widgets/device_alarm_widget.dart';
import 'package:iot_app/widgets/device_sensor_reading_widget.dart';
import 'package:iot_app/widgets/device_detail_button_widget.dart';
import 'package:iot_app/widgets/placeholder_box_widget.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:iot_app/repository/api_service.dart';

import '../widgets/drawer_widget.dart';

class DeviceDetailScreen extends StatefulWidget {
  static const routeName = '/device_detail';

  final Device device;

  DeviceDetailScreen({required this.device});

  @override
  _DeviceDetailScreenState createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  late MQTTManager mqttManager;
  bool _isSwitched = false;
  bool _hasSubscribedTopics = false;
  StreamSubscription<String>? _temperatureSubscription;
  StreamSubscription<String>? _switchStatusSubscription;
  final List<SwitchEvent> _switchEvents = [];
  double _currentSoilMoisture = 0.0;
  double _currentTemperature = 0.0;

  Map<String, dynamic>? _waterMeterData;
  bool _isLoadingWater = false;
  String? _waterError;

  int? get _deviceLocalId =>
      widget.device.id is int ? widget.device.id as int : null;

  String? get _historyDeviceId => widget.device.id?.toString();

  void _showMissingDeviceIdMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thiết bị này chưa có ID, không thể tải lịch sử.'),
      ),
    );
  }

  // method to save switch history to server
  Future<void> _saveSwitchDeviceHistory(int status) async {
    try {
      final deviceId = _historyDeviceId;
      print("deviceId for history: $deviceId");
      if (deviceId == null) {
        _showMissingDeviceIdMessage();
        return;
      }

      final completer = Completer<void>();
      context.read<DeviceBloc>().add(
        DeviceSwitchHistorySaved(
          deviceId: deviceId.toString(),
          isSwitched: status,
          completer: completer,
        ),
      );
      await completer.future;
      setState(() {
        _isSwitched = status == 1;
      });
    } catch (e) {
      print('Error saving switch history: $e');
    }
  }

  // method to query switch events by device id (from server)
  Future<void> _loadSwitchEvents([String? historyDeviceId]) async {
    try {
      final id = historyDeviceId ?? _historyDeviceId;
      if (id == null) {
        if (mounted) {
          setState(() {
            _switchEvents.clear();
          });
        }
        return;
      }

      final api = ApiService();
      final List<dynamic> data = await api.fetchDeviceHistoryByDeviceId(id);
      final events = data
          .map((e) => SwitchEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _switchEvents.clear();
        _switchEvents.addAll(events);
      });
    } catch (e) {
      print('Error loading switch events from server: $e');
    }
  }

  // method to clear all switch events
  void _clearSwitchEvents() async {
    try {
      final deviceId = _deviceLocalId;
      if (deviceId == null) {
        _showMissingDeviceIdMessage();
        return;
      }

      await DatabaseHelper.instance.deleteSwitchEvents(deviceId);
      _loadSwitchEvents();
    } catch (e) {
      print('Error clearing switch events: $e');
    }
  }

  Future<void>? _connectionFuture;

  @override
  void initState() {
    super.initState();
    // Use the singleton MQTT manager - no need to create new connections
    mqttManager = MQTTManager.instance;
    _connectionFuture = mqttManager.ensureConnected().then((_) {
      if (mounted) {
        _subscribeToTopics();
      }
    });

    _isSwitched = widget.device.deviceStatus == 1;
    _loadSwitchEvents();

    if (widget.device.deviceType == 'Đồng hồ nước') {
      _fetchWaterMeterData();
    }
  }

  @override
  void dispose() {
    _temperatureSubscription?.cancel();
    _switchStatusSubscription?.cancel();
    if (mqttManager.isConnected) {
      mqttManager.unsubscribe(
        'NhaCuaToi_${widget.device.deviceSerial}_nhietdo',
      );
      mqttManager.unsubscribe('NhaCuaToi_${widget.device.deviceSerial}_status');
    }
    // Don't dispose the singleton MQTTManager
    super.dispose();
    print("did dispose of device detail screen");
  }

  void _subscribeToTopics() {
    if (_hasSubscribedTopics) {
      return;
    }

    if (mqttManager.isConnected) {
      _hasSubscribedTopics = true;
      // Subscribe to general sensor topics
      mqttManager.subscribe('NhaCuaToi_${widget.device.deviceSerial}_doam');
      mqttManager.subscribe('NhaCuaToi_${widget.device.deviceSerial}_nhietdo');
      mqttManager.subscribe('NhaCuaToi_${widget.device.deviceSerial}_status');

      // Subscribe to water level sensor topic if this is a water level sensor
      if (widget.device.deviceType == 'Cảm biến mực nước') {
        mqttManager.subscribe(
          'NhaCuaToi_${widget.device.deviceSerial}_mucnuoc',
        );
        print(
          '📡 Subscribed to water level topic: NhaCuaToi_${widget.device.deviceSerial}_mucnuoc',
        );
      }

      // Listen for updates on the 'doam' topic
      // mqttManager.updates('NhaCuaToi_${widget.device.deviceSerial}_doam')?.listen((message) {
      //   String str = message.replaceAll(r'\', '');
      //   try {
      //     print('Received message: $str');
      //
      //     // Ensure message is a valid JSON string
      //     if (str is String) {
      //       // Remove all backslashes from the JSON string
      //
      //       print('Cleaned message: $str');
      //
      //       // Remove leading and trailing incorrect double-quotes if present
      //       if (str.startsWith('"') && str.endsWith('"')) {
      //         str = str.substring(1, str.length - 1);
      //       }
      //
      //       final decodedMessage = jsonDecode(str);
      //       print('Decoded message type: ${decodedMessage.runtimeType}');
      //       print('Decoded message: $decodedMessage');
      //
      //       if (decodedMessage is Map<String, dynamic>) {
      //         setState(() {
      //           _currentSoilMoisture = decodedMessage['value'];
      //         });
      //       } else {
      //         print('Decoded message is not a Map: $decodedMessage');
      //       }
      //     } else {
      //       print('Received message is not a valid JSON string.');
      //     }
      //   } catch (e) {
      //     print('Error decoding message: $e');
      //     print('Received message: $str');
      //   }
      // });

      // Listen for updates on the 'nhietdo' topic
      _temperatureSubscription?.cancel();
      _temperatureSubscription = mqttManager
          .updates('NhaCuaToi_${widget.device.deviceSerial}_nhietdo')
          .listen((message) {
            String str = message;
            try {
              print('Received message: $str');
              print('Cleaned message: $str');
              final decodedMessage = jsonDecode(str);
              print('Decoded message type: ${decodedMessage.runtimeType}');
              print('Decoded message: $decodedMessage');

              if (decodedMessage is Map<String, dynamic>) {
                setState(() {
                  //final alert = jsonDecode(decodedMessage['messages']) as Map<String, dynamic>;
                  //print(decodedMessage);
                  String temperature = decodedMessage['Temperature'];
                  String SoilMoisture = decodedMessage['Moisture'];
                  final double temperaturenew =
                      double.tryParse(temperature) ?? 0.0;
                  final double SoilMoisturenew =
                      double.tryParse(SoilMoisture) ?? 0.0;
                  _currentSoilMoisture = SoilMoisturenew;
                  _currentTemperature = temperaturenew;
                  //print('giá trị Temperature lấy được: $temperature');
                });
              } else {
                print('Decoded message is not a Map: $decodedMessage');
              }
            } catch (e) {
              print('Error decoding message: $e');
              print('Received message: $str');
            }
            // setState(() {
            //   _currentTemperature = 42.5;
            // });
          });

      _switchStatusSubscription?.cancel();
      _switchStatusSubscription = mqttManager
          .updates('NhaCuaToi_${widget.device.deviceSerial}_status')
          .listen(_onSwitchStatusMessage);
    } else {
      print('MQTT manager not connected');
    }
  }

  void _onSwitchStatusMessage(String message) {
    try {
      print('Received switch status message: $message');
      final bool? nextState = _parseSwitchState(message);
      if (nextState == null || !mounted || nextState == _isSwitched) {
        return;
      }

      setState(() {
        _isSwitched = nextState;
      });

      unawaited(_syncSwitchStateFromServer(nextState));
    } catch (e) {
      print('Error handling switch status message: $e');
    }
  }

  Future<void> _syncSwitchStateFromServer(bool nextState) async {
    await _saveSwitchDeviceHistory(nextState ? 1 : 0);

    if (!mounted) {
      return;
    }

    await _loadSwitchEvents();
  }

  bool? _parseSwitchState(String rawMessage) {
    final normalized = rawMessage.trim().toUpperCase();
    if (normalized == 'ON' || normalized == '1' || normalized == 'TRUE') {
      return true;
    }
    if (normalized == 'OFF' || normalized == '0' || normalized == 'FALSE') {
      return false;
    }

    final decoded = jsonDecode(rawMessage);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final dynamic serial = decoded['serial'];
    if (serial != null) {
      final value = serial.toString();
      final expected1 = widget.device.deviceSerial;
      final expected2 = 'NhaCuaToi_${widget.device.deviceSerial}';
      if (value != expected1 && value != expected2) {
        return null;
      }
    }

    final dynamic status =
        decoded['status'] ??
        decoded['state'] ??
        decoded['power'] ??
        decoded['value'];
    if (status is bool) {
      return status;
    }
    if (status is num) {
      return status == 1;
    }
    if (status is String) {
      final value = status.trim().toUpperCase();
      if (value == 'ON' || value == '1' || value == 'TRUE') {
        return true;
      }
      if (value == 'OFF' || value == '0' || value == 'FALSE') {
        return false;
      }
    }

    return null;
  }

  Future<void> _fetchWaterMeterData() async {
    setState(() {
      _isLoadingWater = true;
      _waterError = null;
    });
    try {
      final api = ApiService();
      final data = await api.fetchWaterMeterData(widget.device.deviceSerial);
      setState(() {
        _waterMeterData = data;
        _isLoadingWater = false;
      });
    } catch (e) {
      setState(() {
        _waterError = e.toString();
        _isLoadingWater = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(widget.device.deviceName),
            Text(widget.device.deviceType, style: TextStyle(fontSize: 14)),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _isSwitched);
          },
        ),
      ),
      drawer: const AppDrawer(),
      body: FutureBuilder(
        future: _connectionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Có lỗi xảy ra khi kết nối đến máy chủ'));
          }
          return (widget.device.deviceType == 'Sensor')
              ? Center(
                  child: Column(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Serial: ${widget.device.deviceSerial}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            Expanded(
                              child: SfRadialGauge(
                                title: GaugeTitle(
                                  text: 'Nhiệt độ',
                                  textStyle: const TextStyle(
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                axes: <RadialAxis>[
                                  RadialAxis(
                                    minimum: 0,
                                    maximum: 100,
                                    ranges: <GaugeRange>[
                                      GaugeRange(
                                        startValue: 0,
                                        endValue: 20,
                                        color: Colors.blue,
                                        startWidth: 10,
                                        endWidth: 10,
                                      ),
                                      GaugeRange(
                                        startValue: 20,
                                        endValue: 40,
                                        color: Colors.cyan,
                                        startWidth: 10,
                                        endWidth: 10,
                                      ),
                                      GaugeRange(
                                        startValue: 40,
                                        endValue: 60,
                                        color: Colors.green,
                                        startWidth: 10,
                                        endWidth: 10,
                                      ),
                                      GaugeRange(
                                        startValue: 60,
                                        endValue: 80,
                                        color: Colors.orange,
                                        startWidth: 10,
                                        endWidth: 10,
                                      ),
                                      GaugeRange(
                                        startValue: 80,
                                        endValue: 100,
                                        color: Colors.red,
                                        startWidth: 10,
                                        endWidth: 10,
                                      ),
                                    ],
                                    pointers: <GaugePointer>[
                                      NeedlePointer(value: _currentTemperature),
                                    ],
                                    annotations: <GaugeAnnotation>[
                                      GaugeAnnotation(
                                        widget: Container(
                                          child: Text(
                                            '$_currentTemperature°C',
                                            style: TextStyle(
                                              fontSize: 25,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        angle: 90,
                                        positionFactor: 0.5,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),
                            Expanded(
                              child: SfRadialGauge(
                                title: GaugeTitle(
                                  text: 'Độ ẩm không khí',
                                  textStyle: const TextStyle(
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                axes: <RadialAxis>[
                                  RadialAxis(
                                    minimum: 0,
                                    maximum: 100,
                                    ranges: <GaugeRange>[
                                      GaugeRange(
                                        startValue: 0,
                                        endValue: 20,
                                        color: Colors.blue,
                                        startWidth: 10,
                                        endWidth: 10,
                                      ),
                                      GaugeRange(
                                        startValue: 20,
                                        endValue: 40,
                                        color: Colors.cyan,
                                        startWidth: 10,
                                        endWidth: 10,
                                      ),
                                      GaugeRange(
                                        startValue: 40,
                                        endValue: 60,
                                        color: Colors.green,
                                        startWidth: 10,
                                        endWidth: 10,
                                      ),
                                      GaugeRange(
                                        startValue: 60,
                                        endValue: 80,
                                        color: Colors.orange,
                                        startWidth: 10,
                                        endWidth: 10,
                                      ),
                                      GaugeRange(
                                        startValue: 80,
                                        endValue: 100,
                                        color: Colors.red,
                                        startWidth: 10,
                                        endWidth: 10,
                                      ),
                                    ],
                                    pointers: <GaugePointer>[
                                      NeedlePointer(
                                        value: _currentSoilMoisture,
                                      ),
                                    ],
                                    annotations: <GaugeAnnotation>[
                                      GaugeAnnotation(
                                        widget: Container(
                                          child: Text(
                                            '$_currentSoilMoisture%',
                                            style: TextStyle(
                                              fontSize: 25,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        angle: 90,
                                        positionFactor: 0.5,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : widget.device.deviceType == 'Đồng hồ nước'
              ? _buildWaterMeterInfo()
              : widget.device.deviceType == 'Cảm biến mực nước'
              ? _buildWaterLevelSensorInfo()
              : ListView(
                  children: [
                    FutureBuilder(
                      future: _connectionFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container();
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Có lỗi xảy ra khi kết nối đến máy chủ',
                            ),
                          );
                        }
                        return AlarmWidget(
                          deviceSerial: widget.device.deviceSerial,
                          mqttManager: mqttManager,
                        );
                      },
                    ),
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(5),
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FutureBuilder(
                        future: _connectionFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  PlaceholderBox(),
                                  Container(
                                    height: 100,
                                    width: 1,
                                    color: Colors.grey,
                                  ),
                                  PlaceholderBox(),
                                ],
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Đã có lỗi khi kết nối.'),
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: DeviceSensorReadingBox(
                                  deviceSerial: widget.device.deviceSerial,
                                  icon: Icons.opacity,
                                  title: "Độ ẩm đất",
                                  sensorType: "doam",
                                  color: Colors.brown[400]!,
                                  mqttManager: mqttManager,
                                ),
                              ),
                              Container(
                                height: 100,
                                width: 1,
                                color: Colors.grey,
                              ),
                              Expanded(
                                child: DeviceSensorReadingBox(
                                  deviceSerial: widget.device.deviceSerial,
                                  icon: Icons.water,
                                  title: "Mức nước",
                                  sensorType: "chatlong",
                                  color: Colors.blueAccent,
                                  mqttManager: mqttManager,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Điều khiển",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 5,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          DeviceDetailButton(
                            color: _isSwitched
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                            icon: Icons.power_settings_new,
                            shouldDisplayDotIndicator: true,
                            dotIndicatorColor: _isSwitched
                                ? Colors.green
                                : Colors.grey[200],
                            title: "Bật/Tắt",
                            onTap: () async {
                              bool newSwitchState = !_isSwitched;
                              await _saveSwitchDeviceHistory(
                                newSwitchState ? 1 : 0,
                              );

                              String topic =
                                  "NhaCuaToi_${widget.device.deviceSerial}";
                              String message = newSwitchState ? 'ON' : 'OFF';
                              mqttManager.publish(topic, message);

                              await _loadSwitchEvents();

                              setState(() {
                                _isSwitched = newSwitchState;
                              });
                            },
                          ),
                          DeviceDetailButton(
                            color: Theme.of(context).primaryColorDark,
                            icon: Icons.timer,
                            title: "Hẹn giờ",
                            shouldDisplayDotIndicator: false,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/device_schedule',
                                arguments: widget.device,
                              );
                              mqttManager.ensureConnected();
                            },
                          ),
                          DeviceDetailButton(
                            color: Theme.of(context).primaryColorDark,
                            icon: Icons.info,
                            title: "Thông tin",
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog.adaptive(
                                  title: Text("Thông tin thiết bị"),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Tên thiết bị: ${widget.device.deviceName}",
                                      ),
                                      Text(
                                        "Loại thiết bị: ${widget.device.deviceType}",
                                      ),
                                      Text(
                                        "Serial thiết bị: ${widget.device.deviceSerial}",
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text("OK"),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          if (widget.device.deviceType == 'Trạm bơm')
                            DeviceDetailButton(
                              color: Colors.blue[600]!,
                              icon: Icons.water,
                              title: "Quản lý",
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/pump_station',
                                  arguments: widget.device,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Lịch sử",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.refresh),
                                onPressed: () {
                                  _loadSwitchEvents();
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_forever),
                                onPressed: () {
                                  if (Platform.isAndroid) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text("Xoá lịch sử"),
                                        content: Text(
                                          "Bạn có chắc chắn muốn xoá lịch sử của thiết bị này không?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: Text("Huỷ"),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              _clearSwitchEvents();
                                              Navigator.of(context).pop();
                                            },
                                            child: Text("Xoá"),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (Platform.isIOS) {
                                    showCupertinoDialog(
                                      context: context,
                                      builder: (context) => CupertinoAlertDialog(
                                        title: Text("Xoá lịch sử"),
                                        content: Text(
                                          "Bạn có chắc chắn muốn xoá lịch sử của thiết bị này không?",
                                        ),
                                        actions: [
                                          CupertinoDialogAction(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: Text("Huỷ"),
                                          ),
                                          CupertinoDialogAction(
                                            onPressed: () {
                                              _clearSwitchEvents();
                                              Navigator.of(context).pop();
                                            },
                                            child: Text("Xoá"),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: _switchEvents.isEmpty
                          ? [Text("Chưa có lịch sử bật/tắt thiết bị")]
                          : _switchEvents.reversed.map((event) {
                              final dateFormat = DateFormat(
                                'HH:mm:ss, dd/MM/yyyy',
                              );
                              final dateString = dateFormat.format(
                                event.timestamp.add(const Duration(hours: 7)),
                              );
                              return ListTile(
                                leading: Icon(
                                  Icons.power_settings_new,
                                  color: event.isSwitched
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                title: Text(
                                  '${event.isSwitched ? 'Bật' : 'Tắt'} vào lúc $dateString',
                                  style: TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }).toList(),
                    ),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildWaterMeterInfo() {
    if (_isLoadingWater) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_waterError != null) {
      return Center(child: Text('Lỗi: \\$_waterError'));
    }
    if (_waterMeterData == null || _waterMeterData!['Data'] == null) {
      return const Center(child: Text('Không có dữ liệu đồng hồ nước.'));
    }
    final List data = List.from(_waterMeterData!['Data']);
    if (data.isEmpty) {
      return const Center(child: Text('Không có dữ liệu đồng hồ nước.'));
    }
    // Sắp xếp theo thời gian mới nhất lên đầu
    data.sort((a, b) {
      final at = DateTime.tryParse(a['Timestamp'] ?? '') ?? DateTime(1970);
      final bt = DateTime.tryParse(b['Timestamp'] ?? '') ?? DateTime(1970);
      return bt.compareTo(at);
    });
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        return Card(
          margin: const EdgeInsets.all(12),
          child: ListTile(
            leading: const Icon(Icons.water, color: Colors.blue),
            title: Text('Chỉ số: \\${item['MeterReadingLiters']} lít'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thời gian: \\${item['Timestamp']}'),
                Text('Trạng thái van: \\${item['ValveStatus']}'),
                Text('Tình trạng van: \\${item['ValveFaultStatus']}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaterLevelSensorInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.water_drop, size: 48, color: Colors.blue[600]),
                  const SizedBox(height: 8),
                  Text(
                    'Cảm biến mực nước',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Serial: ${widget.device.deviceSerial}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Water Level Reading Widget
          Expanded(
            child: DeviceSensorReadingBox(
              deviceSerial: widget.device.deviceSerial,
              icon: Icons.water,
              title: "Mức nước",
              sensorType: "mucnuoc",
              color: Colors.blue[600]!,
              mqttManager: mqttManager,
            ),
          ),

          const SizedBox(height: 16),

          // Instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hướng dẫn test:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Topic: NhaCuaToi_${widget.device.deviceSerial}_mucnuoc',
                  ),
                  const SizedBox(height: 4),
                  Text('Message JSON:'),
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '{"water_level": 45.5, "unit": "cm", "status": "normal"}',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
