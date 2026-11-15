/// Ground type of a tile. Stored by [index] in the map's byte arrays, so only
/// append new values at the end.
enum TileType {
  grass('Grass', 'Open, buildable land.'),
  sand('Sand', 'Sandy shoreline. Buildable.'),
  water('Water', 'Deep water. Cannot be built on.'),
  road('Road', 'Paved road. Connects the city.');

  const TileType(this.label, this.description);

  final String label;
  final String description;

  bool get isLand => this != water;

  /// Whether a future building could be placed here.
  bool get isBuildable => this == grass || this == sand;
}

/// Decorative object standing on a tile. Stored by [index]; append only.
enum TileDecoration {
  none('None'),
  tree('Oak tree'),
  pine('Pine tree'),
  bush('Bush'),
  rock('Boulder'),
  flowers('Wildflowers');

  const TileDecoration(this.label);

  final String label;

  bool get isNone => this == none;
}
