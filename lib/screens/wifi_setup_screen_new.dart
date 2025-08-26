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
  String statusMessage = 'Sẵn sàng quét mã QR thiết bị';
  String connectionStatus = '';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWiFiScanCapability();
    });
  }

  @override
  void dispose() {
    qrController?.dispose();
    passwordController.dispose();
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

  // Kiểm tra khả năng quét WiFi
  Future<void> _checkWiFiScanCapability() async {
    try {
      final can = await WiFiScan.instance.canGetScannedResults();
      print('Khả năng quét WiFi: $can');
      
      if (can == CanGetScannedResults.yes) {
        print('✅ Có thể quét WiFi');
      } else {
        print('❌ Không thể quét WiFi: $can');
      }
    } catch (e) {
      print('Lỗi kiểm tra khả năng quét WiFi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài Đặt WiFi Thiết Bị IoT'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStepIndicator(),
            const SizedBox(height: 20),
            _buildCurrentStepContent(),
          ],
        ),
      ),
    );
  }

  // Chỉ báo bước
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepCircle(0, 'QR', Colors.blue),
        Expanded(child: _buildStepLine(currentStep > 0)),
        _buildStepCircle(1, 'WiFi', Colors.orange),
        Expanded(child: _buildStepLine(currentStep > 1)),
        _buildStepCircle(2, 'Setup', Colors.green),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label, Color color) {
    final isActive = currentStep >= step;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? color : Colors.grey.shade300,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          step == 0 ? 'Quét QR' : step == 1 ? 'Chọn WiFi' : 'Cài Đặt',
          style: TextStyle(
            fontSize: 10,
            color: isActive ? color : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Container(
      height: 2,
      color: isActive ? Colors.green : Colors.grey.shade300,
    );
  }

  // Nội dung bước hiện tại
  Widget _buildCurrentStepContent() {
    switch (currentStep) {
      case 0:
        return _buildQRScanStep();
      case 1:
        return _buildWiFiSelectionStep();
      case 2:
        return _buildDeviceSetupStep();
      default:
        return _buildQRScanStep();
    }
  }

  // Bước 1: Quét QR code
  Widget _buildQRScanStep() {
    return Column(
      children: [
        Text(
          'Bước 1: Quét Mã QR Thiết Bị',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Quét mã QR trên thiết bị IoT để lấy thông tin kết nối',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        
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
        
        const SizedBox(height: 20),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hướng camera vào mã QR trên thiết bị IoT để quét thông tin WiFi',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Nút bỏ qua để test
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              currentStep = 1;
              statusMessage = 'Đã bỏ qua quét QR - chuyển sang chọn WiFi';
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
        Text(
          'Bước 2: Chọn WiFi 2.4GHz',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Chọn mạng WiFi 2.4GHz và nhập mật khẩu',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        
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
            label: Text(isScanning ? 'Đang Quét...' : 'Quét Mạng WiFi 2.4GHz'),
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
                        'Tín hiệu: ${wifi.level} dBm • ${_getWiFiSecurityText(wifi)}',
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
        
        // Nhập mật khẩu WiFi
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
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.visibility_off),
                      onPressed: () {
                        // Toggle hiển thị mật khẩu
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.orange.shade300),
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
          
          const SizedBox(height: 20),
          
          // Nút tiếp tục
          if (passwordController.text.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    currentStep = 2;
                    statusMessage = 'Sẵn sàng cài đặt WiFi cho thiết bị';
                  });
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Tiếp Tục Cài Đặt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
        
        // Thông báo khi chưa chọn WiFi
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
                    'Nhấn nút "Quét Mạng WiFi" để tìm các mạng WiFi 2.4GHz có sẵn',
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
    return Column(
      children: [
        if (isSettingUp)
          const CircularProgressIndicator(),
        const SizedBox(height: 16),
        
        Text(
          'Bước 3: Cài Đặt WiFi Cho Thiết Bị',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
        
        const SizedBox(height: 12),
        
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
        
        const SizedBox(height: 20),
        
        if (selectedWiFi != null && passwordController.text.isNotEmpty) ...[
          // Thông tin cài đặt
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
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Icon(Icons.wifi, color: Colors.green.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'WiFi: ${selectedWiFi!.ssid}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Icon(Icons.lock, color: Colors.green.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mật khẩu: ${'*' * passwordController.text.length}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Hiển thị URL sẽ được gửi
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
                    'http://192.168.4.1/setting?ssid=${selectedWiFi!.ssid}&pass=${passwordController.text}',
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
          
          // Nút test kết nối
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
          
          // Nút cài đặt chính
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
                    'Vui lòng chọn WiFi và nhập mật khẩu ở bước trước',
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
      
      print('📍 Location permission: $locationPermission');
      print('📶 WiFi permission: $wifiPermission');
      
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
      
      // Kiểm tra GPS
      final isLocationEnabled = await Permission.location.serviceStatus.isEnabled;
      if (!isLocationEnabled) {
        throw Exception('Vui lòng bật GPS để quét WiFi');
      }
      
      print('🔍 Bắt đầu quét WiFi...');
      
      // Thực hiện quét
      await WiFiScan.instance.startScan();
      await Future.delayed(const Duration(seconds: 3));
      
      final results = await WiFiScan.instance.getScannedResults();
      print('📶 Tìm thấy ${results.length} mạng WiFi');
      
      // Lọc WiFi 2.4GHz và loại bỏ trùng lặp
      final filteredResults = <String, WiFiAccessPoint>{};
      for (final wifi in results) {
        if (wifi.ssid.isNotEmpty && !wifi.ssid.startsWith('DIRECT-')) {
          // Ưu tiên WiFi có tín hiệu mạnh hơn
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
      
      print('✅ Quét WiFi hoàn tất: ${availableWiFiList.length} mạng');
      
    } catch (e) {
      print('❌ Lỗi quét WiFi: $e');
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

  // Test kết nối thiết bị
  Future<void> _testDeviceConnection() async {
    setState(() {
      connectionStatus = 'Đang test kết nối...';
    });
    
    try {
      final client = http.Client();
      final response = await client
        .get(Uri.parse('http://192.168.4.1'))
        .timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        setState(() {
          connectionStatus = 'Kết nối thiết bị thành công!';
        });
      } else {
        setState(() {
          connectionStatus = 'Thiết bị phản hồi mã: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        connectionStatus = '''❌ Lỗi kết nối: ${e.toString()}

🔧 Hướng dẫn khắc phục:
1. Bật thiết bị IoT và đợi đèn nhấp nháy
2. Vào Settings > WiFi trên điện thoại
3. Tìm và kết nối với WiFi có tên như "ESP_xxxx" hoặc "IoT_Device"
4. Nhập mật khẩu nếu có (thường là "12345678")
5. Quay lại app và thử test lại''';
      });
    }
  }

  // Cài đặt WiFi cho thiết bị
  Future<void> _setupDeviceWiFi() async {
    if (selectedWiFi == null || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn WiFi và nhập mật khẩu'),
          backgroundColor: Colors.red,
        ),
      );
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
      
      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        setState(() {
          statusMessage = '✅ Cài đặt WiFi thành công!\n\nThiết bị đang kết nối WiFi "${selectedWiFi!.ssid}".\nVui lòng đợi thiết bị khởi động lại.';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cài đặt WiFi thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          statusMessage = '❌ Thiết bị phản hồi lỗi: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '''❌ Lỗi gửi cài đặt: ${e.toString()}

🔧 Hướng dẫn khắc phục:
1. Kiểm tra kết nối WiFi với thiết bị IoT
2. Đảm bảo thiết bị ở chế độ AP (Access Point)
3. Thử test kết nối trước khi cài đặt
4. Kiểm tra tên WiFi và mật khẩu''';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSettingUp = false;
      });
    }
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
            currentStep = 1;
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

  // Lấy text bảo mật WiFi
  String _getWiFiSecurityText(WiFiAccessPoint wifi) {
    if (wifi.capabilities.contains('WPA3')) return 'WPA3';
    if (wifi.capabilities.contains('WPA2')) return 'WPA2';
    if (wifi.capabilities.contains('WPA')) return 'WPA';
    if (wifi.capabilities.contains('WEP')) return 'WEP';
    return 'Open';
  }
}
