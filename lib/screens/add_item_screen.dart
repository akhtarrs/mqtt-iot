import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/alert_notification_item.dart';

class AddItemScreen extends StatefulWidget {
  final AlertNotificationItem? existingItem;

  const AddItemScreen({super.key, this.existingItem});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  ItemType _selectedType = ItemType.alert;
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool get isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final item = widget.existingItem!;
      _selectedType = item.type;
      _topicController.text = item.topic;
      _titleController.text = item.title;
      _descriptionController.text = item.description ?? '';
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    final topic = _topicController.text.trim();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (topic.isEmpty || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill topic and title')),
      );
      return;
    }

    final id =
        widget.existingItem?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final item = AlertNotificationItem(
      id: id,
      type: _selectedType,
      topic: topic,
      title: title,
      description: description.isEmpty ? null : description,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('alert_notification_items') ?? <String>[];
      final items = raw
          .map(
            (s) => AlertNotificationItem.fromJson(
              json.decode(s) as Map<String, dynamic>,
            ),
          )
          .toList();

      if (isEditing) {
        final idx = items.indexWhere((element) => element.id == item.id);
        if (idx != -1) {
          items[idx] = item;
        } else {
          items.add(item);
        }
      } else {
        items.add(item);
      }

      final store = items.map((e) => json.encode(e.toJson())).toList();
      await prefs.setStringList('alert_notification_items', store);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Item updated successfully' : 'Item added successfully',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving item: $error'),
        ),
      );
    }
  }

  Widget _buildTypeChip({
    required ItemType type,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withAlpha((0.18 * 255).round()) : Colors.white,
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.05 * 255).round()),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: isSelected ? activeColor : Colors.grey.shade300,
              child: Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? activeColor : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  type == ItemType.alert
                      ? 'Popup with sound'
                      : 'Mobile notification',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          isEditing ? 'Edit Alert/Notification' : 'Add Alert/Notification',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF85D8CE), Color(0xFF0D6EFD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Manage Alert + Notifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Set up your MQTT alert conditions with ease',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Type',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildTypeChip(
                    type: ItemType.alert,
                    label: 'Alert',
                    icon: Icons.notification_important,
                    activeColor: Colors.deepOrange,
                  ),
                  _buildTypeChip(
                    type: ItemType.notification,
                    label: 'Notification',
                    icon: Icons.notifications_active,
                    activeColor: Colors.blueAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                labelText: 'MQTT Topic',
                hintText: 'Enter MQTT topic to monitor',
                prefixIcon: const Icon(Icons.topic),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'Enter title for this item',
                prefixIcon: const Icon(Icons.title),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Enter description',
                prefixIcon: const Icon(Icons.description),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveItem,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isEditing ? 'Update Item' : 'Add Item',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'How it works',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Alert: shows popup with sound when MQTT message received',
            ),
            const Text(
              '• Notification: shows mobile notification when MQTT message received',
            ),
            const Text('• Topic: MQTT topic to subscribe for triggers'),
          ],
        ),
      ),
    );
  }
}
