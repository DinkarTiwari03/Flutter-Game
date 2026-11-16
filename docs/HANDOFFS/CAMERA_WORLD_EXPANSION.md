# Phase Handoff: Full-Viewport Isometric World & Expandable Terrain (Minecraft-Style Camera)

## 1. Overview
This upgrade eliminates the "tiny island floating in empty purple void" effect by transitioning City Builder 2040 to a **Minecraft-style full-viewport world experience**. 

The playable map seamlessly occupies the full available display area between the top HUD and bottom navigation/rail. Zooming out no longer shrinks the world into an empty void; instead, the camera uses **adaptive minimum zoom** tailored to the device screen size and aspect ratio, while an **expandable tile-based world system** allows deterministic expansion beyond the initial boundaries without disrupting existing roads, buildings, or decorations.

---

## 2. Core Features Implemented

### A. Full-Viewport Map Layout
- **Complete Viewport Utilization:**
  - In portrait mode: The map occupies 100% of the screen height between the `CompactTopBar` and `GameNavigation` bottom bar.
  - In landscape/desktop mode: The map spans the full vertical height alongside the navigation rail and section panels.
  - No overlap occurs with the top HUD or bottom navigation bars.
  - Isometric proportions (2:1 diamond ratio) remain strictly preserved.
- **Elimination of Unnecessary Purple Void:**
  - Boundary margin reduced from `192.0` down to `64.0` px, preventing excessive camera drift past world bounds.
  - When the user zooms all the way out, the camera is constrained to the adaptive fit/fill bounds so the terrain fills the visible game screen.

### B. Adaptive Camera & Zoom System
- **Adaptive Minimum Zoom (`effectiveMinZoom`):**
  - Instead of a rigid hardcoded minimum zoom (e.g. 0.3), `MapCamera` dynamically evaluates the viewport size (`_viewport`) against the world bounding box (`_worldBounds`).
  - Small maps (e.g., 16×16 or 48×48) on high-resolution screens cannot be shrunk into a tiny speck.
  - Huge maps (e.g., 128×128 or 256×256) dynamically scale their minimum zoom so players can smoothly zoom out and view their entire metropolitan empire.
- **Initial Auto-Fit (`jumpToFit()`):**
  - On the first layout pass, `MapViewport` calculates the exact viewport constraints and automatically centers and scales the camera to display the whole city.
- **Double-Tap Shortcut:**
  - Double-tapping anywhere on the map triggers `widget.controller.showWholeMap()`, smoothly animating the camera back to framing the whole world.
- **Multi-Platform Gestures:**
  - **Android / Touch:** Smooth pinch-to-zoom, single-finger drag-to-pan, velocity-based fling inertia with frictionless damping.
  - **Windows / Mouse:** Mouse-wheel zoom centered on cursor, right/middle click drag, WASD / arrow key panning, on-screen zoom HUD buttons (`+`, `-`, fit, grid toggle).

### C. Expandable Tile-Based World System
- **Deterministic Procedural Expansion (`WorldExpansionService`):**
  - Players are not restricted to a small, fixed island.
  - `GameMap.expanded(newCols, newRows)` creates a larger grid, copying all existing tile data (roads, trees, buildings, water) into the expanded coordinate matrix.
  - `GameMap.mergeExpanded(generated, originalCols, originalRows)` blends fresh terrain generated with the city's original deterministic seed into the newly exposed outer territory.
  - Existing infrastructure, roads, and player-constructed buildings remain 100% intact and undisturbed.
- **Persistence & State Synchronization:**
  - The updated dimensions (`mapWidth`, `mapHeight`) are updated on the `City` model and written to the database on the next autosave cycle.
  - `expandableGameMapProvider` and `GameScreen` immediately update camera bounds via `camera.setWorldBounds(newBounds)` and trigger `controller.showWholeMap()`.

### D. Rendering Optimizations
- **Chunk Caching (`IsoMapRenderer`):**
  - Map tiles are split into 16×16 tile chunks, recorded into hardware-accelerated `Picture` objects on first view.
  - Panning and zooming over thousands of tiles incurs zero redraw overhead for off-screen tiles.
- **Frustum Culling (`visibleTiles`):**
  - Only chunks intersecting the camera's `visibleWorldRect` (+ padding for tall building sprites) are submitted to the GPU.
- **Repaint Boundaries:**
  - Ground tiles, buildings/urban entities, and selection/hover overlays live in separate `RepaintBoundary` layers.

---

## 3. Files Modified & Created

| File | Status | Description |
|---|---|---|
| `lib/core/constants/game_constants.dart` | Modified | Adjusted `boundaryMargin` (64.0) and camera limits. |
| `lib/game/engine/map_camera.dart` | Modified | Added `adaptiveMinZoom`, `effectiveMinZoom`, `jumpToFit()`, and `fillZoom`. |
| `lib/game/engine/map_camera_controller.dart` | Modified | Added `fillViewport()`, clamped `_animate` to `effectiveMinZoom`. |
| `lib/game/map/game_map.dart` | Modified | Implemented `expanded()` and `mergeExpanded()`. |
| `lib/widgets/game/map_viewport.dart` | Modified | Added double-tap detection and first-layout `jumpToFit()`. |
| `lib/screens/game_screen.dart` | Modified | Integrated `expandableGameMapProvider`, set `adaptiveMinZoom: true`, and added dynamic camera bounds update on world expansion. |
| `lib/services/world_expansion_service.dart` | Created | Centralized world expansion service, seed-deterministic generation, and provider wiring. |
| `test/game/map_camera_expansion_test.dart` | Created | Comprehensive test suite for adaptive zoom, resize behavior, map expansion, and boundary clamping. |
| `docs/PROJECT_MASTER.md` | Modified | Updated phase table and documentation roadmap. |

---

## 4. Verification & Testing Checklist

- [x] **Initial Opening:** Game opens centered on the city; map fills the available screen space without black or purple sidebars.
- [x] **Maximum Zoom Out:** Zooming out stops cleanly at the world boundary; the city is framed comfortably without shrinking into a tiny dot.
- [x] **Maximum Zoom In:** Zooming in allows close inspection of buildings, pedestrians, and vehicles.
- [x] **Double-Tap:** Double-tapping anywhere on the terrain smoothly frames the full city.
- [x] **Responsive Resizing:** Rotating between portrait and landscape or resizing the desktop window recalibrates `effectiveMinZoom` and keeps the map centered.
- [x] **Deterministic Expansion:** Expanding the world preserves all existing tiles and roads while deterministically populating new outer tiles.
- [x] **Automated Tests:** `test/game/map_camera_expansion_test.dart` passes with full coverage of adaptive zoom, expansion, and merge logic.

---

## 5. Next Steps
Awaiting user review and approval before proceeding to any further feature development.
