// ignore_for_file: prefer_const_constructors, avoid_print, prefer_const_literals_to_create_immutables

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot_app/bloc/device/device_bloc.dart';
import 'package:iot_app/bloc/device/device_event.dart';
import 'package:iot_app/bloc/device/device_state.dart';
import 'package:iot_app/core/state/selected_device_provider.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/screens/device_detail_screen.dart';
import 'package:iot_app/widgets/appbar_dropdown_widget.dart';

import '../utils/toast_helper.dart';

class ManageDeviceScreen extends StatefulWidget {
  const ManageDeviceScreen({Key? key}) : super(key: key);

  @override
  State<ManageDeviceScreen> createState() => _ManageDeviceScreenState();
}

class _ManageDeviceScreenState extends State<ManageDeviceScreen> {
  List<Device> _devices = []; // List to hold devices
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;

  IconData _iconForDeviceType(String type) {
    final normalized = type.toLowerCase();
    if (normalized.contains('bơm')) return Icons.water;
    if (normalized.contains('nước thải')) return Icons.water_drop_outlined;
    if (normalized.contains('mực nước')) return Icons.waves;
    if (normalized.contains('điện') || normalized.contains('công tắc')) {
      return Icons.electrical_services;
    }
    if (normalized.contains('khí thải')) return Icons.air;
    if (normalized.contains('khí tượng')) return Icons.cloud;
    if (normalized.contains('nước sinh hoạt')) return Icons.local_drink;
    if (normalized.contains('sensor')) return Icons.sensors;
    return Icons.devices;
  }

  Color _accentForDeviceType(String type) {
    final normalized = type.toLowerCase();
    if (normalized.contains('bơm')) return Colors.indigo;
    if (normalized.contains('nước')) return Colors.blue;
    if (normalized.contains('điện') || normalized.contains('công tắc')) {
      return Colors.orange;
    }
    if (normalized.contains('khí')) return Colors.teal;
    return Colors.deepPurple;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollLoadMore);
    _loadDevices(); // Load devices when the screen initializes
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Method to load devices from the database
  void _loadDevices() {
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasMorePages = true;
    });
    context.read<DeviceBloc>().add(DeviceLoadManageList());
  }

  void _onScrollLoadMore() {
    if (!_scrollController.hasClients || _isLoading || _isLoadingMore) {
      return;
    }

    if (!_hasMorePages) return;

    final threshold = _scrollController.position.maxScrollExtent - 220;
    if (_scrollController.position.pixels >= threshold) {
      context.read<DeviceBloc>().add(DeviceLoadManageNextPage());
    }
  }

  // Method to delete a device on server via BLoC
  Future<void> _deleteDevice(String id) async {
    final completer = Completer<void>();

    try {
      context.read<DeviceBloc>().add(
        DeviceDeleted(deviceId: id, completer: completer),
      );
      await completer.future;
    } catch (e) {
      print('Error deleting device: $e');
      rethrow;
    }
  }

  Future<void> _confirmDeleteDevice(int index) async {
    final isConfirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog.adaptive(
              title: Text('Cảnh báo'),
              content: Text('Bạn có chắc chắn muốn xoá thiết bị này không?'),
              actions: <Widget>[
                TextButton(
                  child: Text('Huỷ'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text('Xoá'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!isConfirmed) return;

    final dynamic rawDeviceId = _devices[index].id;
    if (rawDeviceId == null) {
      Fluttertoast.showToast(
        msg: 'Thiết bị không có ID hợp lệ để xoá.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
        fontSize: 14,
      );
      return;
    }

    try {
      await _deleteDevice(rawDeviceId.toString());
      setState(() {
        _devices.removeAt(index);
      });

      Fluttertoast.showToast(
        msg: 'Xoá thiết bị thành công.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Theme.of(context).primaryColor,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (_) {
      Fluttertoast.showToast(
        msg: 'Xoá thiết bị thất bại.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
        fontSize: 14,
      );
    }
  }

  Widget _buildDeviceCard(BuildContext context, int index) {
    final device = _devices[index];
    final accentColor = _accentForDeviceType(device.deviceType);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setSelectedDevice(context, device);
        Navigator.pushNamed(context, DeviceDetailScreen.routeName);
      },
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accentColor.withOpacity(0.14), Colors.white],
          ),
          border: Border.all(color: accentColor.withOpacity(0.24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              offset: Offset(0, 8),
              blurRadius: 16,
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _iconForDeviceType(device.deviceType),
                color: accentColor,
                size: 30,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: Color(0xFF222222),
                    ),
                  ),
                  SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      device.deviceType,
                      style: TextStyle(
                        color: Colors.black38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _confirmDeleteDevice(index),
              icon: Icon(Icons.delete_outline_rounded, color: Colors.black87),
              tooltip: 'Xoá thiết bị',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = _devices.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'Quản lý thiết bị',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            Text(
              'Tổng số thiết bị: ${_devices.length}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        actions: [AppBarDropdown()],
      ),
      body: SafeArea(
        child: BlocListener<DeviceBloc, DeviceState>(
          listener: (context, state) {
            if (state is DeviceLoading) {
              setState(() {
                _isLoading = true;
              });
            } else if (state is DeviceManageLoaded) {
              setState(() {
                _isLoading = false;
                _devices = state.devices;
                _isLoadingMore = state.isLoadingMore;
                _hasMorePages = state.hasMorePages;
              });
            } else if (state is DeviceError) {
              setState(() {
                _isLoading = false;
                _isLoadingMore = false;
              });
              Fluttertoast.showToast(
                msg: state.message,
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.redAccent,
                textColor: Colors.white,
                fontSize: 14,
              );
            }
          },
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator.adaptive(),
                )
              : isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 84,
                          width: 84,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.router_rounded,
                            size: 42,
                            color: Colors.blue[700],
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Hiện chưa có thiết bị nào',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Thêm thiết bị để bắt đầu giám sát và điều khiển hệ thống AIoT của bạn.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: 18),
                        CupertinoButton.filled(
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () {
                            Navigator.pushNamed(context, '/add_device');
                          },
                          child: Text('Thêm thiết bị'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _devices.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (BuildContext context, int index) {
                          if (index == _devices.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator.adaptive(),
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildDeviceCard(context, index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
