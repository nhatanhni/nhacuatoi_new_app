// ignore_for_file: prefer_const_constructors, avoid_print, prefer_const_literals_to_create_immutables

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/database/database_helper.dart';
import 'package:iot_app/screens/device_detail_screen.dart';
import 'package:iot_app/widgets/appbar_back_to_home_widget.dart';
import 'package:iot_app/widgets/appbar_dropdown_widget.dart';

class ManageDeviceScreen extends StatefulWidget {
  const ManageDeviceScreen({Key? key}) : super(key: key);

  @override
  State<ManageDeviceScreen> createState() => _ManageDeviceScreenState();
}

class _ManageDeviceScreenState extends State<ManageDeviceScreen> {
  List<Device> _devices = []; // List to hold devices

  @override
  void initState() {
    super.initState();
    _loadDevices(); // Load devices when the screen initializes
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

  // Method to delete a device from the database
  void _deleteDevice(int id) async {
    try {
      await DatabaseHelper.instance.deleteDevice(id);
      _loadDevices();
    } catch (e) {
      print('Error deleting device: $e');
    }
  }

  // Delete switch events associated with the device
  void _deleteSwitchEvents(int id) async {
    try {
      await DatabaseHelper.instance.deleteSwitchEvents(id);
    } catch (e) {
      print('Error deleting switch events: $e');
    }
  }

  // Method to delete all devices
  void _deleteAllDevices() async {
    try {
      await DatabaseHelper.instance.deleteAllDevices();
      _loadDevices();
    } catch (e) {
      print('Error deleting all devices: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            Text("Quản lý thiết bị"),
            Text(
              "Tổng số thiết bị: ${_devices.length}",
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        leading: AppBarBackToHome(),
        actions: [AppBarDropdown()],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(height: 10),
            _devices.isEmpty
                ? Text(
                    'Hiện chưa có thiết bị nào',
                    style: TextStyle(color: Colors.grey),
                  )
                : Expanded(
                    child: ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (BuildContext context, int index) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              DeviceDetailScreen.routeName,
                              arguments: _devices[index],
                            );
                          },
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.15,
                            decoration: BoxDecoration(
                                color: Colors.deepOrange[100],
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF000000).withOpacity(1),
                                    offset: Offset(0, 5),
                                    blurRadius: 0,
                                    spreadRadius: 2,
                                  ),
                                ]),
                            padding: EdgeInsets.all(10),
                            margin: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Icons.toggle_on if "Công tắc", Icons.waves if "Sensor", Icons.lightbulb if "Hồng ngoại"
                                    Icon(
                                      _devices[index].deviceType == 'Công tắc'
                                          ? Icons.toggle_on
                                          : _devices[index].deviceType ==
                                                  'Sensor'
                                              ? Icons.waves
                                              : Icons.visibility,
                                      size: 50,
                                    ),
                                    SizedBox(width: 15),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _devices[index].deviceName,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20),
                                        ),
                                        Text(
                                          _devices[index].deviceType,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                IconButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog.adaptive(
                                          title: Text('Cảnh báo'),
                                          content: Text(
                                              'Bạn có chắc chắn muốn xoá thiết bị này không?'),
                                          actions: <Widget>[
                                            TextButton(
                                              child: Text('Huỷ'),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                            TextButton(
                                              child: Text('Xoá'),
                                              onPressed: () {
                                                _deleteDevice(
                                                    _devices[index].id!);
                                                _deleteSwitchEvents(
                                                    _devices[index].id!);
                                                setState(() {
                                                  _devices.removeAt(index);
                                                });
                                                Navigator.of(context).pop();
                                                Fluttertoast.showToast(
                                                  msg:
                                                      "Xoá thiết bị thành công.",
                                                  toastLength:
                                                      Toast.LENGTH_SHORT,
                                                  gravity: ToastGravity.BOTTOM,
                                                  timeInSecForIosWeb: 1,
                                                  backgroundColor:
                                                      Theme.of(context)
                                                          .primaryColor,
                                                  textColor: Colors.white,
                                                  fontSize: 16.0,
                                                );
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  icon: Icon(Icons.delete, color: Colors.black),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            (_devices.isEmpty)
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: (Platform.isAndroid)
                        ? ElevatedButton(
                            onPressed: () {
                              // Navigate to the AddDeviceScreen
                              Navigator.pushNamed(context, '/add_device');
                            },
                            child: Text("Thêm thiết bị"),
                          )
                        : CupertinoButton(
                            child: Text("Thêm thiết bị"),
                            onPressed: () {
                              Navigator.pushNamed(context, '/add_device');
                            }),
                  )
                : Container(),
            // Padding(
            //   padding: const EdgeInsets.all(8.0),
            //   child: ElevatedButton(
            //     onPressed: () {
            //       // Navigate to the AddDeviceScreen
            //       _deleteAllDevices();
            //     },
            //     child: Text("Xoá hết"),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
