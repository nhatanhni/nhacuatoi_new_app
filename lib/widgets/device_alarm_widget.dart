import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/repository/mqtt_manager.dart';

class AlarmWidget extends StatefulWidget {
  final String deviceSerial;
  final MQTTManager mqttManager;

  const AlarmWidget({
    Key? key,
    required this.deviceSerial,
    required this.mqttManager,
  }) : super(key: key);

  @override
  _AlarmWidgetState createState() => _AlarmWidgetState();
}

class _AlarmWidgetState extends State<AlarmWidget> {
  StreamSubscription<dynamic>? _subscription;
  String? _alarmMessage;

  @override
  void initState() {
    super.initState();
    //_connectAndSubscribe();
  }

  Future<void> _connectAndSubscribe() async {
    try {
      final String topic = 'NhaCuaToi_${widget.deviceSerial}_alarm';
      print('Subscribing to topic: $topic');
      widget.mqttManager.subscribe(topic);
      _subscription = widget.mqttManager.updates(topic).listen((message) {
        if (mounted) {
          setState(() {
            final alarmData = jsonDecode(message) as Map<String, dynamic>;
            final serial = alarmData["id"];
            final liquidPresent = alarmData["LiquidPresent"];
            final timestamp = alarmData["timestamp"];
            final alarmMessage = "Serial: $serial\n"
                "Hết nước: Mực nước bằng $liquidPresent\n"
                "Tại thời điểm: $timestamp\n";
            // _alarmMessage = message;
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text('Cảnh báo'),
                  content: Text(alarmMessage),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('OK'),
                    ),
                  ],
                );
              },
            );
          });
        }
        // cancel subscription after receiving the message to avoid multiple dialogs
        _subscription?.cancel();
      });
    } catch (e) {
      print('Exception while connecting and subscribing: $e');
      _subscription = const Stream.empty().listen((_) {});
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    print("did dispose alarm");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
