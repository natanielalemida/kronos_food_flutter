import 'dart:io';

import 'package:kronos_food/service/ifood_credential_store.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
        'Uso: dart run tool/check_ifood_windows_credential.dart <clientId>');
    exitCode = 2;
    return;
  }
  final installed =
      IfoodCredentialStore.readClientSecret(arguments.single)?.isNotEmpty ??
          false;
  stdout.writeln(
      installed ? 'Credencial iFood disponível.' : 'Credencial iFood ausente.');
  exitCode = installed ? 0 : 1;
}
