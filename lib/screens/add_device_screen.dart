// ignore_for_file: prefer_const_constructors, avoid_print, prefer_const_literals_to_create_immutables, prefer_final_fields, prefer_const_constructors_in_immutables

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:iot_app/bloc/device/device_bloc.dart';
import 'package:iot_app/bloc/device/device_event.dart';
import 'package:iot_app/bloc/device/device_state.dart';
import 'package:iot_app/bloc/organization/organization_bloc.dart';
import 'package:iot_app/bloc/organization/organization_event.dart';
import 'package:iot_app/bloc/organization/organization_state.dart';
import '../widgets/appbar_dropdown_widget.dart';

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
  String? dropdownOrgValue;
  String? dropdownDeviceTypeId;
  String? dropdownDeviceTypeName;
  String dropdownSensorValue = 'Nhiệt độ';
  bool isLoading = false;

  // Form fields cho sensor mực nước
  final _maxCapacityController = TextEditingController(text: '100');
  final _minThresholdController = TextEditingController(text: '10');
  final _maxThresholdController = TextEditingController(text: '90');

  // var to track sensor creation
  var isCreatingSensor = false;
  var baseValueForSlider = 50.0;

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Vui lòng bật dịch vụ vị trí trên thiết bị');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Ứng dụng chưa được cấp quyền truy cập vị trí');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _addDevice(String deviceTypeId, String deviceTypeName) async {
    final localContext = context;
    final serial = _deviceSerialTextEditingController.text.trim();
    final name = _deviceNameTextEditingController.text.trim();

    if (serial.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(localContext).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập Serial và Tên thiết bị')),
      );
      return;
    }

    if (dropdownOrgValue == null) {
      ScaffoldMessenger.of(
        localContext,
      ).showSnackBar(SnackBar(content: Text('Vui lòng chọn đơn vị')));
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      final position = await _getCurrentPosition();
      final orgId = dropdownOrgValue!;

      final uuid = Uuid();
      final payload = {
        'Id': uuid.v4(),
        'IdDeviceType': deviceTypeId,
        'DeviceTypeId': deviceTypeId,
        'ManagementUnitId': orgId,
        'OrganizationId': orgId,
        'Serial': serial,
        'Name': name,
        'Model': '',
        'Manufacturer': '',
        'Description': deviceTypeName == 'Sensor'
            ? 'Loai: $dropdownSensorValue, Nguong: ${baseValueForSlider.round()}'
            : '',
        'PurchaseDate': null,
        'ActivationDate': null,
        'WarrantyExpiryDate': null,
        'RunningTimeToday': 0,
        'TotalRuntime': 0,
        'FirmwareVersion': '',
        'Startup': false,
        'Status': 0,
        'Address': '',
        'Lat': position.latitude.toString(),
        'Long': position.longitude.toString(),
        'Latitude': position.latitude.toString(),
        'Longitude': position.longitude.toString(),
        'Position': 0,
        'PositionName': '',
        'MqUsername': '',
        'MqPass': '',
        'MqTopic': '',
      };

      final completer = Completer<void>();
      localContext.read<DeviceBloc>().add(
        DeviceCreateOnServerRequested(payload: payload, completer: completer),
      );
      await completer.future;

      setState(() {
        isLoading = false;
      });

      // Hiển thị toast thông báo thành công
      Fluttertoast.showToast(
        msg: 'Thêm thiết bị thành công',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      Navigator.pushNamed(localContext, "/manage_device");
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      showDialog(
        context: localContext,
        builder: (context) {
          return AlertDialog(
            title: Text('Lỗi'),
            content: Text('Không thể thêm thiết bị. Lỗi: $e'),
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
  void dispose() {
    _deviceSerialTextEditingController.dispose();
    _deviceNameTextEditingController.dispose();
    _maxCapacityController.dispose();
    _minThresholdController.dispose();
    _maxThresholdController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    context.read<DeviceBloc>().add(DeviceLoadAll());
    context.read<OrganizationBloc>().add(OrganizationLoadAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Thêm thiết bị"),
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
                  margin: EdgeInsets.only(top: 20, bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey, width: 1.0),
                  ),
                  child: BlocBuilder<OrganizationBloc, OrganizationState>(
                    builder: (context, state) {
                      if (state is OrganizationLoaded) {
                        final units = state.units;
                        final unitIds = units.map((u) => u.id).toList();

                        if (dropdownOrgValue == null ||
                            !unitIds.contains(dropdownOrgValue)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() {
                              dropdownOrgValue = units.isNotEmpty
                                  ? units.first.id
                                  : null;
                            });
                          });
                        }

                        return DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: dropdownOrgValue,
                            hint: Text('Chọn đơn vị'),
                            onChanged: (String? newValue) {
                              setState(() {
                                dropdownOrgValue = newValue;
                              });
                            },
                            items: units.map<DropdownMenuItem<String>>((unit) {
                              return DropdownMenuItem<String>(
                                value: unit.id,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    unit.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      } else if (state is OrganizationLoading) {
                        return Center(child: CircularProgressIndicator());
                      } else if (state is OrganizationError) {
                        return Center(child: Text('Error: ${state.message}'));
                      } else {
                        return Center(child: Text('Không có đơn vị'));
                      }
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(10.0),
                  margin: EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey, width: 1.0),
                  ),
                  child: BlocBuilder<DeviceBloc, DeviceState>(
                    builder: (context, state) {
                      if (state is DeviceLoaded) {
                        final deviceTypes = state.devices;
                        final deviceTypeIds = deviceTypes
                            .map((d) => d.id)
                            .toSet()
                            .toList();

                        if (dropdownDeviceTypeId == null ||
                            !deviceTypeIds.contains(dropdownDeviceTypeId)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() {
                              dropdownDeviceTypeId = deviceTypes.isNotEmpty
                                  ? deviceTypes.first.id
                                  : null;
                              dropdownDeviceTypeName = deviceTypes.isNotEmpty
                                  ? deviceTypes.first.name
                                  : null;
                              isCreatingSensor =
                                  dropdownDeviceTypeName == 'Sensor';
                            });
                          });
                        }

                        return DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: dropdownDeviceTypeId,
                            onChanged: (String? newValue) {
                              if (newValue == null) return;
                              final selectedType = deviceTypes.firstWhere(
                                (d) => d.id == newValue,
                              );
                              setState(() {
                                dropdownDeviceTypeId = newValue;
                                dropdownDeviceTypeName = selectedType.name;
                                isCreatingSensor =
                                    dropdownDeviceTypeName == 'Sensor';
                              });
                            },
                            items: deviceTypes.map<DropdownMenuItem<String>>((
                              deviceType,
                            ) {
                              return DropdownMenuItem<String>(
                                value: deviceType.id,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(deviceType.name),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      } else if (state is DeviceLoading) {
                        return Center(child: CircularProgressIndicator());
                      } else if (state is DeviceError) {
                        return Center(child: Text('Error: ${state.message}'));
                      } else {
                        return Center(child: Text('No device types available'));
                      }
                    },
                  ),
                ),
                (isCreatingSensor)
                    ? Container(
                        padding: EdgeInsets.all(10.0),
                        margin: EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey, width: 1.0),
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
                                })
                                .toList(),
                          ),
                        ),
                      )
                    : Container(),
                TextField(
                  controller: _deviceSerialTextEditingController,
                  maxLength: 14,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelText: 'Serial thiết bị',
                  ),
                ),
                TextField(
                  controller: _deviceNameTextEditingController,
                  maxLength: 14,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                  onPressed: isLoading
                      ? null
                      : () {
                          if (dropdownDeviceTypeId != null &&
                              dropdownDeviceTypeName != null) {
                            _addDevice(
                              dropdownDeviceTypeId!,
                              dropdownDeviceTypeName!,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Vui lòng chọn loại thiết bị')),
                            );
                          }
                        },
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text("Thêm thiết bị"),
                )
              : CupertinoButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          if (dropdownDeviceTypeId != null &&
                              dropdownDeviceTypeName != null) {
                            _addDevice(
                              dropdownDeviceTypeId!,
                              dropdownDeviceTypeName!,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Vui lòng chọn loại thiết bị')),
                            );
                          }
                        },
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CupertinoActivityIndicator(),
                        )
                      : Text("Thêm thiết bị"),
                ),
        ],
      ),
    );
  }
}
