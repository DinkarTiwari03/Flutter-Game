import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/models/city_demographics.dart';
import 'package:city_builder_2040/models/city_event.dart';
import 'package:city_builder_2040/models/simulation_clock.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';

/// In-game simulation clock state (Day, Hour, Minute, TickCount, DayPhase).
class SimulationClockNotifier extends Notifier<SimulationClock> {
  @override
  SimulationClock build() {
    ref.watch(activeCityProvider);
    return SimulationClock.initial();
  }

  void update(SimulationClock clock) => state = clock;

  void reset() => state = SimulationClock.initial();
}

final simulationClockProvider =
    NotifierProvider<SimulationClockNotifier, SimulationClock>(
      SimulationClockNotifier.new,
    );

/// City demographics and labor statistics state.
class CityDemographicsNotifier extends Notifier<CityDemographics> {
  @override
  CityDemographics build() {
    ref.watch(activeCityProvider);
    return const CityDemographics();
  }

  void update(CityDemographics demographics) => state = demographics;

  void reset() => state = const CityDemographics();
}

final cityDemographicsProvider =
    NotifierProvider<CityDemographicsNotifier, CityDemographics>(
      CityDemographicsNotifier.new,
    );

/// Active civic events currently exerting modifiers on the city.
class ActiveCityEventsNotifier extends Notifier<List<CityEvent>> {
  @override
  List<CityEvent> build() {
    ref.watch(activeCityProvider);
    return const [];
  }

  void update(List<CityEvent> events) => state = events;

  void add(CityEvent event) => state = [...state, event];

  void remove(String eventId) =>
      state = state.where((e) => e.id != eventId).toList();

  void clear() => state = const [];
}

final activeCityEventsProvider =
    NotifierProvider<ActiveCityEventsNotifier, List<CityEvent>>(
      ActiveCityEventsNotifier.new,
    );

/// The most recently triggered civic event, surfaced for UI banners/notifications.
class LastTriggeredEventNotifier extends Notifier<CityEvent?> {
  @override
  CityEvent? build() => null;

  void trigger(CityEvent event) => state = event;

  void dismiss() => state = null;
}

final lastTriggeredEventProvider =
    NotifierProvider<LastTriggeredEventNotifier, CityEvent?>(
      LastTriggeredEventNotifier.new,
    );
