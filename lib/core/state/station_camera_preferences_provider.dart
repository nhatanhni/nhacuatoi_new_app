import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final stationCameraSelectedIdProvider = StateProvider<String?>((ref) => null);

final stationCameraUrlsProvider =
    AsyncNotifierProvider<StationCameraUrlsNotifier, Map<String, String>>(
      StationCameraUrlsNotifier.new,
    );

class StationCameraUrlsNotifier extends AsyncNotifier<Map<String, String>> {
  static const cameraUrlPreferencePrefix = 'station_camera_url_';

  @override
  Future<Map<String, String>> build() async {
    return _loadFromPreferences();
  }

  Future<void> saveUrl({required String stationId, required String url}) async {
    final normalizedUrl = url.trim();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$cameraUrlPreferencePrefix$stationId',
      normalizedUrl,
    );

    final current = state.valueOrNull ?? <String, String>{};
    state = AsyncData(<String, String>{...current, stationId: normalizedUrl});
  }

  Future<void> removeUrl(String stationId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$cameraUrlPreferencePrefix$stationId');

    final current = state.valueOrNull ?? <String, String>{};
    final next = <String, String>{...current}..remove(stationId);
    state = AsyncData(next);
  }

  Future<Map<String, String>> _loadFromPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final map = <String, String>{};

    for (final key in preferences.getKeys()) {
      if (!key.startsWith(cameraUrlPreferencePrefix)) {
        continue;
      }

      final stationId = key.substring(cameraUrlPreferencePrefix.length);
      final value = preferences.getString(key)?.trim();
      if (value != null && value.isNotEmpty) {
        map[stationId] = value;
      }
    }

    return map;
  }
}
