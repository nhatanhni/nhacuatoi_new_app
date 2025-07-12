import 'package:flutter/material.dart';
import 'package:iot_app/widgets/appbar_dropdown_widget.dart';
import 'package:iot_app/widgets/drawer_widget.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:iot_app/database/database_helper.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/screens/device_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iot_app/main.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';

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
  }

  Future<void> _selectNotification(String? payload) async {
    if (payload != null) {
      try {
        // Parse payload để lấy thông tin
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final deviceSerial = data['deviceSerial'];
        final alert = data['alert'] ?? 'Cảnh báo';
        
        // Lưu trạng thái thông báo với format đúng
        await _saveNotificationState(payload);

        // Print the serial to the console
        print('Serial from notification: $deviceSerial');

        // Hiển thị notification toast
        Fluttertoast.showToast(
          msg: "Thông báo mới: $alert - Thiết bị: $deviceSerial",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );

        // Navigate to DeviceDetailScreen with the deviceSerial from the notification payload
        final device = await DatabaseHelper.instance.queryDeviceBySerial(deviceSerial);

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
          print('Device not found for serial: $deviceSerial');
          Fluttertoast.showToast(
            msg: "Không tìm thấy thiết bị: $deviceSerial",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } catch (e) {
        print('Error processing notification payload: $e');
        // Nếu payload không phải JSON, xử lý như string đơn giản
        await _saveNotificationState(payload);
        
        final device = await DatabaseHelper.instance.queryDeviceBySerial(payload);
        if (device != null) {
          Navigator.of(MyApp.navigatorKey.currentContext!).push(
            MaterialPageRoute(
              builder: (context) => DeviceDetailScreen(device: device),
            ),
          );
        }
      }
    }
  }

  Future<void> _checkNotificationState() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationPayload = prefs.getString('notification_payload');

    if (notificationPayload != null) {
      try {
        // Parse payload để lấy thông tin notification
        final data = jsonDecode(notificationPayload) as Map<String, dynamic>;
        final deviceSerial = data['deviceSerial'];
        final alert = data['alert'] ?? 'Cảnh báo';
        final message = data['message'] ?? '';
        
        // Hiển thị notification toast để người dùng biết
        Fluttertoast.showToast(
          msg: "Thông báo mới: $alert - Thiết bị: $deviceSerial",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        
        // Điều hướng đến màn hình chi tiết thiết bị với payload đã lưu
        final device = await DatabaseHelper.instance.queryDeviceBySerial(deviceSerial);
        if (device != null) {
          Navigator.of(MyApp.navigatorKey.currentContext!).push(
            MaterialPageRoute(
              builder: (context) => DeviceDetailScreen(device: device),
            ),
          );
        } else {
          // Nếu không tìm thấy thiết bị, hiển thị thông báo
          Fluttertoast.showToast(
            msg: "Không tìm thấy thiết bị: $deviceSerial",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }

        // Xóa trạng thái thông báo sau khi xử lý
        await prefs.remove('notification_payload');
      } catch (e) {
        print('Error processing notification payload: $e');
        // Xóa payload lỗi
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
    final padding = MediaQuery.of(context).padding;
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Nhà Của Tôi'),
        actions: const <Widget>[
          AppBarDropdown(),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        // iconTheme: IconThemeData(color: Colors.black),
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: EdgeInsets.only(
          top: padding.top + 8,
          left: 0,
          right: 0,
          bottom: padding.bottom,
        ),
        child: Center(
          child: Column(
            children: <Widget>[
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
            ],
          ),
        ),
      ),
    );
  }
}
