import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wifi_iot/wifi_iot.dart';
import 'dart:async';

class IoTSetupScreen extends StatefulWidget {
  const IoTSetupScreen({Key? key}) : super(key: key);

  @override
  State<IoTSetupScreen> createState() => _IoTSetupScreenState();
}

class _IoTSetupScreenState extends State<IoTSetupScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isScanning = false;
  bool isConnected = false;
  bool isConnectingWifi = false;
  bool isWifiConnected = false;
  bool isConfigurationComplete = false;
  String? selectedSSID;
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isTestingConnection = false;
  bool isConnectionSuccessful = false;
  bool isScanningWifi = false;
  List<WiFiAccessPoint> wifiNetworks = [];
  Timer? _wifiMonitorTimer;
  String? _currentWifiSSID;
  String? _lastShownSSID; // Thêm biến cờ để kiểm soát hiển thị SnackBar

  @override
  void initState() {
    super.initState();
    _startWifiMonitoring();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Kiểm tra quyền camera
    PermissionStatus cameraStatus = await Permission.camera.status;
    PermissionStatus locationStatus = await Permission.location.status;
    
    if (cameraStatus.isDenied || locationStatus.isDenied) {
      // Hiển thị thông báo về quyền cần thiết
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPermissionInfoDialog();
      });
    }
  }

  void _showPermissionInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Quyền cần thiết'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ứng dụng cần các quyền sau để thiết lập thiết bị IoT:'),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.camera_alt, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(child: Text('• Camera: Để scan QR code thiết bị')),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(child: Text('• Vị trí: Để quét và kết nối WiFi')),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'Các quyền này sẽ được yêu cầu khi bạn sử dụng chức năng tương ứng.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    _wifiMonitorTimer?.cancel();
    super.dispose();
  }

  void _startWifiMonitoring() {
    _wifiMonitorTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkWifiStatus();
    });
  }

  Future<void> _checkWifiStatus() async {
    try {
      final currentSSID = await WiFiForIoTPlugin.getSSID();
      
      // Nếu đang ở bước cấu hình WiFi và điện thoại đã ngắt kết nối khỏi WiFi của thiết bị
      if (isConnectionSuccessful && 
          selectedSSID != null && 
          currentSSID != selectedSSID && 
          _currentWifiSSID == selectedSSID) {
        
        // Thiết bị đã có internet (đã ngắt kết nối khỏi WiFi hotspot)
        setState(() {
          isConfigurationComplete = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🎉 Cấu hình thành công! Thiết bị đã có internet."),
            backgroundColor: Colors.green,
          ),
        );
        
        // Dừng monitoring
        _wifiMonitorTimer?.cancel();
      }
      
      _currentWifiSSID = currentSSID;
    } catch (e) {
      // Ignore errors when checking WiFi status
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết lập IoT'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPermissionCheckCard(),
            const SizedBox(height: 16),
            _buildStepCard(
              title: 'Bước 1: Kết nối thiết bị',
              subtitle: 'Scan QR code để lấy thông tin thiết bị',
              content: _buildQRScanner(),
              stepNumber: 1,
            ),
            const SizedBox(height: 16),
            if (isConnected) ...[
              _buildStepCard(
                title: 'Bước 2: Kết nối WiFi thủ công',
                subtitle: 'Kết nối điện thoại đến WiFi của thiết bị',
                content: _buildManualWifiConnection(),
                stepNumber: 2,
              ),
              const SizedBox(height: 16),
            ],
            if (isWifiConnected) ...[
              _buildStepCard(
                title: 'Bước 3: Kiểm tra kết nối',
                subtitle: 'Kiểm tra kết nối đến thiết bị tại 192.168.4.1',
                content: _buildConnectionTest(),
                stepNumber: 3,
              ),
              const SizedBox(height: 16),
            ],
            if (isConnectionSuccessful && !isConfigurationComplete) ...[
              _buildStepCard(
                title: 'Bước 4: Cấu hình WiFi',
                subtitle: 'Chọn mạng WiFi để thiết bị kết nối',
                content: _buildWifiConfiguration(),
                stepNumber: 4,
              ),
            ],
            if (isConfigurationComplete) ...[
              _buildStepCard(
                title: '🎉 Hoàn thành!',
                subtitle: 'Thiết bị đã được cấu hình thành công',
                content: _buildSuccessMessage(),
                stepNumber: 5,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String title,
    required String subtitle,
    required Widget content,
    required int stepNumber,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      stepNumber.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCheckCard() {
    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Kiểm tra quyền',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Đảm bảo ứng dụng có đủ quyền để thiết lập thiết bị IoT:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _checkAndRequestPermissions,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Kiểm tra quyền'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openAppSettings(),
                    icon: const Icon(Icons.settings),
                    label: const Text('Cài đặt'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkAndRequestPermissions() async {
    // Kiểm tra quyền camera
    PermissionStatus cameraStatus = await Permission.camera.status;
    PermissionStatus locationStatus = await Permission.location.status;
    
    List<String> missingPermissions = [];
    
    if (cameraStatus.isDenied) {
      cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        missingPermissions.add('Camera');
      }
    }
    
    if (locationStatus.isDenied) {
      locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        missingPermissions.add('Vị trí');
      }
    }
    
    if (missingPermissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Tất cả quyền đã được cấp'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Thiếu quyền: ${missingPermissions.join(', ')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildQRScanner() {
    if (!isScanning) {
      return Column(
        children: [
          const Icon(
            Icons.qr_code_scanner,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Hướng dẫn:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Đảm bảo thiết bị IoT đang ở chế độ cài đặt\n'
            '2. Kết nối WiFi với SSID "NhaCuaToi_3453893583"\n'
            '3. Scan QR code trên thiết bị hoặc bao bì',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _startQRScan,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Bắt đầu Scan QR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: Theme.of(context).primaryColor,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 250,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _stopQRScan,
          icon: const Icon(Icons.stop),
          label: const Text('Dừng Scan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildManualWifiConnection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Hướng dẫn kết nối thủ công:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '1. Vào Cài đặt > WiFi\n'
                '2. Tìm và chọn WiFi của thiết bị\n'
                '3. Nhập mật khẩu (nếu có)\n'
                '4. Kết nối thành công',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: selectedSSID != null ? () {
              setState(() {
                isWifiConnected = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Đã xác nhận kết nối WiFi thủ công"),
                  backgroundColor: Colors.green,
                ),
              );
            } : null,
            icon: const Icon(Icons.wifi),
            label: const Text('Xác nhận đã kết nối WiFi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionTest() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedSSID != null
                    ? 'Đảm bảo điện thoại đã kết nối với WiFi của thiết bị (SSID: $selectedSSID)'
                    : 'Đang chờ thông tin SSID từ QR code...',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Thông tin kết nối:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '• IP thiết bị: 192.168.4.1\\n'
                '• Port: 80 (HTTP)\\n'
                '• Endpoint: /setting',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!isTestingConnection && !isConnectionSuccessful) ...[
          const Text(
            'Nhấn nút bên dưới để kiểm tra kết nối đến thiết bị',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _testConnection,
              icon: const Icon(Icons.network_check),
              label: const Text('Kiểm tra kết nối'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ] else if (isTestingConnection) ...[
          const Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang kiểm tra kết nối...'),
            ],
          ),
        ] else if (isConnectionSuccessful) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kết nối thành công! Thiết bị đã sẵn sàng nhận cấu hình.',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _startQRScan() async {
    // Kiểm tra quyền camera trước
    PermissionStatus cameraStatus = await Permission.camera.status;
    
    if (cameraStatus.isDenied) {
      // Yêu cầu quyền camera
      cameraStatus = await Permission.camera.request();
    }
    
    if (cameraStatus.isPermanentlyDenied) {
      // Quyền bị từ chối vĩnh viễn, hướng dẫn người dùng vào Settings
      _showPermissionDialog(
        'Quyền Camera',
        'Ứng dụng cần quyền camera để scan QR code. Vui lòng vào Cài đặt > Quyền riêng tư & Bảo mật > Camera và bật quyền cho ứng dụng này.',
        () => openAppSettings(),
      );
      return;
    }
    
    if (cameraStatus.isGranted) {
      setState(() {
        isScanning = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cần quyền camera để scan QR code"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPermissionDialog(String title, String message, VoidCallback onSettingsTap) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onSettingsTap();
              },
              child: const Text('Mở Cài đặt'),
            ),
          ],
        );
      },
    );
  }

  void _stopQRScan() {
    controller?.dispose();
    setState(() {
      isScanning = false;
    });
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        _handleQRCode(scanData.code!);
      }
    });
  }

  void _handleQRCode(String qrData) {
    print('QR Code scanned: $qrData');
    String? newSSID;
    // Parse QR code data
    if (qrData.startsWith('WIFI:')) {
      final ssidMatch = RegExp(r'S:([^;]+)').firstMatch(qrData);
      if (ssidMatch != null) {
        newSSID = ssidMatch.group(1);
      }
    } else {
      try {
        final qrJson = jsonDecode(qrData);
        if (qrJson['ssid'] != null) {
          newSSID = qrJson['ssid'];
        }
      } catch (e) {
        if (qrData.startsWith('NhaCuaToi_')) {
          newSSID = qrData;
        }
      }
    }
    if (newSSID != null) {
      // Chỉ hiển thị SnackBar nếu SSID thực sự thay đổi
      if (_lastShownSSID != newSSID) {
        _lastShownSSID = newSSID;
        setState(() {
          selectedSSID = newSSID!;
          ssidController.text = newSSID!;
          isConnected = true;
          isScanning = false;
          isWifiConnected = false;
          isConnectionSuccessful = false;
          isScanningWifi = false;
          wifiNetworks.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Đã lấy SSID: $newSSID"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    // Nếu không parse được, hiển thị thông báo lỗi
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Không thể đọc SSID từ QR code"),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _connectToDeviceWifi() async {
    setState(() {
      isConnectingWifi = true;
    });

    try {
      // Kiểm tra quyền vị trí (cần thiết cho WiFi connection trên iOS)
      PermissionStatus locationStatus = await Permission.location.status;
      
      if (locationStatus.isDenied) {
        locationStatus = await Permission.location.request();
      }
      
      if (locationStatus.isPermanentlyDenied) {
        _showPermissionDialog(
          'Quyền Vị trí',
          'Ứng dụng cần quyền vị trí để kết nối WiFi. Vui lòng vào Cài đặt > Quyền riêng tư & Bảo mật > Vị trí và bật quyền cho ứng dụng này.',
          () => openAppSettings(),
        );
        setState(() {
          isConnectingWifi = false;
        });
        return;
      }
      
      if (!locationStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cần quyền vị trí để kết nối WiFi"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isConnectingWifi = false;
        });
        return;
      }

      // Lấy SSID từ QR code
      final deviceSSID = selectedSSID ?? '';
      if (deviceSSID.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Không tìm thấy SSID thiết bị từ QR code!"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isConnectingWifi = false;
        });
        return;
      }

      print('Connecting to device WiFi: $deviceSSID');
      
      // Thử kết nối đến WiFi của thiết bị
      final result = await WiFiForIoTPlugin.connect(
        deviceSSID,
        password: '', // WiFi hotspot thường không có password
        security: NetworkSecurity.NONE, // Hoặc WPA nếu có password
        joinOnce: true,
        withInternet: false,
      );
      
      print('WiFi connection result: $result');
      
      if (result == true) {
        setState(() {
          isWifiConnected = true;
          isConnectingWifi = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Đã kết nối WiFi thành công đến $deviceSSID"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          isConnectingWifi = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Không thể kết nối WiFi. Hãy kiểm tra:\n1. Thiết bị có đang tạo WiFi hotspot không?\n2. SSID có đúng không?"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      
    } catch (e) {
      print('WiFi connection error: $e');
      setState(() {
        isConnectingWifi = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Lỗi kết nối WiFi: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      isTestingConnection = true;
    });

    try {
      // Kiểm tra kết nối đến 192.168.4.1
      final response = await http.get(Uri.parse('http://192.168.4.1'));
      if (response.statusCode == 200) {
        setState(() {
          isConnectionSuccessful = true;
          isTestingConnection = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Kết nối thành công! Thiết bị đã sẵn sàng nhận cấu hình."),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          isTestingConnection = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Không thể kết nối đến thiết bị. Hãy kiểm tra lại kết nối."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Connection test error: $e');
      setState(() {
        isTestingConnection = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Lỗi kiểm tra kết nối: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildWifiConfiguration() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thiết bị đã sẵn sàng nhận cấu hình WiFi!',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Chọn mạng WiFi 2.4GHz để thiết bị kết nối:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (!isScanningWifi && wifiNetworks.isEmpty) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _scanWifiNetworks,
              icon: const Icon(Icons.wifi_find),
              label: const Text('Quét mạng WiFi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ] else if (isScanningWifi) ...[
          const Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang quét mạng WiFi...'),
            ],
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Mạng WiFi 2.4GHz tìm thấy:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _scanWifiNetworks,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Làm mới'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedSSID,
                  decoration: const InputDecoration(
                    labelText: 'Chọn mạng WiFi',
                    border: OutlineInputBorder(),
                  ),
                  items: wifiNetworks.map((network) {
                    return DropdownMenuItem<String>(
                      value: network.ssid,
                      child: Text('${network.ssid} (${network.level} dBm)'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSSID = value;
                      if (value != null) {
                        ssidController.text = value;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu WiFi',
              hintText: 'Nhập mật khẩu WiFi',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedSSID != null ? _configureDevice : null,
              icon: const Icon(Icons.send),
              label: const Text('Gửi cấu hình'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _configureDevice() async {
    final ssid = ssidController.text.trim();
    final password = passwordController.text.trim();

    if (ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Vui lòng nhập SSID WiFi"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Hiển thị dialog loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text("Đang gửi cấu hình..."),
              ],
            ),
          );
        },
      );

      // Gửi cấu hình WiFi đến thiết bị
      final response = await http.get(
        Uri.parse('http://192.168.4.1/setting?ssid=${Uri.encodeComponent(ssid)}&pass=${Uri.encodeComponent(password)}'),
      );

      // Đóng dialog loading
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Đã gửi cấu hình! Đang chờ thiết bị kết nối internet..."),
            backgroundColor: Colors.green,
          ),
        );
        
        // Không reset form ngay, để monitoring phát hiện khi thiết bị có internet
        // Chỉ reset khi thiết bị đã có internet (trong _checkWifiStatus)
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi gửi cấu hình: ${response.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Đóng dialog loading nếu có lỗi
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Lỗi kết nối: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scanWifiNetworks() async {
    setState(() {
      isScanningWifi = true;
    });

    try {
      // Kiểm tra quyền vị trí (cần thiết cho WiFi scanning trên iOS)
      PermissionStatus locationStatus = await Permission.location.status;
      
      if (locationStatus.isDenied) {
        locationStatus = await Permission.location.request();
      }
      
      if (locationStatus.isPermanentlyDenied) {
        _showPermissionDialog(
          'Quyền Vị trí',
          'Ứng dụng cần quyền vị trí để quét mạng WiFi. Vui lòng vào Cài đặt > Quyền riêng tư & Bảo mật > Vị trí và bật quyền cho ứng dụng này.',
          () => openAppSettings(),
        );
        setState(() {
          isScanningWifi = false;
        });
        return;
      }
      
      if (!locationStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cần quyền vị trí để quét mạng WiFi"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isScanningWifi = false;
        });
        return;
      }

      // Quét mạng WiFi
      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        final networks = await WiFiScan.instance.getScannedResults();
        setState(() {
          wifiNetworks = networks;
          isScanningWifi = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Đã quét được ${networks.length} mạng WiFi"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          isScanningWifi = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Không thể quét mạng WiFi: $canScan"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('WiFi scan error: $e');
      setState(() {
        isScanningWifi = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Lỗi quét mạng WiFi: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSuccessMessage() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'Thiết bị đã được cấu hình thành công!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Thiết bị đã kết nối internet và sẵn sàng sử dụng.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // Reset toàn bộ trạng thái để bắt đầu lại
              setState(() {
                isConnected = false;
                isWifiConnected = false;
                isConnectionSuccessful = false;
                isConfigurationComplete = false;
                isScanningWifi = false;
                selectedSSID = null;
                passwordController.clear();
                ssidController.clear();
                wifiNetworks.clear();
                _currentWifiSSID = null;
              });
              
              // Khởi động lại monitoring
              _startWifiMonitoring();
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Đã reset để cấu hình thiết bị mới"),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Cấu hình thiết bị khác'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
