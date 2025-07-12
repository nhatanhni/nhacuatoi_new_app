import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iot_app/repository/mqtt_manager.dart';
import 'package:iot_app/repository/user_repository.dart';
import 'package:iot_app/screens/UserListScreen.dart';
import 'package:iot_app/screens/device_list_screen.dart';
import 'package:iot_app/screens/device_scheduling_screen.dart';
import 'package:iot_app/screens/home_screen.dart';
import 'package:iot_app/screens/add_device_screen.dart';
import 'package:iot_app/screens/login_screen.dart';
import 'package:iot_app/screens/manage_device_screen.dart';
import 'package:iot_app/screens/device_detail_screen.dart';
import 'package:iot_app/models/device.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:iot_app/screens/register_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'database/database_helper.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    final MQTTManager mqttManager = MQTTManager('nhacuatoi.com.vn', 'flutter_client');
    await mqttManager.connect();

    List<Device> devices = await DatabaseHelper.instance.queryAllDevices();
    List<String> deviceSerials = devices.map((device) => device.deviceSerial).toList();
    for (String serial in deviceSerials) {
      String topic = "NhaCuaToi_${serial}_alarm";
      mqttManager.subscribe(topic);
    }

    mqttManager.messageStream.listen((mqttMessage) {
      final MqttPublishMessage recMess = mqttMessage.payload as MqttPublishMessage;
      final String message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print("Received message: $message on topic: ${mqttMessage.topic}");

      // Điều kiện để kiểm tra và gửi thông báo
      if (mqttMessage.topic.contains('_alarm') && deviceSerials.any((serial) => mqttMessage.topic.contains(serial))) {
        final alarmData = jsonDecode(message) as Map<String, dynamic>;
        final alert = alarmData["alert"];
        final deviceSerial = alarmData["id"];

        // Kiểm tra nếu thông báo là cần thiết và có dữ liệu hợp lệ
        if (alert != null && deviceSerial != null) {
          print("Sending notification for device: $deviceSerial with alert: $alert");
          _showNotification(message, flutterLocalNotificationsPlugin);
        } else {
          print("Skipped notification for device: $deviceSerial due to missing alert or deviceSerial");
        }
      } else {
        print("Message topic does not contain '_alarm' or does not match any device serials");
      }
    });

    return Future.value(true);
  });
}

void _showNotification(String message, FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'water_supply_channel',
    'Water Supply Notifications',
    channelDescription: 'Notifications for water supply status',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: false,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

  final alarmData = jsonDecode(message) as Map<String, dynamic>;

  final alert = alarmData["alert"];
  final deviceSerial = alarmData["id"];

  await flutterLocalNotificationsPlugin.show(
    0,
    alert,
    message,
    platformChannelSpecifics,
    payload: deviceSerial,
  );
}

Future<void> _selectNotification(String? payload) async {
  print('Payload from notification: $payload');

  if (payload != null) {
    await _saveNotificationState(payload);
    print('Serial from notification: $payload');

    final device = await DatabaseHelper.instance.queryDeviceBySerial(payload);

    if (device != null) {
      print('Navigating to DeviceDetailScreen with device: ${device.deviceSerial}');
      Navigator.of(MyApp.navigatorKey.currentContext!).push(
        MaterialPageRoute(
          builder: (context) => DeviceDetailScreen(device: device),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notification_payload');
    } else {
      print('Device not found for serial: $payload');
    }
  }
}

Future<void> _saveNotificationState(String payload) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('notification_payload', payload);
}

Future<String?> _getNotificationState() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('notification_payload');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  if (Platform.isAndroid) {
    await AndroidAlarmManager.initialize();
  }

  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  try {
    await Workmanager().registerPeriodicTask(
      "1",
      "simpleTask",
      frequency: Duration(minutes: 15),
    );
  } catch (e) {
    print('Error registering Workmanager task: $e');
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

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

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String accessToken = prefs.getString('accessToken') ?? '';

  runApp(MyApp(initialRoute: accessToken.isEmpty ? '/login' : '/'));
}

class MyApp extends StatefulWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

  final String initialRoute;
  final Device? device;

  const MyApp({super.key, this.initialRoute = '/', this.device});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _userRepository = UserRepository();
  late Future<bool> _loginStatus;
  late MQTTManager mqttManager;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loginStatus = _userRepository.getLoginStatus();
    _initializeMQTT();
    _initializeNotifications();
  }

  void _initializeMQTT() async {
    mqttManager = MQTTManager('nhacuatoi.com.vn', 'flutter_client');
    await mqttManager.connect();

    List<Device> devices = await DatabaseHelper.instance.queryAllDevices();
    List<String> deviceSerials = devices.map((device) => device.deviceSerial).toList();
    for (String serial in deviceSerials) {
      String topic = "NhaCuaToi_${serial}_alarm";
      mqttManager.subscribe(topic);
    }

    mqttManager.messageStream.listen((mqttMessage) {
      final MqttPublishMessage recMess = mqttMessage.payload as MqttPublishMessage;
      final String message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print("Received message: $message on topic: ${mqttMessage.topic}");

      // Điều kiện để kiểm tra và gửi thông báo
      if (mqttMessage.topic.contains('_alarm') && deviceSerials.any((serial) => mqttMessage.topic.contains(serial))) {
        final alarmData = jsonDecode(message) as Map<String, dynamic>;
        final alert = alarmData["alert"];
        final deviceSerial = alarmData["id"];

        // Kiểm tra nếu thông báo là cần thiết và có dữ liệu hợp lệ
        if (alert != null && deviceSerial != null) {
          print("Sending notification for device: $deviceSerial with alert: $alert");
          _showNotification(message, flutterLocalNotificationsPlugin);
        } else {
          print("Skipped notification for device: $deviceSerial due to missing alert or deviceSerial");
        }
      } else {
        print("Message topic does not contain '_alarm' or does not match any device serials");
      }
    });
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _selectNotification(response.payload);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loginStatus,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else {
          return MaterialApp(
            navigatorKey: MyApp.navigatorKey,
            title: 'Nhà của tôi',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
              useMaterial3: true,
            ),
            initialRoute: widget.initialRoute,
            routes: {
              '/': (context) => HomeScreen(),
              '/register': (context) => RegisterScreen(),
              '/login': (context) => LoginScreen(),
              '/add_device': (context) => AddDeviceScreen(),
              '/manage_device': (context) => ManageDeviceScreen(),
              '/device_list': (context) => DeviceListScreen(),
              '/user_list': (context) => UserListScreen(),
              '/home': (context) => HomeScreen()
            },
            navigatorObservers: [MyApp.routeObserver],
            onGenerateRoute: (settings) {
              if (settings.name == DeviceDetailScreen.routeName) {
                final device = settings.arguments as Device? ?? widget.device;
                return MaterialPageRoute(
                  builder: (context) {
                    return DeviceDetailScreen(device: device!);
                  },
                );
              } else if (settings.name == DeviceSchedulingScreen.routeName) {
                final device = settings.arguments as Device;
                return MaterialPageRoute(
                  builder: (context) {
                    return DeviceSchedulingScreen(device: device);
                  },
                );
              }
              assert(false, 'Need to implement ${settings.name}');
              return null;
            },
          );
        }
      },
    );
  }
}
