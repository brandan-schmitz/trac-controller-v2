import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../dialogs/estop_dialog.dart';
import '../dialogs/pin_dialog.dart';
import '../services/mqtt_service.dart';
import '../services/settings_service.dart';
import '../widgets/feature_button.dart';

class HomePage extends StatefulWidget {
  final Settings settings;

  const HomePage({super.key, required this.settings});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Settings _settings; // ← always-current settings
  late MqttService mqtt;
  final states = <String, bool>{for (final f in featureIds) f: false};
  String estopState = 'READY';
  Timer? _uiTick;

  // ---- connection alert state ----
  bool _connAlertVisible = false;

  int _ageSeconds() => DateTime.now().difference(mqtt.lastHeartbeat).inSeconds;

  bool _isConnLost() => _ageSeconds() > connRedSeconds;

  @override
  void initState() {
    super.initState();

    _settings = widget.settings; // seed from initial snapshot

    mqtt = MqttService(
      host: _settings.mqttHost,
      port: _settings.mqttPort,
      user: _settings.mqttUser,
      pass: _settings.mqttPass,
      secured: _settings.mqttSecured,
    );
    mqtt.onFeatureState = (fid, on) {
      setState(() => states[fid] = on);
    };
    mqtt.onEstopState = (s) {
      setState(() => estopState = s);
      if (s == 'TRIPPED') {
        _showEstop();
      } else {
        _hideEstop();
      }
    };
    mqtt.onConnected = () {
      // immediately dismiss "not connected" alert if it's open
      _hideConnAlert();
      setState(() {});
    };
    mqtt.onDisconnected = () {
      setState(() {});
    };
    mqtt.connect();

    _uiTick = Timer.periodic(const Duration(seconds: 1), (_) {
      // If alert is open and we regained connection, close it
      if (_connAlertVisible && mqtt.isConnected) {
        _hideConnAlert();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTick?.cancel();
    mqtt.disconnect();
    super.dispose();
  }

  // ---- Settings + MQTT refresh helpers ----

  bool _sameMqtt(Settings a, Settings b) {
    return a.mqttHost == b.mqttHost &&
        a.mqttPort == b.mqttPort &&
        a.mqttSecured == b.mqttSecured &&
        a.mqttUser == b.mqttUser &&
        a.mqttPass == b.mqttPass;
  }

  Future<void> _reloadSettings({bool maybeRestartMqtt = true}) async {
    final fresh = await SettingsStore.load();
    if (!mounted) return;

    final needsRestart = maybeRestartMqtt && !_sameMqtt(_settings, fresh);

    setState(() {
      _settings = fresh;
    });

    if (needsRestart) {
      await _restartMqtt();
    }
  }

  Future<void> _restartMqtt() async {
    try {
      mqtt.disconnect();
    } catch (_) {}
    final next = MqttService(
      host: _settings.mqttHost,
      port: _settings.mqttPort,
      user: _settings.mqttUser,
      pass: _settings.mqttPass,
      secured: _settings.mqttSecured,
    );
    next.onFeatureState = (fid, on) {
      setState(() => states[fid] = on);
    };
    next.onEstopState = (s) {
      setState(() => estopState = s);
      if (s == 'TRIPPED') {
        _showEstop();
      } else {
        _hideEstop();
      }
    };
    next.onConnected = () {
      _hideConnAlert();
      setState(() {});
    };
    next.onDisconnected = () {
      setState(() {});
    };

    setState(() {
      mqtt = next;
    });
    mqtt.connect();
  }

  Color _statusColor() {
    if (_ageSeconds() <= connYellowSeconds) return Colors.green;
    if (_ageSeconds() <= connRedSeconds) return Colors.yellow.shade700;
    return Colors.red;
  }

  void _showEstop() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EstopDialog(onRestart: () => mqtt.publishEstopDisarm()),
    );
  }

  void _hideEstop() {
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  Future<void> _openSettings() async {
    // Always refresh before prompting for PIN (avoid stale pinMustChange)
    await _reloadSettings(maybeRestartMqtt: false);
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PinDialog(settings: _settings),
    );

    if (ok == true && mounted) {
      // Navigate to Settings with a fresh snapshot.
      await Navigator.of(context).pushNamed('/settings', arguments: _settings);

      // After returning, reload again; will auto-restart MQTT if changed.
      await _reloadSettings();
    }
  }

  // ---- Not Connected Alert ----

  void _showConnAlert() {
    if (_connAlertVisible) return;
    _connAlertVisible = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false, // only the button dismisses it
      builder: (ctx) {
        // Visual style aligned to your other dialogs: bold title, roomy content, big action.
        return AlertDialog(
          title: const Text('Connection Lost', textAlign: TextAlign.center),
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 45,
          ),
          titlePadding: EdgeInsetsGeometry.fromLTRB(100, 75, 100, 25),
          content: const Text(
            'This panel is not connect to the MQTT event manager.\n'
            'Please verify settings and re-establish the connection\n'
            'before the feature buttons will work again.',
            textAlign: TextAlign.center,
          ),
          contentPadding: EdgeInsetsGeometry.fromLTRB(100, 50, 100, 75),
          contentTextStyle: TextStyle(fontSize: 24, color: Colors.black),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => _hideConnAlert(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(50, 15, 50, 15),
                child: Text(
                  'Dismiss',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      // If popped externally (e.g., navigator back), keep state consistent
      _connAlertVisible = false;
    });
  }

  void _hideConnAlert() {
    if (!_connAlertVisible) return;
    _connAlertVisible = false;
    // Use rootNavigator to ensure we close the modal even if inside nested navigators.
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  // Helper to gate actions behind connection; shows alert if offline
  void _ensureConnectedOrAlert(VoidCallback onConnectedAction) {
    if (!mqtt.isConnected) {
      _showConnAlert();
      return;
    }
    onConnectedAction();
  }

  Widget _connectionBanner() {
    if (!_isConnLost()) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.red,
      child: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.white),
          Expanded(
            child: Text(
              'WARNING: Connection to the MQTT event manager has been lost. Attempting to reconnect.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _connectionBanner(),
            Container(
              height: _isConnLost() ? 111 : 150,
              alignment: Alignment.center,
              child: const Text(
                appTitle,
                style: TextStyle(fontSize: 70, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 1280,
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _col([
                            'play_structure',
                            'river_fountains',
                            'yellow_slide',
                          ]),
                          _col(['lazy_river', 'center_jets', 'blue_slide']),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 500,
                        height: 75,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _ensureConnectedOrAlert(
                            () => mqtt.publishEstopTrip(),
                          ),
                          child: const Text('Emergency Shutoff'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _statusColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    iconSize: 40,
                    onPressed: _openSettings,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _col(List<String> fids) {
    return Column(
      children: [
        for (final fid in fids) ...[
          FeatureButton(
            label: featureLabels[fid]!,
            on: states[fid] ?? false,
            onPressed: () {
              _ensureConnectedOrAlert(() => mqtt.publishToggle(fid));
            },
          ),
          const SizedBox(height: 40),
        ],
      ],
    );
  }
}
