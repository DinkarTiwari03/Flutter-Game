/// Persisted description of one saved city (one save slot).
///
/// [seed] drives deterministic terrain generation; the same seed always
/// produces the same map so we never need to persist tile data.
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
    this.seed = 0,
    this.day = 1,
    this.population = 0,
  });

  factory City.fromJson(Map<String, Object?> json) {
    return City(
      id: json['id'] as String,
      name: json['name'] as String,
      mapWidth: (json['mapWidth'] as num).toInt(),
      mapHeight: (json['mapHeight'] as num).toInt(),
      seed: (json['seed'] as num?)?.toInt() ?? 0,
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

  /// Terrain generation seed. When non-zero the map is generated from this
  /// value; otherwise the city id hash is used (backwards-compatible).
  final int seed;
  final int day;
  final int population;
  final DateTime createdAt;
  final DateTime updatedAt;

  City copyWith({
    String? name,
    int? seed,
    int? day,
    int? population,
    DateTime? updatedAt,
  }) {
    return City(
      id: id,
      name: name ?? this.name,
      mapWidth: mapWidth,
      mapHeight: mapHeight,
      seed: seed ?? this.seed,
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
    'seed': seed,
    'day': day,
    'population': population,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
