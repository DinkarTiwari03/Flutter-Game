import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/providers/repository_providers.dart';

/// The city currently being played, or `null` on the menu screens.
class ActiveCityNotifier extends Notifier<City?> {
  @override
  City? build() => null;

  void open(City city) => state = city;

  void close() => state = null;
}

final activeCityProvider = NotifierProvider<ActiveCityNotifier, City?>(
  ActiveCityNotifier.new,
);

/// List of all saved cities, ordered by updated_at descending.
final savedCitiesProvider = FutureProvider<List<City>>((ref) async {
  return ref.watch(cityRepositoryProvider).listCities();
});

/// The most recently played/updated city, or null if no cities exist.
final latestCityProvider = FutureProvider<City?>((ref) async {
  return ref.watch(cityServiceProvider).latestCity();
});
