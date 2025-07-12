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
}
