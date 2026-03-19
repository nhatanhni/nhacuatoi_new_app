import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot_app/bloc/device/device_bloc.dart';
import 'package:iot_app/bloc/device/device_event.dart';
import 'package:iot_app/bloc/device/device_state.dart';
import 'package:iot_app/repository/mqtt_manager.dart';
import 'package:iot_app/widgets/appbar_dropdown_widget.dart';
import 'package:iot_app/widgets/drawer_widget.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/screens/device_detail_screen.dart';
import 'package:iot_app/screens/pump_station_screen.dart';
import 'package:mqtt_client/mqtt_client.dart';

class DeviceListScreen extends StatefulWidget {
  final GlobalKey<ScaffoldState>? rootScaffoldKey;

  const DeviceListScreen({Key? key, this.rootScaffoldKey}) : super(key: key);

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  late MQTTManager manager;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  List<Device> _allDevices = [];
  List<Device> _devices = [];
  final Set<String> _subscribedStatusTopics = <String>{};
  String _selectedFilter = 'Tất cả'; // Selected filter

  @override
  void initState() {
    super.initState();
    manager = MQTTManager.instance;
    _scrollController.addListener(_onScrollLoadMore);
    context.read<DeviceBloc>().add(DeviceLoadManageList());
    _initializeMqttConnection();
  }

  void _onScrollLoadMore() {
    if (!_scrollController.hasClients || _isLoading || _isLoadingMore) {
      return;
    }

    if (!_hasMorePages) return;

    final threshold = _scrollController.position.maxScrollExtent - 220;
    if (_scrollController.position.pixels >= threshold) {
      context.read<DeviceBloc>().add(DeviceLoadManageNextPage());
    }
  }

  // Initialize MQTT connection and setup subscriptions
  void _initializeMqttConnection() async {
    try {
      print('🔌 Ensuring MQTT connection...');
      await manager.ensureConnected();

      print('🔌 MQTT Connected! Setting up subscriptions...');
      _setupStatusSubscription();

      await Future.delayed(Duration(milliseconds: 500));
      _subscribeToStatusTopics(_allDevices);
    } catch (e) {
      print('❌ Error initializing MQTT connection: $e');
    }
  }

  // Setup subscription for device status topics
  void _setupStatusSubscription() {
    print('🎧 Setting up MQTT message listener...');

    manager.client.updates?.listen((
      List<MqttReceivedMessage<MqttMessage?>>? c,
    ) {
      for (MqttReceivedMessage<MqttMessage?> receivedMessage in c!) {
        if (receivedMessage.payload != null) {
          final topic = receivedMessage.topic;
          final message = MqttPublishPayload.bytesToStringAsString(
            (receivedMessage.payload as MqttPublishMessage).payload.message,
          );

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

  void _subscribeToStatusTopics(Iterable<Device> devices) async {
    // Check if MQTT client is connected before subscribing
    if (manager.client.connectionStatus?.state !=
        MqttConnectionState.connected) {
      print('🚫 MQTT client not connected, cannot subscribe to status topics');
      print('   Current state: ${manager.client.connectionStatus?.state}');
      return;
    }

    final targets = devices.where((d) => d.deviceSerial.trim().isNotEmpty);
    if (targets.isEmpty) {
      print('📦 No devices to subscribe to status topics');
      return;
    }

    print(
      '📡 Starting status topics subscription for ${targets.length} devices',
    );
    print(
      '   MQTT Connection State: ${manager.client.connectionStatus?.state}',
    );

    for (Device device in targets) {
      String statusTopic = 'NhaCuaToi_${device.deviceSerial}_status';
      if (_subscribedStatusTopics.contains(statusTopic)) {
        continue;
      }

      try {
        print('   📡 Subscribing to status topic: $statusTopic');
        manager.subscribe(statusTopic);
        _subscribedStatusTopics.add(statusTopic);
        // Add small delay between subscriptions
        await Future.delayed(Duration(milliseconds: 100));
        print('   ✅ Successfully subscribed to: $statusTopic');
      } catch (e) {
        print('   ❌ Error subscribing to $statusTopic: $e');
      }
    }

    print('📡 Finished subscribing to ${targets.length} status topics');
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

        setState(() {
          _allDevices = _allDevices
              .map(
                (device) => device.deviceSerial == deviceSerial
                    ? Device(
                        id: device.id,
                        deviceType: device.deviceType,
                        deviceSerial: device.deviceSerial,
                        deviceName: device.deviceName,
                        sensorType: device.sensorType,
                        sensorThreshold: device.sensorThreshold,
                        deviceStatus: device.deviceStatus,
                        connectionStatus: status.toString(),
                        hasSchedule: device.hasSchedule,
                        scheduleTime: device.scheduleTime,
                        scheduleDuration: device.scheduleDuration,
                        scheduleDaily: device.scheduleDaily,
                      )
                    : device,
              )
              .toList();
          _applyFilter(_selectedFilter);
        });
      }
    } catch (e) {
      print('❌ Error parsing status message: $e');
    }
  }

  @override
  void dispose() {
    // Don't dispose the singleton MQTTManager - it's shared across the app
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilter(String filter) {
    if (filter == 'Tất cả') {
      _devices = List<Device>.from(_allDevices);
      return;
    }

    _devices = _allDevices
        .where((device) => device.deviceType == filter)
        .toList();
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
    final deviceTypes =
        _allDevices
            .map((d) => d.deviceType)
            .where((type) => type.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final filters = ['Tất cả', ...deviceTypes];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: const [AppBarDropdown()],
        title: Column(
          children: [
            const Text(
              'Danh sách thiết bị',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            Text(
              'Tổng số thiết bị: ${_devices.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            final scaffoldKey = widget.rootScaffoldKey ?? _scaffoldKey;
            scaffoldKey.currentState?.openDrawer();
          },
          icon: const Icon(Icons.menu),
        ),
      ),
      drawer: widget.rootScaffoldKey == null ? const AppDrawer() : null,
      body: SafeArea(
        child: BlocListener<DeviceBloc, DeviceState>(
          listener: (context, state) {
            if (state is DeviceLoading) {
              setState(() {
                _isLoading = true;
                _isLoadingMore = false;
              });
            } else if (state is DeviceManageLoaded) {
              final previousSerials = _allDevices
                  .map((d) => d.deviceSerial)
                  .where((serial) => serial.trim().isNotEmpty)
                  .toSet();

              setState(() {
                _isLoading = false;
                _isLoadingMore = state.isLoadingMore;
                _hasMorePages = state.hasMorePages;
                _allDevices = state.devices;
                _applyFilter(_selectedFilter);
              });

              final newDevices = _allDevices
                  .where((d) => !previousSerials.contains(d.deviceSerial))
                  .toList();

              if (manager.client.connectionStatus?.state ==
                  MqttConnectionState.connected) {
                _subscribeToStatusTopics(newDevices);
              }
            } else if (state is DeviceError) {
              setState(() {
                _isLoading = false;
                _isLoadingMore = false;
              });
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filters.map((String value) {
                      final isSelected = _selectedFilter == value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(32),
                          onTap: () {
                            setState(() {
                              _selectedFilter = value;
                              _applyFilter(value);
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: isSelected
                                  ? null
                                  : const [
                                      BoxShadow(
                                        color: Color(0x14000000),
                                        blurRadius: 18,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                            ),
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: 15,
                                height: 22 / 15,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF130F26),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator.adaptive())
                    : (_devices.isEmpty)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 84,
                                width: 84,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.router_rounded,
                                  size: 42,
                                  color: Colors.blue[700],
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Hiện chưa có thiết bị nào',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _devices.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _devices.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator.adaptive(),
                              ),
                            );
                          }

                          final device = _devices[index];
                          Color accentColor = Colors.deepPurple;
                          IconData iconData = Icons.devices;
                          final normalized = device.deviceType.toLowerCase();
                          if (normalized.contains('bơm')) {
                            accentColor = Colors.indigo;
                            iconData = Icons.water;
                          } else if (normalized.contains('nước thải')) {
                            accentColor = Colors.blue;
                            iconData = Icons.water_drop_outlined;
                          } else if (normalized.contains('mực nước')) {
                            accentColor = Colors.blue;
                            iconData = Icons.waves;
                          } else if (normalized.contains('điện') ||
                              normalized.contains('công tắc')) {
                            accentColor = Colors.orange;
                            iconData = Icons.electrical_services;
                          } else if (normalized.contains('khí thải')) {
                            accentColor = Colors.teal;
                            iconData = Icons.air;
                          } else if (normalized.contains('khí tượng')) {
                            accentColor = Colors.teal;
                            iconData = Icons.cloud;
                          } else if (normalized.contains('nước sinh hoạt')) {
                            accentColor = Colors.blue;
                            iconData = Icons.local_drink;
                          } else if (normalized.contains('sensor')) {
                            accentColor = Colors.deepPurple;
                            iconData = Icons.sensors;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                if (device.deviceType == 'Trạm bơm') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          PumpStationScreen(device: device),
                                    ),
                                  ).then((value) {
                                    manager.ensureConnected();
                                  });
                                } else {
                                  Navigator.pushNamed(
                                    context,
                                    DeviceDetailScreen.routeName,
                                    arguments: device,
                                  ).then((value) {
                                    manager.ensureConnected();
                                  });
                                }
                              },
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accentColor.withOpacity(0.14),
                                      Colors.white,
                                    ],
                                  ),
                                  border: Border.all(
                                    color: accentColor.withOpacity(0.24),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      offset: const Offset(0, 8),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 54,
                                      width: 54,
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        iconData,
                                        color: accentColor,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            device.deviceName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 17,
                                              color: Color(0xFF222222),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: accentColor.withOpacity(
                                                0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              device.deviceType,
                                              style: TextStyle(
                                                color: accentColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: _getConnectionStatusColor(
                                          device.connectionStatus,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _getConnectionStatusIcon(
                                          device.connectionStatus,
                                        ),
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
