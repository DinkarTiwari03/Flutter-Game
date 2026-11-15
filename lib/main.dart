import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/app.dart';
import 'package:city_builder_2040/core/utils/error_handler.dart';
import 'package:city_builder_2040/providers/repository_providers.dart';
import 'package:city_builder_2040/repositories/local/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorHandler.init();

  // Open the SQLite database before the widget tree is built so every
  // repository provider has access to it via the ProviderScope override.
  final db = await AppDatabase.open();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const CityBuilderApp(),
    ),
  );
}
