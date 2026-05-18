import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iot_app/bloc/device/device_event.dart';
import 'package:iot_app/bloc/device/device_state.dart';
import 'package:iot_app/core/services/database_helper.dart';
import 'package:iot_app/core/models/device.dart';
import 'package:iot_app/core/models/device_detail.dart';
import 'package:iot_app/core/models/device_from_api.dart';
import 'package:iot_app/core/services/api_service.dart';

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  final DatabaseHelper databaseHelper;
  final ApiService apiService;
  final List<Device> _manageDevices = [];
  int _manageCurrentPage = 0;
  int _manageMaxPage = 1;
  int _manageTotalItems = 0;
  bool _isManageLoadingMore = false;

  DeviceBloc({required this.databaseHelper, required this.apiService})
    : super(DeviceInitial()) {
    on<DeviceLoadAll>(_onLoadAll);
    on<DeviceLoadManageList>(_onLoadManageList);
    on<DeviceLoadManageNextPage>(_onLoadManageNextPage);
    on<DeviceDetailRequested>(_onDeviceDetailRequested);
    on<DeviceLoadByType>(_onLoadByType);
    on<DeviceStatusUpdated>(_onStatusUpdated);
    on<DeviceConnectionStatusUpdated>(_onConnectionStatusUpdated);
    on<DeviceAdded>(_onDeviceAdded);
    on<DeviceDeleted>(_onDeviceDeleted);
    on<DeviceSwitchHistorySaved>(_onSwitchHistorySaved);
    on<DeviceCreateOnServerRequested>(_onCreateOnServerRequested);
  }

  Future<void> _onLoadAll(
    DeviceLoadAll event,
    Emitter<DeviceState> emit,
  ) async {
    print("Loading all devices...");
    emit(DeviceLoading());
    try {
      // final devices = await databaseHelper.queryAllDevices();
      final devices = await apiService.fetchUserDevices();
      print("Fetched devices from API: ${devices}");
      //map data
      final deviceList = devices.map((d) => DeviceApi.fromJson(d)).toList();
      print("Loaded devices: ${deviceList}");
      emit(DeviceLoaded(deviceList));
    } catch (e) {
      emit(DeviceError(e.toString()));
    }
  }

  Future<void> _onLoadManageList(
    DeviceLoadManageList event,
    Emitter<DeviceState> emit,
  ) async {
    emit(DeviceLoading());
    try {
      _manageDevices.clear();
      _manageCurrentPage = 0;
      _manageMaxPage = 1;
      _manageTotalItems = 0;

      final response = await apiService.fetchManageDevices(page: 1);
      final devices = response['items'] as List<dynamic>? ?? <dynamic>[];

      final deviceList = devices
          .whereType<Map<String, dynamic>>()
          .map(_mapManageDeviceFromApi)
          .toList();

      _manageDevices.addAll(deviceList);
      _manageCurrentPage = (response['pageIndex'] ?? 1) as int;
      _manageMaxPage = (response['maxPage'] ?? 1) as int;
      _manageTotalItems = (response['totalItems'] ?? _manageDevices.length) as int;

      emit(
        DeviceManageLoaded(
          List<Device>.from(_manageDevices),
          pageIndex: _manageCurrentPage,
          maxPage: _manageMaxPage,
          totalItems: _manageTotalItems,
        ),
      );
    } catch (e) {
      emit(DeviceError(e.toString()));
    }
  }

  Future<void> _onLoadManageNextPage(
    DeviceLoadManageNextPage event,
    Emitter<DeviceState> emit,
  ) async {
    if (_isManageLoadingMore) return;
    if (_manageCurrentPage >= _manageMaxPage) return;

    _isManageLoadingMore = true;
    emit(
      DeviceManageLoaded(
        List<Device>.from(_manageDevices),
        pageIndex: _manageCurrentPage,
        maxPage: _manageMaxPage,
        totalItems: _manageTotalItems,
        isLoadingMore: true,
      ),
    );

    try {
      final nextPage = _manageCurrentPage + 1;
      final response = await apiService.fetchManageDevices(page: nextPage);
      final devices = response['items'] as List<dynamic>? ?? <dynamic>[];

      final fetched = devices
          .whereType<Map<String, dynamic>>()
          .map(_mapManageDeviceFromApi)
          .toList();

      final existingIds =
          _manageDevices.map((d) => d.id?.toString() ?? '').toSet();
      final existingSerials = _manageDevices.map((d) => d.deviceSerial).toSet();

      for (final device in fetched) {
        final id = device.id?.toString() ?? '';
        final serial = device.deviceSerial;
        if ((id.isNotEmpty && existingIds.contains(id)) ||
            (serial.isNotEmpty && existingSerials.contains(serial))) {
          continue;
        }

        _manageDevices.add(device);
        if (id.isNotEmpty) existingIds.add(id);
        if (serial.isNotEmpty) existingSerials.add(serial);
      }

      _manageCurrentPage = (response['pageIndex'] ?? nextPage) as int;
      _manageMaxPage = (response['maxPage'] ?? _manageMaxPage) as int;
      _manageTotalItems = (response['totalItems'] ?? _manageTotalItems) as int;

      emit(
        DeviceManageLoaded(
          List<Device>.from(_manageDevices),
          pageIndex: _manageCurrentPage,
          maxPage: _manageMaxPage,
          totalItems: _manageTotalItems,
        ),
      );
    } catch (e) {
      emit(
        DeviceManageLoaded(
          List<Device>.from(_manageDevices),
          pageIndex: _manageCurrentPage,
          maxPage: _manageMaxPage,
          totalItems: _manageTotalItems,
        ),
      );
      emit(DeviceError(e.toString()));
    } finally {
      _isManageLoadingMore = false;
    }
  }

  Device _mapManageDeviceFromApi(Map<String, dynamic> json) {
    final dynamic rawDeviceId = json['Id'];

    return Device(
      id: rawDeviceId,
      deviceType: (json['DeviceTypeName'] ?? json['deviceTypeName'] ?? '')
          .toString(),
      deviceSerial: (json['Serial'] ?? json['serial'] ?? '').toString(),
      deviceName: (json['Name'] ?? json['name'] ?? '').toString(),
      mqTopic: (json['MqTopic'] ?? json['mqTopic'] ?? '').toString(),
      deviceStatus: (json['Startup'] == true) ? 1 : 0,
      connectionStatus: 'unknown',
    );
  }

  Future<void> _onLoadByType(
    DeviceLoadByType event,
    Emitter<DeviceState> emit,
  ) async {
    emit(DeviceLoading());
    try {
      final devices = await databaseHelper.queryDevicesByType(event.deviceType);
      emit(DeviceManageLoaded(devices));
    } catch (e) {
      emit(DeviceError(e.toString()));
    }
  }

  Future<void> _onDeviceDetailRequested(
    DeviceDetailRequested event,
    Emitter<DeviceState> emit,
  ) async {
    emit(DeviceDetailLoading());
    try {
      final detailData = await apiService.fetchDeviceDetailById(event.deviceId);
      final detail = DeviceDetail.fromJson(detailData);
      emit(DeviceDetailLoaded(detail));
    } catch (e) {
      emit(DeviceError(e.toString()));
    }
  }

  Future<void> _onStatusUpdated(
    DeviceStatusUpdated event,
    Emitter<DeviceState> emit,
  ) async {
    try {
      await databaseHelper.updateDeviceStatus(event.deviceId, event.status);
      // Reload current state
      add(DeviceLoadAll());
    } catch (e) {
      emit(DeviceError(e.toString()));
    }
  }

  Future<void> _onConnectionStatusUpdated(
    DeviceConnectionStatusUpdated event,
    Emitter<DeviceState> emit,
  ) async {
    try {
      await databaseHelper.updateDeviceConnectionStatus(
        event.serial,
        event.connectionStatus,
      );
      // Reload to reflect changes
      add(DeviceLoadAll());
    } catch (e) {
      emit(DeviceError(e.toString()));
    }
  }

  Future<void> _onDeviceAdded(
    DeviceAdded event,
    Emitter<DeviceState> emit,
  ) async {
    try {
      await databaseHelper.insertDevice(event.device);
      add(DeviceLoadAll());
    } catch (e) {
      emit(DeviceError(e.toString()));
    }
  }

  Future<void> _onDeviceDeleted(
    DeviceDeleted event,
    Emitter<DeviceState> emit,
  ) async {
    try {
      await apiService.deleteDeviceOnServer(event.deviceId);
      add(DeviceLoadManageList());
      event.completer?.complete();
    } catch (e) {
      event.completer?.completeError(e);
      emit(DeviceError(e.toString()));
    }
  }

  Future<void> _onSwitchHistorySaved(
    DeviceSwitchHistorySaved event,
    Emitter<DeviceState> emit,
  ) async {
    try {
      await apiService.saveSwitchDeviceHistory(
        event.deviceId,
        event.isSwitched,
      );
      event.completer?.complete();
    } catch (e) {
      event.completer?.completeError(e);
      emit(DeviceError(e.toString()));
    }
  }

  Future<void> _onCreateOnServerRequested(
    DeviceCreateOnServerRequested event,
    Emitter<DeviceState> emit,
  ) async {
    try {
      await apiService.createDevice(event.payload);
      event.completer?.complete();
    } catch (e) {
      event.completer?.completeError(e);
      emit(DeviceError(e.toString()));
    }
  }
}
