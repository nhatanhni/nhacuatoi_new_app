class StationApi {
  final String id;
  final String stationName;
  final String? stationCode;

  StationApi({
    required this.id,
    required this.stationName,
    this.stationCode,
  });

  factory StationApi.fromJson(Map<String, dynamic> json) {
    return StationApi(
      id: json['Id'] ?? json['id'] ?? '',
      stationName: json['StationName'] ?? json['stationName'] ?? '',
      stationCode: json['StationCode'] ?? json['stationCode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'StationName': stationName,
      'StationCode': stationCode,
    };
  }

  @override
  String toString() {
    return 'StationApi(id: $id, stationName: $stationName, stationCode: $stationCode)';
  }
}
