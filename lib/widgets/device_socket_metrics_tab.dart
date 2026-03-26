import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DeviceSocketMetricsTab extends StatelessWidget {
  final String? topic;
  final Map<String, dynamic>? metricsData;
  final String? rawJson;
  final String? error;
  final DateTime? lastUpdated;

  const DeviceSocketMetricsTab({
    super.key,
    required this.topic,
    required this.metricsData,
    required this.rawJson,
    required this.error,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final hasTopic = topic != null && topic!.trim().isNotEmpty;
    final hasData = metricsData != null && metricsData!.isNotEmpty;
    final headlineColor = Theme.of(context).primaryColorDark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        _buildRealtimeHeader(),
        const SizedBox(height: 14),
        if (!hasTopic) _buildMissingTopicBox(),
        if (error != null) _buildErrorBox(),
        if (hasTopic && !hasData && error == null) _buildLoadingBox(),
        if (hasData) ...[
          Text(
            'Thông số chính',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: headlineColor,
            ),
          ),
          const SizedBox(height: 10),
          ...metricsData!.entries.map((entry) => _buildMetricItem(context, entry)),
        ],
        const SizedBox(height: 14),
        // Text(
        //   'JSON payload',
        //   style: TextStyle(
        //     fontSize: 17,
        //     fontWeight: FontWeight.bold,
        //     color: headlineColor,
        //   ),
        // ),
        // const SizedBox(height: 8),
        // _buildJsonContainer(),
      ],
    );
  }

  Widget _buildRealtimeHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B3D91), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children:[
              const Text(
            'Topic',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            topic ?? 'Chưa cấu hình MqTopic',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
            ]
          ),
          if (lastUpdated != null) ...[
            const SizedBox(height: 6),
            Text(
              'Cập nhật: ${DateFormat('HH:mm:ss dd/MM/yyyy').format(lastUpdated!)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMissingTopicBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: const Text(
        'Thiết bị chưa có MqTopic trong dữ liệu API, không thể subscribe socket.',
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Text(
        error!,
        style: TextStyle(color: Colors.red[700]),
      ),
    );
  }

  Widget _buildLoadingBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Text(
        'Đang chờ dữ liệu socket từ server...\nKhi có payload JSON, hệ thống sẽ hiển thị ở bên dưới.',
      ),
    );
  }

  Widget _buildMetricItem(BuildContext context, MapEntry<String, dynamic> entry) {
    final label = _metricLabel(entry);
    final value = _metricValue(entry.value);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey[50]!),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).primaryColorDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _metricLabel(MapEntry<String, dynamic> entry) {
    final raw = entry.value;
    if (raw is Map<String, dynamic>) {
      final dynamic label = raw['label'];
      if (label is String && label.trim().isNotEmpty) {
        return label;
      }
    }

    return entry.key;
  }

  String _metricValue(dynamic raw) {
    dynamic value = raw;
    String? unit;

    if (raw is Map<String, dynamic>) {
      value = raw['value'];
      final dynamic rawUnit = raw['unit'];
      if (rawUnit is String && rawUnit.trim().isNotEmpty) {
        unit = rawUnit;
      }
    }

    final valueText = _formatMetricValue(value);
    if (unit == null || valueText == '-') {
      return valueText;
    }

    return '$valueText $unit';
  }

  String _formatMetricValue(dynamic value) {
    if (value == null) {
      return '-';
    }

    if (value is num) {
      if (value % 1 == 0) {
        return value.toStringAsFixed(0);
      }
      return value.toStringAsFixed(2);
    }

    return value.toString();
  }

  Widget _buildJsonContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        rawJson ?? '{\n  "data": {}\n}',
        style: const TextStyle(
          fontFamily: 'monospace',
          color: Color(0xFFE5E7EB),
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}
