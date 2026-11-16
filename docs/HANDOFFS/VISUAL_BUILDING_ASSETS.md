# Hand-off: Visual Building Assets Upgrade

## 1. Overview

Replaced the legacy procedural coloured-box building placeholders with genuine 2D isometric PNG sprites sourced from Kenney's CC0 asset packs (*Isometric City* and *Isometric Landscape*).

## 2. Integrated Assets

- **Total Assets**: 54 PNG sprites bundled locally in `assets/buildings/`.
- **License**: CC0 1.0 Universal (Public Domain).
- **Categories Covered**:
  - Residential (`small_house`, `apartments`, `residential_tower`)
  - Commercial (`shop`, `shopping_mall`, `office_building`)
  - Industrial (`factory`, `industrial_facility`)
  - Public Services (`hospital`, `school`, `police_station`, `fire_station`)
  - Infrastructure (`road`, `power_plant`, `water_facility`)
  - Environment (`park`, `garden`, `solar_plant`, `water_treatment`)
- **Progression / Level Variations**: Distinct sprites or visual tiers for Levels 1, 2, and 3.

## 3. Architecture & Rendering Pipeline

1. **Sprite Registry** (`lib/game/buildings/building_sprite_registry.dart`):
   - Maps `typeId:level` pairs to bundled asset paths.
2. **Sprite Cache** (`lib/game/components/building_sprite_cache.dart`):
   - Asynchronously decodes `ui.Image` frames into GPU memory and caches them.
   - Lifetime owned by `_MapViewportState` in `lib/widgets/game/map_viewport.dart`.
3. **Renderer** (`lib/game/components/building_art.dart`):
   - `BuildingArt.paintBuilding` renders the cached PNG sprite scaled and anchored to the isometric footprint diamond.
   - Semi-transparent ghost preview with colored placement boundary (cyan for valid, coral for invalid).
   - Seamless fallback to the 2.5D procedural box painter if an asset is not yet loaded or missing.
4. **Custom Painter** (`lib/game/components/building_painter.dart`):
   - Depths-sorts buildings (`row + col`) and requests warm-up from `BuildingSpriteCache`.

## 4. Verification

- `flutter analyze`: 0 issues found.
- Android release APK built successfully (24.3 MB).
