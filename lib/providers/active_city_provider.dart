import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/models/city.dart';

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
