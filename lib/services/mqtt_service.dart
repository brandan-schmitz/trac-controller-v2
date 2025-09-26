import 'dart:async';
import 'dart:io' show X509Certificate;

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../constants.dart';

// Local callback typedefs to avoid depending on Flutter's VoidCallback.
typedef VoidCallback = void Function();
typedef StateCallback = void Function(String featureId, bool on);
typedef EstopCallback = void Function(String state);
typedef ConnectedCallback = void Function();

class MqttService {
  final String host;
  final int port;
  final bool secured;
  final String user;
  final String pass;

  late final MqttServerClient _client;
  StreamSubscription? _updatesSub;
  Timer? _watchdog;
  bool _connecting = false;

  // Current UI-visible state
  final Map<String, bool> _state = <String, bool>{};
  String estopState = 'READY';
  DateTime lastHeartbeat = DateTime.fromMillisecondsSinceEpoch(0);

  // Callbacks (hook these from your UI)
  StateCallback? onFeatureState;
  EstopCallback? onEstopState;
  ConnectedCallback? onConnected;
  VoidCallback? onDisconnected;

  // Quick read for UI to enable/disable controls
  bool get isConnected =>
      _client.connectionStatus?.state == MqttConnectionState.connected;

  MqttService({
    required this.host,
    required this.port,
    required this.secured,
    required this.user,
    required this.pass,
  }) {
    final clientId = 'trac-ui-${DateTime.now().microsecondsSinceEpoch}';

    _client = MqttServerClient(host, clientId)
      ..secure = secured
      ..port = port
      ..logging(on: false)
      ..keepAlivePeriod = 20
      ..connectTimeoutPeriod = 8000
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..setProtocolV311();

    if (_client.secure) {
      // Accept any cert (adjust for production)
      _client.onBadCertificate = (X509Certificate _) => true;
    }

    // IMPORTANT: Put credentials into the connection message so autoReconnect uses them.
    _client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(user, pass)
        .startClean()
        .withWillTopic(mqttUiStatus)
        .withWillMessage('OFFLINE')
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain();

    _client.onConnected = () {
      _ensureSubscriptions();
      _publishOnline();
      _reattachUpdates(); // critical to avoid stale updates stream after reconnect
      onConnected?.call();
    };

    _client.onDisconnected = () {
      onDisconnected?.call();
    };

    _client.onAutoReconnect = () {
      // Optional: add logging if desired
      // e.g., print('MQTT auto-reconnecting…');
    };
  }

  // Public API

  Future<void> connect() => _connectWithRetry();

  void disconnect() {
    _watchdog?.cancel();
    _watchdog = null;
    if (isConnected) _client.disconnect();
  }

  void dispose() {
    _watchdog?.cancel();
    _watchdog = null;
    _updatesSub?.cancel();
    _updatesSub = null;
    if (isConnected) _client.disconnect();
  }

  Map<String, bool> snapshotState() => Map.of(_state);

  /// Returns false immediately if not connected (so UI can toast or ignore).
  bool publishToggle(String featureId) =>
      _pub(mqttFeatureCmd.replaceFirst('{id}', featureId), 'TOGGLE');

  bool publishEstopTrip() => _pub(mqttEstopCmd, 'TRIP');

  bool publishEstopDisarm() => _pub(mqttEstopCmd, 'DISARM');

  // Internals

  Future<void> _connectWithRetry() async {
    if (_connecting) return;
    _connecting = true;
    try {
      if (isConnected) return;
      _startWatchdog();

      // NOTE: credentials are already in connectionMessage; call connect() with no args.
      await _client.connect();
      if (!isConnected) {
        throw Exception('MQTT connect failed: ${_client.connectionStatus}');
      }
    } catch (_) {
      // Keep retry simple; let autoReconnect do the heavy lifting.
      await Future.delayed(const Duration(seconds: 2));
      return _connectWithRetry();
    } finally {
      _connecting = false;
    }
  }

  void _startWatchdog() {
    _watchdog ??= Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!isConnected && !_connecting) {
        _connectWithRetry();
      }
    });
  }

  void _ensureSubscriptions() {
    // These constants come from ../constants.dart
    _client.subscribe(mqttFeatureState, MqttQos.atLeastOnce);
    _client.subscribe(mqttEstopState, MqttQos.atLeastOnce);
    _client.subscribe(mqttHeartbeat, MqttQos.atMostOnce);
  }

  void _reattachUpdates() {
    _updatesSub?.cancel();
    _updatesSub = _client.updates?.listen((
        List<MqttReceivedMessage<MqttMessage>> events,
        ) {
      for (final ev in events) {
        final String topic = ev.topic;
        final MqttPublishMessage msg = ev.payload as MqttPublishMessage;
        final String payload = MqttPublishPayload.bytesToStringAsString(
          msg.payload.message,
        ).trim();

        if (topic == mqttHeartbeat) {
          lastHeartbeat = DateTime.now();
          continue;
        }

        if (topic.startsWith('trac/pool/features/') &&
            topic.endsWith('/state')) {
          // topic: trac/pool/features/<id>/state
          final parts = topic.split('/');
          if (parts.length >= 5) {
            final fid = parts[3];
            final isOn = payload == 'ON';
            _state[fid] = isOn;
            onFeatureState?.call(fid, isOn);
          }
          continue;
        }

        if (topic == mqttEstopState) {
          estopState = payload;
          onEstopState?.call(payload);
          continue;
        }
      }
    });
  }

  void _publishOnline() {
    final b = MqttClientPayloadBuilder()..addString('ONLINE');
    _client.publishMessage(
      mqttUiStatus,
      MqttQos.atLeastOnce,
      b.payload!,
      retain: true,
    );
  }

  // No queue: immediately return false if not connected.
  bool _pub(String topic, String payload) {
    if (!isConnected) return false;
    final b = MqttClientPayloadBuilder()..addString(payload);
    _client.publishMessage(topic, MqttQos.atLeastOnce, b.payload!);
    return true;
  }
}