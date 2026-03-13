enum ItemType { alert, notification, device, sensor }

const String mqttItemsStorageKey = 'mqtt_items';

class MqttItem {
  final String id;
  final ItemType type;
  final String topic;
  final String title;
  final String? description;
  final String? payload;

  MqttItem({
    required this.id,
    required this.type,
    required this.topic,
    required this.title,
    this.description,
    this.payload,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'topic': topic,
      'title': title,
      'description': description,
      'payload': payload,
    };
  }

  factory MqttItem.fromJson(Map<String, dynamic> json) {
    return MqttItem(
      id: json['id'],
      type: ItemType.values.firstWhere((e) => e.name == json['type']),
      topic: json['topic'],
      title: json['title'],
      description: json['description'],
      payload: json['payload'],
    );
  }
}