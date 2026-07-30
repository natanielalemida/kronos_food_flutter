import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/pages/login_page.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  await windowManager.ensureInitialized();
  await _initializeIfoodWidgetWebViewEnvironment();
  const options = WindowOptions(
    size: Size(1980, 1080),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setMinimizable(true);
    await windowManager.setMaximizable(true);
    await windowManager.setClosable(true);
    await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

Future<void> _initializeIfoodWidgetWebViewEnvironment() async {
  if (!Platform.isWindows) return;

  final appData = Platform.environment['APPDATA'];
  final userDataDir = Directory(
    appData == null || appData.isEmpty
        ? '${Directory.current.path}\\Kronos Food\\ifood_widget_webview'
        : '$appData\\Kronos Food\\ifood_widget_webview',
  );

  try {
    if (!userDataDir.existsSync()) {
      userDataDir.createSync(recursive: true);
    }
    await WebviewController.initializeEnvironment(
      userDataPath: userDataDir.path,
    );
  } catch (_) {
    // The app can run without the widget; the chat panel will show details.
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Kronos Food',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Consts.primaryColor),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Consts.primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      home: const LoginPage(),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
