import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  // MQTT / PIN
  final String mqttHost;
  final int mqttPort;
  final bool mqttSecured;
  final String mqttUser;
  final String mqttPass;
  final String pin;
  final bool pinMustChange;

  // ---- New: Network settings (persisted with the same store) ----
  // Wi-Fi
  final String wifiMode; // 'dhcp' | 'static'
  final String wifiSsid;
  final String wifiPsk;
  final String wifiAddr; // CIDR when static
  final String wifiGw;
  final String wifiDns; // comma-separated

  // Ethernet
  final String ethMode; // 'dhcp' | 'static'
  final String ethAddr; // CIDR when static
  final String ethGw;
  final String ethDns; // comma-separated

  Settings({
    // MQTT/PIN
    required this.mqttHost,
    required this.mqttPort,
    required this.mqttUser,
    required this.mqttPass,
    required this.pin,
    required this.pinMustChange,
    required this.mqttSecured,
    // Network
    required this.wifiMode,
    required this.wifiSsid,
    required this.wifiPsk,
    required this.wifiAddr,
    required this.wifiGw,
    required this.wifiDns,
    required this.ethMode,
    required this.ethAddr,
    required this.ethGw,
    required this.ethDns,
  });

  Settings copyWith({
    // MQTT/PIN
    String? mqttHost,
    int? mqttPort,
    String? mqttUser,
    String? mqttPass,
    String? pin,
    bool? pinMustChange,
    bool? mqttSecured,
    // Network
    String? wifiMode,
    String? wifiSsid,
    String? wifiPsk,
    String? wifiAddr,
    String? wifiGw,
    String? wifiDns,
    String? ethMode,
    String? ethAddr,
    String? ethGw,
    String? ethDns,
  }) {
    return Settings(
      mqttHost: mqttHost ?? this.mqttHost,
      mqttPort: mqttPort ?? this.mqttPort,
      mqttUser: mqttUser ?? this.mqttUser,
      mqttPass: mqttPass ?? this.mqttPass,
      pin: pin ?? this.pin,
      pinMustChange: pinMustChange ?? this.pinMustChange,
      mqttSecured: mqttSecured ?? this.mqttSecured,
      wifiMode: wifiMode ?? this.wifiMode,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      wifiPsk: wifiPsk ?? this.wifiPsk,
      wifiAddr: wifiAddr ?? this.wifiAddr,
      wifiGw: wifiGw ?? this.wifiGw,
      wifiDns: wifiDns ?? this.wifiDns,
      ethMode: ethMode ?? this.ethMode,
      ethAddr: ethAddr ?? this.ethAddr,
      ethGw: ethGw ?? this.ethGw,
      ethDns: ethDns ?? this.ethDns,
    );
  }
}

class SettingsStore {
  // MQTT / PIN
  static const _kHost = 'mqtt_host';
  static const _kPort = 'mqtt_port';
  static const _kUser = 'mqtt_user';
  static const _kPass = 'mqtt_pass';
  static const _kPin = 'settings_pin';
  static const _kPinMustChange = 'settings_pin_must_change';
  static const _kSecured = 'mqtt_secured';

  // Network keys
  static const _kWifiMode = 'wifi_mode'; // 'dhcp'|'static'
  static const _kWifiSsid = 'wifi_ssid';
  static const _kWifiPsk = 'wifi_psk';
  static const _kWifiAddr = 'wifi_addr';
  static const _kWifiGw = 'wifi_gw';
  static const _kWifiDns = 'wifi_dns';

  static const _kEthMode = 'eth_mode'; // 'dhcp'|'static'
  static const _kEthAddr = 'eth_addr';
  static const _kEthGw = 'eth_gw';
  static const _kEthDns = 'eth_dns';

  static Future<Settings> load() async {
    final sp = await SharedPreferences.getInstance();
    return Settings(
      // MQTT/PIN
      mqttHost: sp.getString(_kHost) ?? '127.0.0.1',
      mqttPort: sp.getInt(_kPort) ?? 1883,
      mqttUser: sp.getString(_kUser) ?? 'tracpanel',
      mqttPass: sp.getString(_kPass) ?? 'REPLACE_ME',
      pin: sp.getString(_kPin) ?? '1234',
      pinMustChange: sp.getBool(_kPinMustChange) ?? true,
      mqttSecured: sp.getBool(_kSecured) ?? false,
      // Wi-Fi defaults
      wifiMode: sp.getString(_kWifiMode) ?? 'dhcp',
      wifiSsid: sp.getString(_kWifiSsid) ?? '',
      wifiPsk: sp.getString(_kWifiPsk) ?? '',
      wifiAddr: sp.getString(_kWifiAddr) ?? '',
      wifiGw: sp.getString(_kWifiGw) ?? '',
      wifiDns: sp.getString(_kWifiDns) ?? '',
      // Ethernet defaults
      ethMode: sp.getString(_kEthMode) ?? 'dhcp',
      ethAddr: sp.getString(_kEthAddr) ?? '',
      ethGw: sp.getString(_kEthGw) ?? '',
      ethDns: sp.getString(_kEthDns) ?? '',
    );
  }

  static Future<void> save(Settings s) async {
    final sp = await SharedPreferences.getInstance();
    // MQTT/PIN
    await sp.setString(_kHost, s.mqttHost);
    await sp.setInt(_kPort, s.mqttPort);
    await sp.setString(_kUser, s.mqttUser);
    await sp.setString(_kPass, s.mqttPass);
    await sp.setString(_kPin, s.pin);
    await sp.setBool(_kPinMustChange, s.pinMustChange);
    await sp.setBool(_kSecured, s.mqttSecured);
    // Wi-Fi
    await sp.setString(_kWifiMode, s.wifiMode);
    await sp.setString(_kWifiSsid, s.wifiSsid);
    await sp.setString(_kWifiPsk, s.wifiPsk);
    await sp.setString(_kWifiAddr, s.wifiAddr);
    await sp.setString(_kWifiGw, s.wifiGw);
    await sp.setString(_kWifiDns, s.wifiDns);
    // Ethernet
    await sp.setString(_kEthMode, s.ethMode);
    await sp.setString(_kEthAddr, s.ethAddr);
    await sp.setString(_kEthGw, s.ethGw);
    await sp.setString(_kEthDns, s.ethDns);
  }

  static Future<void> setPinMustChange(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kPinMustChange, v);
  }

  static Future<void> setPin(String newPin) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kPin, newPin);
    await sp.setBool(_kPinMustChange, false);
  }
}