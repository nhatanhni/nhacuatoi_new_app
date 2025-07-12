// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/repository/scheduler_repository.dart';
import 'package:iot_app/widgets/schedule_tag_widget.dart';
import 'package:numberpicker/numberpicker.dart';

class DeviceSchedulingScreen extends StatefulWidget {
  static const routeName = '/device_schedule';

  final Device device;

  DeviceSchedulingScreen({required this.device});

  @override
  State<DeviceSchedulingScreen> createState() => _DeviceSchedulingScreenState();
}

class _DeviceSchedulingScreenState extends State<DeviceSchedulingScreen> {
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true; // Add this line
  bool _switchValue = false;

  // for time picker and PUT request
  int _selectedDuration = 0;
  int _selectedHour = 0;
  int _selectedMinute = 0;
  int _repeat = 0;

  // method to get schedule given id
  Future<void> _getSchedule(String serial) async {
    final List<Map<String, dynamic>> schedules =
        await SchedulerRepository().getScheduleBySerial(serial);
    setState(() {
      _schedules = schedules;
      _isLoading = false; // Add this line
    });
  }

  // method to post schedule. After posting, get the schedule again, and reset the time picker, duration, and repeat values
  Future<void> _postSchedule(
      int hour, int minute, int duration, int repeat) async {
    final schedule = {
      "serial": widget.device.deviceSerial,
      "nameDevice": widget.device.deviceName,
      "Date_Type": "1",
      "repeat": repeat,
      "time":
          "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}",
      "numberTime": duration,
      "status": 1,
      "topic": "NhaCuaToi_${widget.device.deviceSerial}",
      "meseger": "1",
      "updateTime": DateTime.now().toIso8601String()
    };
    await SchedulerRepository().createSchedule(schedule);

    await _getSchedule(widget.device.deviceSerial);
    _selectedHour = 0;
    _selectedMinute = 0;
    _selectedDuration = 0;
    _repeat = 0;
  }

  // method to put schedule. After putting, get the schedule again
  Future<void> _putSchedule(String id, Map<String, dynamic> schedule) async {
    await SchedulerRepository().updateSchedule(id, schedule);
    await _getSchedule(widget.device.deviceSerial);
  }

  // method to delete schedule. After deleting, get the schedule again
  Future<void> _deleteSchedule(String id) async {
    await SchedulerRepository().deleteSchedule(id);
    // await SchedulerRepository().deleteScheduleWithGet(id);
    await _getSchedule(widget.device.deviceSerial);
  }

  // method to show dialog for time picker
  void _showScheduleDialog() {
    final TextEditingController durationController = TextEditingController();
    int selectedHour = 0;
    int selectedMinute = 0;
    int selectedDuration = 0;
    int repeat = 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Material(
          type: MaterialType.transparency,
          child: AlertDialog.adaptive(
            title: const Text('Thêm lịch hẹn giờ'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text("Chọn giờ"),
                ),
                // Choose time
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      StatefulBuilder(builder: (context, setState) {
                        return NumberPicker(
                          itemHeight: 35,
                          textStyle: const TextStyle(fontSize: 14),
                          selectedTextStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          zeroPad: true,
                          haptics: true,
                          value: selectedHour,
                          infiniteLoop: true,
                          minValue: 0,
                          maxValue: 23,
                          onChanged: (newValue) {
                            setState(() {
                              selectedHour = newValue;
                            });
                          },
                        );
                      }),
                      const Text(':', style: TextStyle(fontSize: 20)),
                      StatefulBuilder(builder: (context, setState) {
                        return NumberPicker(
                          itemHeight: 35,
                          textStyle: const TextStyle(fontSize: 14),
                          selectedTextStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          infiniteLoop: true,
                          zeroPad: true,
                          haptics: true,
                          value: selectedMinute,
                          minValue: 0,
                          maxValue: 59,
                          onChanged: (newValue) {
                            setState(() {
                              selectedMinute = newValue;
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),

                // Choose duration in seconds by user input, number keyboard

                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Thời lượng (giây)"),
                  onChanged: (value) {
                    setState(() {
                      selectedDuration = int.tryParse(value) ?? 0;
                      if (_selectedDuration > 86400) {
                        durationController.text = '86400'; // Cap value at 86400
                        selectedDuration = 86400;
                      }
                    });
                  },
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "Lặp lại hằng ngày",
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ),
                    StatefulBuilder(builder: (context, setState) {
                      return Switch(
                        value: repeat == 1,
                        onChanged: (value) {
                          setState(() {
                            repeat = value ? 1 : 0;
                          });
                        },
                      );
                    }),
                  ],
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Huỷ'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('OK'),
                onPressed: () async {
                  // Close the dialog
                  // Post the schedule
                  print("Repeat: $repeat");
                  await _postSchedule(
                      selectedHour, selectedMinute, selectedDuration, repeat);
                  Fluttertoast.showToast(
                      msg: "Thêm hẹn giờ thành công!",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      backgroundColor: Theme.of(context).primaryColor,
                      textColor: Colors.white,
                      fontSize: 16.0);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAlterScheduleDialog(
      String id, int hour, int minute, int duration, int repeat) {
    int thisHour = hour;
    int thisMinute = minute;
    int thisDuration = duration;
    int thisRepeat = repeat;
    final putDurationController =
        TextEditingController(text: thisDuration.toString());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Material(
          type: MaterialType.transparency,
          child: AlertDialog.adaptive(
            title: const Text('Sửa lịch hẹn giờ'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text("Chọn giờ"),
                ),
                // Choose time
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      StatefulBuilder(builder: (context, setState) {
                        return NumberPicker(
                          itemHeight: 35,
                          textStyle: const TextStyle(fontSize: 14),
                          selectedTextStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          zeroPad: true,
                          haptics: true,
                          value: thisHour,
                          infiniteLoop: true,
                          minValue: 0,
                          maxValue: 23,
                          onChanged: (newValue) {
                            setState(() {
                              thisHour = newValue;
                            });
                          },
                        );
                      }),
                      const Text(':', style: TextStyle(fontSize: 20)),
                      StatefulBuilder(builder: (context, setState) {
                        return NumberPicker(
                          itemHeight: 35,
                          textStyle: const TextStyle(fontSize: 14),
                          selectedTextStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          infiniteLoop: true,
                          zeroPad: true,
                          haptics: true,
                          value: thisMinute,
                          minValue: 0,
                          maxValue: 59,
                          onChanged: (newValue) {
                            setState(() {
                              thisMinute = newValue;
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),

                // Choose duration in seconds by user input, number keyboard

                TextField(
                  controller: putDurationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Thời lượng (giây)"),
                  onChanged: (value) {
                    setState(() {
                      thisDuration = int.tryParse(value) ?? 0;
                      if (thisDuration > 86400) {
                        putDurationController.text =
                            '86400'; // Cap value at 86400
                        thisDuration = 86400;
                      }
                    });
                  },
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "Lặp lại hằng ngày",
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ),
                    StatefulBuilder(builder: (context, setState) {
                      return Switch(
                        value: thisRepeat == 1,
                        onChanged: (value) {
                          setState(() {
                            thisRepeat = value ? 1 : 0;
                          });
                        },
                      );
                    }),
                  ],
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Huỷ'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('OK'),
                onPressed: () async {
                  print("Repeat: $thisRepeat");
                  // Close the dialog
                  // Post the schedule
                  await _putSchedule(id, {
                    "time":
                        "${thisHour.toString().padLeft(2, '0')}:${thisMinute.toString().padLeft(2, '0')}",
                    "numberTime": thisDuration,
                    "repeat": thisRepeat,
                    "updateTime": DateTime.now().toIso8601String()
                  });
                  Fluttertoast.showToast(
                      msg: "Sửa hẹn giờ thành công!",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      backgroundColor: Theme.of(context).primaryColor,
                      textColor: Colors.white,
                      fontSize: 16.0);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _getSchedule(widget.device.deviceSerial);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Hẹn giờ thiết bị"),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: _isLoading // Modify this line
                ? const CircularProgressIndicator.adaptive()
                : (_schedules.isEmpty)
                    ? Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).focusColor,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                        "Serial: ${widget.device.deviceSerial}",
                                        style: const TextStyle(fontSize: 16)),
                                    Text(
                                        "Số lịch hẹn đã đặt: ${_schedules.length}",
                                        style: const TextStyle(fontSize: 16)),
                                  ],
                                ),
                                (Platform.isIOS)
                                    ? CupertinoButton(
                                        onPressed: () {
                                          _showScheduleDialog();
                                        },
                                        child: const Text("Thêm"))
                                    : ElevatedButton(
                                        onPressed: () {
                                          _showScheduleDialog();
                                        },
                                        child: const Text("Thêm"))
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Center(
                            child: Text("Chưa có hẹn giờ cho thiết bị này."),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).focusColor,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                        "Serial: ${widget.device.deviceSerial}",
                                        style: const TextStyle(fontSize: 16)),
                                    Text(
                                        "Số lịch hẹn đã đặt: ${_schedules.length}",
                                        style: const TextStyle(fontSize: 16)),
                                  ],
                                ),
                                (Platform.isIOS)
                                    ? CupertinoButton(
                                        onPressed: () {
                                          _showScheduleDialog();
                                        },
                                        child: const Text("Thêm"))
                                    : ElevatedButton(
                                        onPressed: () {
                                          _showScheduleDialog();
                                        },
                                        child: const Text("Thêm"))
                              ],
                            ),
                          ),
                          Expanded(
                            child: _schedules.isEmpty
                                ? const Center(
                                    child: Text(
                                        "Chưa có hẹn giờ cho thiết bị này."),
                                  )
                                : ListView(
                                    children: _schedules.map((schedule) {
                                      return Slidable(
                                        key: Key(schedule['Id'].toString()),
                                        endActionPane: ActionPane(
                                          motion: const ScrollMotion(),
                                          children: [
                                            SlidableAction(
                                              onPressed:
                                                  (BuildContext context) {
                                                _showAlterScheduleDialog(
                                                    schedule['Id'],
                                                    int.parse(schedule['Time']
                                                        .split(":")[0]),
                                                    int.parse(schedule['Time']
                                                        .split(":")[1]),
                                                    schedule['NumberTime'],
                                                    schedule['Repeat']);
                                              },
                                              icon: Icons.edit,
                                              backgroundColor: Theme.of(context)
                                                  .primaryColor,
                                            ),
                                            SlidableAction(
                                              onPressed:
                                                  (BuildContext context) {
                                                // show dialog to confirm delete
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) {
                                                    return AlertDialog.adaptive(
                                                      title: const Text(
                                                          "Xác nhận xóa"),
                                                      content: const Text(
                                                          "Bạn có chắc chắn muốn xóa lịch hẹn này không?"),
                                                      actions: <Widget>[
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                          },
                                                          child: const Text(
                                                            "Huỷ",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .black),
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () async {
                                                            print(
                                                                schedule['Id']);
                                                            _deleteSchedule(
                                                                schedule['Id']);
                                                            print("did delete");
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                            Fluttertoast.showToast(
                                                                msg:
                                                                    "Xoá hẹn giờ thành công!",
                                                                toastLength: Toast
                                                                    .LENGTH_SHORT,
                                                                gravity:
                                                                    ToastGravity
                                                                        .BOTTOM,
                                                                timeInSecForIosWeb:
                                                                    1,
                                                                backgroundColor:
                                                                    Theme.of(
                                                                            context)
                                                                        .primaryColor,
                                                                textColor:
                                                                    Colors
                                                                        .white,
                                                                fontSize: 16.0);
                                                          },
                                                          child: const Text(
                                                            "Xóa",
                                                            style: TextStyle(
                                                                color:
                                                                    Colors.red),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                              icon: Icons.delete,
                                              backgroundColor:
                                                  Colors.deepOrangeAccent[100]!,
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                              border: Border(
                                                  bottom: BorderSide(
                                                      color: Colors.grey[300]!,
                                                      width: 1.0))),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8.0),
                                          child: ListTile(
                                            title: Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8.0),
                                              child:
                                                  // Text(schedule['NameDevice']),
                                                  Row(
                                                children: [
                                                  Text(
                                                      "Lịch chạy | ${schedule['Repeat'] == 1 ? "Lặp lại hằng ngày" : "Chỉ hôm nay"}"),
                                                ],
                                              ),
                                            ),
                                            subtitle: Row(
                                              children: [
                                                ScheduleTag(
                                                    icon: Icons.alarm,
                                                    text: schedule["Time"],
                                                    textColor: Colors.black,
                                                    color: Theme.of(context)
                                                        .primaryColorLight),
                                                const SizedBox(width: 10),
                                                ScheduleTag(
                                                    icon: Icons.timer,
                                                    text:
                                                        "${schedule['NumberTime']}s",
                                                    textColor: Colors.black,
                                                    color:
                                                        Colors.deepOrangeAccent[
                                                            100]!),
                                                // const SizedBox(width: 10),
                                                // ScheduleTag(
                                                //     icon: Icons.calendar_month,
                                                //     text: (schedule["repeat"] ==
                                                //             1)
                                                //         ? "Hằng ngày"
                                                //         : "Hôm nay",
                                                //     textColor: Colors.black,
                                                //     color: Colors.yellow[100]!),
                                              ],
                                            ),
                                            trailing: Switch(
                                              value: schedule['Status'] == 1,
                                              onChanged: (value) async {
                                                // Update the status in the schedule map
                                                schedule['Status'] =
                                                    value ? 1 : 0;

                                                // Update the switch value in the state
                                                setState(() {
                                                  _switchValue = value;
                                                });

                                                // Send a PUT request with the updated schedule
                                                await _putSchedule(
                                                    schedule['Id'], schedule);
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ],
                      ),
          ),
        ));
  }
}
