import 'dart:convert';
import 'dart:io';

class AppLogger {
  static Future<String> get logPath async => (await _logFile()).path;

  static Future<void> error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) async {
    try {
      final file = await _logFile();
      final buffer = StringBuffer()
        ..writeln('[${DateTime.now().toIso8601String()}] $message');

      if (data != null && data.isNotEmpty) {
        buffer.writeln(_sanitize(jsonEncode(data)));
      }

      if (error != null) {
        buffer.writeln(_sanitize(error.toString()));
      }

      if (stackTrace != null) {
        buffer.writeln(_sanitize(stackTrace.toString()));
      }

      buffer.writeln();
      await file.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  static Future<File> _logFile() async {
    final localAppData =
        Platform.environment['LOCALAPPDATA'] ?? Directory.current.path;
    final dir = Directory('$localAppData\\Kronos Food\\logs');
    await dir.create(recursive: true);
    return File('${dir.path}\\kronos_food_errors.txt');
  }

  static String _sanitize(String value) {
    return value
        .replaceAll(RegExp(r'("senha"\s*:\s*")[^"]+(")', caseSensitive: false),
            r'$1***$2')
        .replaceAll(
          RegExp(r'("clientSecret"\s*:\s*")[^"]+(")', caseSensitive: false),
          r'$1***$2',
        )
        .replaceAll(
          RegExp(r'("accessToken"\s*:\s*")[^"]+(")', caseSensitive: false),
          r'$1***$2',
        )
        .replaceAll(
          RegExp(r'("refreshToken"\s*:\s*")[^"]+(")', caseSensitive: false),
          r'$1***$2',
        );
  }
}
