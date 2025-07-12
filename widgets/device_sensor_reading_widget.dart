import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iot_app/repository/mqtt_manager.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shimmer/shimmer.dart';

class DeviceSensorReadingBox extends StatefulWidget {
  final String title;
  final String sensorType;
  final IconData icon;
  final Color color;
  final String deviceSerial;
  final MQTTManager mqttManager;

  const DeviceSensorReadingBox({
    Key? key,
    required this.title,
    required this.sensorType,
    required this.icon,
    required this.color,
    required this.deviceSerial,
    required this.mqttManager,
  }) : super(key: key);

  @override
  _DeviceSensorReadingBoxState createState() => _DeviceSensorReadingBoxState();
}

class _DeviceSensorReadingBoxState extends State<DeviceSensorReadingBox> {
  double? value;
  String? errorMessage;

  StreamSubscription<dynamic>? _subscription;
  @override
  void initState() {
    super.initState();
    _connectAndSubscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _connectAndSubscribe() async {
    try {
      final String topic =
          'NhaCuaToi_${widget.deviceSerial}_${widget.sensorType}';
      print('Subscribing to topic: $topic');
      widget.mqttManager.subscribe(topic);
      _subscription = widget.mqttManager.updates(topic).listen((message) {
        print("vào trong reading: "+message);
        if (mounted) {
          setState(() {
            if (widget.sensorType == "chatlong") {
              value = (message == "Còn chất lỏng" || message == "1") ? 100 : 0;
            } else if (widget.sensorType == "doam") {
              value = double.parse(message);
            } else if (widget.sensorType == "nhietdo") {
              value = double.parse(message);
            }
            errorMessage = null;
          });
        }
      });
    } catch (e) {
      print('Exception while connecting and subscribing: $e');
      _subscription = const Stream.empty().listen((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (value != null)
                    CircularProgressIndicator(
                      value: value! / 100,
                      strokeWidth: 3.0,
                      color: widget.color,
                      backgroundColor: Colors.grey[300],
                    )
                  else
                    CircularProgressIndicator(
                      value: 0,
                      strokeWidth: 3.0,
                      color: widget.color,
                      backgroundColor: Colors.grey[300],
                    ),
                  Icon(widget.icon, color: widget.color),
                ],
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (value == null)
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Theme.of(context).primaryColor,
                      child: const Text('...'),
                    )
                  else
                    Text(
                      (widget.sensorType == "chatlong")
                          ? ((value == 100) ? "Có nước" : "Hết nước")
                          : "${value!.toStringAsFixed(1)}%",
                      style: const TextStyle(overflow: TextOverflow.ellipsis),
                    ),
                  if (value != null && widget.sensorType != "chatlong")
                    Text(widget.title),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }
}
