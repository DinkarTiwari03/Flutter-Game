import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/models/city_event.dart';

void main() {
  group('CityEvent Model Tests', () {
    test('tick decrements duration until expiration', () {
      final event = const CityEvent(
        id: 'event_test',
        title: 'Festival',
        description: 'Music everywhere',
        type: CityEventType.happinessBonus,
        durationTicks: 3,
        remainingTicks: 3,
        happinessModifier: 10,
      );

      expect(event.isExpired, isFalse);
      expect(event.remainingHours, 3);

      final t1 = event.tick();
      expect(t1.remainingTicks, 2);
      expect(t1.remainingHours, 2);
      expect(t1.isExpired, isFalse);

      final t2 = t1.tick();
      expect(t2.remainingTicks, 1);

      final t3 = t2.tick();
      expect(t3.remainingTicks, 0);
      expect(t3.isExpired, isTrue);
    });

    test('CityEventPool contains balanced positive event templates', () {
      expect(CityEventPool.all, isNotEmpty);
      expect(CityEventPool.all.length, 4);

      for (final event in CityEventPool.all) {
        expect(event.durationTicks, greaterThan(0));
        expect(event.remainingTicks, equals(event.durationTicks));
        expect(event.title, isNotEmpty);
      }
    });

    test('JSON serialization and deserialization', () {
      final event = CityEventPool.techBoom;
      final json = event.toJson();
      final revived = CityEvent.fromJson(json);

      expect(revived.id, event.id);
      expect(revived.title, event.title);
      expect(revived.type, CityEventType.taxIncomeBonus);
      expect(revived.multiplier, 1.25);
    });
  });
}
