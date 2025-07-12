import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../database/database_helper.dart';
import '../models/device.dart';
import '../screens/device_detail_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static const String _channelId = 'water_supply_channel';
  static const String _channelName = 'Thông báo Hệ thống Nước';
  static const String _channelDescription = 'Thông báo về trạng thái cung cấp nước và cảnh báo';

  // Global navigator key để có thể navigate từ bất kỳ đâu
  static GlobalKey<NavigatorState>? navigatorKey;

  // Khởi tạo notification service
  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    NotificationService.navigatorKey = navigatorKey;
    
    const AndroidInitializationSettings initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Xử lý khi user tap vào notification
        if (response.payload != null) {
          await _handleNotificationTap(response.payload!);
        }
      },
    );

    // Tạo notification channel cho Android
    await _createNotificationChannel();
    
    // Yêu cầu quyền notification cho iOS
    await requestPermissions();
  }

  // Tạo notification channel cho Android
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Hiển thị notification cho cảnh báo nước
  Future<void> showWaterAlarmNotification(String message) async {
    try {
      final alarmData = jsonDecode(message) as Map<String, dynamic>;
      final alert = alarmData["alert"] ?? "Cảnh báo";
      final deviceSerial = alarmData["serial"] ?? alarmData["id"] ?? "Unknown";
      final liquidPresent = alarmData["value"] ?? alarmData["LiquidPresent"] ?? "N/A";
      final timestamp = alarmData["timestamp"] ?? "N/A";

      // Tạo nội dung notification
      String notificationBody = "Thiết bị: $deviceSerial\n";
      if (liquidPresent != "N/A") {
        notificationBody += "Mực nước: $liquidPresent\n";
      }
      notificationBody += "Thời gian: $timestamp";

      final AndroidNotificationDetails androidPlatformChannelSpecifics = 
          AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        enableLights: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics = 
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
        categoryIdentifier: 'water_alarm_category',
        threadIdentifier: 'water_supply_thread',
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // Tạo unique ID cho notification
      int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        alert,
        notificationBody,
        platformChannelSpecifics,
        payload: jsonEncode({
          'deviceSerial': deviceSerial,
          'alert': alert,
          'timestamp': timestamp,
          'type': 'water_alarm',
          'message': message,
        }),
      );

      // Lưu notification vào SharedPreferences để xử lý sau
      await _saveNotificationData(deviceSerial, message);
      
      print('Notification sent successfully for device: $deviceSerial');
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  // Hiển thị notification thông thường
  Future<void> showGeneralNotification(String title, String body, {String? payload}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = 
        AndroidNotificationDetails(
      'general_channel',
      'Thông báo chung',
      channelDescription: 'Thông báo chung của ứng dụng',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics = 
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Xử lý khi user tap vào notification
  Future<void> _handleNotificationTap(String payload) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final deviceSerial = data['deviceSerial'];
      final type = data['type'];
      String? deviceId;
      // Lấy id từ message nếu có
      if (data['message'] != null) {
        try {
          final msgData = jsonDecode(data['message']);
          if (msgData is Map && msgData['id'] != null) {
            deviceId = msgData['id'].toString();
          }
        } catch (_) {}
      }

      if (type == 'water_alarm' && deviceSerial != null) {
        // Loại bỏ tiền tố NhaCuaToi_ nếu có
        String cleanSerial = deviceSerial;
        if (deviceSerial.startsWith('NhaCuaToi_')) {
          cleanSerial = deviceSerial.replaceFirst('NhaCuaToi_', '');
        }
        print('Tìm thiết bị với serial sạch: $cleanSerial');
        final device = await DatabaseHelper.instance.queryDeviceBySerial(cleanSerial);
        if (device != null) {
          print('Found device: ${device.deviceName}');
          if (navigatorKey?.currentState != null) {
            navigatorKey!.currentState!.push(
              MaterialPageRoute(
                builder: (context) => DeviceDetailScreen(device: device!),
              ),
            );
          }
        } else if (deviceId != null) {
          print('Trying to find device with id: $deviceId');
          try {
            final idInt = int.parse(deviceId);
            final device = await DatabaseHelper.instance.queryDeviceById(idInt);
            if (device != null) {
              print('Found device: ${device.deviceName}');
              if (navigatorKey?.currentState != null) {
                navigatorKey!.currentState!.push(
                  MaterialPageRoute(
                    builder: (context) => DeviceDetailScreen(device: device!),
                  ),
                );
              }
            } else {
              print('Device not found for id: $deviceId');
              ScaffoldMessenger.of(navigatorKey!.currentState!.context).showSnackBar(
                SnackBar(
                  content: Text("Không tìm thấy thiết bị trong danh sách"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } catch (e) {
            print('Error parsing device id: $e');
          }
        } else {
          print('Không tìm thấy thiết bị với serial: $cleanSerial');
          ScaffoldMessenger.of(navigatorKey!.currentState!.context).showSnackBar(
            SnackBar(
              content: Text("Không tìm thấy thiết bị trong danh sách"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Lỗi khi xử lý notification tap: $e');
    }
  }

  // Kiểm tra và xử lý pending notification khi app khởi động
  Future<void> checkPendingNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingDevice = prefs.getString('pending_notification_device');
      if (pendingDevice != null) {
        print('Found pending notification for device: $pendingDevice');
        await Future.delayed(const Duration(milliseconds: 500));
        // Tạo payload đúng format chỉ chứa serial sạch
        final payload = jsonEncode({
          'deviceSerial': pendingDevice,
          'type': 'water_alarm',
          'timestamp': DateTime.now().toIso8601String(),
        });
        await _handleNotificationTap(payload);
        await prefs.remove('pending_notification_device');
      }
    } catch (e) {
      print('Error checking pending notifications: $e');
    }
  }

  // Lưu dữ liệu notification
  Future<void> _saveNotificationData(String deviceSerial, String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = prefs.getStringList('notifications') ?? [];
      
      final notificationData = {
        'deviceSerial': deviceSerial,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      notifications.add(jsonEncode(notificationData));
      
      // Giữ tối đa 50 notification gần nhất
      if (notifications.length > 50) {
        notifications.removeAt(0);
      }
      
      await prefs.setStringList('notifications', notifications);
    } catch (e) {
      print('Error saving notification data: $e');
    }
  }

  // Lấy danh sách notification đã lưu
  Future<List<Map<String, dynamic>>> getSavedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = prefs.getStringList('notifications') ?? [];
      
      return notifications.map((notification) {
        return jsonDecode(notification) as Map<String, dynamic>;
      }).toList();
    } catch (e) {
      print('Error getting saved notifications: $e');
      return [];
    }
  }

  // Xóa tất cả notification
  Future<void> clearAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notifications');
      await prefs.remove('pending_notification_device');
      await prefs.remove('pending_notification_data');
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }

  // Kiểm tra quyền notification
  Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final bool? grantedNotificationPermission =
        await androidImplementation?.requestNotificationsPermission();
    
    // Kiểm tra quyền iOS - sử dụng cách khác
    try {
      final iOSImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      
      final bool grantedIOSPermission =
          await iOSImplementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ?? false;
      
      print('Android notification permission: $grantedNotificationPermission');
      print('iOS notification permission: $grantedIOSPermission');
      
      return grantedNotificationPermission ?? false || grantedIOSPermission;
    } catch (e) {
      print('Error requesting iOS permissions: $e');
      return grantedNotificationPermission ?? false;
    }
  }

  // Test notification để debug
  Future<void> showTestNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics = 
          AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        enableLights: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics = 
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        'Test Notification',
        'Click vào để test navigation đến thiết bị NhaCuaToi_9736401926',
        platformChannelSpecifics,
        payload: jsonEncode({
          'deviceSerial': 'NhaCuaToi_9736401926',
          'alert': 'Test Alert',
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'water_alarm',
          'message': 'Test message',
        }),
      );

      print('Test notification sent successfully');
    } catch (e) {
      print('Error showing test notification: $e');
    }
  }
}
