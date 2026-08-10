import 'dart:async';
import 'dart:developer' as dart_developer;

import 'package:kronos_food/utils/app_logger.dart';

void log(
  String message, {
  DateTime? time,
  int? sequenceNumber,
  int level = 0,
  String name = '',
  Zone? zone,
  Object? error,
  StackTrace? stackTrace,
}) {
  dart_developer.log(
    message,
    time: time,
    sequenceNumber: sequenceNumber,
    level: level,
    name: name,
    zone: zone,
    error: error,
    stackTrace: stackTrace,
  );

  final category = name.trim().isEmpty ? 'DEVELOPER' : name.trim();
  final future = error != null || level >= 1000
      ? AppLogger.error(
          message,
          category: category,
          status: 'LOG_$level',
          error: error,
          stackTrace: stackTrace,
        )
      : level >= 900
          ? AppLogger.warning(
              message,
              category: category,
              status: 'LOG_$level',
              error: error,
              stackTrace: stackTrace,
            )
          : AppLogger.debug(message, category: category, status: 'LOG_$level');
  unawaited(future);
}
