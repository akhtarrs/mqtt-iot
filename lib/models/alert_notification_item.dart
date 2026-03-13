enum ItemType { alert, notification, device, sensor }

class AlertNotificationItem {
  final String id;
  final ItemType type;
  final String topic;
  final String title;
  final String? description;

  AlertNotificationItem({
    required this.id,
    required this.type,
    required this.topic,
    required this.title,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'topic': topic,
      'title': title,
      'description': description,
    };
  }

  factory AlertNotificationItem.fromJson(Map<String, dynamic> json) {
    return AlertNotificationItem(
      id: json['id'],
      type: ItemType.values.firstWhere((e) => e.name == json['type']),
      topic: json['topic'],
      title: json['title'],
      description: json['description'],
    );
  }
}
