import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_iot/wifi_iot.dart';

class WiFiSetupScreen extends StatefulWidget {
  const WiFiSetupScreen({Key? key}) : super(key: key);

  @override
  _WiFiSetupScreenState createState() => _WiFiSetupScreenState();
}

class _WiFiSetupScreenState extends State<WiFiSetupScreen> {
  int currentStep = 0;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  
  // Dữ liệu từ QR code WiFi
  String? scannedSSID;
  String? scannedPassword;
  
  // Danh sách WiFi quét được
  List<WiFiAccessPoint> availableWiFiList = [];
  WiFiAccessPoint? selectedWiFi;
  
  // Controller cho password
  final TextEditingController passwordController = TextEditingController();
  
  // Trạng thái
  bool isScanning = false;
  bool isConnecting = false;
  bool isSettingUp = false;
  String statusMessage = '';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    // Test quét WiFi ngay khi khởi tạo để kiểm tra permission
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWiFiScanCapability();
    });
  }
  
  // Kiểm tra khả năng quét WiFi ngay từ đầu
  Future<void> _checkWiFiScanCapability() async {
    try {
      final canStartScan = await WiFiScan.instance.canStartScan();
      final canGetResults = await WiFiScan.instance.canGetScannedResults();
      
      print('🔍 Can start scan: $canStartScan');
      print('📊 Can get results: $canGetResults');
      
      String message = '';
      if (canStartScan != CanStartScan.yes) {
        switch (canStartScan) {
          case CanStartScan.notSupported:
            message = 'Thiết bị không hỗ trợ quét WiFi';
            break;
          case CanStartScan.noLocationPermissionRequired:
          case CanStartScan.noLocationPermissionDenied:
            message = 'Cần cấp quyền vị trí để quét WiFi';
            break;
          case CanStartScan.noLocationServiceDisabled:
            message = 'Cần bật GPS để quét WiFi';
            break;
          default:
            message = 'Không thể quét WiFi: $canStartScan';
        }
      } else if (canGetResults != CanGetScannedResults.yes) {
        message = 'Không thể lấy kết quả quét WiFi';
      } else {
        message = 'Sẵn sàng quét WiFi 2.4GHz';
      }
      
      setState(() {
        statusMessage = message;
      });
      
    } catch (e) {
      print('❌ Lỗi kiểm tra khả năng quét WiFi: $e');
      setState(() {
        statusMessage = 'Lỗi kiểm tra: $e';
      });
    }
  }

  @override
  void dispose() {
    qrController?.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Yêu cầu quyền cần thiết
  Future<void> _requestPermissions() async {
    print('🔐 Yêu cầu quyền truy cập...');
    
    // Yêu cầu quyền camera cho QR scanning
    final cameraStatus = await Permission.camera.request();
    print('📷 Camera permission: $cameraStatus');
    if (cameraStatus != PermissionStatus.granted) {
      _showMessage('Cần quyền camera để quét QR code');
    }
    
    // Yêu cầu quyền vị trí cho WiFi scanning (quan trọng nhất)
    print('📍 Yêu cầu quyền vị trí...');
    
    // Kiểm tra trạng thái hiện tại
    final currentLocationStatus = await Permission.location.status;
    final currentLocationWhenInUseStatus = await Permission.locationWhenInUse.status;
    
    print('📍 Current location status: $currentLocationStatus');
    print('📍 Current locationWhenInUse status: $currentLocationWhenInUseStatus');
    
    // Yêu cầu quyền location when in use trước
    PermissionStatus locationWhenInUseStatus = currentLocationWhenInUseStatus;
    if (locationWhenInUseStatus != PermissionStatus.granted) {
      locationWhenInUseStatus = await Permission.locationWhenInUse.request();
      print('📍 LocationWhenInUse request result: $locationWhenInUseStatus');
    }
    
    // Yêu cầu quyền location chính xác
    PermissionStatus locationStatus = currentLocationStatus;
    if (locationStatus != PermissionStatus.granted) {
      locationStatus = await Permission.location.request();
      print('📍 Location request result: $locationStatus');
    }
    
    // Đối với Android 12+ cần thêm quyền này
    if (Platform.isAndroid) {
      final nearbyWifiDevicesStatus = await Permission.nearbyWifiDevices.request();
      print('📶 Nearby WiFi devices permission: $nearbyWifiDevicesStatus');
    }
    
    // Kiểm tra xem có cần mở cài đặt không
    if (locationWhenInUseStatus == PermissionStatus.permanentlyDenied || 
        locationStatus == PermissionStatus.permanentlyDenied) {
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cần Quyền Vị Trí'),
            content: const Text(
              'Ứng dụng cần quyền vị trí để quét WiFi. '
              'Vui lòng vào Cài đặt > Ứng dụng > IoT App > Quyền và bật quyền Vị trí.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Mở Cài Đặt'),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    // Kiểm tra và thông báo trạng thái cuối cùng
    if (locationWhenInUseStatus != PermissionStatus.granted && 
        locationStatus != PermissionStatus.granted) {
      _showMessage('Cần quyền vị trí để quét WiFi. Vui lòng cấp quyền và thử lại.');
    } else {
      _showMessage('Quyền đã được cấp. Bây giờ có thể quét WiFi.');
    }
    
    // Kiểm tra và hiển thị trạng thái tất cả quyền
    final permissions = await [
      Permission.camera,
      Permission.location,
      Permission.locationWhenInUse,
    ].request();
    
    permissions.forEach((permission, status) {
      print('🔐 Permission $permission: $status');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài Đặt WiFi Thiết Bị'),
        centerTitle: true,
      ),
      body: Stepper(
        currentStep: currentStep,
        onStepTapped: (step) {
          // Chỉ cho phép quay lại bước trước đó
          if (step < currentStep) {
            setState(() {
              currentStep = step;
            });
          }
        },
        controlsBuilder: (context, details) {
          return Row(
            children: [
              if (details.stepIndex < 4)
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: Text(details.stepIndex == 3 ? 'Cài Đặt' : 'Tiếp Theo'),
                ),
              const SizedBox(width: 8),
              if (details.stepIndex > 0)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Quay Lại'),
                ),
            ],
          );
        },
        onStepContinue: _handleStepContinue,
        onStepCancel: _handleStepCancel,
        steps: [
          // Bước 1: Quét QR code WiFi
          Step(
            title: const Text('Quét QR Code WiFi'),
            content: _buildQRScanStep(),
            isActive: currentStep >= 0,
            state: currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          
          // Bước 2: Kết nối WiFi từ QR
          Step(
            title: const Text('Kết Nối WiFi'),
            content: _buildConnectStep(),
            isActive: currentStep >= 1,
            state: currentStep > 1 ? StepState.complete : 
                   currentStep == 1 ? StepState.indexed : StepState.disabled,
          ),
          
          // Bước 3: Quét WiFi 2.4GHz
          Step(
            title: const Text('Quét WiFi 2.4GHz'),
            content: _buildWiFiScanStep(),
            isActive: currentStep >= 2,
            state: currentStep > 2 ? StepState.complete : 
                   currentStep == 2 ? StepState.indexed : StepState.disabled,
          ),
          
          // Bước 4: Chọn WiFi và nhập mật khẩu
          Step(
            title: const Text('Chọn WiFi & Nhập Mật Khẩu'),
            content: _buildWiFiSelectStep(),
            isActive: currentStep >= 3,
            state: currentStep > 3 ? StepState.complete : 
                   currentStep == 3 ? StepState.indexed : StepState.disabled,
          ),
          
          // Bước 5: Cài đặt WiFi cho thiết bị
          Step(
            title: const Text('Cài Đặt Thiết Bị'),
            content: _buildDeviceSetupStep(),
            isActive: currentStep >= 4,
            state: currentStep == 4 ? StepState.indexed : StepState.disabled,
          ),
        ],
      ),
    );
  }

  // Xây dựng bước quét QR code
  Widget _buildQRScanStep() {
    return Column(
      children: [
        Container(
          height: 300,
          child: QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.blue,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 250,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          scannedSSID != null 
            ? 'Đã quét: $scannedSSID' 
            : 'Quét QR code chứa thông tin WiFi',
          style: const TextStyle(fontSize: 16),
        ),
        if (scannedSSID != null)
          Text(
            'Mật khẩu: ${scannedPassword?.replaceAll(RegExp(r'.'), '*')}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
      ],
    );
  }

  // Xây dựng bước kết nối WiFi
  Widget _buildConnectStep() {
    return Column(
      children: [
        if (scannedSSID != null)
          ListTile(
            leading: const Icon(Icons.wifi),
            title: Text(scannedSSID!),
            subtitle: const Text('Đang kết nối...'),
            trailing: isConnecting 
              ? const CircularProgressIndicator()
              : const Icon(Icons.check_circle, color: Colors.green),
          ),
        const SizedBox(height: 16),
        Text(
          statusMessage.isNotEmpty ? statusMessage : 'Sẵn sàng kết nối WiFi',
          style: TextStyle(
            color: statusMessage.contains('thành công') ? Colors.green : Colors.orange,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // Xây dựng bước quét WiFi 2.4GHz
  Widget _buildWiFiScanStep() {
    return SingleChildScrollView( // Wrap toàn bộ với SingleChildScrollView
      child: Column(
        mainAxisSize: MainAxisSize.min, // Fix layout constraint
        children: [
          // Thông tin hướng dẫn quan trọng
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.orange.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📍 Cần bật GPS để quét WiFi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vào Cài đặt > Vị trí > Bật dịch vụ vị trí\nhoặc kéo thanh thông báo xuống và bật GPS',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isScanning ? null : _scanWiFiNetworks,
                  icon: Icon(isScanning ? Icons.refresh : Icons.wifi_find),
                  label: Text(isScanning ? 'Đang Quét...' : 'Quét WiFi 2.4GHz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Nút kiểm tra quyền
              IconButton(
                onPressed: _checkWiFiScanCapability,
                icon: const Icon(Icons.settings),
                tooltip: 'Kiểm tra quyền',
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Hiển thị trạng thái quét
          if (statusMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: statusMessage.contains('Lỗi') ? Colors.red.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: statusMessage.contains('Lỗi') ? Colors.red.shade200 : Colors.blue.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    statusMessage.contains('Lỗi') ? Icons.error : Icons.info,
                    color: statusMessage.contains('Lỗi') ? Colors.red : Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusMessage,
                      style: TextStyle(
                        color: statusMessage.contains('Lỗi') ? Colors.red.shade700 : Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          if (isScanning)
            const LinearProgressIndicator(),
            
          const SizedBox(height: 16),
          
          // Hiển thị danh sách WiFi có thể chọn với Container có chiều cao cố định
          Container(
            height: 350, // Tăng chiều cao một chút
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: availableWiFiList.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isScanning 
                          ? 'Đang quét WiFi...' 
                          : 'Chưa tìm thấy WiFi nào.\n\n1️⃣ Kiểm tra GPS đã bật\n2️⃣ Nhấn "Quét WiFi 2.4GHz"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header cho danh sách WiFi
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Tìm thấy ${availableWiFiList.length} WiFi',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Danh sách WiFi cuộn được
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: availableWiFiList.length,
                        itemBuilder: (context, index) {
                          final wifi = availableWiFiList[index];
                          final isSelected = selectedWiFi?.ssid == wifi.ssid;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: isSelected ? Colors.blue.shade50 : null,
                            elevation: isSelected ? 3 : 1,
                            child: ListTile(
                              leading: Icon(
                                _getWiFiIcon(wifi.level),
                                color: _getSignalColor(wifi.level),
                              ),
                              title: Text(
                                wifi.ssid,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text('${wifi.level} dBm • ${_getFrequencyBand(wifi.frequency)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (wifi.capabilities.contains('WPA') || wifi.capabilities.contains('WEP'))
                                    const Icon(Icons.lock, size: 16),
                                  const SizedBox(width: 8),
                                  if (isSelected)
                                    Icon(Icons.check_circle, color: Colors.blue.shade600),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  selectedWiFi = wifi;
                                  // Tự động chuyển sang bước tiếp theo nếu đã chọn WiFi
                                  if (currentStep == 2) {
                                    currentStep = 3;
                                  }
                                });
                                _showMessage('✅ Đã chọn WiFi: ${wifi.ssid}');
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  // Xây dựng bước chọn WiFi và nhập mật khẩu
  Widget _buildWiFiSelectStep() {
    return Column(
      children: [
        // Hiển thị WiFi đã chọn
        if (selectedWiFi != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  _getWiFiIcon(selectedWiFi!.level),
                  color: _getSignalColor(selectedWiFi!.level),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WiFi đã chọn:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedWiFi!.ssid,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${selectedWiFi!.level} dBm • ${_getFrequencyBand(selectedWiFi!.frequency)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedWiFi!.capabilities.contains('WPA') || selectedWiFi!.capabilities.contains('WEP'))
                  const Icon(Icons.lock, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
              ],
            ),
          ),

        // Nút thay đổi WiFi
        if (selectedWiFi != null)
          TextButton.icon(
            onPressed: () {
              setState(() {
                currentStep = 2; // Quay về bước quét WiFi
              });
            },
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Chọn WiFi khác'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue.shade600,
            ),
          ),

        // Nếu chưa chọn WiFi, hiển thị thông báo
        if (selectedWiFi == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.wifi_off, size: 48, color: Colors.orange.shade400),
                const SizedBox(height: 12),
                Text(
                  'Chưa chọn WiFi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vui lòng quay về bước trước để chọn WiFi',
                  style: TextStyle(
                    color: Colors.orange.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      currentStep = 2; // Quay về bước quét WiFi
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Quay về chọn WiFi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          decoration: InputDecoration(
            labelText: 'Mật khẩu WiFi',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () {
                // Toggle password visibility
              },
            ),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        if (selectedWiFi != null)
          Card(
            child: ListTile(
              title: Text('WiFi được chọn: ${selectedWiFi!.ssid}'),
              subtitle: Text('Tín hiệu: ${selectedWiFi!.level} dBm'),
              leading: Icon(
                _getWiFiIcon(selectedWiFi!.level),
                color: _getSignalColor(selectedWiFi!.level),
              ),
            ),
          ),
      ],
    );
  }

  // Xây dựng bước cài đặt thiết bị
  Widget _buildDeviceSetupStep() {
    return Column(
      children: [
        if (isSettingUp)
          const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          statusMessage,
          style: TextStyle(
            fontSize: 16,
            color: statusMessage.contains('thành công') 
              ? Colors.green 
              : statusMessage.contains('lỗi') 
                ? Colors.red 
                : Colors.blue,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (selectedWiFi != null && passwordController.text.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thông tin cài đặt:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // SSID
                  Row(
                    children: [
                      const Icon(Icons.wifi, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('SSID: ', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Expanded(child: Text(selectedWiFi!.ssid, style: const TextStyle(color: Colors.blue))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Password
                  Row(
                    children: [
                      const Icon(Icons.lock, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text('Mật khẩu: ', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('${'*' * passwordController.text.length} (${passwordController.text.length} ký tự)'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // URL đầy đủ (không encode để giống trình duyệt)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.link, size: 16, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text('URL: ', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Expanded(
                        child: SelectableText(
                          'http://192.168.4.1/setting?ssid=${selectedWiFi!.ssid}&pass=${passwordController.text}',
                          style: TextStyle(
                            color: Colors.blue.shade600, 
                            fontSize: 12, 
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Thiết bị phải ở chế độ AP (192.168.4.1) để nhận cài đặt',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        const SizedBox(height: 20),
        
        // Hiển thị URL sẽ được gửi đến thiết bị
        if (selectedWiFi != null && passwordController.text.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link, color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'URL sẽ được gửi đến thiết bị:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // URL box có thể copy
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    'http://192.168.4.1/setting?ssid=${selectedWiFi!.ssid}&pass=${passwordController.text}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Thông tin chi tiết
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'App sẽ giả lập trình duyệt Chrome để gửi URL này đến thiết bị',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 20),
        
        // Các nút thao tác
        if (selectedWiFi != null && passwordController.text.isNotEmpty) ...[
          // Nút test kết nối thiết bị
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isSettingUp ? null : _testDeviceConnection,
              icon: const Icon(Icons.wifi_find),
              label: const Text('Test Kết Nối Thiết Bị'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.blue.shade600),
                foregroundColor: Colors.blue.shade600,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Nút cài đặt WiFi chính với mô tả chi tiết
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSettingUp ? null : _setupDeviceWiFi,
              icon: isSettingUp 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
              label: Text(isSettingUp 
                ? 'Đang Cài Đặt...' 
                : 'Gửi Cài Đặt WiFi Đến Thiết Bị'
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Mô tả hoạt động
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nhấn nút trên để app giả lập Chrome gửi URL cài đặt đến thiết bị IoT',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vui lòng chọn WiFi và nhập mật khẩu để xem URL cài đặt',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
                  child: Text(
                    'Vui lòng hoàn thành các bước trước:\n• Chọn WiFi 2.4GHz\n• Nhập mật khẩu WiFi',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Xử lý QR code được quét
  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      qrController = controller;
    });
    
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        _parseWiFiQRCode(scanData.code!);
      }
    });
  }

  // Phân tích QR code WiFi
  void _parseWiFiQRCode(String qrData) {
    try {
      // Format: WIFI:T:WPA;S:ssid;P:password;H:false;;
      if (qrData.startsWith('WIFI:')) {
        final parts = qrData.split(';');
        for (String part in parts) {
          if (part.startsWith('S:')) {
            scannedSSID = part.substring(2);
          } else if (part.startsWith('P:')) {
            scannedPassword = part.substring(2);
          }
        }
        
        if (scannedSSID != null) {
          setState(() {
            statusMessage = 'Đã quét thành công WiFi: $scannedSSID';
          });
          qrController?.pauseCamera();
        }
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Lỗi phân tích QR code: $e';
      });
    }
  }

  // Xử lý tiếp theo bước
  void _handleStepContinue() async {
    switch (currentStep) {
      case 0: // QR Scan
        if (scannedSSID != null) {
          setState(() {
            currentStep = 1;
          });
        } else {
          _showMessage('Vui lòng quét QR code WiFi trước');
        }
        break;
        
      case 1: // Connect WiFi
        await _connectToScannedWiFi();
        break;
        
      case 2: // WiFi Scan
        if (availableWiFiList.isNotEmpty) {
          setState(() {
            currentStep = 3;
          });
        } else {
          await _scanWiFiNetworks();
        }
        break;
        
      case 3: // WiFi Select
        if (selectedWiFi != null && passwordController.text.isNotEmpty) {
          setState(() {
            currentStep = 4;
          });
          await _setupDeviceWiFi();
        } else {
          _showMessage('Vui lòng chọn WiFi và nhập mật khẩu');
        }
        break;
    }
  }

  // Xử lý quay lại bước
  void _handleStepCancel() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
    }
  }

  // Kết nối WiFi từ QR code
  Future<void> _connectToScannedWiFi() async {
    if (scannedSSID == null || scannedPassword == null) return;
    
    setState(() {
      isConnecting = true;
      statusMessage = 'Đang kết nối WiFi...';
    });
    
    try {
      // Kết nối WiFi bằng WiFiIot plugin
      final connected = await WiFiForIoTPlugin.connect(
        scannedSSID!,
        password: scannedPassword!,
        security: NetworkSecurity.WPA,
      );
      
      if (connected) {
        setState(() {
          statusMessage = 'Kết nối WiFi thành công!';
          currentStep = 2;
        });
        
        // Tự động chuyển sang bước quét WiFi
        await Future.delayed(const Duration(seconds: 2));
        await _scanWiFiNetworks();
      } else {
        setState(() {
          statusMessage = 'Kết nối WiFi thất bại';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Lỗi kết nối: $e';
      });
    } finally {
      setState(() {
        isConnecting = false;
      });
    }
  }

  // Quét WiFi 2.4GHz
  Future<void> _scanWiFiNetworks() async {
    setState(() {
      isScanning = true;
      statusMessage = 'Đang quét WiFi...';
    });
    
    try {
      print('🔍 Bắt đầu quét WiFi 2.4GHz...');
      
      // Kiểm tra quyền vị trí trước
      final locationStatus = await Permission.location.status;
      final locationWhenInUseStatus = await Permission.locationWhenInUse.status;
      
      print('📍 Location permission: $locationStatus');
      print('📍 LocationWhenInUse permission: $locationWhenInUseStatus');
      
      if (locationStatus != PermissionStatus.granted && 
          locationWhenInUseStatus != PermissionStatus.granted) {
        // Yêu cầu quyền lại
        final newLocationStatus = await Permission.locationWhenInUse.request();
        if (newLocationStatus != PermissionStatus.granted) {
          throw Exception('Cần quyền vị trí để quét WiFi. Vui lòng cấp quyền trong Cài đặt.');
        }
      }
      
      // Kiểm tra khả năng quét WiFi
      final canStartScan = await WiFiScan.instance.canStartScan();
      print('🔍 Can start scan: $canStartScan');
      
      if (canStartScan != CanStartScan.yes) {
        switch (canStartScan) {
          case CanStartScan.notSupported:
            throw Exception('Thiết bị không hỗ trợ quét WiFi');
          case CanStartScan.noLocationPermissionRequired:
            throw Exception('Cần quyền vị trí để quét WiFi');
          case CanStartScan.noLocationPermissionDenied:
            throw Exception('Quyền vị trí bị từ chối. Vui lòng cấp quyền trong Cài đặt.');
          case CanStartScan.noLocationServiceDisabled:
            throw Exception('Dịch vụ vị trí bị tắt. Vui lòng bật GPS.');
          default:
            throw Exception('Không thể quét WiFi: $canStartScan');
        }
      }
      
      // Kiểm tra khả năng lấy kết quả
      final canGetResults = await WiFiScan.instance.canGetScannedResults();
      print('📊 Can get results: $canGetResults');
      
      if (canGetResults != CanGetScannedResults.yes) {
        switch (canGetResults) {
          case CanGetScannedResults.notSupported:
            throw Exception('Thiết bị không hỗ trợ lấy kết quả quét WiFi');
          case CanGetScannedResults.noLocationPermissionRequired:
            throw Exception('Cần quyền vị trí để lấy kết quả quét WiFi');
          case CanGetScannedResults.noLocationPermissionDenied:
            throw Exception('Quyền vị trí bị từ chối');
          case CanGetScannedResults.noLocationServiceDisabled:
            throw Exception('Dịch vụ vị trí bị tắt');
          default:
            throw Exception('Không thể lấy kết quả quét: $canGetResults');
        }
      }
      
      print('🔍 Bắt đầu quét WiFi...');
      // Bắt đầu quét
      final startResult = await WiFiScan.instance.startScan();
      print('🔍 Start scan result: $startResult');
      
      setState(() {
        statusMessage = 'Đang quét mạng WiFi...';
      });
      
      // Đợi kết quả quét (tăng thời gian đợi)
      await Future.delayed(const Duration(seconds: 5));
      
      print('📊 Lấy kết quả quét...');
      // Lấy kết quả
      final results = await WiFiScan.instance.getScannedResults();
      print('📊 Tổng số WiFi tìm được: ${results.length}');
      
      // In ra thông tin WiFi để debug
      for (var wifi in results.take(10)) { // Chỉ in 10 WiFi đầu để không spam log
        print('WiFi: ${wifi.ssid} - ${wifi.frequency}MHz - ${wifi.level}dBm');
      }
      
      // Lọc WiFi 2.4GHz (tần số từ 2400-2500 MHz)
      final wifi24GHz = results.where((wifi) {
        return wifi.frequency >= 2400 && wifi.frequency <= 2500 && wifi.ssid.isNotEmpty;
      }).toList();
      
      print('📊 WiFi 2.4GHz tìm được: ${wifi24GHz.length}');
      
      // Loại bỏ WiFi trùng lặp theo SSID
      final uniqueWiFiMap = <String, WiFiAccessPoint>{};
      for (var wifi in wifi24GHz) {
        if (!uniqueWiFiMap.containsKey(wifi.ssid) || 
            wifi.level > uniqueWiFiMap[wifi.ssid]!.level) {
          uniqueWiFiMap[wifi.ssid] = wifi;
        }
      }
      
      final uniqueWiFi = uniqueWiFiMap.values.toList();
      
      // Sắp xếp theo cường độ tín hiệu (từ mạnh nhất đến yếu nhất)
      uniqueWiFi.sort((a, b) => b.level.compareTo(a.level));
      
      setState(() {
        availableWiFiList = uniqueWiFi;
        statusMessage = 'Đã quét được ${uniqueWiFi.length} mạng WiFi 2.4GHz';
      });
      
      print('✅ Quét WiFi thành công: ${uniqueWiFi.length} mạng');
      
    } catch (e) {
      print('❌ Lỗi quét WiFi: $e');
      setState(() {
        statusMessage = 'Lỗi quét WiFi: $e';
        availableWiFiList = [];
      });
      
      // Hiển thị dialog lỗi với hướng dẫn
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Lỗi Quét WiFi'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chi tiết: $e'),
                const SizedBox(height: 16),
                const Text('Hướng dẫn khắc phục:', style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('1. Bật GPS/Vị trí trên thiết bị'),
                const Text('2. Cấp quyền vị trí cho ứng dụng'),
                const Text('3. Đảm bảo WiFi đã được bật'),
                const Text('4. Thử lại sau vài giây'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _requestPermissions(); // Yêu cầu quyền lại
                },
                child: const Text('Cấp Quyền'),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  // Test kết nối với thiết bị IoT
  Future<void> _testDeviceConnection() async {
    setState(() {
      statusMessage = '🔍 Đang test kết nối với thiết bị...';
    });
    
    try {
      print('🔗 Testing connection to http://192.168.4.1');
      
      setState(() {
        statusMessage = '🔍 Đang kiểm tra kết nối...\n📡 Gửi request đến http://192.168.4.1';
      });
      
      final response = await http.get(
        Uri.parse('http://192.168.4.1'),
        headers: {'User-Agent': 'IoT-App/1.0'},
      ).timeout(const Duration(seconds: 10));
      
      print('📡 Test response status: ${response.statusCode}');
      print('📡 Test response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
      
      if (response.statusCode == 200) {
        setState(() {
          statusMessage = '✅ Kết nối thiết bị thành công!\n📡 Thiết bị đang ở chế độ AP (192.168.4.1)\n🎯 Sẵn sàng cài đặt WiFi';
        });
        _showMessage('✅ Thiết bị IoT đã sẵn sàng nhận cài đặt!');
      } else {
        setState(() {
          statusMessage = '⚠️ Thiết bị phản hồi nhưng có lỗi\nHTTP Status: ${response.statusCode}';
        });
      }
    } on TimeoutException {
      setState(() {
        statusMessage = '''⏰ Timeout kết nối thiết bị (10s)

💡 HƯỚNG DẪN KHẮC PHỤC:
• Thiết bị có thể chưa sẵn sàng
• Thử lại sau 10-15 giây''';
      });
    } catch (e) {
      print('❌ Test connection error: $e');
      setState(() {
        statusMessage = '''❌ Không thể kết nối thiết bị IoT

� HƯỚNG DẪN CHI TIẾT:

1️⃣ Bật thiết bị IoT:
   • Cắm nguồn thiết bị
   • Đợi LED sáng/nhấp nháy

2️⃣ Tìm WiFi của thiết bị:
   • Vào Cài đặt → WiFi điện thoại
   • Tìm tên như: "ESP32-Setup"
   • Hoặc: "Device-Config", "IoT-Device"

3️⃣ Kết nối WiFi thiết bị:
   • Chọn WiFi của thiết bị
   • Mật khẩu: thường "123456789"
   • Hoặc để trống

4️⃣ Test bằng Chrome:
   • Mở trình duyệt
   • Vào: http://192.168.4.1
   • Thấy trang cài đặt = OK!

5️⃣ Quay lại app và thử lại

⚠️ Lỗi chi tiết: $e''';
      });
    }
  }

  // Cài đặt WiFi cho thiết bị (giả lập trình duyệt)
  Future<void> _setupDeviceWiFi() async {
    if (selectedWiFi == null || passwordController.text.isEmpty) {
      _showMessage('❌ Lỗi: Chưa chọn WiFi hoặc chưa nhập mật khẩu');
      return;
    }
    
    setState(() {
      isSettingUp = true;
      statusMessage = 'Đang cài đặt WiFi cho thiết bị...';
    });
    
    try {
      // Tạo URL với parameters (không encode để giống trình duyệt)
      final ssid = selectedWiFi!.ssid;
      final password = passwordController.text;
      final url = 'http://192.168.4.1/setting?ssid=$ssid&pass=$password';
      
      // Log URL để debug
      print('🔗 URL cài đặt WiFi: $url');
      print('📡 SSID: $ssid');
      print('🔑 Password: ${password.isNotEmpty ? '***[${password.length} ký tự]***' : '[trống]'}');
      
      setState(() {
        statusMessage = 'Đang gửi cài đặt đến thiết bị...\n🌐 Giả lập Chrome browser...';
      });
      
      // Giả lập Chrome browser với headers đơn giản hơn (như khi gõ URL trực tiếp)
      final response = await http.get(
        Uri.parse(url),
        headers: {
          // Headers cơ bản giống Chrome khi gõ URL trực tiếp
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9,vi;q=0.8',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
          // Không dùng Referer và Origin để giống việc gõ URL trực tiếp
        },
      ).timeout(const Duration(seconds: 15)); // Giảm timeout xuống 15s
      
      print('📡 Response status: ${response.statusCode}');
      print('📡 Response headers: ${response.headers}');
      print('📡 Response body: ${response.body}');
      
      // Phân tích response từ thiết bị
      if (response.statusCode == 200) {
        final responseBody = response.body.toLowerCase();
        
        // Kiểm tra các từ khóa trong response để xác định thành công
        if (responseBody.contains('success') || 
            responseBody.contains('ok') || 
            responseBody.contains('saved') ||
            responseBody.contains('configured') ||
            responseBody.contains('connected') ||
            responseBody.contains('done') ||
            responseBody.trim().isEmpty) { // Một số thiết bị trả về empty response khi thành công
          
          setState(() {
            statusMessage = '✅ Cài đặt WiFi thành công!\n📡 Thiết bị đã nhận được thông tin WiFi\n🔄 Đang chờ thiết bị khởi động lại...';
          });
          
          // Chờ thiết bị khởi động lại
          await _waitForDeviceRestart();
          
        } else {
          // Response không chứa từ khóa thành công, nhưng vẫn có thể thành công
          setState(() {
            statusMessage = '✅ Đã gửi cài đặt thành công!\n📄 Response: ${response.body.length > 100 ? response.body.substring(0, 100) + "..." : response.body}\n🔄 Đang chờ thiết bị khởi động lại...';
          });
          
          // Vẫn thử chờ restart vì có thể thiết bị vẫn hoạt động
          await Future.delayed(const Duration(seconds: 3));
          await _waitForDeviceRestart();
        }
        
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        // Thiết bị redirect - thường là dấu hiệu tốt
        setState(() {
          statusMessage = '🔄 Thiết bị redirect (${response.statusCode})\n✅ Có thể đã nhận được cài đặt\n⏳ Đang chờ khởi động lại...';
        });
        await _waitForDeviceRestart();
        
      } else if (response.statusCode == 404) {
        setState(() {
          statusMessage = '❌ Lỗi 404: Thiết bị không hỗ trợ endpoint /setting\n\n💡 Thử kiểm tra:\n• Thiết bị có đúng là loại hỗ trợ cài đặt qua web?\n• URL có đúng không?';
        });
        
      } else {
        setState(() {
          statusMessage = '❌ Lỗi HTTP ${response.statusCode}\n📄 Response: ${response.body.length > 100 ? response.body.substring(0, 100) + "..." : response.body}';
        });
        print('❌ HTTP Error: ${response.statusCode} - ${response.body}');
      }
      
    } on TimeoutException {
      // Timeout có thể là dấu hiệu thiết bị đã khởi động lại
      print('⏰ Timeout - thiết bị có thể đang khởi động lại');
      setState(() {
        statusMessage = '⏰ Timeout kết nối (15s)\n🤔 Có thể thiết bị đã nhận được cài đặt và đang khởi động lại...\n🔍 Đang kiểm tra...';
      });
      await _waitForDeviceRestart();
      
    } on SocketException catch (e) {
      print('❌ Socket error: $e');
      setState(() {
        statusMessage = '❌ Lỗi kết nối mạng: $e\n\n💡 Kiểm tra:\n• Đã kết nối WiFi thiết bị?\n• Thiết bị ở địa chỉ 192.168.4.1?\n• Thiết bị có đang ở chế độ AP?';
      });
      
    } catch (e) {
      print('❌ Lỗi cài đặt WiFi: $e');
      setState(() {
        statusMessage = '❌ Lỗi không xác định: $e\n\n💡 Thử lại hoặc kiểm tra kết nối';
      });
    } finally {
      setState(() {
        isSettingUp = false;
      });
    }
  }

  // Chờ thiết bị khởi động lại (thay thế _waitForDeviceDisconnection)
  Future<void> _waitForDeviceRestart() async {
    int attempts = 0;
    const maxAttempts = 30; // 30 giây
    bool deviceDisconnected = false;
    
    setState(() {
      statusMessage = '🔄 Đang chờ thiết bị khởi động lại...\n⏳ Kiểm tra kết nối...';
    });
    
    // Giai đoạn 1: Chờ thiết bị ngắt kết nối (tối đa 15 giây)
    while (attempts < 15 && !deviceDisconnected) {
      try {
        await Future.delayed(const Duration(seconds: 1));
        attempts++;
        
        // Thử ping thiết bị với timeout ngắn
        final response = await http.get(
          Uri.parse('http://192.168.4.1'),
          headers: {'User-Agent': 'IoT-App-Ping/1.0'},
        ).timeout(const Duration(seconds: 2));
        
        setState(() {
          statusMessage = '🔄 Thiết bị vẫn phản hồi...\n⏳ Chờ khởi động lại (${attempts}s)';
        });
        
      } catch (e) {
        // Không kết nối được = thiết bị đã ngắt kết nối
        deviceDisconnected = true;
        setState(() {
          statusMessage = '✅ Thiết bị đã ngắt kết nối!\n🎉 Cài đặt WiFi thành công\n📶 Thiết bị đang kết nối WiFi mới...';
        });
        break;
      }
    }
    
    if (!deviceDisconnected) {
      setState(() {
        statusMessage = '⚠️ Thiết bị vẫn phản hồi sau ${attempts}s\n🤔 Có thể cài đặt chưa thành công hoặc thiết bị chưa restart';
      });
    }
    
    // Hiển thị dialog kết quả
    _showSetupResultDialog(deviceDisconnected);
  }

  // Chờ thiết bị ngắt kết nối
  Future<void> _waitForDeviceDisconnection() async {
    int attempts = 0;
    const maxAttempts = 30; // 30 giây
    
    while (attempts < maxAttempts) {
      try {
        // Thử ping thiết bị
        final response = await http.get(
          Uri.parse('http://192.168.4.1'),
        ).timeout(const Duration(seconds: 2));
        
        // Nếu vẫn kết nối được, tiếp tục chờ
        await Future.delayed(const Duration(seconds: 1));
        attempts++;
        
        setState(() {
          statusMessage = 'Đang chờ thiết bị khởi động lại... (${attempts}s)';
        });
      } catch (e) {
        // Không kết nối được = thiết bị đã ngắt kết nối
        setState(() {
          statusMessage = 'Cài đặt WiFi cho thiết bị thành công!\nThiết bị đã khởi động lại với WiFi mới.';
        });
        
        // Hiển thị dialog thành công
        _showSuccessDialog();
        return;
      }
    }
    
    // Timeout
    setState(() {
      statusMessage = 'Cài đặt có thể đã thành công.\nVui lòng kiểm tra thiết bị.';
    });
  }

  // Hiển thị dialog kết quả cài đặt
  void _showSetupResultDialog(bool success) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.warning,
              color: success ? Colors.green : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(success ? 'Cài Đặt Thành Công!' : 'Cài Đặt Hoàn Tất'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (success) ...[
              const Text('🎉 Thiết bị đã nhận được thông tin WiFi'),
              const SizedBox(height: 8),
              const Text('📶 Thiết bị đang kết nối đến WiFi mới'),
              const SizedBox(height: 8),
              Text('🌐 WiFi: ${selectedWiFi?.ssid ?? ""}'),
              const SizedBox(height: 16),
              const Text(
                '✨ Bước tiếp theo:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('1. Kết nối điện thoại về WiFi nhà'),
              const Text('2. Mở app để tìm thiết bị trên mạng'),
              const Text('3. Thêm thiết bị vào danh sách'),
            ] else ...[
              const Text('⚠️ Không rõ trạng thái thiết bị'),
              const SizedBox(height: 8),
              const Text('🔧 Khuyến nghị:'),
              const SizedBox(height: 4),
              const Text('• Kiểm tra thiết bị có LED báo trạng thái'),
              const Text('• Thử kết nối điện thoại về WiFi nhà'),
              const Text('• Kiểm tra thiết bị có xuất hiện trên mạng'),
            ],
          ],
        ),
        actions: [
          if (!success)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Thử lại cài đặt
                _setupDeviceWiFi();
              },
              child: const Text('Thử Lại'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Về trang chính hoặc trang thiết bị
              Navigator.of(context).pushReplacementNamed('/home');
            },
            child: const Text('Hoàn Thành'),
          ),
        ],
      ),
    );
  }

  // Hiển thị dialog thành công
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Thành Công!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text('Cài đặt WiFi cho thiết bị thành công!'),
            const SizedBox(height: 8),
            Text('WiFi: ${selectedWiFi?.ssid}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Đóng dialog
              Navigator.of(context).pop(); // Quay về màn hình trước
            },
            child: const Text('Hoàn Thành'),
          ),
        ],
      ),
    );
  }

  // Hiển thị thông báo
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Lấy icon WiFi theo cường độ tín hiệu
  IconData _getWiFiIcon(int level) {
    if (level > -50) return Icons.wifi;
    if (level > -60) return Icons.wifi_2_bar;
    if (level > -70) return Icons.wifi_1_bar;
    return Icons.wifi_off;
  }

  // Lấy màu theo cường độ tín hiệu
  Color _getSignalColor(int level) {
    if (level > -50) return Colors.green;
    if (level > -60) return Colors.orange;
    if (level > -70) return Colors.red;
    return Colors.grey;
  }

  // Lấy tần số band
  String _getFrequencyBand(int frequency) {
    if (frequency < 3000) return '2.4GHz';
    return '5GHz';
  }
}
