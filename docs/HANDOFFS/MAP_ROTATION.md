# Handoff: Interactive Isometric Map Rotation System

## Overview
This feature introduces continuous 360-degree interactive map rotation to City Builder 2040, supporting multi-touch twisting on Android, Q/E keyboard keys and dedicated UI buttons on Windows desktop, alongside seamless coordinate transformations ensuring full gameplay compatibility.

---

## 1. Gesture & Input System

### Android Touch Gestures
- **Two-Finger Twist**: Tracks two active touch pointer positions $(P_1, P_2)$, calculating the angular delta:
  $$\alpha = \operatorname{atan2}(P_2.y - P_1.y, P_2.x - P_1.x)$$
  $$\Delta\alpha = \alpha_t - \alpha_{t-1} \pmod{2\pi}$$
- **Simultaneous Pinch & Twist**: Zooms and rotates concurrently around the fingers' focal midpoint:
  $$F = \frac{P_1 + P_2}{2}$$
  World point pinned under the gesture remains stationary relative to the screen.
- **Accidental Placement Prevention**: Two-finger interactions flag `_hadMultiTouch = true`, strictly suppressing single-touch tap candidates. Releasing fingers never triggers accidental tile selection or building construction.

### Windows Desktop Controls
- **Keyboard Shortcuts**:
  - `Q`: Smooth animated counterclockwise rotation ($\Delta\theta = -\frac{\pi}{4}$).
  - `E`: Smooth animated clockwise rotation ($\Delta\theta = +\frac{\pi}{4}$).
- **Mouse & On-Screen UI Controls**:
  - `Rotate Left` (`control-rotate-left`): Counterclockwise turn button.
  - `Rotate Right` (`control-rotate-right`): Clockwise turn button.
  - `Reset View & Orientation` (`control-fit`): Smoothly animates rotation back to $0.0$ while framing the whole city.
  - Trackpad precision rotation via `PointerPanZoomUpdateEvent.rotation`.

---

## 2. Coordinate Transformation & Mathematical Model

The rotation operates purely on the camera viewport layer, leaving the underlying simulation, grid data, and models in canonical isometric world coordinates.

### Forward Transform (World to Screen)
Given world coordinate $P_w = (x_w, y_w)$, camera focus $F_w$, zoom $z$, and rotation $\theta$:
$$P_{\text{rel}} = (P_w - F_w) \cdot z$$
$$\begin{bmatrix} x_s \\ y_s \end{bmatrix} = \begin{bmatrix} \cos\theta & -\sin\theta \\ \sin\theta & \cos\theta \end{bmatrix} \begin{bmatrix} x_{\text{rel}} \\ y_{\text{rel}} \end{bmatrix} + \begin{bmatrix} x_{\text{center}} \\ y_{\text{center}} \end{bmatrix}$$

### Inverse Transform (Screen to World)
Given screen coordinate $P_s = (x_s, y_s)$:
$$P_{\text{sc\_rel}} = P_s - \text{viewportCenter}$$
$$\begin{bmatrix} x_u \\ y_u \end{bmatrix} = \begin{bmatrix} \cos(-\theta) & -\sin(-\theta) \\ \sin(-\theta) & \cos(-\theta) \end{bmatrix} \begin{bmatrix} x_{\text{sc\_rel}} \\ y_{\text{sc\_rel}} \end{bmatrix}$$
$$P_w = \frac{P_u}{z} + F_w$$

### Screen Drag Panning under Rotation
When panning by screen delta $\Delta S$, the focus shift in world coordinates is rotated by $-\theta$:
$$\Delta F_w = -\frac{\operatorname{rotate}(\Delta S, -\theta)}{z}$$
Dragging right on screen continues to move the map right on screen regardless of orientation angle.

---

## 3. Gameplay Compatibility Guarantee
- **Grid Snapping**: `IsoProjection.worldToGrid(_camera.screenToWorld(screenPos))` automatically maps rotated screen taps to the exact underlying isometric tile.
- **Building Placement**: Preview footprint and placement confirmation snap accurately to grid coordinates regardless of rotation angle.
- **Urban Life**: Vehicles and pedestrians continue tracking their designated road graphs and sidewalks in world coordinates; the hardware canvas rotation transforms the entire layer seamlessly without altering agent states.
- **Stationary Overlays**: Top HUD, bottom navigation, and floating camera controls remain stationary.

---

## 4. Modified & Added Files

1. **`lib/game/engine/map_camera.dart`**:
   - Added `_rotation` state (radians) and `rotation` getter.
   - Updated `screenToWorld`, `worldToScreen`, `panByScreen`, and `anchorAt` with trigonometric rotation transforms.
   - Updated `visibleWorldRect` to calculate enclosing axis-aligned bounds of rotated screen corners.
2. **`lib/game/engine/map_camera_controller.dart`**:
   - Added animated rotation with shortest angular path interpolation.
   - Added `rotateBy`, `rotateLeft`, `rotateRight`, `resetRotation`, and `resetCamera`.
3. **`lib/game/components/iso_map_painter.dart`**:
   - Updated `MapCameraCanvas.applyCamera` to apply `canvas.rotate(camera.rotation)`.
4. **`lib/widgets/game/map_viewport.dart`**:
   - Added two-finger touch twist rotation gesture tracking with angle wrapping.
   - Added trackpad rotation gesture support.
5. **`lib/widgets/game/map_controls.dart`**:
   - Added rotate left, rotate right, and orientation reset buttons.
6. **`lib/screens/game/game_shortcuts.dart`**:
   - Added `RotateViewIntent` bound to `Q` and `E` keys.
7. **`test/game/map_rotation_test.dart`**:
   - Comprehensive unit and widget tests covering rotation math, combined gestures, tile picking, placement, and keyboard shortcuts.

---

## 5. Verification Results
- `Clockwise rotation (+pi/2)`: Verified exact coordinate transforms and round-trip identity.
- `Counterclockwise rotation (-pi/2)`: Verified coordinate transformations and inverse mapping.
- `360-degree rotation`: Verified identity preservation.
- `Combined pinch & twist`: Verified world point stays pinned under focal point.
- `Tile picking under rotation`: Verified tapping rotated screen snaps to correct isometric tile.
- `Building placement`: Verified preview snaps accurately to target grid tiles.
- `Windows shortcuts`: Verified Q and E trigger animated rotation.
