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
    final subtitle = switch (type) {
      ItemType.alert => 'Popup with sound',
      ItemType.notification => 'Mobile notification',
      ItemType.device => 'Send payload to device',
      ItemType.sensor => 'Receive payload from sensor',
    };

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        height: 84,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withAlpha((0.14 * 255).round())
              : Colors.white,
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(
                ((isSelected ? 0.07 : 0.04) * 255).round(),
              ),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected ? activeColor : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? activeColor : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle,
                  size: 16,
                  color: activeColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Alert/Notification' : 'Add Alert/Notification',
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFD5EDF9),
              Color(0xFFF6FBFE),
              Color(0xFFE8FBF5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD5EDF9), Color(0xFF57C7F9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.08 * 255).round()),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Alert + Notifications',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Set up MQTT trigger rules for alerts and notifications',
                      style: TextStyle(color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.06 * 255).round()),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWideLayout = constraints.maxWidth >= 560;
                        const chipSpacing = 10.0;

                        Widget buildChip(ItemType type, String label, IconData icon, Color activeColor) {
                          return _buildTypeChip(
                            type: type,
                            label: label,
                            icon: icon,
                            activeColor: activeColor,
                          );
                        }

                        final chips = [
                          buildChip(
                            ItemType.alert,
                            'Alert',
                            Icons.notification_important,
                            Colors.deepOrange,
                          ),
                          buildChip(
                            ItemType.notification,
                            'Notification',
                            Icons.notifications_active,
                            const Color(0xFF57C7F9),
                          ),
                          buildChip(
                            ItemType.device,
                            'Device',
                            Icons.memory,
                            const Color(0xFF57C7F9),
                          ),
                          buildChip(
                            ItemType.sensor,
                            'Sensor',
                            Icons.sensors,
                            const Color(0xFF57C7F9),
                          ),
                        ];

                        if (isWideLayout) {
                          final chipWidth = (constraints.maxWidth - chipSpacing) / 2;
                          return Wrap(
                            spacing: chipSpacing,
                            runSpacing: chipSpacing,
                            children: chips
                                .map((chip) => SizedBox(width: chipWidth, child: chip))
                                .toList(),
                          );
                        }

                        return SizedBox(
                          height: 88,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: chips.length,
                            separatorBuilder: (_, __) => const SizedBox(width: chipSpacing),
                            itemBuilder: (context, index) {
                              return SizedBox(width: 158, child: chips[index]);
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _topicController,
                      decoration: InputDecoration(
                        labelText: 'MQTT Topic',
                        hintText: 'Enter MQTT topic to monitor',
                        prefixIcon: const Icon(Icons.topic),
                        filled: true,
                        fillColor: const Color(0xFFF8FBFE),
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
                        fillColor: const Color(0xFFF8FBFE),
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
                        fillColor: const Color(0xFFF8FBFE),
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
                          backgroundColor: const Color(0xFF57C7F9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF57C7F9).withAlpha((0.3 * 255).round()),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.05 * 255).round()),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How it works',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Alert: shows popup with sound when MQTT message received'),
                    const Text('• Notification: shows mobile notification when MQTT message received'),
                    const Text('• Device: sends payload to actual device'),
                    const Text('• Sensor: receives payload from actual sensor'),
                    const Text('• Topic: MQTT topic to subscribe for triggers'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
