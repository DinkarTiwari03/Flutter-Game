# Handoff: Windows Desktop UI Improvements & Separation

## Overview
Comprehensive fixes and architectural cleanups specifically targeting the Windows desktop mode of City Builder 2040, without modifying or breaking any aspect of the mobile experience.

---

## 1. Problem Analysis & Resolutions

### A. Build Tool Automatic Selection & Deselection
- **Previous Cause:** In `DesktopGameLayout`, `final section = ref.watch(activeSectionProvider) ?? GameSection.build;` and `GameNavigation(alwaysOpen: true)` were forcing `GameSection.build` to remain active at all times. Tapping "Build" called `notifier.open(section)` rather than toggling, and closing/clearing was ignored due to the null-coalescing fallback.
- **Fix:**
  - Removed `alwaysOpen: true` from `DesktopGameLayout`. It now uses `alwaysOpen: false`, allowing `activeSectionProvider` to be `null` when no tool is active.
  - When the game starts on Windows, no tool is selected.
  - Clicking a tool in the rail selects it; clicking it again toggles it off.
  - Clicking the close `[X]` button on `SectionSidePanel` dismisses it.
  - Clicking outside on the map automatically dismisses the active tool panel.
  - Preserved full building placement workflow (`startPlacement` -> preview -> construct/cancel).

### B. City Map and UI Overlapping
- **Previous Cause:** `DesktopGameLayout` was arranged as a `Stack` where `Positioned.fill` held the map and side panels (with hardcoded `top: 84.0` padding), while `DesktopTopBar` floated over the entire screen at `Positioned(top: 0)`. The `MapViewport` had no top inset, causing the top portion of the city map to render underneath the top dashboard.
- **Fix:**
  - Re-architected `DesktopGameLayout` into a bounded `Column`:
    1. Top: `DesktopTopBar` (sits in its natural height without floating).
    2. Body: `Expanded` containing a `Row` with `GameNavigation`, optional `SectionSidePanel`, `Expanded(MapViewport)`, and optional `_InspectorPanel`.
  - Added `ClipRect` around `MapViewport` so isometric draw calls never leak outside the viewport bounds.
  - There is zero vertical or horizontal overlap between the map, top dashboard, and side panels.

### C. Right-Side Keys / How to Play Panel Toggle
- **Previous Cause:** `_InspectorPanel` (which contains `ShortcutHints` and tile/building info) was hardcoded at 300px width on the right of the desktop screen at all times.
- **Fix:**
  - Added `desktopInspectorVisibleProvider` in `lib/providers/game_providers.dart` (starts hidden by default for maximum map space).
  - Added a floating `[Controls]` pill button on the top-right of the map viewport.
  - Added a dedicated sidebar toggle icon button in `DesktopTopBar`.
  - Added a close `[X]` button in the `_InspectorPanel` header.
  - Added keyboard shortcut `H` (`ToggleInspectorIntent`) to quickly toggle the panel.
  - Selecting a building or tile automatically opens the inspector, and closing it dismisses the selection and returns map to full width.
  - When hidden, `Expanded(MapViewport)` automatically expands to occupy the full remaining width.

### D. Desktop Layout Responsiveness
- **Fix:**
  - Wrapped `DesktopGameLayout` in a `LayoutBuilder`.
  - Responsive panel width calculation: `(constraints.maxWidth * 0.22).clamp(260.0, 320.0)`.
  - Seamless adaptation across standard desktop resolutions (1024x768, 1366x768, 1920x1080, 2560x1440, 4K).

---

## 2. Preservation of Mobile UI
- `PhoneGameLayout` and `CompactTopBar` were untouched.
- `GameNavigation` on mobile continues using `alwaysOpen: false` and adaptive styles (`bottomBar` in portrait, `rail` in landscape).
- Mobile layout breakpoints and touch interactions are 100% preserved.

---

## 3. Files Modified & Created

### Core Logic & UI
- [lib/providers/game_providers.dart](file:///c:/Flutter_Game/lib/providers/game_providers.dart) — Added `desktopInspectorVisibleProvider`.
- [lib/screens/game/desktop_game_layout.dart](file:///c:/Flutter_Game/lib/screens/game/desktop_game_layout.dart) — Completely revised layout (Column, non-overlapping boundaries, responsive panels, toggle controls).
- [lib/widgets/game/desktop_top_bar.dart](file:///c:/Flutter_Game/lib/widgets/game/desktop_top_bar.dart) — Added topbar inspector toggle button.
- [lib/widgets/game/section_panel.dart](file:///c:/Flutter_Game/lib/widgets/game/section_panel.dart) — Added `onClose` callback to `SectionSidePanel`.
- [lib/widgets/game/map_viewport.dart](file:///c:/Flutter_Game/lib/widgets/game/map_viewport.dart) — Dismiss open tool on map tap outside.
- [lib/screens/game/game_shortcuts.dart](file:///c:/Flutter_Game/lib/screens/game/game_shortcuts.dart) — Bound `H` key to `ToggleInspectorIntent`.
- [lib/widgets/game/shortcut_hints.dart](file:///c:/Flutter_Game/lib/widgets/game/shortcut_hints.dart) — Updated cheat sheet with `Q/E`, `R`, and `H`.

### Tests
- [test/screens/desktop_ui_test.dart](file:///c:/Flutter_Game/test/screens/desktop_ui_test.dart) — Full desktop test suite verifying tool selection, non-overlapping layout, right panel toggle, resolution scaling, and mobile UI preservation.
- [test/screens/game_screen_test.dart](file:///c:/Flutter_Game/test/screens/game_screen_test.dart) — Updated existing test expectations.
