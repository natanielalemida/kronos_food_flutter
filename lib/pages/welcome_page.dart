import 'package:flutter/material.dart';
import 'package:kronos_food/controllers/auth_controller.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late AuthController authController;

  @override
  void initState() {
    super.initState();
    authController = AuthController();
    authController.addListener(() => setState(() {}));
    authController.init(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SizedBox(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: Builder(builder: (context) {
        if (authController.isAuthenticating.value) {
          return const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Aguarde, buscando credenciais...")
            ],
          );
        } else if (authController.haveError.value) {
          return Center(
            child: Text(authController.errorMsg.value),
          );
        } else if (authController.isAuthenticated.value) {
          return const Center(
            child: Text("Bem vindo!"),
          );
        } else {
          return const Center(
            child: Text("Bem vindo!"),
          );
        }
      }),
    ));
  }
}
