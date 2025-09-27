import 'dart:async';
import 'dart:io' show X509Certificate;

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../constants.dart';

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
  final String identifier;

  late final MqttServerClient _client;
  StreamSubscription? _updatesSub;
  Timer? _watchdog;
  bool _connecting = false;
  bool _watchdogFailed = false;

  final Map<String, bool> _state = <String, bool>{};
  String estopState = 'READY';
  DateTime lastHeartbeat = DateTime.fromMillisecondsSinceEpoch(0);

  StateCallback? onFeatureState;
  EstopCallback? onEstopState;
  ConnectedCallback? onConnected;
  VoidCallback? onDisconnected;

  bool get isConnected => !_watchdogFailed && (_client.connectionStatus?.state == MqttConnectionState.connected);

  MqttService({
    required this.host,
    required this.port,
    required this.secured,
    required this.user,
    required this.pass,
    required this.identifier
  }) {
    final clientId = 'trac-ui-$identifier';

    // Build the client
    _client = MqttServerClient(host, clientId)
      ..secure = secured
      ..port = port
      ..keepAlivePeriod = 20
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..setProtocolV311();

    // Allow using self signed certificates if one is invalid
    if (_client.secure) {
      _client.onBadCertificate = (X509Certificate _) => true;
    }

    // Create the connection message
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
      _reattachUpdates();
      onConnected?.call();
    };

    _client.onAutoReconnect = () {
      _ensureSubscriptions();
      _publishOnline();
      _reattachUpdates();
      onConnected?.call();
    };

    _client.onDisconnected = () {
      onDisconnected?.call();
    };
  }

  Future<void> connect() async {
    _startWatchdog();
    _connectWithRetry();
  }

  Future<void> _connectWithRetry() async {
    if (_connecting) return;
    _connecting = true;
    try {
      if (isConnected && !_watchdogFailed) return;

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
      _watchdogFailed = false;
    }
  }

  void _startWatchdog() {
    _watchdog ??= Timer.periodic(const Duration(seconds: 3), (_) async {
      if (DateTime.now().difference(lastHeartbeat).inSeconds >= 7) {
        _watchdogFailed = true;
      } else {
        _watchdogFailed = false;
      }

      if (!isConnected && !_connecting || _watchdogFailed) {
        _connectWithRetry();
      }
    });
  }

  void disconnect() {
    if (isConnected) _client.disconnect();
  }

  void dispose() {
    _updatesSub?.cancel();
    _updatesSub = null;
    if (isConnected) _client.disconnect();
  }

  bool publishToggle(String featureId) =>
      _pub(mqttFeatureCmd.replaceFirst('{id}', featureId), 'TOGGLE');
  bool publishEstopTrip() => _pub(mqttEstopCmd, 'TRIP');
  bool publishEstopDisarm() => _pub(mqttEstopCmd, 'DISARM');

  void _ensureSubscriptions() {
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

  bool _pub(String topic, String payload) {
    if (!isConnected) return false;
    final b = MqttClientPayloadBuilder()..addString(payload);
    _client.publishMessage(topic, MqttQos.atLeastOnce, b.payload!);
    return true;
  }
}
