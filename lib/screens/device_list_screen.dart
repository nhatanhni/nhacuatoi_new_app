import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:iot_app/repository/mqtt_manager.dart';
import 'package:iot_app/widgets/appbar_dropdown_widget.dart';
import 'package:iot_app/widgets/drawer_widget.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/database/database_helper.dart' if (dart.library.html) '../database/web_database_helper.dart';
import 'package:iot_app/screens/device_detail_screen.dart';
import 'package:iot_app/screens/pump_station_screen.dart';
import 'package:mqtt_client/mqtt_client.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({Key? key}) : super(key: key);

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late MQTTManager manager;

  bool _isSwitched = false; // test
  List<Device> _devices = []; // List to hold devices
  String _selectedFilter = 'Tất cả'; // Selected filter

  @override
  void initState() {
    super.initState();
    manager = MQTTManager();
    _initializeApp(); // Initialize app in the right order
  }

  // Initialize app with proper order: devices first, then MQTT
  void _initializeApp() async {
    // First load devices from database
    await _loadDevices();
    
    // Then initialize MQTT connection
    _initializeMqttConnection();
  }

  // Initialize MQTT connection and setup subscriptions
  void _initializeMqttConnection() async {
    try {
      print('🔌 Connecting to MQTT...');
      await manager.connect();
      
      // Wait a bit for connection to be fully established
      await Future.delayed(Duration(milliseconds: 1500));
      
      print('🔌 MQTT Connected! Setting up subscriptions...');
      
      // Setup message listener first
      _setupStatusSubscription();
      
      // Wait a bit before subscribing
      await Future.delayed(Duration(milliseconds: 500));
      
      // Subscribe to status topics for all loaded devices
      _subscribeToStatusTopics();
    } catch (e) {
      print('❌ Error initializing MQTT connection: $e');
    }
  }

  // Setup subscription for device status topics
  void _setupStatusSubscription() {
    print('🎧 Setting up MQTT message listener...');
    
    manager.client.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      for (MqttReceivedMessage<MqttMessage?> receivedMessage in c!) {
        if (receivedMessage.payload != null) {
          final topic = receivedMessage.topic;
          final message = MqttPublishPayload.bytesToStringAsString(
              (receivedMessage.payload as MqttPublishMessage).payload.message);
          
          print('📨 MQTT message received - Topic: $topic, Message: $message');
          
          // Check if it's a status topic
          if (topic.endsWith('_status')) {
            print('🔔 Status topic detected: $topic');
            _handleStatusMessage(topic, message);
          } else {
            print('ℹ️ Non-status topic: $topic');
          }
        }
      }
    });
    
    print('🎧 MQTT message listener setup complete');
  }

  void _subscribeToStatusTopics() async {
    // Check if MQTT client is connected before subscribing
    if (manager.client.connectionStatus?.state != MqttConnectionState.connected) {
      print('🚫 MQTT client not connected, cannot subscribe to status topics');
      print('   Current state: ${manager.client.connectionStatus?.state}');
      return;
    }
    
    if (_devices.isEmpty) {
      print('📦 No devices to subscribe to status topics');
      return;
    }
    
    print('📡 Starting status topics subscription for ${_devices.length} devices');
    print('   MQTT Connection State: ${manager.client.connectionStatus?.state}');
    
    for (Device device in _devices) {
      String statusTopic = 'NhaCuaToi_${device.deviceSerial}_status';
      try {
        print('   📡 Subscribing to status topic: $statusTopic');
        manager.subscribe(statusTopic);
        // Add small delay between subscriptions
        await Future.delayed(Duration(milliseconds: 100));
        print('   ✅ Successfully subscribed to: $statusTopic');
      } catch (e) {
        print('   ❌ Error subscribing to $statusTopic: $e');
      }
    }
    
    print('📡 Finished subscribing to ${_devices.length} status topics');
  }

  void _handleStatusMessage(String topic, String message) {
    try {
      print('🔔 Received status message on topic: $topic, message: $message');
      final data = jsonDecode(message);
      final serial = data['serial'];
      final status = data['status'];
      
      if (serial != null && status != null) {
        // Extract device serial from the full serial (remove "NhaCuaToi_" prefix)
        String deviceSerial = serial.toString().replaceFirst('NhaCuaToi_', '');
        
        print('📝 Updating device $deviceSerial status to: $status');
        
        // Update device connection status in database
        DatabaseHelper.instance.updateDeviceConnectionStatus(deviceSerial, status);
        
        // Reload devices to update UI
        _loadDevices();
      }
    } catch (e) {
      print('❌ Error parsing status message: $e');
    }
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }

  // Method to load devices from the database
  Future<void> _loadDevices() async {
    try {
      print('📦 Loading devices from database...');
      List<Device> devices = await DatabaseHelper.instance.queryAllDevices();
      print('📦 Loaded ${devices.length} devices from database');
      
      // Debug: Print device details
      for (Device device in devices) {
        print('🔍 Device: ${device.deviceName} (${device.deviceSerial}) - Status: ${device.connectionStatus}');
      }
      
      setState(() {
        _devices = devices;
      });
      
      print('📦 Devices loaded into state, total: ${_devices.length}');
      
      // Don't automatically subscribe here - let the MQTT initialization handle it
    } catch (e) {
      print('❌ Error loading devices: $e');
    }
  }

  // // method to add switch event to the database
  // void _addSwitchEvent(int deviceId, bool isSwitched) async {
  //   try {
  //     await DatabaseHelper.instance.insertSwitchEvent(
  //       SwitchEvent(DateTime.now(), isSwitched),
  //       deviceId,
  //     );
  //   } catch (e) {
  //     print('Error adding switch event: $e');
  //   }
  // }

  // Method to load devices by deviceType
  void _loadDevicesByType(String deviceType) async {
    try {
      List<Device> devices =
          await DatabaseHelper.instance.queryDevicesByType(deviceType);
      setState(() {
        _devices = devices;
      });
      // Subscribe to status topics for newly loaded devices (only if MQTT is connected)
      if (manager.client.connectionStatus?.state == MqttConnectionState.connected) {
        _subscribeToStatusTopics();
      }
    } catch (e) {
      print('Error loading devices: $e');
    }
  }

  // method to update devices status
  void _updateDeviceStatus(int id, int status) async {
    try {
      await DatabaseHelper.instance.updateDeviceStatus(id, status);
      _loadDevices();
    } catch (e) {
      print('Error updating device status: $e');
    }
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
      key: _scaffoldKey,
      appBar: AppBar(
        actions: const [AppBarDropdown()],
        title: const Text("Danh sách thiết bị"),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          icon: const Icon(Icons.menu),
        ),
      ),
      drawer: const AppDrawer(),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <String>['Tất cả', 'Công tắc', 'Sensor', 'Hồng ngoại', 'Đồng hồ nước']
                  .map((String value) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedFilter = value;
                        if (value == 'Tất cả') {
                          _loadDevices();
                        } else {
                          _loadDevicesByType(value);
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_selectedFilter == value)
                          ? Theme.of(context).primaryColor
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: (_selectedFilter == value)
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: (_devices.isEmpty)
              ? const Center(
                  child: Text('Hiện chưa có thiết bị nào.'),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                  ),
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        // Check device type and navigate accordingly
                        if (_devices[index].deviceType == 'Trạm bơm') {
                          // Navigate to Pump Station Screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PumpStationScreen(
                                device: _devices[index],
                              ),
                            ),
                          ).then((value) {
                            // Reconnect to the MQTT server because this screen was disposed when navigating to the detail screen
                            // check if the client is connected before reconnecting
                            if (manager.client.connectionStatus?.state !=
                                MqttConnectionState.connected) {
                              manager.connect();
                            }
                          });
                        } else {
                          // Navigate to the device detail screen for other devices
                          Navigator.pushNamed(
                            context,
                            DeviceDetailScreen.routeName,
                            arguments: _devices[index],
                          ).then((value) {
                            if (value != null && value is bool) {
                              // Update the device status in the list based on the returned value
                              _updateDeviceStatus(
                                  _devices[index].id!, value ? 1 : 0);
                            }
                            // Reconnect to the MQTT server because this screen was disposed when navigating to the detail screen
                            // check if the client is connected before reconnecting
                            if (manager.client.connectionStatus?.state !=
                                MqttConnectionState.connected) {
                              manager.connect();
                            }
                          });
                        }
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.4,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (_devices[index].deviceStatus == 0)
                              ? Colors.grey[300]
                              : Colors.green[300],
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF000000).withOpacity(1),
                              offset: const Offset(0, 5),
                              blurRadius: 0,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status indicator row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  _devices[index].deviceType == 'Công tắc'
                                      ? Icons.toggle_on
                                      : _devices[index].deviceType == 'Sensor'
                                          ? Icons.waves
                                          : _devices[index].deviceType == 'Đồng hồ nước'
                                              ? Icons.water
                                              : _devices[index].deviceType == 'Trạm bơm'
                                                  ? Icons.water
                                                  : Icons.visibility,
                                  size: 50,
                                ),
                                // Connection status indicator
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _getConnectionStatusColor(_devices[index].connectionStatus),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getConnectionStatusIcon(_devices[index].connectionStatus),
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _devices[index].deviceName,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(_devices[index].deviceType),
                                    ],
                                  ),
                                ),
                                (_devices[index].deviceType == 'Công tắc')
                                    ? Transform.rotate(
                                        angle: 3 * pi / 2,
                                        child: Switch(
                                          value:
                                              (_devices[index].deviceStatus ==
                                                      0)
                                                  ? false
                                                  : true,
                                          onChanged: (value) {
                                            setState(() {
                                              _isSwitched = value;

                                              // publish message to the MQTT server
                                              String topic =
                                                  "NhaCuaToi_${_devices[index].deviceSerial}";
                                              String message =
                                                  (_isSwitched) ? 'ON' : 'OFF';
                                              print(topic);
                                              print(message);
                                              manager.publish(topic, message);

                                              _updateDeviceStatus(
                                                  _devices[index].id!,
                                                  (_isSwitched) ? 1 : 0);

                                              // _addSwitchEvent(
                                              //     // Add switch event to the database
                                              //     _devices[index].id!,
                                              //     _isSwitched);
                                            });
                                          },
                                        ),
                                      )
                                    : Container(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
