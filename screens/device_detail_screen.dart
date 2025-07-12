import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/models/switch_event.dart';
import 'package:iot_app/database/database_helper.dart';
import 'package:iot_app/repository/mqtt_manager.dart';
import 'package:iot_app/widgets/device_alarm_widget.dart';
import 'package:iot_app/widgets/device_sensor_reading_widget.dart';
import 'package:iot_app/widgets/device_detail_button_widget.dart';
import 'package:iot_app/widgets/placeholder_box_widget.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

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
  final List<SwitchEvent> _switchEvents = [];
  double _currentSoilMoisture = 0.0;
  double _currentTemperature = 0.0;

  // declaration for mqtt alarms:
  final _alarmMessageController = StreamController<String>();

  // method to update devices status
  Future<void> _updateDeviceStatus(int id, int status) async {
    try {
      await DatabaseHelper.instance.updateDeviceStatus(id, status);
      setState(() {
        _isSwitched = status == 1;
      });
    } catch (e) {
      print('Error updating device status: $e');
    }
  }

  // method to query switch events by device id
  Future<void> _loadSwitchEvents(int deviceId) async {
    try {
      List<SwitchEvent> events =
      await DatabaseHelper.instance.querySwitchEventsByDeviceId(deviceId);
      setState(() {
        _switchEvents.clear();
        _switchEvents.addAll(events);
      });
    } catch (e) {
      print('Error loading switch events: $e');
    }
  }

  // method to clear all switch events
  void _clearSwitchEvents() async {
    try {
      await DatabaseHelper.instance.deleteSwitchEvents(widget.device.id!);
      _loadSwitchEvents(widget.device.id!);
    } catch (e) {
      print('Error clearing switch events: $e');
    }
  }

  Future<void>? _connectionFuture;

  @override
  void initState() {
    super.initState();
    //print("đây là thiết bị: ${widget.device.deviceSerial}");
    //print(widget.device.toMap());
    // Initialize the MQTT manager
    mqttManager = MQTTManager('nhacuatoi.com.vn', 'flutter_client');
    _connectionFuture = mqttManager.connect();

    _isSwitched = widget.device.deviceStatus == 1;
    _loadSwitchEvents(widget.device.id!);

  }

  @override
  void dispose() {
    mqttManager.dispose();
    super.dispose();
    print("did dispose of device detail screen");
  }

  void _subscribeToTopics() {
    if (mqttManager.client.connectionStatus?.state == MqttConnectionState.connected) {
      mqttManager.subscribe('NhaCuaToi_${widget.device.deviceSerial}_doam');
      mqttManager.subscribe('NhaCuaToi_${widget.device.deviceSerial}_nhietdo');

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
      mqttManager.updates('NhaCuaToi_${widget.device.deviceSerial}_nhietdo')?.listen((message) {
        String str = message;
        try {
          print('Received message: $str');
          if (str is String) {
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
                final double temperaturenew = double.tryParse(temperature) ?? 0.0;
                final double SoilMoisturenew = double.tryParse(SoilMoisture) ?? 0.0;
                _currentSoilMoisture = SoilMoisturenew;
                _currentTemperature = temperaturenew;
                //print('giá trị Temperature lấy được: $temperature');
              });
            } else {
              print('Decoded message is not a Map: $decodedMessage');
            }
          } else {
            print('Received message is not a valid JSON string.');
          }
        } catch (e) {
          print('Error decoding message: $e');
          print('Received message: $str');
        }
        // setState(() {
        //   _currentTemperature = 42.5;
        // });

      });
    } else {
      print('MQTT manager not connected');
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
            Text(
              widget.device.deviceType,
              style: TextStyle(fontSize: 14),
            ),
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
            return Center(
              child: Text('Có lỗi xảy ra khi kết nối đến máy chủ'),
            );
          }
          if (snapshot.connectionState == ConnectionState.done) {
            _subscribeToTopics();
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
                                fontSize: 20.0, fontWeight: FontWeight.bold),
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
                                fontSize: 20.0, fontWeight: FontWeight.bold),
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
                                NeedlePointer(value: _currentSoilMoisture),
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
                              'Có lỗi xảy ra khi kết nối đến máy chủ'),
                        );
                      }
                      return AlarmWidget(
                          deviceSerial: widget.device.deviceSerial,
                          mqttManager: mqttManager);
                    }),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(5),
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10)),
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
                      }),
                ),
                SizedBox(height: 20),
                Padding(
                  padding:
                  EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Điều khiển",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                ),
                Padding(
                  padding:
                  EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      DeviceDetailButton(
                        color: _isSwitched
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        icon: Icons.power_settings_new,
                        shouldDisplayDotIndicator: true,
                        dotIndicatorColor:
                        _isSwitched ? Colors.green : Colors.grey[200],
                        title: "Bật/Tắt",
                        onTap: () async {
                          bool newSwitchState = !_isSwitched;
                          await _updateDeviceStatus(
                              widget.device.id!, newSwitchState ? 1 : 0);

                          String topic =
                              "NhaCuaToi_${widget.device.deviceSerial}";
                          String message = newSwitchState ? 'ON' : 'OFF';
                          mqttManager.publish(topic, message);

                          await _loadSwitchEvents(widget.device.id!);

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
                          Navigator.pushNamed(context, '/device_schedule',
                              arguments: widget.device);
                          if (mqttManager.client.connectionStatus?.state !=
                              MqttConnectionState.connected) {
                            mqttManager.connect();
                          }
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
                                    mainAxisAlignment:
                                    MainAxisAlignment.start,
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          "Tên thiết bị: ${widget.device.deviceName}"),
                                      Text(
                                          "Loại thiết bị: ${widget.device.deviceType}"),
                                      Text(
                                          "Serial thiết bị: ${widget.device.deviceSerial}"),
                                    ]),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text("OK"),
                                  ),
                                ],
                              ));
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                Padding(
                  padding:
                  EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Lịch sử",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20)),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.refresh),
                            onPressed: () {
                              _loadSwitchEvents(widget.device.id!);
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
                                        "Bạn có chắc chắn muốn xoá lịch sử của thiết bị này không?"),
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
                                  builder: (context) =>
                                      CupertinoAlertDialog(
                                        title: Text("Xoá lịch sử"),
                                        content: Text(
                                            "Bạn có chắc chắn muốn xoá lịch sử của thiết bị này không?"),
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
                      ? [
                    Text("Chưa có lịch sử bật/tắt thiết bị"),
                  ]
                      : _switchEvents.map((event) {
                    final dateFormat =
                    DateFormat('HH:mm:ss, dd/MM/yyyy');
                    final dateString =
                    dateFormat.format(event.timestamp);
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
                            overflow: TextOverflow.ellipsis),
                      ),
                    );
                  }).toList(),
                ),
              ]);
        },
      ),
    );
  }
}
