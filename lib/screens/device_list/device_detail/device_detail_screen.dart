// ignore_for_file: unused_element, unused_field
import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:iot_app/bloc/device/device_bloc.dart';
import 'package:iot_app/bloc/device/device_event.dart';
import 'package:iot_app/bloc/device/device_state.dart';
import 'package:iot_app/core/models/device.dart';
import 'package:iot_app/core/models/device_detail.dart';
import 'package:iot_app/core/models/switch_event.dart';
import 'package:iot_app/core/services/database_helper.dart'
    if (dart.library.html) 'package:iot_app/core/services/web_database_helper.dart';
import 'package:iot_app/core/services/mqtt_manager.dart';
import 'package:iot_app/core/widgets/device_alarm_widget.dart';
import 'package:iot_app/core/widgets/device_sensor_reading_widget.dart';
import 'package:iot_app/core/widgets/device_detail_button_widget.dart';
import 'package:iot_app/core/widgets/device_socket_metrics_tab.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:iot_app/main.dart';
import 'package:iot_app/core/utils/socket_metrics_parser.dart';
import 'package:iot_app/core/state/selected_device_provider.dart';
import 'package:iot_app/widgets/drawer_widget.dart';


class DeviceDetailScreen extends StatefulWidget {
  static const routeName = '/device_detail';

  final Device device;

  DeviceDetailScreen({required this.device});

  @override
  _DeviceDetailScreenState createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen>
    with SingleTickerProviderStateMixin {
  late MQTTManager mqttManager;
  late TabController _tabController;
  bool _isSwitched = false;
  bool _hasSubscribedTopics = false;
  StreamSubscription<String>? _temperatureSubscription;
  StreamSubscription<String>? _switchStatusSubscription;
  StreamSubscription<String>? _socketMetricsSubscription;
  final List<SwitchEvent> _switchEvents = [];
  double _currentSoilMoisture = 0.0;
  double _currentTemperature = 0.0;
  Map<String, dynamic>? _socketMetricsData;
  String? _socketRawJson;
  String? _socketError;
  DateTime? _socketLastUpdated;

  Map<String, dynamic>? _waterMeterData;
  bool _isLoadingWater = false;
  String? _waterError;
  bool _isLoadingDetail = true;
  String? _detailError;
  DeviceDetail? _deviceDetail;

  int? get _deviceLocalId =>
      widget.device.id is int ? widget.device.id as int : null;

  String? get _historyDeviceId => widget.device.id?.toString();

  String? get _socketMetricsTopic {
    final topic = widget.device.mqTopic?.trim();
    if (topic == null || topic.isEmpty) {
      return null;
    }
    return topic;
  }

  void _showMissingDeviceIdMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thiết bị này chưa có ID, không thể tải lịch sử.'),
      ),
    );
  }

  // method to save switch history to server
  Future<void> _saveSwitchDeviceHistory(int status) async {
    try {
      final deviceId = _historyDeviceId;
      print("deviceId for history: $deviceId");
      if (deviceId == null) {
        _showMissingDeviceIdMessage();
        return;
      }

      final completer = Completer<void>();
      context.read<DeviceBloc>().add(
        DeviceSwitchHistorySaved(
          deviceId: deviceId.toString(),
          isSwitched: status,
          completer: completer,
        ),
      );
      await completer.future;
      setState(() {
        _isSwitched = status == 1;
      });
    } catch (e) {
      print('Error saving switch history: $e');
    }
  }

  // method to query switch events by device id (from server)
  Future<void> _loadSwitchEvents([String? historyDeviceId]) async {
    try {
      final id = historyDeviceId ?? _historyDeviceId;
      if (id == null) {
        if (mounted) {
          setState(() {
            _switchEvents.clear();
          });
        }
        return;
      }

      final api = MyApp.apiService;
      final List<dynamic> data = await api.fetchDeviceHistoryByDeviceId(id);
      final events = data
          .map((e) => SwitchEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _switchEvents.clear();
        _switchEvents.addAll(events);
      });
    } catch (e) {
      print('Error loading switch events from server: $e');
    }
  }

  // method to clear all switch events
  void _clearSwitchEvents() async {
    try {
      final deviceId = _deviceLocalId;
      if (deviceId == null) {
        _showMissingDeviceIdMessage();
        return;
      }

      await DatabaseHelper.instance.deleteSwitchEvents(deviceId);
      _loadSwitchEvents();
    } catch (e) {
      print('Error clearing switch events: $e');
    }
  }

  Future<void>? _connectionFuture;

  bool get _isDeviceDisabled => _deviceDetail?.isDisabled == true;

  bool get _canControlDevice {
    if (_isDeviceDisabled) return false;
    final type = widget.device.deviceType.toLowerCase();
    return !(type.contains('sensor') ||
        type.contains('đồng hồ nước') ||
        type.contains('cảm biến mực nước'));
  }

  void _requestDeviceDetail() {
    final id = _historyDeviceId;
    if (id == null || id.isEmpty) {
      setState(() {
        _isLoadingDetail = false;
        _detailError = 'Thiết bị này chưa có ID để tải thông tin chi tiết.';
      });
      return;
    }

    context.read<DeviceBloc>().add(DeviceDetailRequested(id));
  }

  void _onDeviceStateChanged(DeviceState state) {
    if (!mounted) {
      return;
    }

    if (state is DeviceDetailLoading) {
      setState(() {
        _isLoadingDetail = true;
        _detailError = null;
      });
      return;
    }

    if (state is DeviceDetailLoaded) {
      setState(() {
        _isLoadingDetail = false;
        _detailError = null;
        _deviceDetail = state.detail;
      });
      return;
    }

    if (state is DeviceError && _isLoadingDetail) {
      setState(() {
        _isLoadingDetail = false;
        _detailError = state.message;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    setSelectedDevice(context, widget.device);
    _tabController = TabController(length: 3, vsync: this);
    // Use the singleton MQTT manager - no need to create new connections
    mqttManager = MQTTManager.instance;
    _connectionFuture = mqttManager.ensureConnected().then((_) {
      if (mounted) {
        _subscribeToTopics();
      }
    });

    _isSwitched = widget.device.deviceStatus == 1;
    _requestDeviceDetail();
    _loadSwitchEvents();

    if (widget.device.deviceType == 'Đồng hồ nước') {
      _fetchWaterMeterData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _temperatureSubscription?.cancel();
    _switchStatusSubscription?.cancel();
    _socketMetricsSubscription?.cancel();
    if (mqttManager.isConnected) {
      mqttManager.unsubscribe(
        'NhaCuaToi_${widget.device.deviceSerial}_nhietdo',
      );
      mqttManager.unsubscribe('NhaCuaToi_${widget.device.deviceSerial}_status');
      final socketTopic = _socketMetricsTopic;
      if (socketTopic != null) {
        mqttManager.unsubscribe(socketTopic);
      }
    }
    // Don't dispose the singleton MQTTManager
    super.dispose();
    print("did dispose of device detail screen");
  }

  void _subscribeToTopics() {
    if (_hasSubscribedTopics) {
      return;
    }

    if (mqttManager.isConnected) {
      _hasSubscribedTopics = true;
      // Subscribe to general sensor topics
      mqttManager.subscribe('NhaCuaToi_${widget.device.deviceSerial}_doam');
      mqttManager.subscribe('NhaCuaToi_${widget.device.deviceSerial}_nhietdo');
      mqttManager.subscribe('NhaCuaToi_${widget.device.deviceSerial}_status');
      final socketTopic = _socketMetricsTopic;
      if (socketTopic != null) {
        mqttManager.subscribe(socketTopic);
      }

      // Subscribe to water level sensor topic if this is a water level sensor
      if (widget.device.deviceType == 'Cảm biến mực nước') {
        mqttManager.subscribe(
          'NhaCuaToi_${widget.device.deviceSerial}_mucnuoc',
        );
        print(
          '📡 Subscribed to water level topic: NhaCuaToi_${widget.device.deviceSerial}_mucnuoc',
        );
      }

      // Listen for updates on the 'doam' topic
      // mqttManager.updates('NhaCuaToi_${widget.device.deviceSerial}_doam')?.listen((message) {
      //   String str = message.replaceAll(r'\', '');
      //   try {
      //     print('Received message: $str');
      //
      //     // Ensure message is a valid JSON string
      //     if (str is String) {
      //       // Remove all backslashes from the JSON string
      //
      //       print('Cleaned message: $str');
      //
      //       // Remove leading and trailing incorrect double-quotes if present
      //       if (str.startsWith('"') && str.endsWith('"')) {
      //         str = str.substring(1, str.length - 1);
      //       }
      //
      //       final decodedMessage = jsonDecode(str);
      //       print('Decoded message type: ${decodedMessage.runtimeType}');
      //       print('Decoded message: $decodedMessage');
      //
      //       if (decodedMessage is Map<String, dynamic>) {
      //         setState(() {
      //           _currentSoilMoisture = decodedMessage['value'];
      //         });
      //       } else {
      //         print('Decoded message is not a Map: $decodedMessage');
      //       }
      //     } else {
      //       print('Received message is not a valid JSON string.');
      //     }
      //   } catch (e) {
      //     print('Error decoding message: $e');
      //     print('Received message: $str');
      //   }
      // });

      // Listen for updates on the 'nhietdo' topic
      _temperatureSubscription?.cancel();
      _temperatureSubscription = mqttManager
          .updates('NhaCuaToi_${widget.device.deviceSerial}_nhietdo')
          .listen((message) {
            String str = message;
            try {
              print('Received message: $str');
              print('Cleaned message: $str');
              final decodedMessage = jsonDecode(str);
              print('Decoded message type: ${decodedMessage.runtimeType}');
              print('Decoded message: $decodedMessage');

              if (decodedMessage is Map<String, dynamic>) {
                setState(() {
                  //final alert = jsonDecode(decodedMessage['messages']) as Map<String, dynamic>;
                  //print(decodedMessage);
                  String temperature = decodedMessage['Temperature'];
                  String SoilMoisture = decodedMessage['Moisture'];
                  final double temperaturenew =
                      double.tryParse(temperature) ?? 0.0;
                  final double SoilMoisturenew =
                      double.tryParse(SoilMoisture) ?? 0.0;
                  _currentSoilMoisture = SoilMoisturenew;
                  _currentTemperature = temperaturenew;
                  //print('giá trị Temperature lấy được: $temperature');
                });
              } else {
                print('Decoded message is not a Map: $decodedMessage');
              }
            } catch (e) {
              print('Error decoding message: $e');
              print('Received message: $str');
            }
            // setState(() {
            //   _currentTemperature = 42.5;
            // });
          });

      _switchStatusSubscription?.cancel();
      _switchStatusSubscription = mqttManager
          .updates('NhaCuaToi_${widget.device.deviceSerial}_status')
          .listen(_onSwitchStatusMessage);

      _socketMetricsSubscription?.cancel();
      final socketTopicForStream = _socketMetricsTopic;
      if (socketTopicForStream != null) {
        _socketMetricsSubscription = mqttManager
        .updates(socketTopicForStream)
            .listen(_onSocketMetricsMessage);
      }
    } else {
      print('MQTT manager not connected');
    }
  }

  void _onSocketMetricsMessage(String message) {
    if (!mounted) {
      return;
    }

    final result = SocketMetricsParser.parse(message);
    setState(() {
      _socketMetricsData = result.data;
      _socketRawJson = result.prettyJson;
      _socketError = result.error;
      if (result.data != null) {
        _socketLastUpdated = DateTime.now();
      }
    });
  }

  Widget _buildSocketMetricsTab() {
    return DeviceSocketMetricsTab(
      topic: _socketMetricsTopic,
      metricsData: _socketMetricsData,
      rawJson: _socketRawJson,
      error: _socketError,
      lastUpdated: _socketLastUpdated,
    );
  }

  Color get _connectionColor {
    switch (widget.device.connectionStatus.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get _connectionLabel {
    switch (widget.device.connectionStatus.toLowerCase()) {
      case 'online':
        return 'Trực tuyến';
      case 'offline':
        return 'Ngoại tuyến';
      default:
        return 'Không rõ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.device.deviceName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _connectionColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.device.deviceType} · $_connectionLabel',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _isSwitched);
          },
        ),
      ),
      drawer: const AppDrawer(),
      body: BlocListener<DeviceBloc, DeviceState>(
        listener: (context, state) {
          _onDeviceStateChanged(state);
        },
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).primaryColor,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black87,
                tabs: const [
                  Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Thông tin'),
                  Tab(icon: Icon(Icons.tune, size: 18), text: 'Điều khiển'),
                  Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Thông số'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInfoTab(),
                  _buildControlTab(),
                  _buildSocketMetricsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSwitchStatusMessage(String message) {
    try {
      print('Received switch status message: $message');
      final bool? nextState = _parseSwitchState(message);
      if (nextState == null || !mounted || nextState == _isSwitched) {
        return;
      }

      setState(() {
        _isSwitched = nextState;
      });

      unawaited(_syncSwitchStateFromServer(nextState));
    } catch (e) {
      print('Error handling switch status message: $e');
    }
  }

  Future<void> _syncSwitchStateFromServer(bool nextState) async {
    await _saveSwitchDeviceHistory(nextState ? 1 : 0);

    if (!mounted) {
      return;
    }

    await _loadSwitchEvents();
  }

  bool? _parseSwitchState(String rawMessage) {
    final normalized = rawMessage.trim().toUpperCase();
    if (normalized == 'ON' || normalized == '1' || normalized == 'TRUE') {
      return true;
    }
    if (normalized == 'OFF' || normalized == '0' || normalized == 'FALSE') {
      return false;
    }

    final decoded = jsonDecode(rawMessage);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final dynamic serial = decoded['serial'];
    if (serial != null) {
      final value = serial.toString();
      final expected1 = widget.device.deviceSerial;
      final expected2 = 'NhaCuaToi_${widget.device.deviceSerial}';
      if (value != expected1 && value != expected2) {
        return null;
      }
    }

    final dynamic status =
        decoded['status'] ??
        decoded['state'] ??
        decoded['power'] ??
        decoded['value'];
    if (status is bool) {
      return status;
    }
    if (status is num) {
      return status == 1;
    }
    if (status is String) {
      final value = status.trim().toUpperCase();
      if (value == 'ON' || value == '1' || value == 'TRUE') {
        return true;
      }
      if (value == 'OFF' || value == '0' || value == 'FALSE') {
        return false;
      }
    }

    return null;
  }

  Future<void> _fetchWaterMeterData() async {
    setState(() {
      _isLoadingWater = true;
      _waterError = null;
    });
    try {
      final api = MyApp.apiService;
      final data = await api.fetchWaterMeterData(widget.device.deviceSerial);
      setState(() {
        _waterMeterData = data;
        _isLoadingWater = false;
      });
    } catch (e) {
      setState(() {
        _waterError = e.toString();
        _isLoadingWater = false;
      });
    }
  }

  Widget _buildInfoTab() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: _buildDetailSummary(),
        ),
        Expanded(child: _buildInfoContentByType()),
      ],
    );
  }

  Widget _buildDetailSummary() {
    if (_isLoadingDetail) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 18, width: 180, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 10),
            Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(height: 12, width: 240, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(height: 12, width: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
          ],
        ),
      );
    }

    if (_detailError != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _detailError!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      );
    }

    final detail = _deviceDetail;
    if (detail == null) {
      return const Text('Không có thông tin chi tiết thiết bị.');
    }

    final bool isDisabled = detail.isDisabled;
    // _isSwitched là nguồn sự thật: cập nhật từ manual toggle + MQTT status message
    // detail.startup chỉ là giá trị khởi tạo ban đầu từ API
    final bool isRunning = !isDisabled && _isSwitched;
    final Color statusColor = isDisabled
        ? Colors.grey
        : (isRunning ? Colors.green : Colors.orange);
    final String statusText = isDisabled
        ? 'Ngừng hoạt động'
        : (isRunning ? 'Đang chạy' : 'Đang tắt');
    final IconData statusIcon = isDisabled
        ? Icons.cancel_outlined
        : (isRunning ? Icons.check_circle_outline : Icons.pause_circle_outline);

    final heartbeatText = detail.lastHeartbeat == null
        ? 'Chưa có dữ liệu'
        : DateFormat('HH:mm · dd/MM/yyyy').format(
            detail.lastHeartbeat!.add(const Duration(hours: 7)),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                detail.name.isEmpty ? widget.device.deviceName : detail.name,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 13, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _infoRow(Icons.category_outlined, 'Loại', detail.deviceTypeName),
        _infoRow(Icons.qr_code, 'Serial', detail.serial),
        _infoRow(Icons.cell_tower, 'Trạm', detail.stationName),
        _infoRow(Icons.map_outlined, 'Khu vực', detail.adminLevelName),
        _infoRow(Icons.location_on_outlined, 'Địa chỉ', detail.address),
        if (detail.model.isNotEmpty) _infoRow(Icons.devices_outlined, 'Model', detail.model),
        if (detail.manufacturer.isNotEmpty) _infoRow(Icons.business_outlined, 'Hãng', detail.manufacturer),
        _infoRow(Icons.place_outlined, 'Vị trí', detail.positionName),
        _infoRow(Icons.favorite_border, 'Heartbeat', heartbeatText),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    if (value.isEmpty || value == '-') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey[600]),
          const SizedBox(width: 6),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoContentByType() {
    if (widget.device.deviceType == 'Sensor') {
      return _buildSensorGaugeInfo();
    }
    if (widget.device.deviceType == 'Đồng hồ nước') {
      return _buildWaterMeterInfo();
    }
    if (widget.device.deviceType == 'Cảm biến mực nước') {
      return _buildWaterLevelSensorInfo();
    }
    return _buildDefaultInfoContent();
  }

  Widget _buildSensorGaugeInfo() {
    return Center(
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Serial: ${widget.device.deviceSerial}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: SfRadialGauge(
                    title: GaugeTitle(
                      text: 'Nhiệt độ',
                      textStyle: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    axes: <RadialAxis>[
                      RadialAxis(
                        minimum: 0,
                        maximum: 100,
                        ranges: <GaugeRange>[
                          GaugeRange(
                            startValue: 0,
                            endValue: 20,
                            color: Colors.blue,
                            startWidth: 10,
                            endWidth: 10,
                          ),
                          GaugeRange(
                            startValue: 20,
                            endValue: 40,
                            color: Colors.cyan,
                            startWidth: 10,
                            endWidth: 10,
                          ),
                          GaugeRange(
                            startValue: 40,
                            endValue: 60,
                            color: Colors.green,
                            startWidth: 10,
                            endWidth: 10,
                          ),
                          GaugeRange(
                            startValue: 60,
                            endValue: 80,
                            color: Colors.orange,
                            startWidth: 10,
                            endWidth: 10,
                          ),
                          GaugeRange(
                            startValue: 80,
                            endValue: 100,
                            color: Colors.red,
                            startWidth: 10,
                            endWidth: 10,
                          ),
                        ],
                        pointers: <GaugePointer>[
                          NeedlePointer(value: _currentTemperature),
                        ],
                        annotations: <GaugeAnnotation>[
                          GaugeAnnotation(
                            widget: Text(
                              '$_currentTemperature°C',
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            angle: 90,
                            positionFactor: 0.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SfRadialGauge(
                    title: GaugeTitle(
                      text: 'Độ ẩm không khí',
                      textStyle: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    axes: <RadialAxis>[
                      RadialAxis(
                        minimum: 0,
                        maximum: 100,
                        ranges: <GaugeRange>[
                          GaugeRange(
                            startValue: 0,
                            endValue: 20,
                            color: Colors.blue,
                            startWidth: 10,
                            endWidth: 10,
                          ),
                          GaugeRange(
                            startValue: 20,
                            endValue: 40,
                            color: Colors.cyan,
                            startWidth: 10,
                            endWidth: 10,
                          ),
                          GaugeRange(
                            startValue: 40,
                            endValue: 60,
                            color: Colors.green,
                            startWidth: 10,
                            endWidth: 10,
                          ),
                          GaugeRange(
                            startValue: 60,
                            endValue: 80,
                            color: Colors.orange,
                            startWidth: 10,
                            endWidth: 10,
                          ),
                          GaugeRange(
                            startValue: 80,
                            endValue: 100,
                            color: Colors.red,
                            startWidth: 10,
                            endWidth: 10,
                          ),
                        ],
                        pointers: <GaugePointer>[
                          NeedlePointer(value: _currentSoilMoisture),
                        ],
                        annotations: <GaugeAnnotation>[
                          GaugeAnnotation(
                            widget: Text(
                              '$_currentSoilMoisture%',
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            angle: 90,
                            positionFactor: 0.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultInfoContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AlarmWidget(
          deviceSerial: widget.device.deviceSerial,
          mqttManager: mqttManager,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Cảm biến thời gian thực',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: DeviceSensorReadingBox(
                  deviceSerial: widget.device.deviceSerial,
                  icon: Icons.opacity,
                  title: 'Độ ẩm đất',
                  sensorType: 'doam',
                  color: Colors.brown[400]!,
                  mqttManager: mqttManager,
                ),
              ),
              Container(height: 80, width: 1, color: Colors.grey[300]),
              Expanded(
                child: DeviceSensorReadingBox(
                  deviceSerial: widget.device.deviceSerial,
                  icon: Icons.water,
                  title: 'Mức nước',
                  sensorType: 'chatlong',
                  color: Colors.blueAccent,
                  mqttManager: mqttManager,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  bool _isSwitchLoading = false;

  Future<void> _handleToggleSwitch() async {
    if (_isSwitchLoading) return;
    setState(() => _isSwitchLoading = true);
    try {
      final newSwitchState = !_isSwitched;
      await _saveSwitchDeviceHistory(newSwitchState ? 1 : 0);
      final topic = 'NhaCuaToi_${widget.device.deviceSerial}';
      final message = newSwitchState ? 'ON' : 'OFF';
      mqttManager.publish(topic, message);
      await _loadSwitchEvents();
      if (mounted) setState(() => _isSwitched = newSwitchState);
    } finally {
      if (mounted) setState(() => _isSwitchLoading = false);
    }
  }

  Widget _buildControlTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (!_canControlDevice)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _isDeviceDisabled ? Colors.red[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDeviceDisabled ? Colors.red[300]! : Colors.orange[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isDeviceDisabled ? Icons.block : Icons.info_outline,
                  color: _isDeviceDisabled ? Colors.red[700] : Colors.orange[700],
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isDeviceDisabled
                        ? 'Thiết bị đã ngừng hoạt động. Không thể điều khiển.'
                        : 'Thiết bị này chỉ hỗ trợ giám sát. Các thao tác điều khiển bị vô hiệu hóa.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isDeviceDisabled ? Colors.red[800] : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Điều khiển',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildPowerButton(),
              AbsorbPointer(
                absorbing: !_canControlDevice,
                child: DeviceDetailButton(
                  color: !_canControlDevice
                      ? Colors.grey[400]!
                      : Theme.of(context).primaryColorDark,
                  icon: Icons.timer,
                  title: 'Hẹn giờ',
                  shouldDisplayDotIndicator: false,
                  onTap: () {
                    setSelectedDevice(context, widget.device);
                    Navigator.pushNamed(context, '/device_schedule');
                    mqttManager.ensureConnected();
                  },
                ),
              ),
              if (widget.device.deviceType == 'Trạm bơm')
                DeviceDetailButton(
                  color: Colors.blue[600]!,
                  icon: Icons.water,
                  title: 'Quản lý',
                  onTap: () {
                    setSelectedDevice(context, widget.device);
                    Navigator.pushNamed(context, '/pump_station');
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lịch sử bật/tắt',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Làm mới',
                onPressed: _loadSwitchEvents,
              ),
            ],
          ),
        ),
        _buildSwitchHistory(),
      ],
    );
  }

  Widget _buildPowerButton() {
    final canControl = _canControlDevice;
    final color = !canControl
        ? Colors.grey[400]!
        : (_isSwitched ? Theme.of(context).primaryColor : Colors.grey[500]!);

    return AbsorbPointer(
      absorbing: !canControl || _isSwitchLoading,
      child: GestureDetector(
        onTap: _handleToggleSwitch,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.1,
          width: MediaQuery.of(context).size.width * 0.25,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              Center(
                child: _isSwitchLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.power_settings_new, color: Colors.white, size: 25),
                          const SizedBox(height: 4),
                          Text(
                            _isSwitched ? 'Đang bật' : 'Đang tắt',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _isSwitched ? Colors.greenAccent : Colors.grey[300],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchHistory() {
    if (_switchEvents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off, size: 48, color: Colors.grey[350]),
            const SizedBox(height: 12),
            Text(
              'Chưa có lịch sử bật/tắt',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('HH:mm:ss · dd/MM/yyyy');
    final events = _switchEvents.reversed.toList();

    return Column(
      children: events.map((event) {
        final dateString = dateFormat.format(
          event.timestamp.add(const Duration(hours: 7)),
        );
        final isOn = event.isSwitched;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isOn ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isOn ? Colors.green[200]! : Colors.red[200]!,
            ),
          ),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: isOn ? Colors.green[100] : Colors.red[100],
              child: Icon(
                Icons.power_settings_new,
                size: 16,
                color: isOn ? Colors.green[700] : Colors.red[700],
              ),
            ),
            title: Text(
              isOn ? 'Đã bật thiết bị' : 'Đã tắt thiết bị',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isOn ? Colors.green[800] : Colors.red[800],
              ),
            ),
            subtitle: Text(
              dateString,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWaterMeterInfo() {
    if (_isLoadingWater) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_waterError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text(
                'Không thể tải dữ liệu đồng hồ nước',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red[700]),
              ),
              const SizedBox(height: 6),
              Text(
                _waterError!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _fetchWaterMeterData,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (_waterMeterData == null || _waterMeterData!['Data'] == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_outlined, size: 48, color: Colors.blue[200]),
            const SizedBox(height: 12),
            const Text('Không có dữ liệu đồng hồ nước.'),
          ],
        ),
      );
    }
    final List data = List.from(_waterMeterData!['Data']);
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_outlined, size: 48, color: Colors.blue[200]),
            const SizedBox(height: 12),
            const Text('Không có dữ liệu đồng hồ nước.'),
          ],
        ),
      );
    }
    data.sort((a, b) {
      final at = DateTime.tryParse(a['Timestamp'] ?? '') ?? DateTime(1970);
      final bt = DateTime.tryParse(b['Timestamp'] ?? '') ?? DateTime(1970);
      return bt.compareTo(at);
    });
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        final liters = item['MeterReadingLiters'];
        final timestamp = item['Timestamp'] ?? '-';
        final valveStatus = item['ValveStatus'] ?? '-';
        final valveFault = item['ValveFaultStatus'] ?? '-';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue[50],
                  child: Icon(Icons.water_drop, color: Colors.blue[600], size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$liters lít',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timestamp,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _valveStatusChip(valveStatus),
                    if (valveFault != '-' && valveFault != 'Normal')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          valveFault,
                          style: TextStyle(fontSize: 11, color: Colors.red[400]),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _valveStatusChip(String status) {
    final isOpen = status.toLowerCase() == 'open' || status == 'Mở';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isOpen ? Colors.green[300]! : Colors.orange[300]!),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isOpen ? Colors.green[700] : Colors.orange[700],
        ),
      ),
    );
  }

  Widget _buildWaterLevelSensorInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue[50],
                    child: Icon(Icons.water_drop, size: 28, color: Colors.blue[600]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cảm biến mực nước',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Serial: ${widget.device.deviceSerial}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: DeviceSensorReadingBox(
              deviceSerial: widget.device.deviceSerial,
              icon: Icons.water,
              title: "Mức nước",
              sensorType: "mucnuoc",
              color: Colors.blue[600]!,
              mqttManager: mqttManager,
            ),
          ),
        ],
      ),
    );
  }
}

