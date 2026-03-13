class MqttSettings {
  final String host;
  final int port;
  final String clientId;

  MqttSettings({
    required this.host,
    required this.port,
    required this.clientId,
  });

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'clientId': clientId,
    };
  }

  factory MqttSettings.fromJson(Map<String, dynamic> json) {
    return MqttSettings(
      host: json['host'] ?? 'test.mosquitto.org',
      port: json['port'] ?? 1883,
      clientId: json['clientId'] ?? '',
    );
  }
}
