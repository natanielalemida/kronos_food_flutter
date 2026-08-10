import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;

enum AppLogLevel { trace, debug, info, status, warning, error, fatal }

class AppLogger {
  static const int _maximumTextLength = 65536;
  static const String _redacted = '***MASCARADO***';
  static final String _sessionId =
      '${DateTime.now().microsecondsSinceEpoch}-$pid';

  static File? _file;
  static Future<void> _writeQueue = Future<void>.value();
  static bool _initialized = false;

  static Future<String> get logPath async => (await _logFile()).path;

  static Future<String> get logDirectoryPath async =>
      (await _logFile()).parent.path;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    var version = 'desconhecida';
    var build = 'desconhecido';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      version = packageInfo.version;
      build = packageInfo.buildNumber;
    } catch (_) {
      // O logger precisa continuar funcional mesmo sem metadados do pacote.
    }

    await info(
      'Nova sessão do aplicativo iniciada.',
      category: 'APP',
      status: 'SESSION_START',
      data: {
        'sessionId': _sessionId,
        'version': version,
        'build': build,
        'pid': pid,
        'operatingSystem': Platform.operatingSystem,
        'operatingSystemVersion': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
        'numberOfProcessors': Platform.numberOfProcessors,
        'executable': Platform.resolvedExecutable,
        'workingDirectory': Directory.current.path,
        'logFile': await logPath,
      },
    );
  }

  static Dio createDio({required String source, BaseOptions? options}) {
    return attachDio(Dio(options), source: source);
  }

  static Dio attachDio(Dio dio, {required String source}) {
    final alreadyAttached = dio.interceptors.any(
      (interceptor) => interceptor is _AppLoggerDioInterceptor,
    );
    if (!alreadyAttached) {
      dio.interceptors.add(_AppLoggerDioInterceptor(source));
    }
    return dio;
  }

  static Future<void> trace(
    String message, {
    String category = 'GENERAL',
    String? status,
    Map<String, dynamic>? data,
  }) {
    return log(
      AppLogLevel.trace,
      message,
      category: category,
      status: status,
      data: data,
    );
  }

  static Future<void> debug(
    String message, {
    String category = 'GENERAL',
    String? status,
    Map<String, dynamic>? data,
  }) {
    return log(
      AppLogLevel.debug,
      message,
      category: category,
      status: status,
      data: data,
    );
  }

  static Future<void> info(
    String message, {
    String category = 'GENERAL',
    String? status,
    Map<String, dynamic>? data,
  }) {
    return log(
      AppLogLevel.info,
      message,
      category: category,
      status: status,
      data: data,
    );
  }

  static Future<void> status(
    String message, {
    String category = 'GENERAL',
    String? status,
    Map<String, dynamic>? data,
  }) {
    return log(
      AppLogLevel.status,
      message,
      category: category,
      status: status,
      data: data,
    );
  }

  static Future<void> warning(
    String message, {
    String category = 'GENERAL',
    String? status,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return log(
      AppLogLevel.warning,
      message,
      category: category,
      status: status,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Future<void> error(
    String message, {
    String category = 'GENERAL',
    String? status,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    return log(
      AppLogLevel.error,
      message,
      category: category,
      status: status,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Future<void> fatal(
    String message, {
    String category = 'APP',
    String? status,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    return log(
      AppLogLevel.fatal,
      message,
      category: category,
      status: status,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Future<void> console(String message) {
    return debug(message, category: 'CONSOLE', status: 'OUTPUT');
  }

  static Future<void> log(
    AppLogLevel level,
    String message, {
    String category = 'GENERAL',
    String? status,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final levelName = level.name.toUpperCase();
    final safeCategory = _sanitizeText(category);
    final safeStatus = status == null ? null : _sanitizeText(status);
    final header = StringBuffer()
      ..write('[$timestamp]')
      ..write(' [SESSION=$_sessionId]')
      ..write(' [$levelName]')
      ..write(' [$safeCategory]');
    if (safeStatus != null && safeStatus.isNotEmpty) {
      header.write(' [STATUS=$safeStatus]');
    }
    header.writeln(' ${_sanitizeText(message)}');

    if (data != null && data.isNotEmpty) {
      header.writeln('DATA ${_encode(_sanitizeValue(data))}');
    }
    if (error != null) {
      header.writeln('ERROR ${_sanitizeText(error.toString())}');
    }
    if (stackTrace != null) {
      header.writeln('STACK ${_sanitizeText(stackTrace.toString())}');
    }
    header.writeln('---');

    return _append(header.toString());
  }

  static Future<void> flush() => _writeQueue;

  @visibleForTesting
  static dynamic sanitizeForTesting(dynamic value) => _sanitizeValue(value);

  static Future<void> _append(String contents) {
    final operation = _writeQueue.then((_) async {
      try {
        final file = await _logFile();
        await file.writeAsString(contents, mode: FileMode.append, flush: true);
      } catch (_) {
        // Falhas do logger nunca podem derrubar a aplicação.
      }
    });
    _writeQueue = operation;
    return operation;
  }

  static Future<File> _logFile() async {
    if (_file != null) return _file!;

    final localAppData =
        Platform.environment['LOCALAPPDATA'] ?? Directory.current.path;
    final directory = Directory(path.join(localAppData, 'Kronos Food', 'logs'));
    await directory.create(recursive: true);
    _file = File(path.join(directory.path, 'kronos_food_diagnostics.txt'));
    return _file!;
  }

  static dynamic _sanitizeValue(dynamic value, {String? key}) {
    if (key != null && _isSensitiveKey(key)) return _redacted;
    if (value == null || value is num || value is bool) return value;

    if (value is String) return _sanitizeText(value);
    if (value is DateTime) return value.toIso8601String();
    if (value is Duration) return value.toString();
    if (value is Uri) return _sanitizeText(value.toString());

    if (value is FormData) {
      return {
        'fields': {
          for (final field in value.fields)
            field.key: _sanitizeValue(field.value, key: field.key),
        },
        'files': [
          for (final file in value.files)
            {
              'field': file.key,
              'filename': file.value.filename,
              'length': file.value.length,
              'contentType': file.value.contentType?.toString(),
            },
        ],
      };
    }

    if (value is Map) {
      return value.map<String, dynamic>((dynamic mapKey, dynamic mapValue) {
        final stringKey = mapKey.toString();
        return MapEntry(stringKey, _sanitizeValue(mapValue, key: stringKey));
      });
    }

    if (value is List) {
      if (value.length > 128 && value.every((item) => item is int)) {
        return '[CONTEÚDO BINÁRIO OMITIDO: ${value.length} bytes]';
      }
      return value.map(_sanitizeValue).toList();
    }

    if (value is Iterable) {
      return value.map(_sanitizeValue).toList();
    }

    return _sanitizeText(value.toString());
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized.contains('senha') ||
        normalized.contains('password') ||
        normalized.contains('passwd') ||
        normalized.contains('secret') ||
        normalized.contains('token') ||
        normalized.contains('authorization') ||
        normalized.contains('cookie') ||
        normalized.contains('apikey') ||
        normalized.contains('codeverifier');
  }

  static String _sanitizeText(String value) {
    var sanitized = value.replaceAllMapped(
      RegExp(
        r'''(["']?authorization["']?\s*[:=]\s*["']?)(?:bearer|basic)\s+([^\s,"'}&]+)''',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}$_redacted',
    );
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(bearer\s+)[a-z0-9._~+\-/]+=*', caseSensitive: false),
      (match) => '${match.group(1)}$_redacted',
    );
    sanitized = sanitized.replaceAllMapped(
      RegExp(
        r'''(["']?(?:senha|password|passwd|client[_-]?secret|access[_-]?token|refresh[_-]?token|authorization|cookie|set-cookie|api[_-]?key|code[_-]?verifier)["']?\s*[:=]\s*["']?)([^\s,"'}&]+)''',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}$_redacted',
    );

    if (sanitized.length > _maximumTextLength) {
      final omitted = sanitized.length - _maximumTextLength;
      sanitized = '${sanitized.substring(0, _maximumTextLength)}'
          '\n[CONTEÚDO TRUNCADO: $omitted caracteres omitidos]';
    }
    return sanitized;
  }

  static String _encode(dynamic value) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return _sanitizeText(value.toString());
    }
  }
}

class _AppLoggerDioInterceptor extends Interceptor {
  _AppLoggerDioInterceptor(this.source);

  static const String _startedAtKey = '__app_logger_started_at';
  static const String _requestIdKey = '__app_logger_request_id';
  static int _nextRequestId = 0;

  final String source;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId =
        '${DateTime.now().microsecondsSinceEpoch}-${_nextRequestId++}';
    options.extra[_startedAtKey] = DateTime.now().microsecondsSinceEpoch;
    options.extra[_requestIdKey] = requestId;

    unawaited(
      AppLogger.info(
        'Requisição HTTP iniciada.',
        category: 'HTTP',
        status: 'REQUEST',
        data: _requestData(options, requestId),
      ),
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final options = response.requestOptions;
    final requestId = options.extra[_requestIdKey]?.toString() ?? 'unknown';
    final statusCode = response.statusCode;
    final data = _requestData(options, requestId)
      ..addAll({
        'statusCode': statusCode,
        'statusMessage': response.statusMessage,
        'elapsedMilliseconds': _elapsedMilliseconds(options),
        'responseHeaders': response.headers.map,
        'responseBody': response.data,
      });

    final log = statusCode != null && statusCode >= 400
        ? AppLogger.warning(
            'Resposta HTTP recebida com falha.',
            category: 'HTTP',
            status: 'RESPONSE_$statusCode',
            data: data,
          )
        : AppLogger.info(
            'Resposta HTTP recebida.',
            category: 'HTTP',
            status: 'RESPONSE_${statusCode ?? 'UNKNOWN'}',
            data: data,
          );
    unawaited(log);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final requestId = options.extra[_requestIdKey]?.toString() ?? 'unknown';
    unawaited(
      AppLogger.error(
        'Requisição HTTP falhou.',
        category: 'HTTP',
        status: 'ERROR_${err.response?.statusCode ?? err.type.name}',
        error: err,
        stackTrace: err.stackTrace,
        data: _requestData(options, requestId)
          ..addAll({
            'dioExceptionType': err.type.name,
            'statusCode': err.response?.statusCode,
            'statusMessage': err.response?.statusMessage,
            'elapsedMilliseconds': _elapsedMilliseconds(options),
            'responseHeaders': err.response?.headers.map,
            'responseBody': err.response?.data,
          }),
      ),
    );
    handler.next(err);
  }

  Map<String, dynamic> _requestData(RequestOptions options, String requestId) {
    return {
      'requestId': requestId,
      'source': source,
      'method': options.method,
      'url': options.uri.toString(),
      'headers': options.headers,
      'queryParameters': options.queryParameters,
      'requestBody': options.data,
      'contentType': options.contentType,
      'responseType': options.responseType.name,
      'followRedirects': options.followRedirects,
      'connectTimeout': options.connectTimeout?.inMilliseconds,
      'sendTimeout': options.sendTimeout?.inMilliseconds,
      'receiveTimeout': options.receiveTimeout?.inMilliseconds,
    };
  }

  int? _elapsedMilliseconds(RequestOptions options) {
    final startedAt = options.extra[_startedAtKey];
    if (startedAt is! int) return null;
    return (DateTime.now().microsecondsSinceEpoch - startedAt) ~/ 1000;
  }
}
