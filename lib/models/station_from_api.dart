class StationApi {
  final String id;
  final String stationName;
  final String? stationCode;
  final String? cameraUrl;
  final String? streamUrl;
  final String? rtspUrl;
  final String? hlsUrl;

  StationApi({
    required this.id,
    required this.stationName,
    this.stationCode,
    this.cameraUrl,
    this.streamUrl,
    this.rtspUrl,
    this.hlsUrl,
  });

  factory StationApi.fromJson(Map<String, dynamic> json) {
    return StationApi(
      id: json['Id'] ?? json['id'] ?? '',
      stationName: json['StationName'] ?? json['stationName'] ?? '',
      stationCode: json['StationCode'] ?? json['stationCode'],
      cameraUrl: _readNullableString(json, ['CameraUrl', 'cameraUrl']),
      streamUrl: _readNullableString(json, ['StreamUrl', 'streamUrl']),
      rtspUrl: _readNullableString(json, ['RtspUrl', 'rtspUrl']),
      hlsUrl: _readNullableString(json, ['HlsUrl', 'hlsUrl']),
    );
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) {
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String? get preferredCameraUrl {
    for (final candidate in [cameraUrl, streamUrl, hlsUrl, rtspUrl]) {
      final url = candidate?.trim();
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'StationName': stationName,
      'StationCode': stationCode,
      'CameraUrl': cameraUrl,
      'StreamUrl': streamUrl,
      'RtspUrl': rtspUrl,
      'HlsUrl': hlsUrl,
    };
  }

  @override
  String toString() {
    return 'StationApi(id: $id, stationName: $stationName, stationCode: $stationCode, preferredCameraUrl: $preferredCameraUrl)';
  }
}
