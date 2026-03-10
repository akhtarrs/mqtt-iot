import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mqtt_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _clientIdController;
  String _generatedClientId = '';

  @override
  void initState() {
    super.initState();
    _generatedClientId = _generateClientId();
    _hostController = TextEditingController(text: 'test.mosquitto.org');
    _portController = TextEditingController(text: '1883');
    _clientIdController = TextEditingController(text: _generatedClientId);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _clientIdController.dispose();
    super.dispose();
  }

  String _generateClientId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
  }

  void _regenerateClientId() {
    setState(() {
      _generatedClientId = _generateClientId();
      _clientIdController.text = _generatedClientId;
    });
  }

  void _saveSettings() async {
    final host = _hostController.text.trim();
    final port = _portController.text.trim();
    final clientId = _clientIdController.text.trim();

    if (host.isEmpty || port.isEmpty || clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = MqttSettings(
        host: host,
        port: int.parse(port),
        clientId: clientId,
      );

      await prefs.setString('mqtt_settings', 
        '${settings.host}|${settings.port}|${settings.clientId}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MQTT Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // MQTT Server Section
            Text(
              'MQTT Server',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Host Field
            TextField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: 'Host',
                hintText: 'Enter MQTT broker host',
                prefixIcon: const Icon(Icons.language),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Port Field
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Port',
                hintText: 'Enter MQTT broker port',
                prefixIcon: const Icon(Icons.pin),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Client ID Section
            Text(
              'Client Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Client ID Field
            TextField(
              controller: _clientIdController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Client ID',
                hintText: 'Auto-generated',
                prefixIcon: const Icon(Icons.assignment_ind),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Regenerate Client ID Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _regenerateClientId,
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerate Client ID'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Save Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Info Section
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ℹ️ Default Settings',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Host: test.mosquitto.org (Public MQTT Broker)'),
                  const Text('• Port: 1883 (Standard MQTT)'),
                  const Text('• Client ID: Auto-generated (12 characters)'),
                  const Text('• Security: None (for development)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
