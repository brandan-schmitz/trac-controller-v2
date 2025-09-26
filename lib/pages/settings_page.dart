import 'dart:io';

import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../widgets/dashed_divider.dart';

class SettingsPage extends StatefulWidget {
  final Settings initial;

  const SettingsPage({super.key, required this.initial});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // MQTT/PIN controllers
  late TextEditingController host, port, user, pass, pin;
  bool _wifiPassObscured = true;
  bool _mqttPassObscured = true;
  bool _adminPinObscured = true;

  // Local working copy of Settings so we can copyWith and save
  late Settings _current;

  // Networking controls (controllers seeded from _current in initState)
  String ipModeWifi = 'dhcp', ipModeEth = 'dhcp';
  final ssidCtrl = TextEditingController();
  final wifiPsk = TextEditingController();
  final wifiAddr = TextEditingController(),
      wifiGw = TextEditingController(),
      wifiDns = TextEditingController();
  final ethAddr = TextEditingController(),
      ethGw = TextEditingController(),
      ethDns = TextEditingController();

  // SSID picker dialog
  bool _manualSsid = false;
  String? _selectedSsid;
  bool _ssidScanning = false;
  List<String> _ssidOptions = [];
  bool _ssidScanInFlight = false; // <-- add this

  @override
  void initState() {
    super.initState();
    _current = widget.initial;

    // MQTT/PIN
    host = TextEditingController(text: _current.mqttHost);
    port = TextEditingController(text: _current.mqttPort.toString());
    user = TextEditingController(text: _current.mqttUser);
    pass = TextEditingController(text: _current.mqttPass);
    pin = TextEditingController(text: _current.pin);

    // Wi-Fi
    ipModeWifi = _current.wifiMode;
    _selectedSsid = _current.wifiSsid.isNotEmpty ? _current.wifiSsid : null;
    ssidCtrl.text = _current.wifiSsid;
    wifiPsk.text = _current.wifiPsk;
    wifiAddr.text = _current.wifiAddr;
    wifiGw.text = _current.wifiGw;
    wifiDns.text = _current.wifiDns;

    // Ethernet
    ipModeEth = _current.ethMode;
    ethAddr.text = _current.ethAddr;
    ethGw.text = _current.ethGw;
    ethDns.text = _current.ethDns;
  }

  // ---------- SSID picker dialog ----------
  Future<void> _openSsidPicker() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        bool started = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            if (!started) {
              started = true;
              _ssidScanning = true;
              _ssidOptions = [];
              _scanAndPopulateSsids(ctx, setLocal: setLocal);
            }

            return AlertDialog(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Wi-Fi Networks', textAlign: TextAlign.center),
                  SizedBox(height: 30),
                  Text(
                    "Please select a WiFI network to use below. If your network SSID is hidden,\n"
                        "please select the Hidden SSID option to manually input your SSID.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              titleTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 50,
              ),
              titlePadding: const EdgeInsets.fromLTRB(100, 50, 100, 40),
              contentPadding: const EdgeInsets.fromLTRB(100, 0, 100, 50),

              // Give dialog content explicit bounds
              content: SizedBox(
                width: 800,
                height: 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (_ssidScanning)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 125,
                              height: 125,
                              child: CircularProgressIndicator(strokeWidth: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          // These two lines avoid intrinsic measurement paths
                          shrinkWrap: true,
                          primary: false,
                          padding: EdgeInsets.zero,
                          itemCount:
                          _ssidOptions.length + 1 /* Hidden option */,
                          separatorBuilder: (_, _) => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: DashedDivider(
                              thickness: 1.2,
                              dashWidth: 7,
                              dashGap: 5,
                              color: Color(0xFFCCCCCC),
                            ),
                          ),
                          itemBuilder: (_, i) {
                            if (i == _ssidOptions.length) {
                              return ListTile(
                                leading: Text(
                                  '$i. ',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                title: const Text(
                                  'Hidden SSID (Manual entry required)',
                                  style: TextStyle(fontSize: 22),
                                ),
                                onTap: () {
                                  setState(() {
                                    _manualSsid = true;
                                    _selectedSsid = null;
                                  });
                                  Navigator.pop(ctx);
                                },
                              );
                            }

                            final s = _ssidOptions[i];
                            return ListTile(
                              leading: Text(
                                '$i. ',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              title: Text(
                                s,
                                style: const TextStyle(fontSize: 22),
                              ),
                              trailing: (_selectedSsid == s)
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _manualSsid = false;
                                  _selectedSsid = s;
                                  ssidCtrl.text = s;
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actionsPadding: EdgeInsetsGeometry.fromLTRB(100, 25, 100, 50),
              actions: [
                Row(
                  spacing: 75,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        if (_ssidScanInFlight) return;
                        setLocal(() {
                          _ssidScanning = true;
                          _ssidOptions = [];
                        });
                        await _scanAndPopulateSsids(ctx, setLocal: setLocal);
                      },
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(60, 15, 60, 15),
                        child: Text(
                          'Rescan',
                          style: TextStyle(fontSize: 24, color: Colors.red),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(65, 15, 65, 15),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _scanAndPopulateSsids(
      BuildContext ctx, {
        void Function(void Function())? setLocal,
      }) async {
    if (_ssidScanInFlight) return;
    _ssidScanInFlight = true;

    try {
      final r = await Process.run('sudo', [
        '/opt/trac_controller_v2/trac-net-apply.sh',
        'scan',
      ]);

      // If the page got disposed while scanning, just bail.
      if (!mounted) return;

      if (r.exitCode != 0) {
        final msg =
            'Wi-Fi scan failed (exit ${r.exitCode}). stderr: ${(r.stderr ?? '').toString().trim()}';
        // ignore: avoid_print
        print('[SETTINGS] $msg');

        // Update the dialog state only
        if (setLocal != null) {
          setLocal(() {
            _ssidScanning = false;
            _ssidOptions = [];
          });
        }

        // Also show a toast/snackbar on the page (non-blocking)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
        );
        return;
      }

      final out = (r.stdout as String).trim();
      final lines = out.isEmpty ? <String>[] : out.split('\n');

      final ssids = <String>{};
      for (final l in lines) {
        final p = l.split(':'); // idx:SSID:RSSI:SEC
        if (p.length > 1) {
          final s = p[1].trim();
          if (s.isNotEmpty) ssids.add(s);
        }
      }

      // Ensure the saved/current SSID is present even if scan didn't see it
      final saved = _selectedSsid ?? ssidCtrl.text.trim();
      if (saved.isNotEmpty) ssids.add(saved);

      final list = ssids.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      // IMPORTANT: Update ONLY the dialog (local) state here.
      if (setLocal != null) {
        setLocal(() {
          _ssidOptions = list;
          _ssidScanning = false;
        });
      }
    } finally {
      _ssidScanInFlight = false;
    }
  }

  // ---------- Apply buttons ----------
  Future<void> _applyWifi() async {
    final chosenSsid = _manualSsid
        ? ssidCtrl.text.trim()
        : (_selectedSsid ?? '');
    if (chosenSsid.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or enter an SSID')),
        );
      }
      return;
    }
    final hidden = (_manualSsid && Platform.isLinux) ? 'true' : 'false';

    await Process.run('sudo', [
      '/opt/trac_controller_v2/trac-net-apply.sh',
      'wifi',
      chosenSsid,
      wifiPsk.text,
      hidden,
    ]);

    if (ipModeWifi == 'dhcp') {
      await Process.run('sudo', [
        '/opt/trac_controller_v2/trac-net-apply.sh',
        'wifi-ipv4',
        'dhcp',
      ]);
    } else {
      await Process.run('sudo', [
        '/opt/trac_controller_v2/trac-net-apply.sh',
        'wifi-ipv4',
        'static',
        wifiAddr.text,
        wifiGw.text,
        wifiDns.text,
      ]);
    }

    // Persist via SettingsStore only (single source of truth)
    _current = _current.copyWith(
      wifiMode: ipModeWifi,
      wifiSsid: chosenSsid,
      wifiPsk: wifiPsk.text,
      wifiAddr: wifiAddr.text,
      wifiGw: wifiGw.text,
      wifiDns: wifiDns.text,
    );
    await SettingsStore.save(_current);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WiFi Settings Saved', style: TextStyle(fontSize: 18)),
        ),
      );
    }
  }

  Future<void> _applyEth() async {
    if (ipModeEth == 'dhcp') {
      await Process.run('sudo', [
        '/opt/trac_controller_v2/trac-net-apply.sh',
        'eth-ipv4',
        'dhcp',
      ]);
    } else {
      await Process.run('sudo', [
        '/opt/trac_controller_v2/trac-net-apply.sh',
        'eth-ipv4',
        'static',
        ethAddr.text,
        ethGw.text,
        ethDns.text,
      ]);
    }

    _current = _current.copyWith(
      ethMode: ipModeEth,
      ethAddr: ethAddr.text,
      ethGw: ethGw.text,
      ethDns: ethDns.text,
    );
    await SettingsStore.save(_current);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ethernet Settings Saved',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }
  }

  Future<void> _saveMqtt() async {
    _current = _current.copyWith(
      mqttHost: host.text.trim(),
      mqttPort: int.tryParse(port.text.trim()) ?? 1883,
      mqttUser: user.text.trim(),
      mqttPass: pass.text,
    );
    await SettingsStore.save(_current);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MQTT Settings Saved', style: TextStyle(fontSize: 18)),
        ),
      );
    }
  }

  Future<void> _saveAdmin() async {
    _current = _current.copyWith(pin: pin.text, pinMustChange: false);
    await SettingsStore.save(_current);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Admin Settings Saved.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ssidDisplay = _manualSsid
        ? '(Hidden: manual entry)'
        : (_selectedSsid?.isNotEmpty == true
        ? _selectedSsid!
        : _current.wifiSsid);

    var conditionalFields = [
      const Text(
        'WiFi Settings',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 40),
      ),
      const SizedBox(height: 15),
      GestureDetector(
        onTap: _openSsidPicker,
        child: AbsorbPointer(
          child: TextField(
            controller: TextEditingController(text: ssidDisplay),
            style: TextStyle(fontSize: 22),
            decoration: const InputDecoration(
              labelStyle: TextStyle(fontSize: 24),
              labelText: 'SSID',
              suffixIcon: Icon(Icons.wifi_find),
            ),
            readOnly: true,
          ),
        ),
      ),
      if (_manualSsid) ...[
        const SizedBox(height: 15),
        TextField(
          controller: ssidCtrl,
          style: TextStyle(fontSize: 22),
          decoration: const InputDecoration(
            labelStyle: TextStyle(fontSize: 24),
            labelText: 'SSID (hidden/manual)',
          ),
        ),
      ],
      const SizedBox(height: 15),
      TextField(
        controller: wifiPsk,
        style: TextStyle(fontSize: 22),
        decoration: InputDecoration(
          labelText: 'Password',
          labelStyle: TextStyle(fontSize: 24),
          suffixIcon: IconButton(
            icon: Icon(
              _wifiPassObscured ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () =>
                setState(() => _wifiPassObscured = !_wifiPassObscured),
          ),
        ),
        obscureText: _wifiPassObscured,
      ),
      const SizedBox(height: 50),
      Row(
        spacing: 15,
        children: [
          const Text('IP Mode:', style: TextStyle(fontSize: 24)),
          DropdownButton<String>(
            value: ipModeWifi,
            items: const [
              DropdownMenuItem(
                value: 'dhcp',
                child: Text('DHCP', style: TextStyle(fontSize: 24)),
              ),
              DropdownMenuItem(
                value: 'static',
                child: Text('Static', style: TextStyle(fontSize: 24)),
              ),
            ],
            onChanged: (v) => setState(() => ipModeWifi = v ?? 'dhcp'),
          ),
        ],
      ),
      const SizedBox(height: 15),
      Row(
        spacing: 15,
        children: [
          if (ipModeWifi == 'static') ...[
            Expanded(
              child: TextField(
                controller: wifiAddr,
                style: TextStyle(fontSize: 22),
                decoration: const InputDecoration(
                  labelText: 'Address (CIDR)',
                  labelStyle: TextStyle(fontSize: 24),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: wifiGw,
                style: TextStyle(fontSize: 22),
                decoration: const InputDecoration(
                  labelText: 'Gateway',
                  labelStyle: TextStyle(fontSize: 24),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: wifiDns,
                style: TextStyle(fontSize: 22),
                decoration: const InputDecoration(
                  labelText: 'DNS (comma-sep)',
                  labelStyle: TextStyle(fontSize: 24),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 75),
      ElevatedButton(
        onPressed: _applyWifi,
        child: Padding(
          padding: EdgeInsetsGeometry.fromLTRB(0, 15, 0, 15),
          child: const Text(
            'Apply Wi-Fi Settings',
            style: TextStyle(fontSize: 28, color: Colors.red),
          ),
        ),
      ),
      const Divider(height: 200, thickness: 3),

      const Text(
        'Ethernet Settings',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 40),
      ),
      const SizedBox(height: 15),
      Row(
        spacing: 15,
        children: [
          const Text('IP Mode:', style: TextStyle(fontSize: 24)),
          DropdownButton<String>(
            value: ipModeEth,
            items: const [
              DropdownMenuItem(
                value: 'dhcp',
                child: Text('DHCP', style: TextStyle(fontSize: 24)),
              ),
              DropdownMenuItem(
                value: 'static',
                child: Text('Static', style: TextStyle(fontSize: 24)),
              ),
            ],
            onChanged: (v) => setState(() => ipModeEth = v ?? 'dhcp'),
          ),
        ],
      ),
      const SizedBox(height: 15),
      Row(
        spacing: 15,
        children: [
          if (ipModeEth == 'static') ...[
            Expanded(
              child: TextField(
                controller: ethAddr,
                style: TextStyle(fontSize: 22),
                decoration: const InputDecoration(
                  labelText: 'Address (CIDR)',
                  labelStyle: TextStyle(fontSize: 24),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: ethGw,
                style: TextStyle(fontSize: 22),
                decoration: const InputDecoration(
                  labelText: 'Gateway',
                  labelStyle: TextStyle(fontSize: 24),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: ethDns,
                style: TextStyle(fontSize: 22),
                decoration: const InputDecoration(
                  labelText: 'DNS',
                  labelStyle: TextStyle(fontSize: 24),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 75),
      ElevatedButton(
        onPressed: _applyEth,
        child: Padding(
          padding: EdgeInsetsGeometry.fromLTRB(0, 15, 0, 15),
          child: const Text(
            'Apply Ethernet Settings',
            style: TextStyle(fontSize: 28, color: Colors.red),
          ),
        ),
      ),
      const Divider(height: 200, thickness: 3),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Panel Settings',
          style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
        ),
        toolbarHeight: 100,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(100, 50, 100, 75),
        children: [
          if (Platform.isLinux) ...conditionalFields,

          const Text(
            'MQTT Server Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 40),
          ),
          const SizedBox(height: 15),
          Row(
            spacing: 15,
            children: [
              SizedBox(
                width: 500,
                child: TextField(
                  controller: host,
                  style: TextStyle(fontSize: 22),
                  decoration: const InputDecoration(
                    labelText: 'Server Address',
                    labelStyle: TextStyle(fontSize: 24),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: port,
                  style: TextStyle(fontSize: 22),
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    labelStyle: TextStyle(fontSize: 24),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            spacing: 10,
            children: [
              SizedBox(
                width: 500,
                child: TextField(
                  controller: user,
                  style: TextStyle(fontSize: 22),
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(fontSize: 24),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: pass,
                  style: TextStyle(fontSize: 22),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(fontSize: 24),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _mqttPassObscured
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                            () => _mqttPassObscured = !_mqttPassObscured,
                      ),
                    ),
                  ),
                  obscureText: _mqttPassObscured,
                ),
              ),
            ],
          ),
          const SizedBox(height: 75),
          ElevatedButton(
            onPressed: _saveMqtt,
            child: Padding(
              padding: EdgeInsetsGeometry.fromLTRB(0, 15, 0, 15),
              child: const Text(
                'Apply MQTT Settings',
                style: TextStyle(fontSize: 28, color: Colors.red),
              ),
            ),
          ),
          const Divider(height: 200, thickness: 3),

          const Text(
            'Admin Access Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 40),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: pin,
            style: TextStyle(fontSize: 22),
            decoration: InputDecoration(
              labelText: 'Settings PIN',
              labelStyle: TextStyle(fontSize: 24),
              suffixIcon: IconButton(
                icon: Icon(
                  _adminPinObscured ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _adminPinObscured = !_adminPinObscured),
              ),
            ),
            obscureText: _adminPinObscured,
          ),
          const SizedBox(height: 75),
          ElevatedButton(
            onPressed: _saveAdmin,
            child: Padding(
              padding: EdgeInsetsGeometry.fromLTRB(0, 15, 0, 15),
              child: const Text(
                'Apply Admin Settings',
                style: TextStyle(fontSize: 28, color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}