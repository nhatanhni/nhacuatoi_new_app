import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../models/device.dart';
import '../models/violation_report.dart';
import '../database/database_helper.dart';

class WastewaterMonitoringWidget extends StatefulWidget {
  final Device device;

  const WastewaterMonitoringWidget({
    Key? key,
    required this.device,
  }) : super(key: key);

  @override
  State<WastewaterMonitoringWidget> createState() => _WastewaterMonitoringWidgetState();
}

class _WastewaterMonitoringWidgetState extends State<WastewaterMonitoringWidget> {
  late WastewaterMonitoringData _currentData;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _currentData = WastewaterMonitoringData.generateDemo();
    // Cập nhật dữ liệu mỗi 3 giây để tạo hiệu ứng real-time
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      setState(() {
        _currentData = WastewaterMonitoringData.generateDemo();
      });
      // Kiểm tra và lưu vi phạm
      _checkAndSaveViolations();
    });
  }

  void _checkAndSaveViolations() {
    final alerts = _currentData.getAlertStatus();
    
    for (String parameter in alerts.keys) {
      _saveViolationIfNeeded(parameter, alerts[parameter]!);
    }
  }

  void _saveViolationIfNeeded(String parameter, Map<String, dynamic> alertData) async {
    try {
      // Kiểm tra xem vi phạm này đã được lưu trong 5 phút gần đây chưa
      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
      
      final existingReports = await DatabaseHelper.instance.queryViolationReportsByDeviceSerial(widget.device.deviceSerial);
      final recentViolations = existingReports.where((report) => 
        report.parameterName == parameter && 
        report.violationTime.isAfter(fiveMinutesAgo)
      ).toList();
      
      // Nếu chưa có vi phạm gần đây cho thông số này, lưu mới
      if (recentViolations.isEmpty) {
        final report = ViolationReport(
          deviceSerial: widget.device.deviceSerial,
          deviceName: widget.device.deviceName,
          parameterName: parameter,
          violationValue: alertData['value'],
          violationTime: now,
          thresholdValue: alertData['threshold'].toString(),
        );
        
        await DatabaseHelper.instance.insertViolationReport(report);
        print('Đã lưu vi phạm: $parameter - ${alertData['value']}');
      }
    } catch (e) {
      print('Lỗi khi lưu vi phạm: $e');
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _currentData.getAlertStatus();
    final waterQuality = _currentData.getWaterQuality();

    return Scaffold(
      appBar: AppBar(
        title: Text('Quan trắc nước thải - ${widget.device.deviceName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header với chất lượng nước tổng thể
            _buildWaterQualityHeader(waterQuality),
            const SizedBox(height: 20),
            
            // Grid các thông số
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
                          children: [
              _buildParameterCard(
                'Lưu lượng',
                '${_currentData.flowRate.toStringAsFixed(1)} m³/h',
                Icons.water_drop,
                Colors.blue,
                alerts.containsKey('Lưu lượng'),
                'Kiểm soát lượng nước thải xả ra môi trường',
              ),
              _buildParameterCard(
                'Nhiệt độ',
                '${_currentData.temperature.toStringAsFixed(1)}°C',
                Icons.thermostat,
                Colors.orange,
                alerts.containsKey('Nhiệt độ'),
                'Đảm bảo không gây hại đến hệ sinh thái',
              ),
              _buildParameterCard(
                'Độ PH',
                _currentData.ph.toStringAsFixed(2),
                Icons.science,
                Colors.purple,
                alerts.containsKey('Độ PH'),
                'Kiểm soát tính axit hoặc kiềm, bảo vệ sinh vật',
              ),
              _buildParameterCard(
                'TSS',
                '${_currentData.tss.toStringAsFixed(0)} mg/L',
                Icons.cloud,
                Colors.grey,
                alerts.containsKey('TSS'),
                'Đánh giá mức độ ô nhiễm của nước thải',
              ),
              _buildParameterCard(
                'COD',
                '${_currentData.cod.toStringAsFixed(0)} mg/L',
                Icons.biotech,
                Colors.green,
                alerts.containsKey('COD'),
                'Đánh giá mức độ ô nhiễm hữu cơ của nước thải',
              ),
              _buildParameterCard(
                'Amoni',
                '${_currentData.ammonia.toStringAsFixed(1)} mg/L',
                Icons.eco,
                Colors.teal,
                alerts.containsKey('Amoni'),
                'Kiểm soát hợp chất nitơ, ngăn ngừa phú dưỡng',
              ),
            ],
            ),
            
            const SizedBox(height: 20),
            
            // Gauge chart cho lưu lượng
            _buildFlowRateGauge(),
            
            const SizedBox(height: 20),
            
            // Bảng thống kê
            _buildStatisticsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterQualityHeader(String quality) {
    Color qualityColor;
    IconData qualityIcon;
    
    switch (quality) {
      case 'Tốt':
        qualityColor = Colors.green;
        qualityIcon = Icons.check_circle;
        break;
      case 'Trung bình':
        qualityColor = Colors.orange;
        qualityIcon = Icons.warning;
        break;
      case 'Kém':
        qualityColor = Colors.red;
        qualityIcon = Icons.error;
        break;
      default:
        qualityColor = Colors.grey;
        qualityIcon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [qualityColor.withOpacity(0.1), qualityColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: qualityColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(qualityIcon, color: qualityColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chất lượng nước: $quality',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: qualityColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cập nhật: ${_currentData.timestamp.toString().substring(11, 19)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterCard(String title, String value, IconData icon, Color color, bool isAlert, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAlert ? Colors.red.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlert ? Colors.red : Colors.grey.withOpacity(0.3),
          width: isAlert ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isAlert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'CẢNH BÁO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isAlert ? Colors.red : color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFlowRateGauge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Biểu đồ lưu lượng nước thải',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: 0,
                  maximum: 100,
                  ranges: <GaugeRange>[
                    GaugeRange(
                      startValue: 0,
                      endValue: 50,
                      color: Colors.green,
                    ),
                    GaugeRange(
                      startValue: 50,
                      endValue: 75,
                      color: Colors.orange,
                    ),
                    GaugeRange(
                      startValue: 75,
                      endValue: 100,
                      color: Colors.red,
                    ),
                  ],
                  pointers: <GaugePointer>[
                    NeedlePointer(
                      value: _currentData.flowRate,
                      needleColor: Colors.blue,
                      knobStyle: const KnobStyle(
                        color: Colors.blue,
                        borderColor: Colors.blue,
                        borderWidth: 0.025,
                      ),
                    ),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      widget: Text(
                        '${_currentData.flowRate.toStringAsFixed(1)}\nm³/h',
                        style: const TextStyle(
                          fontSize: 16,
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
    );
  }

  Widget _buildStatisticsTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thống kê thông số',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Table(
            border: TableBorder.all(color: Colors.grey.withOpacity(0.3)),
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Colors.grey),
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Thông số', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Giá trị hiện tại', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              _buildTableRow('Lưu lượng', '${_currentData.flowRate.toStringAsFixed(1)} m³/h', _currentData.flowRate <= 55 ? 'Bình thường' : 'Cao'),
              _buildTableRow('Nhiệt độ', '${_currentData.temperature.toStringAsFixed(1)}°C', _currentData.temperature <= 21 ? 'Bình thường' : 'Cao'),
              _buildTableRow('Độ PH', _currentData.ph.toStringAsFixed(2), (_currentData.ph >= 6.0 && _currentData.ph <= 8.5) ? 'Bình thường' : 'Bất thường'),
              _buildTableRow('TSS', '${_currentData.tss.toStringAsFixed(0)} mg/L', _currentData.tss <= 100 ? 'Bình thường' : 'Cao'),
              _buildTableRow('COD', '${_currentData.cod.toStringAsFixed(0)} mg/L', _currentData.cod <= 200 ? 'Bình thường' : 'Cao'),
              _buildTableRow('Amoni', '${_currentData.ammonia.toStringAsFixed(1)} mg/L', _currentData.ammonia <= 6 ? 'Bình thường' : 'Cao'),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String parameter, String value, String status) {
    Color statusColor = status == 'Bình thường' ? Colors.green : Colors.red;
    
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(parameter),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(value),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            status,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
} 