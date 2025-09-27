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
  late Settings _settings;
  late MqttService mqtt;
  final states = <String, bool>{for (final f in featureIds) f: false};
  String estopState = 'READY';
  Timer? _uiTick;
  bool _connAlertVisible = false;

  @override
  void initState() {
    super.initState();

    _settings = widget.settings;

    // Connect to the MQTT server
    connectMqtt();

    // Create a timer that runs every second to monitor for changes in the connection status.
    // This hides the connect alert if it is connected.
    _uiTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connAlertVisible && mqtt.isConnected) {
        _hideConnAlert();
      }
      setState(() {});
    });
  }

  // Control what happens when the home page is disposed of
  @override
  void dispose() {
    _uiTick?.cancel();
    try { mqtt.disconnect(); } catch (_) {}
    super.dispose();
  }

  // Restart the MQTT service
  Future<void> connectMqtt() async {
    // Attempt to disconnect from the currently connected service
    try {
      mqtt.disconnect();
    } catch (_) {}

    final newMqtt = MqttService(
      host: _settings.mqttHost,
      port: _settings.mqttPort,
      user: _settings.mqttUser,
      pass: _settings.mqttPass,
      secured: _settings.mqttSecured,
      identifier: _settings.mqttIdentifier
    );

    newMqtt.onFeatureState = (fid, on) {
      setState(() {
        states[fid] = on;
      });
    };

    newMqtt.onEstopState = (state) {
      setState(() {
        estopState = state;
      });

      if (state == 'TRIPPED') {
        if (!mounted) return;
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => EstopDialog(onRestart: () async {
              _ensureConnectedOrAlert(() {
                mqtt.publishEstopDisarm();
              });
            })
        );
      } else {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).maybePop();
        }
      }
    };

    // Control the actions taken when mqtt is connected
    newMqtt.onConnected = () {
      _hideConnAlert();
      setState(() {});
    };

    // Control the actions taken when mqtt is disconnected
    newMqtt.onDisconnected = () {
      setState(() {});
    };

    // Replace the mqtt object with the configured one
    setState(() {
      mqtt = newMqtt;
    });

    // Connect to the mqtt server
    await mqtt.connect();
  }

  // Reload the MQTT settings
  Future<void> _reloadSettings() async {
    // Load the latest settings from the settings storage
    final latestSettings = await SettingsStore.load();

    // Compare the latest settings against the previous settings and if they have changed
    // then restart the MQTT connection.
    if (!(_settings.mqttHost == latestSettings.mqttHost &&
        _settings.mqttPort == latestSettings.mqttPort &&
        _settings.mqttSecured == latestSettings.mqttSecured &&
        _settings.mqttUser == latestSettings.mqttUser &&
        _settings.mqttPass == latestSettings.mqttPass)) {
      setState(() {
        _settings = latestSettings;
      });
      await connectMqtt();
    }
  }

  // Builder for creating the columns used for the feature buttons
  Widget _col(List<String> fids) {
    return Column(
      children: [
        for (final fid in fids) ...[
          FeatureButton(
            label: featureLabels[fid]!,
            on: states[fid] ?? false,
            onPressed: () async {
              _ensureConnectedOrAlert(() {
                mqtt.publishToggle(fid);
              });
            },
          ),
          const SizedBox(height: 40),
        ],
      ],
    );
  }

  // Hide the disconnected mqtt connection alert
  void _hideConnAlert() {
    if (!_connAlertVisible) return;
    _connAlertVisible = false;
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  // Helper to gate actions behind connection; shows alert if offline
  void _ensureConnectedOrAlert(VoidCallback onConnectedAction) {
    // Check to see if MQTT is disconnected
    if (!mqtt.isConnected) {
      // If disconnected, but the alert is already disable we do not need to do anything
      if (_connAlertVisible) return;

      // Show the dialog stating that the mqtt connection is diconnected
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
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
        // If popped externally keep the state consistent
        _connAlertVisible = false;
      });

      // Set that the connection alert is now visible
      _connAlertVisible = true;
      return;
    } else {
      // The action to take if mqtt was connected
      onConnectedAction();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            if (mqtt.isConnected)
              const SizedBox.shrink()
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
              ),
            Container(
              height: mqtt.isConnected ? 150 : 111,
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
                          color: mqtt.isConnected ? Colors.green : Colors.red,
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
                    onPressed: () async {
                      final ctx = context;
                      // Always refresh before prompting for PIN
                      await _reloadSettings();

                      if (!ctx.mounted) return;

                      // Show the pin dialog
                      final ok = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => PinDialog(settings: _settings),
                      );

                      if (!ctx.mounted) return;
                      // If the pin was successfully entered, show the settings dialog
                      // and reload settings upon closing them.
                      if (ok == true) {
                        await Navigator.of(
                          context,
                        ).pushNamed('/settings', arguments: _settings);
                        await _reloadSettings();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
