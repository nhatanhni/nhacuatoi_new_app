// ignore_for_file: prefer_const_constructors, avoid_print, prefer_const_literals_to_create_immutables, prefer_final_fields, prefer_const_constructors_in_immutables

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/database/database_helper.dart';
import 'package:iot_app/widgets/appbar_back_to_home_widget.dart';
import 'package:iot_app/widgets/appbar_dropdown_widget.dart';
import 'package:iot_app/widgets/custom_button_widget.dart';

class AddDeviceScreen extends StatefulWidget {
  AddDeviceScreen({Key? key}) : super(key: key);

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  TextEditingController _deviceSerialTextEditingController =
      TextEditingController();
  TextEditingController _deviceNameTextEditingController =
      TextEditingController();
  String dropdownValue = 'Công tắc';
  String dropdownSensorValue = 'Nhiệt độ';

  final dbHelper = DatabaseHelper.instance;

  // var to track sensor creation
  var isCreatingSensor = false;
  var baseValueForSlider = 50.0;

  void _addDevice(String deviceType) async {
    // Create a new SmartDevice
    var device;
    if (deviceType == 'Sensor') {
      // Create a new device with type sensor (with sensor type and threshold)
      device = Device(
        deviceType: deviceType,
        deviceSerial: _deviceSerialTextEditingController.text,
        deviceName: _deviceNameTextEditingController.text,
        deviceStatus: 0,
        sensorType: dropdownSensorValue,
        sensorThreshold: baseValueForSlider.round(),
      );
    } else {
      // Create a new device with type switch
      device = Device(
        deviceType: deviceType,
        deviceSerial: _deviceSerialTextEditingController.text,
        deviceName: _deviceNameTextEditingController.text,
        deviceStatus: 0,
      );
    }

    // Get a local reference to the context
    final localContext = context;

    // Insert the SmartDevice into the database
    try {
      await dbHelper.insertDevice(device);

      Navigator.pushNamed(localContext, "/manage_device");
    } catch (e) {
      showDialog(
        context: localContext,
        builder: (context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Failed to add device. Error: $e'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  print(e);
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Thêm thiết bị"),
        leading: AppBarBackToHome(),
        actions: [AppBarDropdown()],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(10.0),
                  margin: EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey,
                      width: 1.0,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: dropdownValue,
                      onChanged: (String? newValue) {
                        setState(() {
                          dropdownValue = newValue!;
                          isCreatingSensor = newValue == 'Sensor';
                        });
                      },
                      items: <String>['Công tắc', 'Sensor', 'Hồng ngoại','Contactor']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(value),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                (isCreatingSensor)
                    ? Container(
                        padding: EdgeInsets.all(10.0),
                        margin: EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.grey,
                            width: 1.0,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: dropdownSensorValue,
                            onChanged: (String? newValue) {
                              setState(() {
                                dropdownSensorValue = newValue!;
                              });
                            },
                            items: <String>['Nhiệt độ', 'Độ ẩm']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(value),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      )
                    : Container(),
                TextField(
                  controller: _deviceSerialTextEditingController,
                  maxLength: 14,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    labelText: 'Serial thiết bị',
                  ),
                ),
                TextField(
                  controller: _deviceNameTextEditingController,
                  maxLength: 14,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    labelText: 'Tên thiết bị',
                  ),
                ),
                (isCreatingSensor)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Ngưỡng cảnh báo'),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text('0'),
                              Expanded(
                                child: Slider(
                                  value: baseValueForSlider,
                                  onChanged: (double value) {
                                    setState(() {
                                      baseValueForSlider = value;
                                    });
                                  },
                                  min: 0,
                                  max: 100,
                                  divisions: 100,
                                  label: baseValueForSlider.round().toString(),
                                ),
                              ),
                              Text('100'),
                            ],
                          ),
                        ],
                      )
                    : Container(),
              ],
            ),
          ),
          (Platform.isAndroid)
              ? ElevatedButton(
                  onPressed: () {
                    _addDevice(dropdownValue);
                  },
                  child: Text("Thêm thiết bị"))
              : CupertinoButton(
                  child: Text("Thêm thiết bị"),
                  onPressed: () {
                    _addDevice(dropdownValue);
                  }),
        ],
      ),
    );
  }
}
