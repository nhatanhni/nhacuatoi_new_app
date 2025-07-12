import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:iot_app/repository/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserListScreen extends StatefulWidget {
  static const routeName = '/user_list';

  const UserListScreen({Key? key}) : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ApiService _apiService = ApiService();
  String? _userId;
  String? _userName;
  String? _fullName;
  String? _phone;
  String? _email;

  @override
  void initState() {
    super.initState();
    _getUserInfo(); // Load user info when the screen initializes
  }

  // Method to get user info
  void _getUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final response = await _apiService.getUserInfo(accessToken);
      setState(() {
        _userId = response['Data']['Id'] as String?;
        _userName = response['Data']['UserName'] as String?;
        _fullName = response['Data']['FullName'] as String?;
        _phone = response['Data']['Phone'] as String?;
        _email = response['Data']['Email'] as String?;
      });
    } catch (e) {
      print('Error getting user info: $e');
      // Handle error if necessary
    }
  }

  // Method to delete the current user
  void _deleteUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accessToken');

    if (_userId == null || accessToken == null) return;

    try {
      await _apiService.deleteUserById(_userId!, accessToken);
      prefs.remove('accessToken');
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Error deleting user: $e');
    }
  }

  // Method to show confirmation dialog
  Future<void> _showDeleteConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button to close the dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận'),
          content: const Text('Bạn có chắc chắn muốn xóa tài khoản này không?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Không'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Có'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteUser();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Cập nhật tài khoản"),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context); // Quay lại màn hình trước đó
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Họ Tên', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _fullName),
              readOnly: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Số điện thoại', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _phone),
              readOnly: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Email', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _email),
              readOnly: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Nhập email của bạn',
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: _showDeleteConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Màu nền xanh
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: const Text(
                  'Xóa tài khoản',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white, // Màu chữ trắng
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
