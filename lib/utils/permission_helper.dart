import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';

// Temporary placeholder for permission handling during iOS development
enum Permission {
  camera,
  location,
  locationWhenInUse,
  nearbyWifiDevices,
}

extension PermissionSingleExtension on Permission {
  Future<PermissionStatus> request() async {
    // Temporary implementation - return granted for all permissions
    return PermissionStatus.granted;
  }
  
  Future<PermissionStatus> get status async {
    // Temporary implementation - return granted for all permissions
    return PermissionStatus.granted;
  }
}

enum PermissionStatus {
  granted,
  denied,
  restricted,
  permanentlyDenied,
}

extension PermissionExtension on List<Permission> {
  Future<Map<Permission, PermissionStatus>> request() async {
    // Temporary implementation - return granted for all permissions
    Map<Permission, PermissionStatus> result = {};
    for (Permission permission in this) {
      result[permission] = PermissionStatus.granted;
    }
    return result;
  }
}

class PermissionHelper {
  static Future<bool> checkAndRequestPermissions(BuildContext context) async {
    Map<Permission, PermissionStatus> permissions = await [
      Permission.camera,
      Permission.location,
      Permission.locationWhenInUse,
    ].request();

    List<String> deniedPermissions = [];
    
    permissions.forEach((permission, status) {
      if (status != PermissionStatus.granted) {
        switch (permission) {
          case Permission.camera:
            deniedPermissions.add('Camera (để quét QR code)');
            break;
          case Permission.location:
          case Permission.locationWhenInUse:
            deniedPermissions.add('Vị trí (để quét WiFi)');
            break;
          default:
            break;
        }
      }
    });

    if (deniedPermissions.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cần Quyền Truy Cập'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ứng dụng cần các quyền sau để hoạt động:'),
              const SizedBox(height: 8),
              ...deniedPermissions.map((permission) => 
                Text('• $permission', style: const TextStyle(fontSize: 14))
              ),
              const SizedBox(height: 16),
              const Text('Vui lòng cấp quyền trong Cài đặt ứng dụng.'),
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
                openAppSettings();
              },
              child: const Text('Mở Cài Đặt'),
            ),
          ],
        ),
      );
      return false;
    }

    return true;
  }

  static Widget buildPermissionStatusCard(String title, PermissionStatus status) {
    Color color;
    IconData icon;
    String statusText;

    switch (status) {
      case PermissionStatus.granted:
        color = Colors.green;
        icon = Icons.check_circle;
        statusText = 'Đã cấp';
        break;
      case PermissionStatus.denied:
        color = Colors.orange;
        icon = Icons.warning;
        statusText = 'Bị từ chối';
        break;
      case PermissionStatus.permanentlyDenied:
        color = Colors.red;
        icon = Icons.block;
        statusText = 'Từ chối vĩnh viễn';
        break;
      case PermissionStatus.restricted:
        color = Colors.grey;
        icon = Icons.security;
        statusText = 'Bị hạn chế';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        statusText = 'Không xác định';
    }

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(statusText),
        trailing: status == PermissionStatus.granted 
          ? null 
          : IconButton(
              icon: const Icon(Icons.settings),
              onPressed: openAppSettings,
            ),
      ),
    );
  }
}

// Global function for opening app settings
Future<bool> openAppSettings() async {
  // Temporary implementation - just print for now
  print('📱 Opening app settings...');
  return true;
}
