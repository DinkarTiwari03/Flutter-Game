# Handoff: Building Rotation System

## Overview
Added complete 4-direction building rotation support (0°, 90°, 180°, 270°) to City Builder 2040.
Players can now rotate buildings prior to placement using:
- **Mobile/Touch:** A dedicated rotate button in the placement HUD showing current orientation (e.g. `90°`), cycling through 0° → 90° → 180° → 270° → 0°.
- **Desktop/Keyboard:** The `R` key, which rotates clockwise in 90° increments while in placement mode.

Map/camera rotation and building rotation are completely decoupled.

---

## Architecture & Implementation

### 1. Building Model (`lib/models/building.dart`)
- Added `final int rotation;` (0, 90, 180, 270) with default `0`.
- Updated `fromJson`, `toJson`, and `copyWith` to serialize and copy rotation.

### 2. Building Definition (`lib/game/buildings/building_definition.dart`)
- Added `footprintTilesRotated(GridPoint origin, int rotation)`:
  - 0° and 180° maintain `width` cols × `height` rows.
  - 90° and 270° swap dimensions to `height` cols × `width` rows.
- Added `effectiveWidth(int rotation)` and `effectiveHeight(int rotation)` helper accessors.

### 3. Placement Validation (`lib/game/buildings/placement_validator.dart`)
- `PlacementValidator.validate` takes `int rotation = 0`.
- Validates the active placement using `definition.footprintTilesRotated(origin, rotation)`.
- Validates occupancy against existing buildings using each building's stored `b.rotation`.

### 4. Reactive State (`lib/providers/building_providers.dart`)
- `PlacementState` holds `int rotation` (defaults to 0).
- `PlacementNotifier.rotateBuilding()` increments rotation by 90° modulo 360 and immediately re-runs validation at `previewOrigin`.
- `confirmPlacement()` transfers `state.rotation` into `placeBuilding()`.
- `buildingOccupancyProvider` maps occupied tiles according to each placed building's rotation.

### 5. Services & Repositories (`lib/services/building_service.dart`, `lib/repositories/local/`)
- `BuildingService.placeBuilding` accepts `int rotation = 0`, validates with it, and instantiates the `Building` with the orientation.
- `LocalBuildingRepository` and `AppDatabase` persist the `rotation` column in SQLite with backwards compatibility.

### 6. 2.5D Art & Rendering (`lib/game/components/building_art.dart`, `building_painter.dart`)
- `BuildingArt.paintBuilding` accepts `int rotation = 0`.
- For sprites: applies horizontal reflection when rotated 90° or 270° so the visual facing direction matches the player's choice without requiring 4 distinct asset files per building.
- For procedural buildings: geometry and footprint diamond adapt to `effectiveWidth` and `effectiveHeight`.
- Placement ghost preview footprint draws the rotated diamond tiles and updates in real-time.

### 7. Controls & Shortcuts (`lib/widgets/game/placement_hud.dart`, `lib/screens/game/game_shortcuts.dart`)
- `PlacementHud`: Displays effective footprint dimensions (e.g. `2x3` or `3x2`) and a rotate button with the current angle badge (`0°`, `90°`, `180°`, `270°`).
- `GameShortcuts`: Binds `LogicalKeyboardKey.keyR` to `RotateBuildingIntent`, calling `rotateBuilding()` during placement mode without interfering with camera shortcuts.

---

## Verification
- Unit test suite: `test/game/building_rotation_test.dart`
  - 1×1 symmetric buildings remain 1-tile across all rotations.
  - 2×3 buildings swap effective dimensions (3×2) at 90° and 270°.
  - 4-step cycling verified (0° → 90° → 180° → 270° → 0°).
  - Model serialization, default values, and copyWith tested.
  - Placement boundary checks and overlap detection verified with rotated footprints.
