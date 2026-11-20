import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';

import 'package:city_builder_2040/core/constants/game_constants.dart';

/// 2D camera over world space.
///
/// The camera is defined by [focus] (the world point shown at the center of
/// the viewport), [zoom] (screen pixels per world unit), and [rotation]
/// (orientation in radians, 0 = default isometric orientation). Everything here
/// is plain maths with no widgets or tickers, so it is easy to unit test.
/// Listeners (painters) are notified whenever the view changes.
///
/// Conversions:
///     screen = rotate((world - focus) * zoom, rotation) + viewportCenter
///     world  = rotate(screen - viewportCenter, -rotation) / zoom + focus
class MapCamera extends ChangeNotifier {
  MapCamera({
    required Rect worldBounds,
    this.minZoom = GameConstants.minZoom,
    this.maxZoom = GameConstants.maxZoom,
    this.boundaryMargin = GameConstants.boundaryMargin,
    double zoom = GameConstants.initialZoom,
    double rotation = 0.0,
    Offset? focus,
    this.adaptiveMinZoom = false,
  }) : _worldBounds = worldBounds,
       _zoom = zoom.clamp(minZoom, maxZoom).toDouble(),
       _rotation = rotation,
       _focus = focus ?? worldBounds.center {
    _clampFocus();
  }

  final double minZoom;
  final double maxZoom;

  /// When true, [effectiveMinZoom] adapts to the viewport so the map fills the
  /// available game screen instead of shrinking to a tiny island with empty space.
  final bool adaptiveMinZoom;

  /// Extra world space allowed around the map edges, so the map can be
  /// scrolled slightly past its borders.
  final double boundaryMargin;

  /// Effective lower zoom limit. When [adaptiveMinZoom] is enabled, it computes
  /// the exact zoom to frame the world in the viewport without leaving empty
  /// margins.
  double get effectiveMinZoom {
    if (!adaptiveMinZoom || _viewport.isEmpty) return minZoom;
    final fit = math.min(
      _viewport.width / _worldBounds.width,
      _viewport.height / _worldBounds.height,
    );
    return fit.clamp(0.05, maxZoom).toDouble();
  }

  Rect _worldBounds;
  Size _viewport = Size.zero;
  double _zoom;
  double _rotation = 0.0;
  Offset _focus;

  Rect get worldBounds => _worldBounds;
  Size get viewport => _viewport;
  double get zoom => _zoom;
  double get rotation => _rotation;
  Offset get focus => _focus;

  Offset get viewportCenter =>
      Offset(_viewport.width / 2, _viewport.height / 2);

  /// Rotates an offset by [angle] radians around (0,0).
  static Offset rotateOffset(Offset o, double angle) {
    if (angle == 0) return o;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return Offset(o.dx * cosA - o.dy * sinA, o.dx * sinA + o.dy * cosA);
  }

  /// The part of world space currently visible.
  Rect get visibleWorldRect {
    if (_viewport.isEmpty) return _worldBounds;
    if (_rotation == 0) {
      final halfW = _viewport.width / 2 / _zoom;
      final halfH = _viewport.height / 2 / _zoom;
      return Rect.fromLTRB(
        _focus.dx - halfW,
        _focus.dy - halfH,
        _focus.dx + halfW,
        _focus.dy + halfH,
      );
    }
    final c1 = screenToWorld(Offset.zero);
    final c2 = screenToWorld(Offset(_viewport.width, 0));
    final c3 = screenToWorld(Offset(_viewport.width, _viewport.height));
    final c4 = screenToWorld(Offset(0, _viewport.height));
    final minX = math.min(math.min(c1.dx, c2.dx), math.min(c3.dx, c4.dx));
    final maxX = math.max(math.max(c1.dx, c2.dx), math.max(c3.dx, c4.dx));
    final minY = math.min(math.min(c1.dy, c2.dy), math.min(c3.dy, c4.dy));
    final maxY = math.max(math.max(c1.dy, c2.dy), math.max(c3.dy, c4.dy));
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Offset screenToWorld(Offset screen) {
    if (_rotation == 0) {
      return (screen - viewportCenter) / _zoom + _focus;
    }
    final unrotated = rotateOffset(screen - viewportCenter, -_rotation);
    return unrotated / _zoom + _focus;
  }

  Offset worldToScreen(Offset world) {
    if (_rotation == 0) {
      return (world - _focus) * _zoom + viewportCenter;
    }
    final scaled = (world - _focus) * _zoom;
    return rotateOffset(scaled, _rotation) + viewportCenter;
  }

  /// Updates the viewport size (call on layout). Keeps the focus valid and
  /// ensures the zoom never goes below [effectiveMinZoom] (which adapts to
  /// the viewport so the map always fills the screen).
  ///
  /// Pass `notify: false` when calling during a build; the resized render
  /// objects repaint on their own.
  void setViewport(Size size, {bool notify = true}) {
    if (size == _viewport) return;
    _viewport = size;
    // After the viewport changes the effective min-zoom changes too;
    // clamp the current zoom so the map keeps filling the screen.
    _zoom = _zoom.clamp(effectiveMinZoom, maxZoom).toDouble();
    _clampFocus();
    if (notify) notifyListeners();
  }

  /// Zooms to [fitZoom] so the whole map is visible and restores default orientation.
  void jumpToFit() {
    _rotation = 0.0;
    _zoom = fitZoom;
    _focus = clampFocus(_worldBounds.center, _zoom);
    notifyListeners();
  }

  void setWorldBounds(Rect bounds) {
    if (bounds == _worldBounds) return;
    _worldBounds = bounds;
    _clampFocus();
    notifyListeners();
  }

  /// Moves the view by [screenDelta] pixels, as if dragging the map. Dragging
  /// right moves the map right, so the focus moves left. Accounts for camera rotation.
  void panByScreen(Offset screenDelta) {
    final delta = _rotation == 0
        ? screenDelta
        : rotateOffset(screenDelta, -_rotation);
    _setView(focus: _focus - delta / _zoom, zoom: _zoom, rotation: _rotation);
  }

  /// Moves the focus by [worldDelta] world units.
  void panByWorld(Offset worldDelta) {
    _setView(focus: _focus + worldDelta, zoom: _zoom, rotation: _rotation);
  }

  void jumpTo({Offset? focus, double? zoom, double? rotation}) {
    _setView(
      focus: focus ?? _focus,
      zoom: zoom ?? _zoom,
      rotation: rotation ?? _rotation,
    );
  }

  /// Sets the zoom and rotation so that [worldPoint] stays under [screenPoint].
  void anchorAt({
    required Offset worldPoint,
    required Offset screenPoint,
    required double zoom,
    double? rotation,
  }) {
    final newZoom = zoom.clamp(effectiveMinZoom, maxZoom).toDouble();
    final newRotation = rotation ?? _rotation;
    final newFocus = worldPoint -
        rotateOffset(screenPoint - viewportCenter, -newRotation) / newZoom;
    _setView(focus: newFocus, zoom: newZoom, rotation: newRotation);
  }

  /// Zooms to [newZoom] keeping the world point under [screenPoint] fixed.
  void zoomAt(Offset screenPoint, double newZoom, {double? rotation}) {
    anchorAt(
      worldPoint: screenToWorld(screenPoint),
      screenPoint: screenPoint,
      zoom: newZoom,
      rotation: rotation,
    );
  }

  /// Clamps a focus point so the viewport stays within the map bounds (plus
  /// margin) at the given [zoom]. When the whole map fits on an axis, that
  /// axis is centered instead.
  Offset clampFocus(Offset focus, double zoom) {
    if (_viewport.isEmpty) return focus;
    final bounds = _worldBounds.inflate(boundaryMargin);
    final maxHalf = math.max(_viewport.width, _viewport.height) / 2 / zoom;
    final halfW = _rotation == 0 ? _viewport.width / 2 / zoom : maxHalf;
    final halfH = _rotation == 0 ? _viewport.height / 2 / zoom : maxHalf;
    return Offset(
      _clampAxis(focus.dx, bounds.left, bounds.right, halfW),
      _clampAxis(focus.dy, bounds.top, bounds.bottom, halfH),
    );
  }

  double _clampAxis(double value, double min, double max, double half) {
    if (max - min <= half * 2) return (min + max) / 2;
    return value.clamp(min + half, max - half).toDouble();
  }

  void _clampFocus() => _focus = clampFocus(_focus, _zoom);

  void _setView({
    required Offset focus,
    required double zoom,
    double? rotation,
  }) {
    final clampedZoom = zoom.clamp(effectiveMinZoom, maxZoom).toDouble();
    final clampedFocus = clampFocus(focus, clampedZoom);
    final targetRotation = rotation ?? _rotation;
    if (clampedZoom == _zoom &&
        clampedFocus == _focus &&
        targetRotation == _rotation) {
      return;
    }
    _zoom = clampedZoom;
    _focus = clampedFocus;
    _rotation = targetRotation;
    notifyListeners();
  }

  /// Zoom at which the whole map just fits the viewport.
  double get fitZoom {
    if (_viewport.isEmpty) return _zoom;
    final fit = math.min(
      _viewport.width / _worldBounds.width,
      _viewport.height / _worldBounds.height,
    );
    return fit.clamp(effectiveMinZoom, maxZoom).toDouble();
  }

  /// Zoom at which the map completely fills the viewport in both directions.
  double get fillZoom {
    if (_viewport.isEmpty) return _zoom;
    final fill = math.max(
      _viewport.width / _worldBounds.width,
      _viewport.height / _worldBounds.height,
    );
    return fill.clamp(effectiveMinZoom, maxZoom).toDouble();
  }
}
