import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/game/urban/urban_simulation_service.dart';
import 'package:city_builder_2040/models/traffic/traffic_models.dart';

/// Provider exposing the centralized urban life simulation service.
final urbanSimulationProvider = Provider<UrbanSimulationService>((ref) {
  final service = UrbanSimulationService();
  ref.onDispose(service.dispose);
  return service;
});

/// Exposes the live traffic analytics and metrics from the urban simulation.
final trafficMetricsProvider = Provider<TrafficMetrics>((ref) {
  final urban = ref.watch(urbanSimulationProvider);
  return urban.trafficMetrics;
});

/// Controls whether the visual Traffic Congestion Heatmap overlay is shown.
class TrafficHeatmapVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setVisible(bool visible) => state = visible;
}

final trafficHeatmapVisibleProvider =
    NotifierProvider<TrafficHeatmapVisibleNotifier, bool>(
  TrafficHeatmapVisibleNotifier.new,
);
