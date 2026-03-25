import 'package:equatable/equatable.dart';
import 'package:iot_app/models/device_detail.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/models/device_from_api.dart';

abstract class DeviceState extends Equatable {
  const DeviceState();

  @override
  List<Object?> get props => [];
}

class DeviceInitial extends DeviceState {}

class DeviceLoading extends DeviceState {}

class DeviceDetailLoading extends DeviceState {}

class DeviceLoaded extends DeviceState {
  final List<DeviceApi> devices;

  const DeviceLoaded(this.devices);

  @override
  List<Object?> get props => [devices];
}

class DeviceManageLoaded extends DeviceState {
  final List<Device> devices;
  final int pageIndex;
  final int maxPage;
  final int totalItems;
  final bool isLoadingMore;

  const DeviceManageLoaded(
    this.devices, {
    this.pageIndex = 1,
    this.maxPage = 1,
    this.totalItems = 0,
    this.isLoadingMore = false,
  });

  bool get hasMorePages => pageIndex < maxPage;

  @override
  List<Object?> get props => [
    devices,
    pageIndex,
    maxPage,
    totalItems,
    isLoadingMore,
  ];
}

class DeviceDetailLoaded extends DeviceState {
  final DeviceDetail detail;

  const DeviceDetailLoaded(this.detail);

  @override
  List<Object?> get props => [detail];
}

class DeviceError extends DeviceState {
  final String message;

  const DeviceError(this.message);

  @override
  List<Object?> get props => [message];
}
