// ignore_for_file: unused_element
import 'package:flutter/material.dart';
import '../widgets/drawer_widget.dart';
import 'package:iot_app/core/widgets/top_bar.dart';
import 'package:iot_app/core/services/database_helper.dart'
    if (dart.library.html) 'package:iot_app/core/services/web_database_helper.dart';
import '../core/state/selected_device_provider.dart';
import 'package:iot_app/screens/device_list/device_detail/device_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final GlobalKey<ScaffoldState>? rootScaffoldKey;

  const HomeScreen({Key? key, this.rootScaffoldKey}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _checkNotificationState();
    // MQTT is now managed globally via MqttBloc in main.dart
    // No need to initialize MQTT here
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
        print(
          'Navigating to DeviceDetailScreen with device: ${device.deviceSerial}',
        );
        setSelectedDevice(context, device);
        Navigator.of(context).pushNamed(DeviceDetailScreen.routeName);

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
      final device = await DatabaseHelper.instance.queryDeviceBySerial(
        notificationPayload,
      );
      if (device != null) {
        setSelectedDevice(context, device);
        Navigator.of(context).pushNamed(DeviceDetailScreen.routeName);

        // Xóa trạng thái thông báo sau khi xử lý
        await prefs.remove('notification_payload');
      }
    }
  }

  Future<void> _saveNotificationState(String payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_payload', payload);
  }

  @override
  Widget build(BuildContext context) {
    final drawerKey = widget.rootScaffoldKey ?? _scaffoldKey;

    return Scaffold(
      key: _scaffoldKey,
      appBar: FigmaTopBar(scaffoldKey: drawerKey),
      drawer: widget.rootScaffoldKey == null ? const AppDrawer() : null,
      body: OrientationBuilder(
        builder: (context, orientation) {
          return LayoutBuilder(
            builder: (context, constraints) {
              if (orientation == Orientation.landscape) {
                return _buildLandscapeBody(context, constraints);
              }

              return _buildPortraitBody(context);
            },
          );
        },
      ),
    );
  }

  Widget _buildPortraitBody(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroBanner(context),
          _buildQuickActions(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLandscapeBody(BuildContext context, BoxConstraints constraints) {
    final horizontalPadding = constraints.maxWidth >= 1200 ? 24.0 : 16.0;
    final actionColumns = constraints.maxWidth >= 1500 ? 3 : 2;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        16,
        horizontalPadding,
        16,
      ),
      child: SingleChildScrollView(
        child: _buildQuickActions(
          context,
          padding: EdgeInsets.zero,
          crossAxisCount: actionColumns,
          childAspectRatio: actionColumns == 3 ? 1.6 : 1.75,
          itemHeight: MediaQuery.of(context).size.height / 3,
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.asset(
            'assets/images/home-1.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        // Gradient overlay from transparent to dark
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.65),
                ],
                stops: const [0.4, 1.0],
              ),
            ),
          ),
        ),
        // Welcome text pinned to bottom-left
        Positioned(
          bottom: 5,
          left: 20,
          right: 20,
          child: _buildHeroText(context),
        ),
      ],
    );
  }

  Widget _buildHeroText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Xin chào!',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Data Monitoring Platform',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quản lý thiết bị thông minh của bạn',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildQuickActions(
    BuildContext context, {
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 20, 16, 0),
    int crossAxisCount = 2,
    double childAspectRatio = 1.6,
    double? itemHeight,
  }) {
    const actions = [
      _QuickAction(
        icon: Icons.devices_outlined,
        label: 'Danh sách thiết bị',
        subtitle: 'Xem tất cả thiết bị',
        color: Color(0xFF1976D2),
        route: '/device_list',
      ),
      _QuickAction(
        icon: Icons.add_circle_outline,
        label: 'Thêm thiết bị',
        subtitle: 'Kết nối thiết bị mới',
        color: Color(0xFF388E3C),
        route: '/add_device',
      ),
      _QuickAction(
        icon: Icons.settings_outlined,
        label: 'Quản lý thiết bị',
        subtitle: 'Cấu hình & chỉnh sửa',
        color: Color(0xFFF57C00),
        route: '/manage_device',
      ),
      _QuickAction(
        icon: Icons.wifi_outlined,
        label: 'Cài đặt WiFi',
        subtitle: 'Thiết lập kết nối WiFi',
        color: Color(0xFF7B1FA2),
        route: '/wifi_setup',
      ),
    ];

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with accent bar
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Chức năng nhanh',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, gridConstraints) {
              const spacing = 10.0;
              final itemWidth =
                  (gridConstraints.maxWidth - (crossAxisCount - 1) * spacing) /
                  crossAxisCount;
              final effectiveAspectRatio =
                  itemHeight != null ? itemWidth / itemHeight : childAspectRatio;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: effectiveAspectRatio,
                children: actions
                    .map((action) => _buildActionCard(context, action))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, _QuickAction action) {
    return Card(
      elevation: 1.5,
      shadowColor: action.color.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pushNamed(context, action.route),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon with tinted background
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(action.icon, color: action.color, size: 20),
              ),
              // Label + subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String route;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.route,
  });
}
