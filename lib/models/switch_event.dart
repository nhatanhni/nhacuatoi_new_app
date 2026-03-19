class SwitchEvent {
  final DateTime timestamp;
  final bool isSwitched;

  SwitchEvent(this.timestamp, this.isSwitched);

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'isSwitched': isSwitched ? 1 : 0,
    };
  }

  SwitchEvent.fromMap(Map<String, dynamic> map)
      : timestamp = DateTime.parse(map['timestamp']),
        isSwitched = map['isSwitched'] == 1 ? true : false;

  factory SwitchEvent.fromJson(Map<String, dynamic> json) {
    // Server có thể trả về key khác, ví dụ: 'Timestamp', 'IsSwitched'
    final timestampStr = json['timestamp'] ?? json['Timestamp'];
    final isSwitchedVal = json['isSwitched'] ?? json['IsSwitched'] ?? json['status'] ?? json['Status'];
    return SwitchEvent(
      DateTime.tryParse(timestampStr ?? '') ?? DateTime(1970),
      isSwitchedVal == 1 || isSwitchedVal == true || isSwitchedVal == '1' || (isSwitchedVal is String && isSwitchedVal.toLowerCase() == 'true'),
    );
  }
}
