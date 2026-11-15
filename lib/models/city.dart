/// Persisted description of one saved city (one save slot).
///
/// Timestamps are stored in UTC. [updatedAt] is kept on every entity so a
/// future cloud sync can resolve conflicts (last write wins).
class City {
  const City({
    required this.id,
    required this.name,
    required this.mapWidth,
    required this.mapHeight,
    required this.createdAt,
    required this.updatedAt,
    this.day = 1,
    this.population = 0,
  });

  factory City.fromJson(Map<String, Object?> json) {
    return City(
      id: json['id'] as String,
      name: json['name'] as String,
      mapWidth: (json['mapWidth'] as num).toInt(),
      mapHeight: (json['mapHeight'] as num).toInt(),
      day: (json['day'] as num).toInt(),
      population: (json['population'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String id;
  final String name;
  final int mapWidth;
  final int mapHeight;
  final int day;
  final int population;
  final DateTime createdAt;
  final DateTime updatedAt;

  City copyWith({
    String? name,
    int? day,
    int? population,
    DateTime? updatedAt,
  }) {
    return City(
      id: id,
      name: name ?? this.name,
      mapWidth: mapWidth,
      mapHeight: mapHeight,
      day: day ?? this.day,
      population: population ?? this.population,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'mapWidth': mapWidth,
    'mapHeight': mapHeight,
    'day': day,
    'population': population,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
