import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot_app/bloc/auth/auth_bloc.dart';
import 'package:iot_app/bloc/auth/auth_event.dart';
import 'package:iot_app/bloc/device/device_bloc.dart';
import 'package:iot_app/bloc/device/device_event.dart';
import 'package:iot_app/bloc/station/station_bloc.dart';
import 'package:iot_app/bloc/station/station_event.dart';
import 'package:iot_app/bloc/mqtt/mqtt_bloc.dart';
import 'package:iot_app/bloc/mqtt/mqtt_event.dart';
import 'package:iot_app/repository/mqtt_manager.dart';
import 'package:iot_app/repository/api_service.dart';
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
import 'package:workmanager/workmanager.dart';
import 'package:iot_app/screens/pump_station_screen.dart';
import 'package:iot_app/screens/wifi_setup_screen.dart';

import 'database/database_helper.dart';
import 'widgets/notification_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('Background task executed: $task');
    
    final mqttManager = MQTTManager.instance;
    await mqttManager.connect();
    
    await Future.delayed(Duration(seconds: 5));
    
    return Future.value(true);
  });
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
        frequency: Duration(minutes: 15),
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

  runApp(const MyApp(initialRoute: '/'));
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

  // Create shared instances once — NOT inside build() to avoid recreating on every rebuild
  static final _apiService = ApiService();
  static final _userRepository = UserRepository();
  static final _mqttManager = MQTTManager.instance;
  static final _notificationService = NotificationService();

  final String initialRoute;
  final Device? device;

  const MyApp({super.key, this.initialRoute = '/', this.device});

  @override
  Widget build(BuildContext context) {
    final databaseHelper = DatabaseHelper.instance;

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(
            apiService: _apiService,
            userRepository: _userRepository,
          )..add(AuthCheckRequested()),
        ),
        BlocProvider<DeviceBloc>(
          create: (_) => DeviceBloc(
            databaseHelper: databaseHelper,
            apiService: _apiService,
          )..add(DeviceLoadAll())
        ),
        BlocProvider<StationBloc>(
          create: (_) => StationBloc(
            apiService: _apiService,
          )..add(StationLoadAll()),
        ),
        BlocProvider<MqttBloc>(
          create: (_) => MqttBloc(
            mqttManager: _mqttManager,
            notificationService: _notificationService,
          )..add(MqttConnectRequested()),
        ),
      ],
      child: _AppView(
        initialRoute: initialRoute,
        device: device,
      ),
    );
  }
}

class _AppView extends StatefulWidget {
  final String initialRoute;
  final Device? device;

  const _AppView({required this.initialRoute, this.device});

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  @override
  void initState() {
    super.initState();
    _subscribeToAlarms();
  }

  void _subscribeToAlarms() async {
    final devices = await DatabaseHelper.instance.queryAllDevices();
    final serials = devices.map((d) => d.deviceSerial).toList();
    if (serials.isNotEmpty && mounted) {
      context.read<MqttBloc>().add(MqttSubscribeAlarms(serials));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: MyApp.navigatorKey,
      title: 'Nhà của tôi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            systemStatusBarContrastEnforced: false,
            statusBarColor: null,
            systemNavigationBarColor: null,
            systemNavigationBarDividerColor: null,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
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
        '/wifi_setup': (context) => WiFiSetupScreen(),
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
}
