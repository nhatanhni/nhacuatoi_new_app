import 'package:flutter/material.dart';
import 'package:iot_app/database/database_helper.dart';
import 'package:iot_app/models/violation_report.dart';
import 'package:iot_app/widgets/appbar_back_to_home_widget.dart';
import 'package:fl_chart/fl_chart.dart';

class ViolationStatisticsScreen extends StatefulWidget {
  const ViolationStatisticsScreen({Key? key}) : super(key: key);

  @override
  State<ViolationStatisticsScreen> createState() => _ViolationStatisticsScreenState();
}

class _ViolationStatisticsScreenState extends State<ViolationStatisticsScreen> {
  DateTime selectedDate = DateTime.now();
  List<ViolationReport> violationReports = [];
  bool isLoading = false;
  String selectedChartType = 'daily'; // 'daily' or 'device'

  @override
  void initState() {
    super.initState();
    _loadViolationReports();
  }

  Future<void> _loadViolationReports() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get reports for the selected date (from 00:00 to 23:59)
      DateTime startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      DateTime endDate = startDate.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
      
      final reports = await DatabaseHelper.instance.queryViolationReportsByDateRange(startDate, endDate);
      
      setState(() {
        violationReports = reports;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải dữ liệu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      
      if (picked != null && picked != selectedDate) {
        setState(() {
          selectedDate = picked;
        });
        _loadViolationReports();
      }
    } catch (e) {
      print('Error selecting date: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi chọn ngày: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Prepare data for daily chart (violations by hour)
  List<BarChartGroupData> _getDailyChartData() {
    Map<int, int> hourlyViolations = {};
    
    // Initialize all hours with 0
    for (int i = 0; i < 24; i++) {
      hourlyViolations[i] = 0;
    }
    
    // Count violations by hour
    for (var report in violationReports) {
      int hour = report.violationTime.hour;
      hourlyViolations[hour] = (hourlyViolations[hour] ?? 0) + 1;
    }
    
    return hourlyViolations.entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: Colors.blue,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }

  // Prepare data for device chart (violations by device)
  List<BarChartGroupData> _getDeviceChartData() {
    Map<String, int> deviceViolations = {};
    
    // Count violations by device
    for (var report in violationReports) {
      String deviceName = report.deviceName;
      deviceViolations[deviceName] = (deviceViolations[deviceName] ?? 0) + 1;
    }
    
    List<BarChartGroupData> chartData = [];
    int index = 0;
    
    deviceViolations.forEach((deviceName, count) {
      chartData.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: Colors.red,
              width: 30,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
      index++;
    });
    
    return chartData;
  }

  // Get device names for chart labels
  List<String> _getDeviceNames() {
    Map<String, int> deviceViolations = {};
    for (var report in violationReports) {
      String deviceName = report.deviceName;
      deviceViolations[deviceName] = (deviceViolations[deviceName] ?? 0) + 1;
    }
    return deviceViolations.keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê vi phạm'),
        leading: const AppBarBackToHome(),
      ),
      body: Column(
        children: [
          // Date selection section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chọn ngày:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Chọn ngày'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Statistics summary
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Tổng vi phạm',
                  violationReports.length.toString(),
                  Icons.warning,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Thiết bị vi phạm',
                  violationReports.map((r) => r.deviceSerial).toSet().length.toString(),
                  Icons.devices,
                  Colors.red,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Chart type selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'daily',
                        label: Text('Theo giờ'),
                        icon: Icon(Icons.access_time),
                      ),
                      ButtonSegment<String>(
                        value: 'device',
                        label: Text('Theo thiết bị'),
                        icon: Icon(Icons.devices),
                      ),
                    ],
                    selected: {selectedChartType},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        selectedChartType = newSelection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Chart section
          if (violationReports.isNotEmpty) ...[
            Container(
              height: 300,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedChartType == 'daily' 
                        ? 'Vi phạm theo giờ trong ngày'
                        : 'Vi phạm theo thiết bị',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: selectedChartType == 'daily' 
                            ? (violationReports.length * 1.2).toDouble()
                            : (_getDeviceChartData().isNotEmpty 
                                ? _getDeviceChartData().map((e) => e.barRods.first.toY).reduce((a, b) => a > b ? a : b) * 1.2
                                : 10.0),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              String title = '';
                              if (selectedChartType == 'daily') {
                                title = '${group.x}:00 - ${group.x + 1}:00';
                              } else {
                                List<String> deviceNames = _getDeviceNames();
                                if (group.x < deviceNames.length) {
                                  title = deviceNames[group.x];
                                }
                              }
                              return BarTooltipItem(
                                '$title\n',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${rod.toY.toInt()} vi phạm',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                if (selectedChartType == 'daily') {
                                  if (value.toInt() % 3 == 0) {
                                    return Text(
                                      '${value.toInt()}:00',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    );
                                  }
                                  return const Text('');
                                } else {
                                  List<String> deviceNames = _getDeviceNames();
                                  if (value.toInt() < deviceNames.length) {
                                    String deviceName = deviceNames[value.toInt()];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        deviceName.length > 8 
                                            ? '${deviceName.substring(0, 8)}...'
                                            : deviceName,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }
                                  return const Text('');
                                }
                              },
                              reservedSize: 40,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: false,
                        ),
                        barGroups: selectedChartType == 'daily' 
                            ? _getDailyChartData()
                            : _getDeviceChartData(),
                        gridData: const FlGridData(
                          show: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Execute button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadViolationReports,
                icon: const Icon(Icons.refresh),
                label: const Text('Thực hiện thống kê'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Results section
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : violationReports.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Colors.green,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Không có vi phạm nào trong ngày này',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: violationReports.length,
                        itemBuilder: (context, index) {
                          final report = violationReports[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red[100],
                                child: Icon(
                                  Icons.warning,
                                  color: Colors.red[700],
                                ),
                              ),
                              title: Text(
                                report.deviceName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Serial: ${report.deviceSerial}'),
                                  Text('Thông số: ${report.parameterName}'),
                                  Text(
                                    'Giá trị: ${report.violationValue.toStringAsFixed(2)} (Ngưỡng: ${report.thresholdValue})',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Thời gian: ${report.violationTime.day.toString().padLeft(2, '0')}/${report.violationTime.month.toString().padLeft(2, '0')}/${report.violationTime.year} ${report.violationTime.hour.toString().padLeft(2, '0')}:${report.violationTime.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          size: 32,
          color: color,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
} 