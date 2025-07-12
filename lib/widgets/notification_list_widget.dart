import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'notification_service.dart';

class NotificationListWidget extends StatefulWidget {
  const NotificationListWidget({Key? key}) : super(key: key);

  @override
  _NotificationListWidgetState createState() => _NotificationListWidgetState();
}

class _NotificationListWidgetState extends State<NotificationListWidget> {
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notifications = await _notificationService.getSavedNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await _notificationService.clearAllNotifications();
      setState(() {
        _notifications.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa tất cả thông báo'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xóa thông báo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      } else if (difference.inHours > 0) {
        return '${difference.inHours} giờ trước';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} phút trước';
      } else {
        return 'Vừa xong';
      }
    } catch (e) {
      return timestamp;
    }
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    try {
      final messageData = jsonDecode(notification['message']) as Map<String, dynamic>;
      final alert = messageData["alert"] ?? "Cảnh báo";
      final deviceSerial = messageData["serial"] ?? messageData["id"] ?? "Unknown";
      final liquidPresent = messageData["value"] ?? messageData["LiquidPresent"] ?? "N/A";

      // Sử dụng thời gian hiện tại của điện thoại thay vì timestamp từ notification
      final currentTime = DateTime.now();
      final formattedCurrentTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(currentTime);

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red.shade100,
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade600,
            ),
          ),
          title: Text(
            alert,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('Thiết bị: $deviceSerial'),
              if (liquidPresent != "N/A") Text('Mực nước: $liquidPresent'),
              Text('Thời gian: $formattedCurrentTime'),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(notification['timestamp']),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          isThreeLine: true,
          onTap: () {
            // Có thể thêm navigation đến device detail screen
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Thiết bị: $deviceSerial'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      );
    } catch (e) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.grey,
            child: Icon(Icons.error, color: Colors.white),
          ),
          title: const Text('Lỗi hiển thị thông báo'),
          subtitle: Text('Dữ liệu: ${notification['message']}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử Thông báo'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAllNotifications,
              tooltip: 'Xóa tất cả',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có thông báo nào',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Các thông báo cảnh báo sẽ xuất hiện ở đây',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationItem(_notifications[index]);
                    },
                  ),
                ),
    );
  }
} 