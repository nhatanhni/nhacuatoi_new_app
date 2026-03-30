import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iot_app/models/device.dart';

final selectedDeviceProvider = StateProvider<Device?>((ref) => null);

void setSelectedDevice(BuildContext context, Device device) {
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(selectedDeviceProvider.notifier).state = device;
}

Device? readSelectedDevice(BuildContext context) {
  return ProviderScope.containerOf(
    context,
    listen: false,
  ).read(selectedDeviceProvider);
}