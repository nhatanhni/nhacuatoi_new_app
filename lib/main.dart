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
import 'package:iot_app/screens/iot_setup_screen.dart';
import 'package:iot_app/screens/violation_statistics_screen.dart';

import 'database/database_helper.dart';
import 'widgets/notification_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('Background task executed: $task');
    
    // Initialize MQTT manager for background tasks
    final mqttManager = MQTTManager();
    await mqttManager.connect();
    
    // Process any pending notifications or tasks
    await Future.delayed(Duration(seconds: 5));
    
    return Future.value(true);
  });
}

void _showNotification(String message, FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
  final notificationService = NotificationService();
  await notificationService.showWaterAlarmNotification(message);
}

Future<void> _selectNotification(String? payload) async {
  print('Payload from notification: $payload');

  if (payload != null) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final deviceSerial = data['deviceSerial'];
      
      if (deviceSerial != null) {
        final device = await DatabaseHelper.instance.queryDeviceBySerial(deviceSerial);

        if (device != null) {
          print('Navigating to DeviceDetailScreen with device: ${device.deviceSerial}');
          Navigator.of(MyApp.navigatorKey.currentContext!).push(
            MaterialPageRoute(
              builder: (context) => DeviceDetailScreen(device: device),
            ),
          );
        } else {
          print('Device not found for serial: $deviceSerial');
        }
      }
    } catch (e) {
      print('Error processing notification payload: $e');
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

  // Enable edge-to-edge display for Android 15 compatibility
  if (Platform.isAndroid) {
    // Use new API for Android 15 - avoid deprecated setStatusBarColor, etc.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    
    // Set system UI overlay style with new properties for Android 15
    // Completely avoid deprecated properties: statusBarColor, systemNavigationBarColor, systemNavigationBarDividerColor
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        // Only use non-deprecated properties for Android 15
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
        // Android 15 specific properties - avoid deprecated color properties
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
        // Use new properties for edge-to-edge
        systemNavigationBarDividerColor: null, // Explicitly set to null to avoid deprecated API
      ),
    );
  }

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
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loginStatus = _userRepository.getLoginStatus();
    _initializeNotificationService();
    _initializeMQTT();
  }

  void _initializeNotificationService() async {
    // Khởi tạo NotificationService với navigator key
    await _notificationService.initialize(navigatorKey: MyApp.navigatorKey);
    
    // Yêu cầu quyền notification
    await _notificationService.requestPermissions();
    
    // Kiểm tra pending notifications
    await _notificationService.checkPendingNotifications();
  }

  void _initializeMQTT() async {
    mqttManager = MQTTManager();
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
        try {
          final alarmData = jsonDecode(message) as Map<String, dynamic>;
          final alert = alarmData["alert"];
          final deviceSerial = alarmData["serial"] ?? alarmData["id"];

          // Kiểm tra nếu thông báo là cần thiết và có dữ liệu hợp lệ
          if (alert != null && deviceSerial != null) {
            print("Sending notification for device: $deviceSerial with alert: $alert");
            _notificationService.showWaterAlarmNotification(message);
          } else {
            print("Skipped notification for device: $deviceSerial due to missing alert or deviceSerial");
          }
        } catch (e) {
          print("Error processing alarm message: $e");
        }
      } else {
        print("Message topic does not contain '_alarm' or does not match any device serials");
      }
    });
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
              // Enable edge-to-edge display support for Android 15
              appBarTheme: const AppBarTheme(
                systemOverlayStyle: SystemUiOverlayStyle(
                  // Completely avoid deprecated statusBarColor property
                  statusBarIconBrightness: Brightness.dark,
                  // Android 15 specific properties
                  systemStatusBarContrastEnforced: false,
                  // Explicitly avoid deprecated properties
                  statusBarColor: null,
                  systemNavigationBarColor: null,
                  systemNavigationBarDividerColor: null,
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              // Ensure proper edge-to-edge support
              scaffoldBackgroundColor: Colors.white,
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
              '/home': (context) => HomeScreen(),
              '/iot_setup': (context) => IoTSetupScreen()
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
