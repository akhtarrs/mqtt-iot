import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF57C7F9),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF57C7F9),
          secondary: const Color(0xFF08F2B7),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6FBFE),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF0F172A),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
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
        } else {
          debugPrint('Error loading settings: Invalid settings format');
          setState(() {
            _mqttSettings = null;
          });
        }
      } 
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() {
        _mqttSettings = null;
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
      if (_mqttSettings == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set MQTT server from Settings before connecting.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

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
        child: Column(
          children: [
            // Connection Status
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(14),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isConnected
                          ? const Color(0xFF08F2B7).withAlpha((0.2 * 255).round())
                          : Colors.grey.withAlpha((0.15 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isConnected ? Icons.cloud_done : Icons.cloud_off,
                      size: 20,
                      color: _isConnected ? const Color(0xFF08F2B7) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color: _isConnected ? const Color(0xFF0F766E) : Colors.grey,
                      fontWeight: FontWeight.w700,
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
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha((0.06 * 255).round()),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_circle_outline,
                              size: 44,
                              color: Color(0xFF57C7F9),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No alerts or notifications added yet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap the + button to add your first item',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
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
                          child: ListTile(
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: item.type == ItemType.alert
                                    ? Colors.orange.withAlpha((0.2 * 255).round())
                                    : const Color(0xFF57C7F9)
                                        .withAlpha((0.2 * 255).round()),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.type == ItemType.alert
                                    ? Icons.warning
                                    : Icons.notifications,
                                color: item.type == ItemType.alert
                                    ? Colors.orange
                                    : const Color(0xFF57C7F9),
                                size: 22,
                              ),
                            ),
                            title: Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
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
                                        : const Color(0xFF57C7F9),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            trailing: _AnimatedIconButton(
                              icon: Icons.edit,
                              tooltip: 'Edit',
                              onTap: () => _editItem(item),
                            ),
                            onTap: () => _editItem(item),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.08 * 255).round()),
              blurRadius: 16,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: BottomAppBar(
          elevation: 0,
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Settings Button
              _AnimatedIconButton(
                icon: Icons.settings,
                tooltip: 'Settings',
                onTap: _onSettingsPressed,
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
                child: _AnimatedPress(
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
              _AnimatedIconButton(
                tooltip: _isConnecting ? 'Connecting...' : 'Connect',
                onTap: _onConnectPressed,
                child: _isConnecting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isConnected ? Icons.cloud_done : Icons.cloud_off,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedIconButton extends StatelessWidget {
  const _AnimatedIconButton({
    required this.onTap,
    this.icon,
    this.tooltip,
    this.child,
  });

  final VoidCallback onTap;
  final IconData? icon;
  final String? tooltip;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final buttonChild = child ??
        Icon(
          icon,
          color: const Color(0xFF0F172A),
        );
    return _AnimatedPress(
      onTap: onTap,
      child: Tooltip(
        message: tooltip ?? '',
        waitDuration: const Duration(milliseconds: 400),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: buttonChild),
        ),
      ),
    );
  }
}

class _AnimatedPress extends StatefulWidget {
  const _AnimatedPress({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_AnimatedPress> createState() => _AnimatedPressState();
}

class _AnimatedPressState extends State<_AnimatedPress> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}
