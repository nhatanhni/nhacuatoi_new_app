import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iot_app/core/services/mqtt_manager.dart';
import 'package:iot_app/core/services/user_repository.dart';
import 'package:iot_app/screens/user_list/user_list_screen.dart';
import 'package:iot_app/screens/device_list/device_list_screen.dart';
import 'package:iot_app/screens/device_list/device_detail/device_scheduling/device_scheduling_screen.dart';
import 'package:iot_app/screens/home/home_screen.dart';
import 'package:iot_app/screens/device_list/add_device/add_device_screen.dart';
import 'package:iot_app/screens/login/login_screen.dart';
import 'package:iot_app/screens/device_list/manage_device/manage_device_screen.dart';
import 'package:iot_app/screens/device_list/device_detail/device_detail_screen.dart';
import 'package:iot_app/core/models/device.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:iot_app/screens/forgot_password/forgot_password_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:iot_app/screens/pump_station/pump_station_screen.dart';
import 'package:iot_app/screens/splash/splash_screen.dart';
import 'package:iot_app/core/theme/app_colors.dart';
import 'package:iot_app/core/theme/app_styles.dart';

import 'package:iot_app/core/services/database_helper.dart';
import 'package:iot_app/core/widgets/notification_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('Background task executed: $task');

    final mqttManager = MQTTManager();
    await mqttManager.connect();

    await Future.delayed(Duration(seconds: 5));

    return Future.value(true);
  });
}

void _showNotification(
  String message,
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
) async {
  final notificationService = NotificationService();
  await notificationService.showNotification('Thông báo', message);
}

Future<void> _selectNotification(String? payload) async {
  print('Payload from notification: $payload');

  if (payload != null) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final deviceSerial = data['deviceSerial'];

      if (deviceSerial != null) {
        final device = await DatabaseHelper.instance.queryDeviceBySerial(
          deviceSerial,
        );

        if (device != null) {
          print(
            'Navigating to DeviceDetailScreen with device: ${device.deviceSerial}',
          );
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

  if (!kIsWeb) {
    await dotenv.load();
  }

  if (!kIsWeb && Platform.isAndroid) {
    await AndroidAlarmManager.initialize();
  }

  if (!kIsWeb) {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

    try {
      await Workmanager().registerPeriodicTask(
        "1",
        "simpleTask",
        frequency: const Duration(minutes: 15),
      );
    } catch (e) {
      print('Error registering Workmanager task: $e');
    }
  }

  if (!kIsWeb && Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarDividerColor: null,
      ),
    );
  }

  final userRepository = UserRepository();
  final isLoggedIn = await userRepository.getLoginStatus();

  runApp(MyApp(
    initialRoute: '/',
    nextRoute: isLoggedIn ? '/home' : '/login',
  ));
}

class MyApp extends StatefulWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  final String initialRoute;
  final String nextRoute;
  final Device? device;

  const MyApp({
    super.key,
    this.initialRoute = '/',
    this.nextRoute = '/login',
    this.device,
  });

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
    print('NotificationService initialized');
  }

  void _initializeMQTT() async {
    mqttManager = MQTTManager();
    await mqttManager.connect();

    List<Device> devices = await DatabaseHelper.instance.queryAllDevices();
    List<String> deviceSerials = devices
        .map((device) => device.deviceSerial)
        .toList();
    for (String serial in deviceSerials) {
      String topic = "NhaCuaToi_${serial}_alarm";
      mqttManager.subscribe(topic);
    }

    mqttManager.messageStream.listen((mqttMessage) {
      final MqttPublishMessage recMess =
          mqttMessage.payload as MqttPublishMessage;
      final String message = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );
      print("Received message: $message on topic: ${mqttMessage.topic}");

      if (mqttMessage.topic.contains('_alarm') &&
          deviceSerials.any((serial) => mqttMessage.topic.contains(serial))) {
        try {
          final alarmData = jsonDecode(message) as Map<String, dynamic>;
          final alert = alarmData["alert"];
          final deviceSerial = alarmData["serial"] ?? alarmData["id"];

          if (alert != null && deviceSerial != null) {
            print(
              "Sending notification for device: $deviceSerial with alert: $alert",
            );
            _notificationService.showNotification('Thông báo', message);
          } else {
            print(
              "Skipped notification for device: $deviceSerial due to missing alert or deviceSerial",
            );
          }
        } catch (e) {
          print("Error processing alarm message: $e");
        }
      } else {
        print(
          "Message topic does not contain '_alarm' or does not match any device serials",
        );
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
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                primary: AppColors.primary,
                background: AppColors.backgroundLight,
              ),
              useMaterial3: true,
              fontFamily: 'Roboto',
              appBarTheme: const AppBarTheme(
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarIconBrightness: Brightness.dark,
                  systemStatusBarContrastEnforced: false,
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarDividerColor: Colors.transparent,
                ),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textWhite,
                elevation: 0,
                centerTitle: true,
              ),
              scaffoldBackgroundColor: AppColors.backgroundLight,
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                  ),
                ),
              ),
            ),
            initialRoute: widget.initialRoute,
            routes: {
              '/': (context) => SplashScreen(nextRoute: widget.nextRoute),
              '/home': (context) => HomeScreen(),
              '/forgot_password': (context) => const ForgotPasswordScreen(),
              '/login': (context) => LoginScreen(),
              '/add_device': (context) => AddDeviceScreen(),
              '/manage_device': (context) => ManageDeviceScreen(),
              '/device_list': (context) => DeviceListScreen(),
              '/user_list': (context) => UserListScreen(),
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
              } else if (settings.name == '/pump_station') {
                final device = settings.arguments as Device;
                return MaterialPageRoute(
                  builder: (context) {
                    return PumpStationScreen(device: device);
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
