import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/utils/error_handler.dart';
import 'package:city_builder_2040/providers/storage_provider.dart';

/// Runs once-per-launch startup work while the splash screen is visible.
///
/// Automatic retry is disabled so a startup failure is shown immediately
/// with a manual "Try again" action instead of silently looping.
final bootstrapProvider = FutureProvider<void>((ref) async {
  try {
    await ref.read(storageServiceProvider).init();
  } catch (error, stack) {
    ErrorHandler.report(error, stack, source: 'bootstrap');
    rethrow;
  }
}, retry: (retryCount, error) => null);
