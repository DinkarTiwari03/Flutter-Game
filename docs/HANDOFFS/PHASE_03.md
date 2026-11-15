# Phase 03 Handoff: Cross-Platform Building Placement System

## 1. Features Implemented

### Building Definitions & Registry
- **19 Reusable Building Definitions (`BuildingDefinition`, `BuildingRegistry`):**
  - **Residential:** Small House (1x1), Apartments (2x2), Residential Tower (2x2, max lvl 4).
  - **Commercial:** Shop (1x1), Shopping Mall (2x2), Office Building (2x2, max lvl 4).
  - **Industrial:** Factory (2x2), Industrial Facility / Complex (3x3).
  - **Public Services:** Hospital (2x2), School (2x2), Police Station (1x1), Fire Station (1x1).
  - **Infrastructure:** Road (1x1), Power Plant (2x2), Water Facility (2x2).
  - **Environment:** City Park (2x2), Botanical Garden (1x1), Solar Plant (2x2), Water Treatment (2x2).
- **Extensible Configuration:**
  - Standardized properties: width, height, base construction cost, base upgrade cost, max level, category, icon, and accent color.
  - Multi-tile footprint calculation (`footprintTiles`) for 1x1, 2x2, and 3x3 structures.
  - Tiered upgrade cost scaling (`upgradeCost`) based on current level.
  - Demolition refund formula (`demolitionRefund`): 50% refund of base construction cost plus 50% of invested upgrade costs.

### Grid Placement & Validation System
- **Placement Validator (`PlacementValidator`):**
  - **Boundary Checking:** Validates all footprint tiles against `GameMap` bounds. Rejects out-of-bounds placement.
  - **Terrain Compatibility:** Checks ground type; prevents construction on water or non-buildable terrain.
  - **Collision & Overlap Detection:** Builds an occupancy map of existing buildings and detects overlaps across single-tile and multi-tile footprints.
  - **Road Segments & Rules:** Roads can be placed along valid ground; buildings cannot be placed on top of existing roads.
  - Clear validation results (`PlacementValidationResult`) with specific enum reasons (`PlacementValidationReason`) and localized status messages for players.

### 2.5D Isometric Building Art & Rendering
- **Procedural 2.5D Isometric Building Drawing (`BuildingArt`):**
  - Custom canvas geometry with footprint foundations, shaded left/right wall elevations, and roof diamonds.
  - Category-specific details: hospital red crosses & helipads, emergency antennas, park water fountains, solar cell panel grids, power plant cooling towers, and window glints.
  - Level badges and indicator dots on building roofs indicating tier upgrades.
- **Dedicated Building Painter Layer (`BuildingPainter`):**
  - **Isometric Depth Sorting:** Automatically sorts placed structures by isometric depth `(y + x)` to guarantee accurate front-to-back occlusion.
  - **Selection Glow:** Highlight outline around selected buildings with soft glow and crisp inner stroke.
  - **Placement Ghost Preview:** Real-time semi-transparent building preview rendered at the hover/touch coordinate with dynamic color feedback (teal for valid, coral for blocked/invalid).
  - Rendered inside its own `RepaintBoundary` to decouple building and preview updates from map chunk rasterization.

### Building Management & Service Layer
- **Building Business Logic (`BuildingService`):**
  - Validates and constructs buildings via `placeBuilding`.
  - Upgrades buildings to higher tiers via `upgradeBuilding` (validating max level constraints).
  - Demolishes buildings via `demolishBuilding` and calculates coin refunds.
  - Persists directly through `BuildingRepository` interface.
- **Riverpod State Management (`building_providers.dart`):**
  - `cityBuildingsProvider`: AsyncNotifier managing placed buildings in the active city.
  - `buildingOccupancyProvider`: Fast spatial dictionary mapping every occupied `GridPoint` to its building.
  - `placementProvider`: Manages active building definition, preview origin, and live validation status.
  - `selectedBuildingIdProvider` & `selectedBuildingProvider`: Tracks and resolves the selected building for inspection.

### Responsive UI & Cross-Platform Controls
- **Building Selection Menu (`BuildingSelectionMenu`):**
  - Scrollable category filter bar (Residential, Commercial, Industrial, Public Services, Infrastructure, Environment).
  - Building option cards displaying dimensions (e.g. 2x2), description, cost, and "Build" action.
  - Directly opens in the Build and Roads sections on mobile and desktop.
- **Placement HUD (`PlacementHud`):**
  - Floating bottom card during placement showing building preview name, dimensions, cost, live validity message, and "Cancel" / "Place" buttons.
- **Building Inspector Panel (`BuildingInspectorPanel`):**
  - Detailed inspection card for placed buildings showing level, category, footprint, upgrade cost / status, and demolition refund.
  - Direct upgrade and demolish action buttons.
- **Touch & Mouse Controls:**
  - **Android:** Tap to select building from menu, drag or tap on map to position preview, tap again or press "Place" in HUD to confirm.
  - **Windows Desktop:** Mouse hover moves preview with grid snapping; click to place/confirm; `Escape` key clears placement mode, then clears building selection, then clears tile selection.

---

## 2. Files Created, Modified and Deleted

### Created
- `lib/game/buildings/building_definition.dart` — 19 building definitions, `BuildingCategory`, `BuildingRegistry`.
- `lib/game/buildings/placement_validator.dart` — Grid bounds, terrain checks, and collision detection rules.
- `lib/services/building_service.dart` — Business service for building placement, upgrades, and demolition.
- `lib/providers/building_providers.dart` — Riverpod providers for buildings, occupancy map, placement state, and selection.
- `lib/game/components/building_art.dart` — Canvas 2.5D building drawing routines with architectural accents and level indicators.
- `lib/game/components/building_painter.dart` — Depth-sorted CustomPainter for placed buildings and placement ghost previews.
- `lib/widgets/game/building_selection_menu.dart` — Category chips and building cards menu.
- `lib/widgets/game/placement_hud.dart` — Floating HUD with status, cost, and confirm/cancel actions.
- `lib/widgets/game/building_inspector_panel.dart` — Inspector sidebar/drawer for upgrading and demolishing buildings.
- `test/game/building_definition_test.dart` — Unit tests for registry, footprints, upgrade costs, and refunds.
- `test/game/placement_validator_test.dart` — Unit tests for bounds, terrain, overlap, and road validation.
- `test/services/building_service_test.dart` — Unit tests for building placement, upgrades, and demolition.
- `docs/HANDOFFS/PHASE_03.md` — This handoff document.

### Modified
- `lib/providers/repository_providers.dart` — Registered `buildingServiceProvider`.
- `lib/widgets/game/section_panel.dart` — Integrated `BuildingSelectionMenu` into Build and Roads sections; removed obsolete placeholder grids.
- `lib/widgets/game/map_viewport.dart` — Added `BuildingPainter` layer, hover/tap placement interaction, building selection priority over tile selection.
- `lib/screens/game/phone_game_layout.dart` — Added `PlacementHud` and `BuildingInspectorPanel` support.
- `lib/screens/game/desktop_game_layout.dart` — Added `PlacementHud` overlay on map and `BuildingInspectorPanel` in right sidebar.
- `lib/screens/game/game_shortcuts.dart` — Updated `Escape` shortcut to cancel placement mode before clearing selections.
- `docs/PROJECT_MASTER.md` — Updated phase status and roadmap.

### Deleted
- None.

---

## 3. Architecture Decisions

1. **Repository Pattern Adherence:**
   - UI widgets never touch repositories directly; interactions flow through `CityBuildingsNotifier` and `BuildingService`, which in turn talk to `BuildingRepository` interfaces.
2. **Spatial Occupancy Lookup (`buildingOccupancyProvider`):**
   - Maintained as an indexed `Map<GridPoint, Building>` for $O(1)$ collision checks and tile-to-building resolution when clicking on any tile of a multi-tile footprint.
3. **Depth Sorting by Diagonal Coordinates:**
   - Placed buildings are sorted by $(y + x)$ before painting, ensuring correct isometric front-over-back occlusions regardless of placement sequence.
4. **Isolated Ghost Layer within Viewport:**
   - Placed buildings and placement ghosts share the `BuildingPainter` layer, which repaints smoothly when moving the preview cursor without invalidating terrain background chunks.

---

## 4. Dependencies Added

No runtime packages were added. Stack remains:
- `flutter_riverpod` (3.3.2)
- `hive` (2.2.3)
- `hive_flutter` (1.1.0)
- `cupertino_icons` (1.0.8)

---

## 5. Tests Performed and Results

- **Unit and Integration Tests (`flutter test`):**
  - Building definition and registry calculations: **Passed**.
  - Grid bounds, water, overlap, and road placement validation: **Passed**.
  - BuildingService placement, upgrade tiers, and demolition refund calculations: **Passed**.
- **Static Analysis (`flutter analyze`):**
  - **No issues found!** Clean analysis across all project files.
- **Platform Verification:**
  - Android APK debug build verified.

---

## 6. Known Issues

- **Windows Desktop Native Toolchain:** Visual Studio "Desktop development with C++" workload required for native Windows desktop executable compilation.
- **Physical Device:** Android device `6b5e656f` offline via ADB; APK builds cleanly.
- **Resource Balances:** Actual coin deduction, resource production, and simulation loop integration are scheduled for Phase 4.

---

## 7. Instructions for Phase 4

Phase 4: **City Economy, Resource Simulation, and Game Loop**.
1. **Economic Model:**
   - Implement coin generation from residential taxes and commercial buildings.
   - Implement power generation and water supply networks.
   - Implement maintenance upkeep deductions per building tier.
2. **Game Loop & Simulation Ticker:**
   - Connect `simulationSpeedProvider` (paused, 1x, 2x, 3x) to an active game loop ticker.
   - Deduct costs when placing and upgrading buildings via `BuildingService` + `ResourceRepository`.
   - Update `cityStatsProvider` dynamically with live economy calculations.
