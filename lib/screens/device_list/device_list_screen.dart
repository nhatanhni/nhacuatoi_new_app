import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:iot_app/core/services/mqtt_manager.dart';
import 'package:iot_app/core/models/device.dart';
import 'package:iot_app/core/services/database_helper.dart' if (dart.library.html) 'package:iot_app/core/services/web_database_helper.dart';
import 'package:iot_app/screens/device_list/device_detail/device_detail_screen.dart';
import 'package:iot_app/screens/pump_station/pump_station_screen.dart';
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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Custom Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 50, // Added padding for status bar
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF28356A), // Dark blue
                  Color(0xFF8B9DC9), // Light blue
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(0),
              )
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm thiết bị...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Chips
                Row(
                  children: [
                    _buildTopChip(Icons.tune, 'Lọc'),
                    const SizedBox(width: 12),
                    _buildTopChip(Icons.swap_vert, 'Mới nhất'),
                  ],
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildGroupHeader('ĐƠN VỊ A — TRẠM QUAN TRẮC NƯỚC'),
                  const SizedBox(height: 16),
                  _buildDeviceCard(
                    iconData: Icons.water_drop_outlined,
                    iconColor: Colors.green.shade600,
                    iconBgColor: Colors.green.shade50,
                    name: 'Cảm biến độ ẩm HA-02',
                    serial: 'SN·2024-HA-002156',
                    isActive: true,
                    warningCount: 1,
                    metrics: [
                      _FakeMetric('Mực nước', '245.5', 'm²', Icons.open_in_full),
                      _FakeMetric('Lượng mưa', '10000', 'mm', Icons.water),
                      _FakeMetric('Cường độ mưa', '100', 'mm/h', Icons.trending_up),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDeviceCard(
                    iconData: Icons.show_chart,
                    iconColor: Colors.orange.shade600,
                    iconBgColor: Colors.orange.shade50,
                    name: 'Máy đo chất lượng nước WQ-03',
                    serial: 'SN·2024-HA-002156',
                    isActive: true,
                    warningCount: 1,
                    metrics: [
                      _FakeMetric('Mực nước', '245.5', 'm²', Icons.open_in_full),
                      _FakeMetric('Lượng mưa', '10000', 'mm', Icons.water),
                      _FakeMetric('Cường độ mưa', '100', 'mm/h', Icons.trending_up),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDeviceCard(
                    iconData: Icons.thermostat,
                    iconColor: Colors.red.shade600,
                    iconBgColor: Colors.red.shade50,
                    name: 'Cảm biến nhiệt độ TH-01',
                    serial: 'SN·2024-HA-002156',
                    isActive: false,
                    warningCount: 0,
                    metrics: [
                      _FakeMetric('Mực nước', '--', 'm²', Icons.open_in_full),
                      _FakeMetric('Lượng mưa', '--', 'mm', Icons.water),
                      _FakeMetric('Cường độ mưa', '--', 'mm/h', Icons.trending_up),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildGroupHeader('ĐƠN VỊ B — TRẠM XỬ LÝ NƯỚC THẢI'),
                  const SizedBox(height: 16),
                  _buildDeviceCard(
                    iconData: Icons.water_drop_outlined,
                    iconColor: Colors.green.shade600,
                    iconBgColor: Colors.green.shade50,
                    name: 'Cảm biến độ pH',
                    serial: 'SN·2024-HA-002156',
                    isActive: true,
                    warningCount: 1,
                    metrics: [
                      _FakeMetric('Mực nước', '245.5', 'm²', Icons.open_in_full),
                      _FakeMetric('Lượng mưa', '10000', 'mm', Icons.water),
                      _FakeMetric('Cường độ mưa', '100', 'mm/h', Icons.trending_up),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Row(
      children: [
        const Icon(Icons.business, color: Colors.grey, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard({
    required IconData iconData,
    required Color iconColor,
    required Color iconBgColor,
    required String name,
    required String serial,
    required bool isActive,
    required int warningCount,
    required List<_FakeMetric> metrics,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: iconColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      serial,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status tags
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'Đang hoạt động' : 'Không hoạt động',
                  style: TextStyle(
                    color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (warningCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$warningCount cảnh báo',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Metrics row
          Row(
            children: metrics.map((m) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: m != metrics.last ? 8.0 : 0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA), // Very light grey
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(m.icon, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                m.name,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              m.value,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2.0),
                              child: Text(
                                m.unit,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FakeMetric {
  final String name;
  final String value;
  final String unit;
  final IconData icon;

  _FakeMetric(this.name, this.value, this.unit, this.icon);
}
