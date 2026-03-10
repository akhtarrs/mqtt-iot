import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/mqtt_settings.dart';

class MqttService {
  MqttServerClient? _client;
  bool _isConnected = false;
  Function? _onConnected;
  Function? _onDisconnected;
  Function(String, String)? _onMessage;

  bool get isConnected => _isConnected;

  MqttService();

  void setOnConnected(Function onConnected) {
    _onConnected = onConnected;
  }

  void setOnDisconnected(Function onDisconnected) {
    _onDisconnected = onDisconnected;
  }

  void setOnMessage(Function(String, String) onMessage) {
    _onMessage = onMessage;
  }

  Future<bool> connect(MqttSettings settings) async {
    try {
      _client = MqttServerClient(settings.host, settings.clientId)
        ..port = settings.port
        ..logging(on: false)
        ..onConnected = _onConnectedHandler
        ..onDisconnected = _onDisconnectedHandler
        ..onSubscribed = _onSubscribedHandler;

      final connMessage = MqttConnectMessage()
        ..withClientIdentifier(settings.clientId)
        ..withWillTopic('willtopic')
        ..withWillMessage('Will message')
        ..startClean();

      _client!.connectionMessage = connMessage;

      await _client!.connect().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _client!.disconnect();
          throw Exception('Connection timeout');
        },
      );

      // Set up message handler
      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String topic = c[0].topic;
        final String message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        _onMessage?.call(topic, message);
      });

      _isConnected = true;
      _onConnected?.call();
      return true;
    } catch (e) {
      print('MQTT Connection error: $e');
      _isConnected = false;
      _onDisconnected?.call();
      return false;
    }
  }

  void disconnect() {
    try {
      _client?.disconnect();
      _isConnected = false;
      _onDisconnected?.call();
    } catch (e) {
      print('MQTT Disconnect error: $e');
    }
  }

  void publish(String topic, String message) {
    if (!_isConnected || _client == null) {
      print('Client is not connected');
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void subscribe(String topic) {
    if (!_isConnected || _client == null) {
      print('MQTT: Cannot subscribe to $topic - client not connected');
      return;
    }

    print('MQTT: Subscribing to topic: $topic');
    _client!.subscribe(topic, MqttQos.atLeastOnce);
  }

  void _onConnectedHandler() {
    print('MQTT: Connection established successfully');
    _isConnected = true;
    _onConnected?.call();
  }

  void _onDisconnectedHandler() {
    print('MQTT: Connection lost/disconnected');
    _isConnected = false;
    _onDisconnected?.call();
  }

  void _onSubscribedHandler(String topic) {
    print('MQTT: Successfully subscribed to topic: $topic');
  }
}
