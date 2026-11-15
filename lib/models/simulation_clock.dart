import 'package:flutter/material.dart';

/// Phase of the in-game day/night diurnal cycle.
enum DayPhase {
  dawn('Dawn', Icons.wb_twilight_rounded, Color(0x28FFAB40)),
  day('Day', Icons.wb_sunny_rounded, Colors.transparent),
  dusk('Dusk', Icons.nights_stay_rounded, Color(0x35E040FB)),
  night('Night', Icons.bedtime_rounded, Color(0x550A1931));

  const DayPhase(this.label, this.icon, this.ambientColor);

  final String label;
  final IconData icon;

  /// Ambient lighting tint color applied across the city view.
  final Color ambientColor;

  bool get isNight => this == night;
  bool get isDay => this == day;
}

/// In-game simulation clock tracking day count, hours, and day/night transitions.
class SimulationClock {
  const SimulationClock({
    this.day = 1,
    this.hour = 8,
    this.minute = 0,
    this.tickCount = 0,
  });

  factory SimulationClock.initial() => const SimulationClock(
        day: 1,
        hour: 8,
        minute: 0,
        tickCount: 0,
      );

  factory SimulationClock.fromJson(Map<String, Object?> json) {
    return SimulationClock(
      day: (json['day'] as num?)?.toInt() ?? 1,
      hour: (json['hour'] as num?)?.toInt() ?? 8,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      tickCount: (json['tickCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Day number (starts at Day 1).
  final int day;

  /// Hour of the day (0 to 23).
  final int hour;

  /// Minute of the hour (0 to 59).
  final int minute;

  /// Total simulation ticks elapsed.
  final int tickCount;

  /// Determines the current diurnal phase based on the hour.
  DayPhase get phase {
    if (hour >= 5 && hour < 8) return DayPhase.dawn;
    if (hour >= 8 && hour < 18) return DayPhase.day;
    if (hour >= 18 && hour < 21) return DayPhase.dusk;
    return DayPhase.night;
  }

  /// Formatted 24-hour time string (e.g. "08:00", "19:30").
  String get formattedTime {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Formatted date string (e.g. "Day 1").
  String get formattedDay => 'Day $day';

  /// Complete formatted string (e.g. "Day 1 • 08:00").
  String get formattedFull => 'Day $day • $formattedTime';

  /// Advances the simulation clock by [minutesAdvanced] minutes.
  SimulationClock advance({int minutesAdvanced = 60}) {
    var totalMinutes = hour * 60 + minute + minutesAdvanced;
    var newDay = day;

    if (totalMinutes >= 1440) {
      newDay += totalMinutes ~/ 1440;
      totalMinutes %= 1440;
    }

    final newHour = totalMinutes ~/ 60;
    final newMinute = totalMinutes % 60;

    return SimulationClock(
      day: newDay,
      hour: newHour,
      minute: newMinute,
      tickCount: tickCount + 1,
    );
  }

  SimulationClock copyWith({
    int? day,
    int? hour,
    int? minute,
    int? tickCount,
  }) {
    return SimulationClock(
      day: day ?? this.day,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      tickCount: tickCount ?? this.tickCount,
    );
  }

  Map<String, Object?> toJson() => {
        'day': day,
        'hour': hour,
        'minute': minute,
        'tickCount': tickCount,
      };
}
