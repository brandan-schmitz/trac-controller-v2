import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'constants.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'services/settings_service.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const size = Size(1280, 720);
  WindowOptions windowOptions = const WindowOptions(
    size: size,
    minimumSize: size,
    title: "TRAC Waterpark Controller",
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  final settings = await SettingsStore.load();
  runApp(App(initial: settings));
}

class App extends StatelessWidget {
  final Settings initial;

  const App({super.key, required this.initial});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: appTitle,
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
      routes: {
        '/': (_) => HomePage(settings: initial),
        '/settings': (ctx) {
          final arg = ModalRoute.of(ctx)!.settings.arguments as Settings;
          return SettingsPage(initial: arg);
        },
      },
    );
  }
}
