import 'package:flutter/material.dart';
import 'package:iot_app/core/models/device.dart';
import 'package:iot_app/core/services/database_helper.dart'
    if (dart.library.html) 'package:iot_app/core/services/web_database_helper.dart';
import 'package:iot_app/core/services/mqtt_manager.dart';
import 'package:iot_app/core/theme/app_colors.dart';
import 'package:iot_app/screens/device_list/device_detail/device_detail_screen.dart';
import 'package:iot_app/screens/device_list/device_list_screen.dart';
import 'package:iot_app/screens/dashboard/dashboard_screen.dart';
import 'package:iot_app/screens/map/map_screen.dart';
import 'package:iot_app/screens/chart/chart_screen.dart';
import 'package:iot_app/screens/warning/warning_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Giữ lại logic khởi tạo thông báo và MQTT quan trọng
    _checkNotificationState();
    _initializeMQTT();
  }

  Future<void> _checkNotificationState() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationPayload = prefs.getString('notification_payload');

    if (notificationPayload != null && mounted) {
      final device = await DatabaseHelper.instance.queryDeviceBySerial(
        notificationPayload,
      );
      if (device != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DeviceDetailScreen(device: device),
          ),
        );
        await prefs.remove('notification_payload');
      }
    }
  }

  void _initializeMQTT() async {
    final mqttManager = MQTTManager();
    await mqttManager.connect();

    List<Device> devices = await DatabaseHelper.instance.queryAllDevices();
    for (var device in devices) {
      mqttManager.subscribe("NhaCuaToi_${device.deviceSerial}_alarm");
    }
  }

  late final List<Widget> _pages = [
    const DashboardScreen(),
    const DeviceListScreen(), // Tận dụng màn hình Danh sách thiết bị đã có sẵn
    const MapScreen(),
    const ChartScreen(),
    const WarningScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dùng IndexedStack để giữ lại state của các tab khi chuyển qua lại
      // Rất quan trọng đối với màn hình DeviceListScreen (có MQTT state)
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey[500],
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.devices_rounded),
            label: 'Thiết bị',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_rounded),
            label: 'Bản đồ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Biểu đồ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_rounded),
            label: 'Cảnh báo',
          ),
        ],
      ),
    );
  }
}
