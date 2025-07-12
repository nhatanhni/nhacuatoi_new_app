import 'dart:math';

import 'package:flutter/material.dart';
import 'package:iot_app/repository/mqtt_manager.dart';
import 'package:iot_app/widgets/appbar_dropdown_widget.dart';
import 'package:iot_app/widgets/drawer_widget.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/database/database_helper.dart';
import 'package:iot_app/screens/device_detail_screen.dart';
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
    manager.connect();
    _loadDevices(); // Load devices when the screen initializes
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }

  // Method to load devices from the database
  void _loadDevices() async {
    try {
      List<Device> devices = await DatabaseHelper.instance.queryAllDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      print('Error loading devices: $e');
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
                        // Navigate to the device detail screen
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
                            Icon(
                              _devices[index].deviceType == 'Công tắc'
                                  ? Icons.toggle_on
                                  : _devices[index].deviceType == 'Sensor'
                                      ? Icons.waves
                                      : _devices[index].deviceType == 'Đồng hồ nước'
                                          ? Icons.water_drop
                                      : Icons.visibility,
                              size: 50,
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
