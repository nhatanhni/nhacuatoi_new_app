import 'package:flutter/material.dart';
import 'package:iot_app/widgets/appbar_dropdown_widget.dart';
import 'package:iot_app/widgets/drawer_widget.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:iot_app/database/database_helper.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/screens/device_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iot_app/main.dart';

import '../repository/mqtt_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MyApp.routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    MyApp.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Kiểm tra trạng thái thông báo khi quay trở lại HomeScreen
    _checkNotificationState();
    // Kết nối lại với MQTT khi quay trở lại HomeScreen
    _initializeMQTT();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      onDidReceiveLocalNotification: (int id, String? title, String? body, String? payload) async {
        _selectNotification(payload);
      },
    );
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _selectNotification(response.payload);
      },
    );
  }

  Future<void> _selectNotification(String? payload) async {
    if (payload != null) {
      // Lưu trạng thái thông báo
      await _saveNotificationState(payload);

      // Print the serial to the console
      print('Serial from notification: $payload');

      // Navigate to DeviceDetailScreen with the deviceSerial from the notification payload
      final device = await DatabaseHelper.instance.queryDeviceBySerial(payload);

      // Kiểm tra xem device có phải là null không
      if (device != null) {
        print('Navigating to DeviceDetailScreen with device: ${device.deviceSerial}');
        Navigator.of(MyApp.navigatorKey.currentContext!).push(
          MaterialPageRoute(
            builder: (context) => DeviceDetailScreen(device: device),
          ),
        );

        // Xóa trạng thái thông báo sau khi xử lý
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('notification_payload');
      } else {
        print('Device not found for serial: $payload');
      }
    }
  }

  Future<void> _checkNotificationState() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationPayload = prefs.getString('notification_payload');

    if (notificationPayload != null) {
      // Điều hướng đến màn hình chi tiết thiết bị với payload đã lưu
      final device = await DatabaseHelper.instance.queryDeviceBySerial(notificationPayload);
      if (device != null) {
        Navigator.of(MyApp.navigatorKey.currentContext!).push(
          MaterialPageRoute(
            builder: (context) => DeviceDetailScreen(device: device),
          ),
        );

        // Xóa trạng thái thông báo sau khi xử lý
        await prefs.remove('notification_payload');
      }
    }
  }

  Future<void> _saveNotificationState(String payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_payload', payload);
  }

  void _initializeMQTT() async {
    final mqttManager = MQTTManager('nhacuatoi.com.vn', 'flutter_client');
    await mqttManager.connect();

    List<Device> devices = await DatabaseHelper.instance.queryAllDevices();
    for (var device in devices) {
      mqttManager.subscribe("NhaCuaToi_${device.deviceSerial}_alarm");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Nhà Của Tôi'),
        actions: const <Widget>[
          AppBarDropdown(),
        ],
      ),
      drawer: const AppDrawer(),
      body: Center(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Container(
                width: MediaQuery.of(context).size.width, // Giảm chiều rộng tổng cộng 10px
                margin: const EdgeInsets.only(bottom: 10),
                child: Transform.translate(
                  offset: const Offset(0, 13), // Di chuyển ảnh xuống 5px
                  child: Image.asset(
                    'assets/images/home-1.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
