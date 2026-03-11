// Web stubs for mobile-only packages
// This file provides placeholder implementations for web platform

class AndroidAlarmManager {
  static Future<bool> initialize() async {
    print('AndroidAlarmManager: Web platform - no initialization needed');
    return true;
  }

  static Future<bool> periodic(
    Duration duration,
    int id,
    Function callback, {
    DateTime? startAt,
    bool exact = false,
    bool wakeup = false,
    bool rescheduleOnReboot = false,
  }) async {
    print('AndroidAlarmManager: Web platform - periodic alarms not supported');
    return true;
  }

  static Future<bool> cancel(int id) async {
    print('AndroidAlarmManager: Web platform - cancel not needed');
    return true;
  }
}

class Workmanager {
  static Workmanager _instance = Workmanager._();
  Workmanager._();

  factory Workmanager() => _instance;

  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async {
    print('Workmanager: Web platform - no background tasks supported');
  }

  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
    String? tag,
  }) async {
    print('Workmanager: Web platform - periodic tasks not supported');
  }

  Future<void> cancelAll() async {
    print('Workmanager: Web platform - cancel not needed');
  }

  Future<bool> executeTask(Function taskFunction) async {
    print('Workmanager: Web platform - execute task not supported');
    return true;
  }
}

class Constraints {
  final NetworkType networkType;
  final bool requiresBatteryNotLow;
  final bool requiresCharging;
  final bool requiresDeviceIdle;
  final bool requiresStorageNotLow;

  const Constraints({
    this.networkType = NetworkType.not_required,
    this.requiresBatteryNotLow = false,
    this.requiresCharging = false,
    this.requiresDeviceIdle = false,
    this.requiresStorageNotLow = false,
  });
}

enum NetworkType {
  not_required,
  connected,
  unmetered,
  not_roaming,
  metered,
}
