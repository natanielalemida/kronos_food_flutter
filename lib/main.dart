import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kronos_food/pages/pedidos_page.dart';
import 'package:window_manager/window_manager.dart';
import 'package:win_toast/win_toast.dart';

import 'package:kronos_food/consts.dart';
import 'package:kronos_food/pages/login_page.dart';

/// Chave global para acessar o Navigator de qualquer lugar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void setupWinToastCallback() {
  WinToast.instance().setActivatedCallback((ActivatedEvent event) async {
    debugPrint('✅ Notificação ativada: ${event.argument}');

    final args = Uri.splitQueryString(event.argument);
    final orderId = args['conversationId'];

    final isMinimized = await windowManager.isMinimized();
    if (isMinimized) {
      await windowManager.restore();
    }

    await windowManager.setSkipTaskbar(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
    await Future.delayed(const Duration(milliseconds: 100));
    await windowManager.focus();
    await Future.delayed(const Duration(milliseconds: 100));
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);

    // if (orderId == null) {
    //   debugPrint('⚠️ ID do pedido não encontrado.');
    //   return;
    // }

    // navigatorKey.currentState?.pushReplacement(
    //   MaterialPageRoute(
    //     builder: (_) => PedidosPage(orderIdSelected: orderId),
    //   ),
    // );
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  // Inicializa o WinToast
  await WinToast.instance().initialize(
    aumId: 'com.kronos.kronosfood',
    displayName: 'Kronos Food',
    iconPath: r'C:\Users\NATANAEL\Downloads\app_icon.ico',
    clsid: '{7F52F9F4-1234-4A1E-A6C0-ABCDEF987654}',
  );

  setupWinToastCallback();

  await windowManager.ensureInitialized();
  WindowOptions options = const WindowOptions(
    size: Size(1980, 1080),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // <- importante!
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
