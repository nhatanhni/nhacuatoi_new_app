import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const IoTApp());
}

class IoTApp extends StatelessWidget {
  const IoTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Control App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WebHomeScreen(),
        '/devices': (context) => const DeviceListScreen(),
        '/device_list': (context) => const DeviceListScreen(),
        '/add-device': (context) => const AddDeviceScreen(),
      },
    );
  }
}

class WebHomeScreen extends StatelessWidget {
  const WebHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Control App'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[50]!,
              Colors.blue[100]!,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.devices,
                size: 100,
                color: Colors.blue[600],
              ),
              const SizedBox(height: 20),
              Text(
                'IoT Control App',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Quản lý thiết bị IoT',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.blue[600],
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/devices');
                },
                icon: const Icon(Icons.list),
                label: const Text('Danh sách thiết bị'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/add-device');
                },
                icon: const Icon(Icons.add),
                label: const Text('Thêm thiết bị'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  List<Map<String, dynamic>> devices = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceKeys = prefs.getKeys().where((key) => key.startsWith('device_')).toList();
      
      List<Map<String, dynamic>> loadedDevices = [];
      for (String key in deviceKeys) {
        final deviceName = prefs.getString(key);
        if (deviceName != null) {
          loadedDevices.add({
            'id': key.replaceFirst('device_', ''),
            'name': deviceName,
            'status': prefs.getBool('${key}_status') ?? false,
          });
        }
      }
      
      setState(() {
        devices = loadedDevices;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _toggleDevice(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = devices[index]['id'];
      final currentStatus = devices[index]['status'] as bool;
      final newStatus = !currentStatus;
      
      await prefs.setBool('device_${deviceId}_status', newStatus);
      
      setState(() {
        devices[index]['status'] = newStatus;
      });
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách thiết bị'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD), // Light blue
              Color(0xFFBBDEFB), // Lighter blue
              Color(0xFF2196F3), // Strong blue
            ],
          ),
        ),
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 20),
                    Text(
                      'Đang tải thiết bị...',
                      style: TextStyle(fontSize: 18, color: Colors.blue),
                    ),
                  ],
                ),
              )
            : devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.devices_other,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Chưa có thiết bị nào',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/add-device');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm thiết bị'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 3,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: device['status'] ? Colors.green : Colors.grey,
                            child: Icon(
                              device['status'] ? Icons.power : Icons.power_off,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            device['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            device['status'] ? 'Đang hoạt động' : 'Tắt',
                            style: TextStyle(
                              color: device['status'] ? Colors.green : Colors.grey,
                            ),
                          ),
                          trailing: Switch(
                            value: device['status'],
                            onChanged: (value) => _toggleDevice(index),
                            activeColor: Colors.green,
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add-device').then((_) => _loadDevices());
        },
        backgroundColor: Colors.green[600],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _addDevice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      
      await prefs.setString('device_$deviceId', _nameController.text);
      await prefs.setBool('device_${deviceId}_status', false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã thêm thiết bị thành công'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Có lỗi xảy ra khi thêm thiết bị'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm thiết bị'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[50]!,
              Colors.blue[100]!,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thông tin thiết bị',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Tên thiết bị',
                            hintText: 'Nhập tên thiết bị',
                            prefixIcon: const Icon(Icons.devices),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập tên thiết bị';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _addDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Thêm thiết bị'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
