import 'package:flutter/material.dart';
import '../widgets/appbar_dropdown_widget.dart';
import '../widgets/drawer_widget.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database/database_helper.dart' if (dart.library.html) '../database/web_database_helper.dart';
import '../models/device.dart';
import 'device_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repository/mqtt_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    // _initializeNotifications();
    // Khi vào HomeScreen, kiểm tra trạng thái thông báo và khởi tạo MQTT một lần
    _checkNotificationState();
    _initializeMQTT();
  }

  Future<void> _initializeNotifications() async {
    // Temporarily disabled due to flutter_local_notifications iOS compatibility issues
    /*
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
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
    */
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
      if (device != null && mounted) {
        print('Navigating to DeviceDetailScreen with device: ${device.deviceSerial}');
        Navigator.of(context).push(
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

    if (notificationPayload != null && mounted) {
      // Điều hướng đến màn hình chi tiết thiết bị với payload đã lưu
      final device = await DatabaseHelper.instance.queryDeviceBySerial(notificationPayload);
      if (device != null) {
        Navigator.of(context).push(
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
    final mqttManager = MQTTManager();
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
      body: Column(
        children: <Widget>[
          // Phần banner hình ảnh
          Expanded(
            child: Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.only(bottom: 10),
              child: Transform.translate(
                offset: const Offset(0, 13),
                child: Image.asset(
                  'assets/images/home-1.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Phần nút chức năng nhanh (menu chính)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Chức năng nhanh',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: (MediaQuery.of(context).size.width - 40) / 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/device_list');
                        },
                        icon: const Icon(Icons.devices_outlined),
                        label: const Text('Danh sách thiết bị'),
                      ),
                    ),
                    SizedBox(
                      width: (MediaQuery.of(context).size.width - 40) / 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/add_device');
                        },
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Thêm thiết bị'),
                      ),
                    ),
                    SizedBox(
                      width: (MediaQuery.of(context).size.width - 40) / 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/manage_device');
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('Quản lý thiết bị'),
                      ),
                    ),
                    SizedBox(
                      width: (MediaQuery.of(context).size.width - 40) / 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/wifi_setup');
                        },
                        icon: const Icon(Icons.wifi_protected_setup),
                        label: const Text('Cài đặt WiFi thiết bị'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
