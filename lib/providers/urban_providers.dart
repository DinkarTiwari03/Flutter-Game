import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/game/urban/urban_simulation_service.dart';

/// Provider exposing the centralized urban life simulation service.
final urbanSimulationProvider = Provider<UrbanSimulationService>((ref) {
  final service = UrbanSimulationService();
  ref.onDispose(service.dispose);
  return service;
});
