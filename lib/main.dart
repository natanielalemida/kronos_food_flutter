import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/pages/login_page.dart';
import 'package:kronos_food/utils/app_logger.dart';
import 'package:kronos_food/utils/app_navigator_observer.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// Mantém o listener vivo durante toda a execução do aplicativo.
// ignore: unused_element
AppLifecycleListener? _appLifecycleListener;

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppLogger.initialize();
      _configureGlobalErrorLogging();
      _configureLifecycleLogging();

      HttpOverrides.global = MyHttpOverrides();
      await AppLogger.status(
        'Override HTTP configurado.',
        category: 'APP',
        status: 'HTTP_OVERRIDE_READY',
      );

      await windowManager.ensureInitialized();
      await AppLogger.status(
        'Gerenciador de janelas inicializado.',
        category: 'APP',
        status: 'WINDOW_MANAGER_READY',
      );

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
        await AppLogger.status(
          'Janela principal exibida.',
          category: 'APP',
          status: 'WINDOW_VISIBLE',
        );
      });

      await AppLogger.status(
        'Flutter iniciando a interface.',
        category: 'APP',
        status: 'RUN_APP',
      );
      runApp(const MyApp());
    },
    (error, stackTrace) {
      unawaited(
        AppLogger.fatal(
          'Erro não tratado capturado pela zona principal.',
          status: 'UNCAUGHT_ZONE_ERROR',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        parent.print(zone, line);
        unawaited(AppLogger.console(line));
      },
    ),
  );
}

void _configureGlobalErrorLogging() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      AppLogger.fatal(
        'Erro não tratado pelo framework Flutter.',
        status: 'FLUTTER_ERROR',
        error: details.exception,
        stackTrace: details.stack,
        data: {
          'library': details.library,
          'context': details.context?.toDescription(),
        },
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      AppLogger.fatal(
        'Erro assíncrono não tratado pela plataforma.',
        status: 'PLATFORM_ERROR',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    return true;
  };
}

void _configureLifecycleLogging() {
  _appLifecycleListener = AppLifecycleListener(
    onResume: () => _logLifecycle('RESUMED'),
    onInactive: () => _logLifecycle('INACTIVE'),
    onHide: () => _logLifecycle('HIDDEN'),
    onShow: () => _logLifecycle('SHOWN'),
    onPause: () => _logLifecycle('PAUSED'),
    onRestart: () => _logLifecycle('RESTARTED'),
    onDetach: () {
      _logLifecycle('DETACHED');
      unawaited(AppLogger.flush());
    },
  );
}

void _logLifecycle(String lifecycleStatus) {
  unawaited(
    AppLogger.status(
      'Estado do aplicativo alterado.',
      category: 'LIFECYCLE',
      status: lifecycleStatus,
    ),
  );
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
    await AppLogger.status(
      'Ambiente WebView do widget iFood inicializado.',
      category: 'IFOOD_WIDGET',
      status: 'WEBVIEW_READY',
      data: {'userDataPath': userDataDir.path},
    );
  } catch (error, stackTrace) {
    await AppLogger.warning(
      'Não foi possível inicializar o ambiente WebView do widget iFood.',
      category: 'IFOOD_WIDGET',
      status: 'WEBVIEW_UNAVAILABLE',
      error: error,
      stackTrace: stackTrace,
      data: {'userDataPath': userDataDir.path},
    );
    // The app can run without the widget; the chat panel will show details.
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final AppNavigatorObserver _navigatorObserver = AppNavigatorObserver();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [_navigatorObserver],
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
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        unawaited(
          AppLogger.warning(
            'Certificado TLS inválido foi aceito pelo override do aplicativo.',
            category: 'HTTP',
            status: 'INVALID_CERTIFICATE_ACCEPTED',
            data: {
              'host': host,
              'port': port,
              'subject': cert.subject,
              'issuer': cert.issuer,
              'startValidity': cert.startValidity.toIso8601String(),
              'endValidity': cert.endValidity.toIso8601String(),
            },
          ),
        );
        return true;
      };
  }
}
