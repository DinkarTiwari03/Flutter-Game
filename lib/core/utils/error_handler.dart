import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:city_builder_2040/core/utils/app_exception.dart';

abstract final class ErrorHandler {
  static const _logName = 'CityBuilder2040';

  /// Installs global handlers for framework and platform errors.
  static void init() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      report(details.exception, details.stack, source: 'FlutterError');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, source: 'PlatformDispatcher');
      return true;
    };
  }

  static void report(Object error, StackTrace? stack, {String source = 'app'}) {
    developer.log(
      'Error from $source',
      name: _logName,
      error: error,
      stackTrace: stack,
    );
  }

  static String messageFor(Object error) {
    if (error is AppException) return error.message;
    return 'An unexpected error occurred. Please try again.';
  }
}
