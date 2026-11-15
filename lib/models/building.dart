/// A building placed on a city's map.
///
/// [typeId] is a stable string id (for example `residential`) rather than a
/// Dart enum, so stored data does not depend on in-game code and survives
/// renamed or reordered game types. The game layer maps it to its own types.
class Building {
  const Building({
    required this.id,
    required this.cityId,
    required this.typeId,
    required this.x,
    required this.y,
    required this.createdAt,
    required this.updatedAt,
    this.level = 1,
  });

  factory Building.fromJson(Map<String, Object?> json) {
    return Building(
      id: json['id'] as String,
      cityId: json['cityId'] as String,
      typeId: json['typeId'] as String,
      x: (json['x'] as num).toInt(),
      y: (json['y'] as num).toInt(),
      level: (json['level'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String id;
  final String cityId;
  final String typeId;
  final int x;
  final int y;
  final int level;
  final DateTime createdAt;
  final DateTime updatedAt;

  Building copyWith({int? level, DateTime? updatedAt}) {
    return Building(
      id: id,
      cityId: cityId,
      typeId: typeId,
      x: x,
      y: y,
      level: level ?? this.level,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'cityId': cityId,
    'typeId': typeId,
    'x': x,
    'y': y,
    'level': level,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
