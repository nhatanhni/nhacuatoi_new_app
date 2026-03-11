import 'package:flutter/material.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/database/database_helper.dart' if (dart.library.html) 'package:iot_app/database/web_database_helper.dart';

class PumpStationManagementScreen extends StatefulWidget {
  final PumpStationDevice pumpStation;
  final Device parentDevice;

  const PumpStationManagementScreen({
    Key? key,
    required this.pumpStation,
    required this.parentDevice,
  }) : super(key: key);

  @override
  _PumpStationManagementScreenState createState() => _PumpStationManagementScreenState();
}

class _PumpStationManagementScreenState extends State<PumpStationManagementScreen> {
  List<SubDevice> _subDevices = [];
  List<WaterLevelSensor> _waterSensors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubDevices();
  }

  Future<void> _loadSubDevices() async {
    try {
      print('🔄 Loading sub-devices for parent ID: ${widget.parentDevice.id}');
      
      final subDevices = await DatabaseHelper.instance.querySubDevicesByParentId(widget.parentDevice.id!);
      final waterSensors = await DatabaseHelper.instance.queryWaterLevelSensorsByParentId(widget.parentDevice.id!);
      
      print('📊 Loaded ${subDevices.length} sub-devices and ${waterSensors.length} water sensors');
      
      // Debug sub devices
      for (var device in subDevices) {
        print('   - Sub Device: ID=${device.id}, Type=${device.subDeviceType}, Number=${device.subDeviceNumber}, Name=${device.deviceName}, Serial=${device.deviceSerial}');
      }
      
      // Debug water sensors
      for (var sensor in waterSensors) {
        print('   - Water Sensor: ID=${sensor.id}, Name=${sensor.name}, Serial=${sensor.serial}, Level=${sensor.currentWaterLevel}');
      }
      
      setState(() {
        _subDevices = subDevices;
        _waterSensors = waterSensors;
        _isLoading = false;
      });
      
      print('✅ State updated with ${_subDevices.length} sub-devices and ${_waterSensors.length} water sensors');
    } catch (e) {
      print('❌ Error loading sub-devices: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddSubDeviceDialog() {
    String selectedType = 'pump';
    final serialController = TextEditingController();
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    final maxCapacityController = TextEditingController(text: '100.0');
    final minThresholdController = TextEditingController(text: '10.0');
    final maxThresholdController = TextEditingController(text: '90.0');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Thêm Thiết Bị Con'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Device Type Selection
                    Text(
                      'Loại thiết bị:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(value: 'pump', child: Text('Máy bơm')),
                        DropdownMenuItem(value: 'gate', child: Text('Cổng phai')),
                        DropdownMenuItem(value: 'water_sensor', child: Text('Cảm biến mực nước')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    
                    // Device Number (for pump and gate)
                    if (selectedType != 'water_sensor') ...[
                      TextFormField(
                        controller: numberController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Số thứ tự',
                          border: OutlineInputBorder(),
                          hintText: 'Nhập số thứ tự',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                    
                    // Serial Number
                    TextFormField(
                      controller: serialController,
                      decoration: InputDecoration(
                        labelText: 'Số Serial',
                        border: OutlineInputBorder(),
                        hintText: 'Nhập số serial thiết bị',
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Device Name
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Tên thiết bị',
                        border: OutlineInputBorder(),
                        hintText: selectedType == 'pump' 
                            ? 'Máy bơm'
                            : selectedType == 'gate'
                                ? 'Cổng phai'
                                : 'Nhập tên thiết bị',
                      ),
                    ),
                    
                    // Water Level Sensor specific fields
                    if (selectedType == 'water_sensor') ...[
                      SizedBox(height: 16),
                      Text(
                        'Thông số cảm biến mực nước:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      
                      // Max Capacity
                      TextFormField(
                        controller: maxCapacityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Dung tích tối đa (m)',
                          border: OutlineInputBorder(),
                          hintText: '100.0',
                        ),
                      ),
                      SizedBox(height: 12),
                      
                      // Min Threshold
                      TextFormField(
                        controller: minThresholdController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Ngưỡng cảnh báo thấp (m)',
                          border: OutlineInputBorder(),
                          hintText: '10.0',
                        ),
                      ),
                      SizedBox(height: 12),
                      
                      // Max Threshold
                      TextFormField(
                        controller: maxThresholdController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Ngưỡng cảnh báo cao (m)',
                          border: OutlineInputBorder(),
                          hintText: '90.0',
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedType != 'water_sensor' && numberController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập số thứ tự')),
                  );
                  return;
                }

                if (serialController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập số serial')),
                  );
                  return;
                }

                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập tên thiết bị')),
                  );
                  return;
                }

                try {
                  print('🔧 Adding sub device: Type=$selectedType, Serial=${serialController.text.trim()}, Name=${nameController.text.trim()}');
                  
                  if (selectedType == 'water_sensor') {
                    // Validate water sensor parameters
                    final maxCapacity = double.tryParse(maxCapacityController.text);
                    final minThreshold = double.tryParse(minThresholdController.text);
                    final maxThreshold = double.tryParse(maxThresholdController.text);
                    
                    if (maxCapacity == null || minThreshold == null || maxThreshold == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Vui lòng nhập đúng định dạng số cho các thông số')),
                      );
                      return;
                    }
                    
                    if (minThreshold >= maxThreshold || maxThreshold > maxCapacity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ngưỡng cảnh báo không hợp lệ')),
                      );
                      return;
                    }
                    
                    // Get next water sensor number
                    final existingWaterSensors = await DatabaseHelper.instance.querySubDevicesByType(
                      widget.parentDevice.id!,
                      'water_sensor',
                    );
                    final nextNumber = existingWaterSensors.isEmpty ? 1 : existingWaterSensors.length + 1;
                    
                    print('🔧 Adding water sensor with number: $nextNumber');
                    
                    // Add sub device record for water sensor
                    final subDeviceId = await DatabaseHelper.instance.insertSubDevice(
                      widget.parentDevice.id!,
                      'water_sensor',
                      nextNumber,
                    );
                    
                    print('🔧 Sub device created with ID: $subDeviceId');
                    
                    // Update the sub device with serial and name
                    await DatabaseHelper.instance.updateSubDeviceInfo(
                      subDeviceId,
                      serialController.text.trim(),
                      nameController.text.trim(),
                    );
                    
                    print('🔧 Sub device info updated');
                    
                    // Add water level sensor
                    final waterSensor = WaterLevelSensor(
                      deviceSerial: serialController.text.trim(),
                      deviceName: nameController.text.trim(),
                      waterLevel: 0.0,
                      maxCapacity: maxCapacity,
                      minThreshold: minThreshold,
                      maxThreshold: maxThreshold,
                      lastUpdate: DateTime.now(),
                      isActive: true,
                      parentDeviceId: widget.parentDevice.id,
                    );
                    final waterSensorId = await DatabaseHelper.instance.insertWaterLevelSensor(waterSensor);
                    print('✅ Added water level sensor with ID: $waterSensorId');
                  } else {
                    // Validate device number
                    final deviceNumber = int.tryParse(numberController.text);
                    if (deviceNumber == null || deviceNumber <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Số thứ tự phải là số nguyên dương')),
                      );
                      return;
                    }
                    

                    
                    // Add sub device (pump or gate)
                    final subDeviceId = await DatabaseHelper.instance.insertSubDevice(
                      widget.parentDevice.id!,
                      selectedType,
                      deviceNumber,
                    );
                    
                    // Update the sub device with serial and name
                    await DatabaseHelper.instance.updateSubDeviceInfo(
                      subDeviceId,
                      serialController.text.trim(),
                      nameController.text.trim(),
                    );
                    print('✅ Added sub device with ID: $subDeviceId');
                  }
                  
                  Navigator.of(context).pop();
                  await _loadSubDevices();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Thêm thiết bị con thành công')),
                  );
                } catch (e) {
                  print('Error adding sub device: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi khi thêm thiết bị con: $e')),
                  );
                }
              },
              child: Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

  Future<int> _getNextSubDeviceNumber(String type) async {
    final subDevices = await DatabaseHelper.instance.querySubDevicesByType(
      widget.parentDevice.id!,
      type,
    );
    
    if (subDevices.isEmpty) {
      return 1;
    }
    
    final maxNumber = subDevices.map((d) => d.subDeviceNumber).reduce((a, b) => a > b ? a : b);
    return maxNumber + 1;
  }



  void _showEditSubDeviceDialog(SubDevice subDevice) {
    final serialController = TextEditingController(text: subDevice.deviceSerial);
    final nameController = TextEditingController(text: subDevice.deviceName);
    final numberController = TextEditingController(text: subDevice.subDeviceNumber.toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sửa Thiết Bị Con'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: numberController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Số thứ tự',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: serialController,
                  decoration: InputDecoration(
                    labelText: 'Số Serial',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Tên thiết bị',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (numberController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập số thứ tự')),
                  );
                  return;
                }

                if (serialController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập số serial')),
                  );
                  return;
                }

                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập tên thiết bị')),
                  );
                  return;
                }

                try {
                  // Validate device number
                  final deviceNumber = int.tryParse(numberController.text);
                  if (deviceNumber == null || deviceNumber <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Số thứ tự phải là số nguyên dương')),
                    );
                    return;
                  }
                  

                  

                  
                  // Update sub device info
                  await DatabaseHelper.instance.updateSubDeviceInfo(
                    subDevice.id!,
                    serialController.text.trim(),
                    nameController.text.trim(),
                  );
                  
                  // Update device number if changed
                  if (deviceNumber != subDevice.subDeviceNumber) {
                    // We need to update the device number in the database
                    // Since there's no direct method, we'll need to handle this
                    // For now, we'll just show a message that number change is not supported
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Thay đổi số thứ tự chưa được hỗ trợ. Vui lòng xóa và tạo lại thiết bị.')),
                    );
                    return;
                  }
                  
                  Navigator.of(context).pop();
                  await _loadSubDevices();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cập nhật thiết bị con thành công')),
                  );
                } catch (e) {
                  print('Error updating sub device: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi khi cập nhật thiết bị con: $e')),
                  );
                }
              },
              child: Text('Cập nhật'),
            ),
          ],
        );
      },
    );
  }

  void _showEditWaterSensorDialog(WaterLevelSensor sensor) {
    final nameController = TextEditingController(text: sensor.name);
    final maxCapacityController = TextEditingController(text: sensor.maxCapacity.toString());
    final minThresholdController = TextEditingController(text: sensor.minThreshold.toString());
    final maxThresholdController = TextEditingController(text: sensor.maxThreshold.toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sửa Cảm Biến Mực Nước'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Tên cảm biến',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: maxCapacityController,
                  decoration: InputDecoration(
                    labelText: 'Dung tích tối đa (m³)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: minThresholdController,
                  decoration: InputDecoration(
                    labelText: 'Ngưỡng tối thiểu (m³)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: maxThresholdController,
                  decoration: InputDecoration(
                    labelText: 'Ngưỡng tối đa (m³)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập tên cảm biến')),
                  );
                  return;
                }

                try {
                  final maxCapacity = double.tryParse(maxCapacityController.text);
                  final minThreshold = double.tryParse(minThresholdController.text);
                  final maxThreshold = double.tryParse(maxThresholdController.text);
                  
                  if (maxCapacity == null || minThreshold == null || maxThreshold == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Vui lòng nhập đúng định dạng số cho các thông số')),
                    );
                    return;
                  }
                  
                  if (minThreshold >= maxThreshold || maxThreshold > maxCapacity) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ngưỡng cảnh báo không hợp lệ')),
                    );
                    return;
                  }
                  
                  final updatedSensor = sensor.copyWith(
                    deviceName: nameController.text.trim(),
                    maxCapacity: maxCapacity,
                    minThreshold: minThreshold,
                    maxThreshold: maxThreshold,
                  );
                  
                  await DatabaseHelper.instance.updateWaterLevelSensor(updatedSensor);
                  
                  Navigator.of(context).pop();
                  await _loadSubDevices();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cập nhật cảm biến thành công')),
                  );
                } catch (e) {
                  print('Error updating water sensor: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi khi cập nhật cảm biến: $e')),
                  );
                }
              },
              child: Text('Cập nhật'),
            ),
          ],
        );
      },
    );
  }

  void _deleteSubDevice(SubDevice subDevice) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa thiết bị "${(subDevice.deviceName?.isNotEmpty ?? false) ? subDevice.deviceName : 'Thiết bị ${subDevice.subDeviceNumber}'}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await DatabaseHelper.instance.deleteSubDevice(subDevice.id!);
                  Navigator.of(context).pop();
                  await _loadSubDevices();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Xóa thiết bị con thành công')),
                  );
                } catch (e) {
                  print('Error deleting sub device: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi khi xóa thiết bị con: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Xóa'),
            ),
          ],
        );
      },
    );
  }

  void _deleteWaterSensor(WaterLevelSensor sensor) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa cảm biến "${sensor.name.isNotEmpty ? sensor.name : 'Cảm biến ${sensor.id}'}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await DatabaseHelper.instance.deleteWaterLevelSensor(sensor.id!);
                  Navigator.of(context).pop();
                  await _loadSubDevices();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Xóa cảm biến thành công')),
                  );
                } catch (e) {
                  print('Error deleting water sensor: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi khi xóa cảm biến: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Xóa'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản Lý Thiết Bị Con'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thiết Bị Con của ${widget.parentDevice.deviceName}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tổng cộng: ${_subDevices.length + _waterSensors.length} thiết bị',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                
                // Add Button
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showAddSubDeviceDialog,
                          icon: Icon(Icons.add),
                          label: Text('Thêm Thiết Bị Con'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 48),
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
                
                // Sub Devices List
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(left: 16, right: 16, bottom: 80),
                    children: [
                      // Sub Devices
                      if (_subDevices.isNotEmpty) ...[
                        Text(
                          'Thiết Bị Con',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 12),
                        ..._subDevices.map((subDevice) => _buildSubDeviceCard(subDevice)),
                        SizedBox(height: 24),
                      ],
                      
                      // Water Level Sensors
                      if (_waterSensors.isNotEmpty) ...[
                        Text(
                          'Cảm Biến Mực Nước',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 12),
                        ..._waterSensors.map((sensor) => _buildWaterSensorCard(sensor)),
                      ],
                      
                      // Empty State
                      if (_subDevices.isEmpty && _waterSensors.isEmpty)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.devices_other,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Chưa có thiết bị con nào',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Nhấn "Thêm Thiết Bị Con" để bắt đầu',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        child: Icon(Icons.check, size: 24),
        tooltip: 'Hoàn thành',
      ),
    );
  }

  Widget _buildSubDeviceCard(SubDevice subDevice) {
    IconData icon;
    Color color;
    String typeName;
    
    switch (subDevice.subDeviceType) {
      case 'pump':
        icon = Icons.water;
        color = Colors.green;
        typeName = 'Máy bơm';
        break;
      case 'gate':
        icon = Icons.door_front_door;
        color = Colors.orange;
        typeName = 'Cổng phai';
        break;
      default:
        icon = Icons.devices_other;
        color = Colors.grey;
        typeName = 'Thiết bị';
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          (subDevice.deviceName?.isNotEmpty ?? false)
              ? subDevice.deviceName!
              : '$typeName ${subDevice.subDeviceNumber}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loại: $typeName'),
            Text('Số thứ tự: ${subDevice.subDeviceNumber}'),
            if (subDevice.deviceSerial?.isNotEmpty ?? false)
              Text('Serial: ${subDevice.deviceSerial}'),
            Text('Trạng thái: ${subDevice.subDeviceStatus == 1 ? 'Hoạt động' : 'Tắt'}'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Sửa'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Xóa', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditSubDeviceDialog(subDevice);
            } else if (value == 'delete') {
              _deleteSubDevice(subDevice);
            }
          },
        ),
      ),
    );
  }

  Widget _buildWaterSensorCard(WaterLevelSensor sensor) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.cyan[100],
          child: Icon(Icons.waves, color: Colors.cyan[700]),
        ),
        title: Text(
          sensor.name.isNotEmpty ? sensor.name : 'Cảm biến ${sensor.id}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loại: Cảm biến mực nước'),
            if (sensor.serial.isNotEmpty)
              Text('Serial: ${sensor.serial}'),
            Text('Mực nước hiện tại: ${sensor.currentWaterLevel.toStringAsFixed(1)} m'),
            Text('Dung tích: ${sensor.maxCapacity} m³'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Sửa'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Xóa', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditWaterSensorDialog(sensor);
            } else if (value == 'delete') {
              _deleteWaterSensor(sensor);
            }
          },
        ),
      ),
    );
  }
}
