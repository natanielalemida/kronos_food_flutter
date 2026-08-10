import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kronos_food/utils/app_logger.dart';

class AppNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logNavigation('PUSH', route, previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logNavigation('POP', route, previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _logNavigation('REPLACE', newRoute, oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logNavigation('REMOVE', route, previousRoute);
    super.didRemove(route, previousRoute);
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    _logNavigation('GESTURE_START', route, previousRoute);
    super.didStartUserGesture(route, previousRoute);
  }

  @override
  void didStopUserGesture() {
    unawaited(
      AppLogger.status(
        'Gesto de navegação finalizado.',
        category: 'NAVIGATION',
        status: 'GESTURE_STOP',
      ),
    );
    super.didStopUserGesture();
  }

  void _logNavigation(
    String action,
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {
    unawaited(
      AppLogger.status(
        'Navegação do aplicativo alterada.',
        category: 'NAVIGATION',
        status: action,
        data: {
          'route': _routeData(route),
          'previousRoute': _routeData(previousRoute),
        },
      ),
    );
  }

  Map<String, dynamic>? _routeData(Route<dynamic>? route) {
    if (route == null) return null;
    return {
      'name': route.settings.name,
      'type': route.runtimeType.toString(),
      'argumentsType': route.settings.arguments?.runtimeType.toString(),
      'isCurrent': route.isCurrent,
      'isActive': route.isActive,
    };
  }
}
