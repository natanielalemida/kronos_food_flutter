import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kronos Food',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Consts.primaryColor),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
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
