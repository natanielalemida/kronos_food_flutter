import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Reads only this application's credential from the current Windows user.
class IfoodCredentialStore {
  static String targetName(String clientId) => 'KronosFood/iFood/$clientId';

  static String? readClientSecret(String clientId) {
    if (!Platform.isWindows || clientId.trim().isEmpty) return null;

    final target = targetName(clientId).toNativeUtf16();
    final result = calloc<Pointer<CREDENTIAL>>();
    try {
      if (CredRead(target, CRED_TYPE_GENERIC, 0, result) == 0) {
        final error = GetLastError();
        if (error == ERROR_NOT_FOUND) return null;
        throw StateError('Não foi possível ler a credencial iFood no Windows. '
            'Código: $error.');
      }

      final credential = result.value.ref;
      final size = credential.CredentialBlobSize;
      if (credential.UserName == nullptr ||
          credential.UserName.toDartString() != clientId ||
          credential.CredentialBlob == nullptr ||
          size == 0 ||
          size.isOdd) {
        throw StateError('A credencial iFood salva no Windows é inválida.');
      }
      return credential.CredentialBlob.cast<Utf16>()
          .toDartString(length: size ~/ 2);
    } finally {
      if (result.value != nullptr) {
        final credential = result.value.ref;
        if (credential.CredentialBlob != nullptr) {
          credential.CredentialBlob.asTypedList(credential.CredentialBlobSize)
              .fillRange(0, credential.CredentialBlobSize, 0);
        }
        CredFree(result.value);
      }
      calloc.free(result);
      calloc.free(target);
    }
  }
}
