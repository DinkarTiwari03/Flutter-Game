import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';

import 'package:city_builder_2040/core/constants/game_constants.dart';

/// 2D camera over world space.
///
/// The camera is defined by [focus] (the world point shown at the center of
/// the viewport) and [zoom] (screen pixels per world unit). Everything here is
/// plain maths with no widgets or tickers, so it is easy to unit test.
/// Listeners (painters) are notified whenever the view changes.
///
/// Conversions:
///     screen = (world - focus) * zoom + viewportCenter
///     world  = (screen - viewportCenter) / zoom + focus
class MapCamera extends ChangeNotifier {
  MapCamera({
    required Rect worldBounds,
    this.minZoom = GameConstants.minZoom,
    this.maxZoom = GameConstants.maxZoom,
    this.boundaryMargin = GameConstants.boundaryMargin,
    double zoom = GameConstants.initialZoom,
    Offset? focus,
  }) : _worldBounds = worldBounds,
       _zoom = zoom.clamp(minZoom, maxZoom).toDouble(),
       _focus = focus ?? worldBounds.center {
    _clampFocus();
  }

  final double minZoom;
  final double maxZoom;

  /// Extra world space allowed around the map edges, so the map can be
  /// scrolled slightly past its borders.
  final double boundaryMargin;

  Rect _worldBounds;
  Size _viewport = Size.zero;
  double _zoom;
  Offset _focus;

  Rect get worldBounds => _worldBounds;
  Size get viewport => _viewport;
  double get zoom => _zoom;
  Offset get focus => _focus;

  Offset get viewportCenter =>
      Offset(_viewport.width / 2, _viewport.height / 2);

  /// The part of world space currently visible.
  Rect get visibleWorldRect {
    final halfW = _viewport.width / 2 / _zoom;
    final halfH = _viewport.height / 2 / _zoom;
    return Rect.fromLTRB(
      _focus.dx - halfW,
      _focus.dy - halfH,
      _focus.dx + halfW,
      _focus.dy + halfH,
    );
  }

  Offset screenToWorld(Offset screen) =>
      (screen - viewportCenter) / _zoom + _focus;

  Offset worldToScreen(Offset world) =>
      (world - _focus) * _zoom + viewportCenter;

  /// Updates the viewport size (call on layout). Keeps the focus valid.
  ///
  /// Pass `notify: false` when calling during a build; the resized render
  /// objects repaint on their own.
  void setViewport(Size size, {bool notify = true}) {
    if (size == _viewport) return;
    _viewport = size;
    _clampFocus();
    if (notify) notifyListeners();
  }

  void setWorldBounds(Rect bounds) {
    if (bounds == _worldBounds) return;
    _worldBounds = bounds;
    _clampFocus();
    notifyListeners();
  }

  /// Moves the view by [screenDelta] pixels, as if dragging the map. Dragging
  /// right moves the map right, so the focus moves left.
  void panByScreen(Offset screenDelta) {
    _setView(focus: _focus - screenDelta / _zoom, zoom: _zoom);
  }

  /// Moves the focus by [worldDelta] world units.
  void panByWorld(Offset worldDelta) {
    _setView(focus: _focus + worldDelta, zoom: _zoom);
  }

  void jumpTo({Offset? focus, double? zoom}) {
    _setView(focus: focus ?? _focus, zoom: zoom ?? _zoom);
  }

  /// Sets the zoom so that [worldPoint] stays under [screenPoint]. Pass the
  /// same point for plain zooming around a cursor or finger, or a different
  /// one to combine zoom and pan (pinch gestures).
  void anchorAt({
    required Offset worldPoint,
    required Offset screenPoint,
    required double zoom,
  }) {
    final newZoom = zoom.clamp(minZoom, maxZoom).toDouble();
    final newFocus = worldPoint - (screenPoint - viewportCenter) / newZoom;
    _setView(focus: newFocus, zoom: newZoom);
  }

  /// Zooms to [newZoom] keeping the world point under [screenPoint] fixed.
  void zoomAt(Offset screenPoint, double newZoom) {
    anchorAt(
      worldPoint: screenToWorld(screenPoint),
      screenPoint: screenPoint,
      zoom: newZoom,
    );
  }

  /// Clamps a focus point so the viewport stays within the map bounds (plus
  /// margin) at the given [zoom]. When the whole map fits on an axis, that
  /// axis is centered instead.
  Offset clampFocus(Offset focus, double zoom) {
    final bounds = _worldBounds.inflate(boundaryMargin);
    final halfW = _viewport.width / 2 / zoom;
    final halfH = _viewport.height / 2 / zoom;
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

  void _setView({required Offset focus, required double zoom}) {
    final clampedZoom = zoom.clamp(minZoom, maxZoom).toDouble();
    final clampedFocus = clampFocus(focus, clampedZoom);
    if (clampedZoom == _zoom && clampedFocus == _focus) return;
    _zoom = clampedZoom;
    _focus = clampedFocus;
    notifyListeners();
  }

  /// Zoom at which the whole map just fits the viewport.
  double get fitZoom {
    if (_viewport.isEmpty) return _zoom;
    final fit = math.min(
      _viewport.width / _worldBounds.width,
      _viewport.height / _worldBounds.height,
    );
    return fit.clamp(minZoom, maxZoom).toDouble();
  }
}
