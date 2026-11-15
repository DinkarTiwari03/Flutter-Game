import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/models/simulation_clock.dart';

void main() {
  group('SimulationClock Model Tests', () {
    test('initial values are Day 1, 08:00, Day phase', () {
      final clock = SimulationClock.initial();
      expect(clock.day, 1);
      expect(clock.hour, 8);
      expect(clock.minute, 0);
      expect(clock.tickCount, 0);
      expect(clock.phase, DayPhase.day);
      expect(clock.formattedTime, '08:00');
      expect(clock.formattedDay, 'Day 1');
      expect(clock.formattedFull, 'Day 1 • 08:00');
    });

    test('advance increments hour and tickCount', () {
      final clock = SimulationClock.initial();
      final advanced = clock.advance(minutesAdvanced: 60);

      expect(advanced.day, 1);
      expect(advanced.hour, 9);
      expect(advanced.minute, 0);
      expect(advanced.tickCount, 1);
    });

    test('phase transitions throughout 24-hour cycle', () {
      var clock = const SimulationClock(day: 1, hour: 4, minute: 0);
      expect(clock.phase, DayPhase.night);

      clock = const SimulationClock(day: 1, hour: 6, minute: 30);
      expect(clock.phase, DayPhase.dawn);

      clock = const SimulationClock(day: 1, hour: 12, minute: 0);
      expect(clock.phase, DayPhase.day);

      clock = const SimulationClock(day: 1, hour: 19, minute: 15);
      expect(clock.phase, DayPhase.dusk);

      clock = const SimulationClock(day: 1, hour: 22, minute: 0);
      expect(clock.phase, DayPhase.night);
    });

    test('midnight rollover increments day count correctly', () {
      final clock = const SimulationClock(day: 1, hour: 23, minute: 30);
      final nextDay = clock.advance(minutesAdvanced: 60);

      expect(nextDay.day, 2);
      expect(nextDay.hour, 0);
      expect(nextDay.minute, 30);
      expect(nextDay.tickCount, 1);
      expect(nextDay.formattedFull, 'Day 2 • 00:30');
    });

    test('JSON serialization and deserialization', () {
      final clock = const SimulationClock(
        day: 5,
        hour: 14,
        minute: 45,
        tickCount: 92,
      );
      final json = clock.toJson();
      final revived = SimulationClock.fromJson(json);

      expect(revived.day, 5);
      expect(revived.hour, 14);
      expect(revived.minute, 45);
      expect(revived.tickCount, 92);
      expect(revived.phase, DayPhase.day);
    });
  });
}
