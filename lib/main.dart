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
import 'package:iot_app/screens/splash_screen.dart';
import 'package:iot_app/models/device.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:iot_app/screens/register_screen.dart';
import 'package:workmanager/workmanager.dart';
import 'package:iot_app/screens/pump_station_screen.dart';
import 'package:iot_app/screens/wifi_setup_screen.dart';
import 'package:iot_app/widgets/drawer_widget.dart';

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
        '/': (context) => const SplashScreen(),
        '/register': (context) => RegisterScreen(),
        '/login': (context) => LoginScreen(),
        '/add_device': (context) => AddDeviceScreen(),
        '/manage_device': (context) => ManageDeviceScreen(),
        '/device_list': (context) => DeviceListScreen(),
        '/user_list': (context) => UserListScreen(),
        '/home': (context) => const MainShell(),
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

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _activeColor = Color(0xFF403AB7);
  static const _inactiveColor = Color(0xFFD2E0EE);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late int _index = widget.initialIndex;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      HomeScreen(rootScaffoldKey: _scaffoldKey),
      DeviceListScreen(rootScaffoldKey: _scaffoldKey),
      const ManageDeviceScreen(),
      const UserListScreen(),
    ];
  }

  void _onTap(int nextIndex) {
    if (nextIndex == _index) return;
    setState(() => _index = nextIndex);
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = active ? _activeColor : _inactiveColor;

    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 14 / 10,
                  letterSpacing: -0.0305,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: const AppDrawer(),
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        height: 56,
        width: 56,
        child: FloatingActionButton(
          elevation: 6,
          backgroundColor: _activeColor,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          onPressed: () => Navigator.of(context).pushNamed('/add_device'),
          child: const Icon(Icons.add, size: 24),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 101,
        color: Colors.white,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            _navItem(
              icon: Icons.home_rounded,
              label: 'Home',
              active: _index == 0,
              onTap: () => _onTap(0),
            ),
            _navItem(
              icon: Icons.schedule_rounded,
              label: 'Schedule',
              active: _index == 1,
              onTap: () => _onTap(1),
            ),
            const SizedBox(width: 75),
            _navItem(
              icon: Icons.description_rounded,
              label: 'Scripts',
              active: _index == 2,
              onTap: () => _onTap(2),
            ),
            _navItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              active: _index == 3,
              onTap: () => _onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}
