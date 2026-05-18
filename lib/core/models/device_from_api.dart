class DeviceApi {
  final String id;
  final String name;
  final String? description;
  final String? type;
  final String? topic;
  final String? messenger;
  final String? configHtml;
  final bool? startup;
  final DateTime? createdDateTime;
  final DateTime? updatedDateTime;

  DeviceApi({
    required this.id,
    required this.name,
    this.description,
    this.type,
    this.topic,
    this.messenger,
    this.configHtml,
    this.startup,
    this.createdDateTime,
    this.updatedDateTime,
  });

  factory DeviceApi.fromJson(Map<String, dynamic> json) {
    return DeviceApi(
      id: json['Id'] ?? json['id'] ?? '',
      name: json['Name'] ?? json['name'] ?? '',
      description: json['Description'],
      type: json['Type'] ?? json['type'],
      topic: json['Topic'],
      messenger: json['Messeger'] ?? json['messenger'],
      configHtml: json['ConfigHtml'],
      startup: json['Startup'] as bool?,
      createdDateTime: json['CreatedDateTime'] != null
          ? DateTime.tryParse(json['CreatedDateTime'])
          : null,
      updatedDateTime: json['UpdatedDateTime'] != null
          ? DateTime.tryParse(json['UpdatedDateTime'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Description': description,
      'Type': type,
      'Topic': topic,
      'Messeger': messenger,
      'ConfigHtml': configHtml,
      'Startup': startup,
      'CreatedDateTime': createdDateTime?.toIso8601String(),
      'UpdatedDateTime': updatedDateTime?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'DeviceApi(id: $id, name: $name, description: $description, type: $type, topic: $topic, startup: $startup)';
  }
}