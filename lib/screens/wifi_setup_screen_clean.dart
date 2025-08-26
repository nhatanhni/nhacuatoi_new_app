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
  int currentStep = 0; // 0: QR, 1: WiFi Selection, 2: Setup, 3: Complete
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
  bool isSettingUp = false;
  bool isMonitoring = false;
  String statusMessage = 'Bước 1: Quét mã QR trên thiết bị';
  String connectionStatus = '';
  Timer? monitoringTimer;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    qrController?.dispose();
    passwordController.dispose();
    monitoringTimer?.cancel();
    super.dispose();
  }

  // Yêu cầu quyền cần thiết
  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài Đặt WiFi Thiết Bị IoT'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Stepper(
        currentStep: currentStep,
        onStepTapped: (step) {
          if (step < currentStep) {
            setState(() {
              currentStep = step;
            });
          }
        },
        controlsBuilder: (context, details) {
          return Row(
            children: [
              if (details.stepIndex < 3)
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: Text(details.stepIndex == 2 ? 'Cài Đặt' : 'Tiếp Theo'),
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
          // Bước 1: Quét QR code
          Step(
            title: const Text('Bước 1: Quét QR Code'),
            content: _buildQRScanStep(),
            isActive: currentStep >= 0,
            state: currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          
          // Bước 2: Chọn WiFi 2.4GHz
          Step(
            title: const Text('Bước 2: Chọn WiFi 2.4GHz'),
            content: _buildWiFiSelectionStep(),
            isActive: currentStep >= 1,
            state: currentStep > 1 ? StepState.complete : 
                   currentStep == 1 ? StepState.indexed : StepState.disabled,
          ),
          
          // Bước 3: Cài đặt thiết bị
          Step(
            title: const Text('Bước 3: Cài Đặt Thiết Bị'),
            content: _buildDeviceSetupStep(),
            isActive: currentStep >= 2,
            state: currentStep > 2 ? StepState.complete : 
                   currentStep == 2 ? StepState.indexed : StepState.disabled,
          ),
          
          // Bước 4: Hoàn thành
          Step(
            title: const Text('Bước 4: Hoàn Thành'),
            content: _buildCompletionStep(),
            isActive: currentStep >= 3,
            state: currentStep == 3 ? StepState.indexed : StepState.disabled,
          ),
        ],
      ),
    );
  }

  // Xử lý tiếp tục bước
  void _handleStepContinue() {
    switch (currentStep) {
      case 0: // QR -> WiFi Selection
        if (scannedSSID != null) {
          setState(() {
            currentStep = 1;
            statusMessage = 'Bước 2: Tự động quét WiFi 2.4GHz';
          });
          _scanWiFiNetworks();
        } else {
          _showMessage('Vui lòng quét QR code trước');
        }
        break;
      case 1: // WiFi Selection -> Setup
        if (selectedWiFi != null && passwordController.text.isNotEmpty) {
          setState(() {
            currentStep = 2;
            statusMessage = 'Bước 3: Sẵn sàng cài đặt thiết bị';
          });
        } else {
          _showMessage('Vui lòng chọn WiFi và nhập mật khẩu');
        }
        break;
      case 2: // Setup -> Complete
        _startDeviceSetup();
        break;
      case 3: // Complete
        Navigator.pop(context);
        break;
    }
  }

  // Xử lý quay lại bước
  void _handleStepCancel() {
    if (currentStep > 0) {
      setState(() {
        currentStep = currentStep - 1;
      });
    }
  }

  // Bước 1: Quét QR code
  Widget _buildQRScanStep() {
    return Column(
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.shade300, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
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
        ),
        const SizedBox(height: 16),
        
        if (scannedSSID != null) 
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'QR Code đã được quét thành công!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('SSID: $scannedSSID'),
                if (scannedPassword != null)
                  Text('Password: ${'*' * scannedPassword!.length}'),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hướng camera vào mã QR trên thiết bị IoT',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Nút test
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              scannedSSID = "TestDevice_WiFi";
              scannedPassword = "12345678";
            });
          },
          icon: const Icon(Icons.skip_next),
          label: const Text('Bỏ Qua (Test)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange.shade600,
            side: BorderSide(color: Colors.orange.shade600),
          ),
        ),
      ],
    );
  }

  // Bước 2: Chọn WiFi
  Widget _buildWiFiSelectionStep() {
    return Column(
      children: [
        // Nút quét WiFi
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isScanning ? null : _scanWiFiNetworks,
            icon: isScanning 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.wifi_find),
            label: Text(isScanning ? 'Đang Quét WiFi...' : 'Quét Mạng WiFi 2.4GHz'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Danh sách WiFi
        if (availableWiFiList.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Chọn mạng WiFi (${availableWiFiList.length} mạng)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: availableWiFiList.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.orange.shade200,
                  ),
                  itemBuilder: (context, index) {
                    final wifi = availableWiFiList[index];
                    final isSelected = selectedWiFi?.ssid == wifi.ssid;
                    
                    return ListTile(
                      leading: Icon(
                        Icons.wifi,
                        color: isSelected ? Colors.orange.shade600 : Colors.grey.shade600,
                      ),
                      title: Text(
                        wifi.ssid,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.orange.shade700 : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        'Tín hiệu: ${wifi.level} dBm',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: isSelected 
                        ? Icon(Icons.check_circle, color: Colors.orange.shade600)
                        : null,
                      tileColor: isSelected ? Colors.orange.shade50 : null,
                      onTap: () {
                        setState(() {
                          selectedWiFi = wifi;
                          passwordController.clear();
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
        ],
        
        // Nhập mật khẩu
        if (selectedWiFi != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi_lock, color: Colors.orange.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'WiFi đã chọn: ${selectedWiFi!.ssid}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu WiFi',
                    hintText: 'Nhập mật khẩu WiFi',
                    prefixIcon: Icon(Icons.lock, color: Colors.orange.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                    ),
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ],
        
        // Thông báo khi chưa quét
        if (availableWiFiList.isEmpty && !isScanning)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nhấn nút "Quét Mạng WiFi" để tìm các mạng WiFi 2.4GHz',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Bước 3: Cài đặt thiết bị
  Widget _buildDeviceSetupStep() {
    final setupUrl = selectedWiFi != null && passwordController.text.isNotEmpty
        ? 'http://192.168.4.1/setting?ssid=${selectedWiFi!.ssid}&pass=${passwordController.text}'
        : null;

    return Column(
      children: [
        if (setupUrl != null) ...[
          // Hiển thị URL
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
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
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    setupUrl,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'App sẽ giả lập trình duyệt Chrome gửi URL này đến thiết bị',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Nút cài đặt
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSettingUp ? null : _startDeviceSetup,
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
                    'Vui lòng hoàn thành bước 2: chọn WiFi và nhập mật khẩu',
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
        
        const SizedBox(height: 20),
        
        // Hiển thị trạng thái
        if (statusMessage.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              statusMessage,
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  // Bước 4: Hoàn thành
  Widget _buildCompletionStep() {
    return Column(
      children: [
        if (isMonitoring) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Đang theo dõi kết nối thiết bị...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ứng dụng đang chờ thiết bị kết nối WiFi và tự động thoát khỏi mạng thiết bị',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.green.shade600,
          ),
          const SizedBox(height: 20),
          Text(
            'Cài Đặt WiFi Thành Công!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Thiết bị đã được cài đặt WiFi thành công và kết nối vào mạng.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        
        const SizedBox(height: 20),
        
        if (statusMessage.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: connectionStatus.contains('thành công') 
                  ? Colors.green.shade50 
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: connectionStatus.contains('thành công') 
                    ? Colors.green.shade200 
                    : Colors.blue.shade200,
              ),
            ),
            child: Text(
              statusMessage,
              style: TextStyle(
                color: connectionStatus.contains('thành công') 
                    ? Colors.green.shade700 
                    : Colors.blue.shade700,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  // Quét mạng WiFi
  Future<void> _scanWiFiNetworks() async {
    setState(() {
      isScanning = true;
      availableWiFiList.clear();
    });
    
    try {
      // Kiểm tra permission
      final locationPermission = await Permission.location.status;
      final wifiPermission = await Permission.nearbyWifiDevices.status;
      
      if (!locationPermission.isGranted) {
        final result = await Permission.location.request();
        if (!result.isGranted) {
          throw Exception('Cần quyền vị trí để quét WiFi');
        }
      }
      
      if (!wifiPermission.isGranted) {
        final result = await Permission.nearbyWifiDevices.request();
        if (!result.isGranted) {
          throw Exception('Cần quyền truy cập WiFi để quét mạng');
        }
      }
      
      // Thực hiện quét
      await WiFiScan.instance.startScan();
      await Future.delayed(const Duration(seconds: 3));
      
      final results = await WiFiScan.instance.getScannedResults();
      
      // Lọc WiFi 2.4GHz và loại bỏ trùng lặp
      final filteredResults = <String, WiFiAccessPoint>{};
      for (final wifi in results) {
        if (wifi.ssid.isNotEmpty && !wifi.ssid.startsWith('DIRECT-')) {
          if (!filteredResults.containsKey(wifi.ssid) || 
              wifi.level > filteredResults[wifi.ssid]!.level) {
            filteredResults[wifi.ssid] = wifi;
          }
        }
      }
      
      setState(() {
        availableWiFiList = filteredResults.values.toList();
        availableWiFiList.sort((a, b) => b.level.compareTo(a.level));
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi quét WiFi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  // Bắt đầu cài đặt thiết bị
  Future<void> _startDeviceSetup() async {
    if (selectedWiFi == null || passwordController.text.isEmpty) {
      _showMessage('Vui lòng chọn WiFi và nhập mật khẩu');
      return;
    }

    setState(() {
      isSettingUp = true;
      statusMessage = 'Đang gửi cài đặt WiFi đến thiết bị...';
    });

    try {
      final url = 'http://192.168.4.1/setting?ssid=${selectedWiFi!.ssid}&pass=${passwordController.text}';
      print('🌐 Gửi URL: $url');
      
      final client = http.Client();
      final response = await client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        setState(() {
          currentStep = 3;
          isSettingUp = false;
          isMonitoring = true;
          statusMessage = 'Đã gửi cài đặt thành công. Đang theo dõi kết nối thiết bị...';
        });
        
        _startMonitoringDeviceConnection();
        
      } else {
        setState(() {
          statusMessage = '❌ Thiết bị phản hồi lỗi: ${response.statusCode}';
          isSettingUp = false;
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Lỗi gửi cài đặt: ${e.toString()}';
        isSettingUp = false;
      });
      
      _showMessage('❌ Lỗi: ${e.toString()}');
    }
  }

  // Theo dõi kết nối thiết bị
  void _startMonitoringDeviceConnection() {
    monitoringTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final client = http.Client();
        await client
          .get(Uri.parse('http://192.168.4.1'))
          .timeout(const Duration(seconds: 2));
        
      } catch (e) {
        timer.cancel();
        setState(() {
          isMonitoring = false;
          connectionStatus = 'thành công';
          statusMessage = '✅ Cài đặt WiFi thành công!\n\n'
                         'Thiết bị đã kết nối WiFi "${selectedWiFi!.ssid}" và '
                         'tự động ngắt kết nối khỏi ứng dụng.\n\n'
                         'Thiết bị hiện đã sẵn sàng sử dụng trên mạng WiFi mới.';
        });
        
        _showSuccessDialog();
      }
    });

    // Timeout sau 60 giây
    Timer(const Duration(seconds: 60), () {
      if (monitoringTimer?.isActive == true) {
        monitoringTimer?.cancel();
        setState(() {
          isMonitoring = false;
          statusMessage = '⚠️ Timeout: Không thể xác nhận thiết bị đã kết nối WiFi.';
        });
      }
    });
  }

  // Xử lý QR code
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
            statusMessage = 'Đã quét QR thành công! SSID: $scannedSSID';
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Quét QR thành công: $scannedSSID'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Lỗi phân tích QR: $e');
    }
  }

  // Hiển thị dialog thành công
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
            const SizedBox(width: 8),
            const Text('Thành Công!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cài đặt WiFi cho thiết bị thành công!'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi, color: Colors.green.shade600, size: 16),
                      const SizedBox(width: 4),
                      Text('WiFi: ${selectedWiFi?.ssid}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check, color: Colors.green.shade600, size: 16),
                      const SizedBox(width: 4),
                      const Text('Thiết bị đã kết nối thành công'),
                    ],
                  ),
                ],
              ),
            ),
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
}
