import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/app.dart';
import 'package:city_builder_2040/core/utils/error_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorHandler.init();
  runApp(const ProviderScope(child: CityBuilderApp()));
}
