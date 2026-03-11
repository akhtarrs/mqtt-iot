import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/settings_screen.dart';
import 'screens/add_item_screen.dart';
import 'services/mqtt_service.dart';
import 'models/mqtt_settings.dart';
import 'models/alert_notification_item.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQTT IoT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _isConnected = false;
  late MqttService _mqttService;
  MqttSettings? _mqttSettings;
  bool _isConnecting = false;
  List<AlertNotificationItem> _items = [];
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  late final AnimationController _addButtonController;
  late final Animation<double> _addButtonFloat;

  @override
  void initState() {
    super.initState();
    _mqttService = MqttService();
    _mqttService.setOnConnected(_handleConnected);
    _mqttService.setOnDisconnected(_handleDisconnected);
    _mqttService.setOnMessage(_handleMqttMessage);
    _addButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _addButtonFloat = Tween<double>(begin: -3.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _addButtonController,
        curve: Curves.easeInOut,
      ),
    );
    _initializeNotifications();
    _loadSettings();
    _loadItems();
  }

  @override
  void dispose() {
    _addButtonController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload settings when returning from settings page
    _loadSettings();
  }

  void _handleConnected() {
    setState(() {
      _isConnected = true;
      _isConnecting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connected to MQTT broker'),
        duration: Duration(seconds: 2),
      ),
    );

    // Wait 5 seconds before subscribing to topics to ensure stable connection
    Future.delayed(const Duration(seconds: 5), () {
      if (_isConnected && _items.isNotEmpty) {
        debugPrint('Subscribing to ${_items.length} topics after connection stabilization...');
        for (final item in _items) {
          _mqttService.subscribe(item.topic);
        }
        debugPrint('All topics subscribed successfully');
      }
    });
  }

  void _handleDisconnected() {
    setState(() {
      _isConnected = false;
      _isConnecting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Disconnected from MQTT broker'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsString = prefs.getString('mqtt_settings');

      if (settingsString != null && settingsString.isNotEmpty) {
        final parts = settingsString.split('|');
        if (parts.length == 3) {
          setState(() {
            _mqttSettings = MqttSettings(
              host: parts[0],
              port: int.parse(parts[1]),
              clientId: parts[2],
            );
          });
        }
      } else {
        // Create default settings if none exist
        setState(() {
          _mqttSettings = MqttSettings(
            host: 'test.mosquitto.org',
            port: 1883,
            clientId: _generateDefaultClientId(),
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      // Set default settings on error
      setState(() {
        _mqttSettings = MqttSettings(
          host: 'test.mosquitto.org',
          port: 1883,
          clientId: _generateDefaultClientId(),
        );
      });
    }
  }

  Future<void> _initializeNotifications() async {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create notification channel for Android 8.0+
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'mqtt_channel',
        'MQTT Notifications',
        description: 'Notifications for MQTT messages',
        importance: Importance.max,
      );
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Request notification permissions
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        debugPrint('Notification permission granted');
      } else {
        debugPrint('Notification permission denied');
      }
    }
  }

  void _handleMqttMessage(String topic, String message) {
    // Find items that match this topic
    final matchingItems = _items.where((item) => item.topic == topic).toList();

    for (final item in matchingItems) {
      if (item.type == ItemType.alert) {
        _showAlert(item, message);
      } else if (item.type == ItemType.notification) {
        _showNotification(item, message);
      }
    }
  }

  void _showAlert(AlertNotificationItem item, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(item.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Topic: ${item.topic}'),
              const SizedBox(height: 8),
              Text('Message: $message'),
              if (item.description != null) ...[
                const SizedBox(height: 8),
                Text('Description: ${item.description}'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showNotification(AlertNotificationItem item, String message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'mqtt_channel',
      'MQTT Notifications',
      channelDescription: 'Notifications for MQTT messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      item.id.hashCode,
      item.title,
      'Topic: ${item.topic} - Message: $message',
      platformChannelSpecifics,
    );
  }

  String _generateDefaultClientId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _loadItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = prefs.getStringList('alert_notification_items') ?? [];
      setState(() {
        _items = itemsJson
            .map((jsonStr) =>
                AlertNotificationItem.fromJson(json.decode(jsonStr)))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading items: $e');
      setState(() {
        _items = [];
      });
    }
  }

  void _editItem(AlertNotificationItem item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddItemScreen(existingItem: item),
      ),
    );
    if (result == true) {
      await _loadItems();
    }
  }

  void _onSettingsPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _onAddPressed() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddItemScreen()),
    );

    if (result == true) {
      await _loadItems();
      // Subscribe to new topics if connected (with delay for stability)
      if (_isConnected && _items.isNotEmpty) {
        Future.delayed(const Duration(seconds: 5), () {
          if (_isConnected) {
            debugPrint('Subscribing to newly added topics...');
            for (final item in _items) {
              _mqttService.subscribe(item.topic);
            }
            debugPrint('New topics subscribed successfully');          }
        });
      }
    }
  }
  Future<void> _onConnectPressed() async {
    if (_isConnecting) return;

    if (_isConnected) {
      _mqttService.disconnect();
    } else {
      setState(() {
        _isConnecting = true;
      });

      final connected = await _mqttService.connect(_mqttSettings!);

      if (!connected && mounted) {
        setState(() {
          _isConnecting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to MQTT broker'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MQTT IoT'),
        centerTitle: true,
        elevation: 2,
      ),
      body: Column(
        children: [
          // Connection Status
          Container(
            padding: const EdgeInsets.all(16),
            color: _isConnected ? Colors.green.shade50 : Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isConnected ? Icons.cloud_done : Icons.cloud_off,
                  size: 24,
                  color: _isConnected ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Items List
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No alerts or notifications added yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the + button to add your first item',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(
                            item.type == ItemType.alert
                                ? Icons.warning
                                : Icons.notifications,
                            color: item.type == ItemType.alert
                                ? Colors.orange
                                : Colors.blue,
                            size: 32,
                          ),
                          title: Text(item.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Topic: ${item.topic}'),
                              if (item.description != null)
                                Text('Description: ${item.description}'),
                              Text(
                                item.type == ItemType.alert ? 'Alert' : 'Notification',
                                style: TextStyle(
                                  color: item.type == ItemType.alert
                                      ? Colors.orange
                                      : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editItem(item),
                          ),
                          onTap: () => _editItem(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.1 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: BottomAppBar(
          elevation: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Settings Button
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: _onSettingsPressed,
              ),
              // Add Button
              AnimatedBuilder(
                animation: _addButtonFloat,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _addButtonFloat.value),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: _onAddPressed,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFD5EDF9),
                          Color(0xFF57C7F9),
                          Color(0xFF08F2B7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.18 * 255).round()),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
              // Connect Button
              IconButton(
                icon: _isConnecting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        _isConnected ? Icons.cloud_done : Icons.cloud_off,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                tooltip: _isConnecting ? 'Connecting...' : 'Connect',
                onPressed: _onConnectPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
