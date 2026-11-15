import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

import 'package:city_builder_2040/core/constants/game_constants.dart';
import 'package:city_builder_2040/game/engine/map_camera.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';

/// Drives a [MapCamera] with smooth animations.
///
/// Owns the animation controllers so input widgets, toolbars and keyboard
/// shortcuts all share one set of camera commands. Direct manipulation
/// (dragging, pinching) goes straight to [camera]; everything else animates.
class MapCameraController {
  MapCameraController({required TickerProvider vsync, required this.camera})
    : _transition = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 280),
      ),
      _fling = AnimationController.unbounded(vsync: vsync) {
    _transition.addListener(_onTransitionTick);
    _fling.addListener(_onFlingTick);
  }

  final MapCamera camera;
  final AnimationController _transition;
  final AnimationController _fling;

  // Transition state: interpolates focus and zoom, optionally anchored so a
  // chosen screen point stays put while zooming.
  Offset _fromFocus = Offset.zero;
  Offset _toFocus = Offset.zero;
  double _fromZoom = 1;
  double _toZoom = 1;
  Offset? _anchorScreen;
  Offset? _anchorWorld;

  // Fling state.
  Offset _flingDirection = Offset.zero;
  double _flingLast = 0;

  bool get isAnimating => _transition.isAnimating || _fling.isAnimating;

  /// Target zoom of the running (or last) animation, for compounding steps.
  double get targetZoom => _transition.isAnimating ? _toZoom : camera.zoom;

  Offset get _targetFocus => _transition.isAnimating ? _toFocus : camera.focus;

  /// Stops any running animation. Call when the user takes over.
  void stop() {
    _transition.stop();
    _fling.stop();
  }

  // --- commands -------------------------------------------------------

  void zoomIn() => zoomBy(GameConstants.zoomStep);

  void zoomOut() => zoomBy(1 / GameConstants.zoomStep);

  /// Multiplies the zoom by [factor] around [screenPoint] (viewport center
  /// by default), animated. Repeated calls compound smoothly.
  void zoomBy(double factor, {Offset? screenPoint}) {
    final anchor = screenPoint ?? camera.viewportCenter;
    _animate(zoom: targetZoom * factor, anchorScreen: anchor);
  }

  /// Pans by [screenDelta] pixels (positive moves the view right/down),
  /// animated. Repeated calls compound smoothly, e.g. from key repeat.
  void panBy(Offset screenDelta) {
    final zoom = _transition.isAnimating ? _toZoom : camera.zoom;
    _animate(focus: _targetFocus + screenDelta / zoom);
  }

  void focusOn(GridPoint tile, {double? zoom}) {
    _animate(
      focus: IsoProjection.tileCenter(tile.col, tile.row),
      zoom: zoom,
      duration: const Duration(milliseconds: 420),
    );
  }

  void focusOnWorld(Offset world, {double? zoom}) {
    _animate(
      focus: world,
      zoom: zoom,
      duration: const Duration(milliseconds: 420),
    );
  }

  /// Frames the whole map.
  void showWholeMap() {
    _animate(
      focus: camera.worldBounds.center,
      zoom: camera.fitZoom,
      duration: const Duration(milliseconds: 420),
    );
  }

  /// Continues a drag with inertia. [velocity] is in screen pixels/second.
  void fling(Offset velocity) {
    final speed = velocity.distance;
    if (speed < GameConstants.minFlingSpeed) return;
    _transition.stop();
    _flingDirection = velocity / speed;
    _flingLast = 0;
    final simulation = FrictionSimulation(0.135, 0, speed);
    _fling.animateWith(simulation);
  }

  void dispose() {
    _transition.dispose();
    _fling.dispose();
  }

  // --- internals ------------------------------------------------------

  void _animate({
    Offset? focus,
    double? zoom,
    Offset? anchorScreen,
    Duration duration = const Duration(milliseconds: 220),
  }) {
    _fling.stop();
    _fromFocus = camera.focus;
    _fromZoom = camera.zoom;
    _toFocus = focus ?? _targetFocus;
    _toZoom =
        (zoom ?? targetZoom).clamp(camera.minZoom, camera.maxZoom).toDouble();
    _anchorScreen = anchorScreen;
    _anchorWorld =
        anchorScreen == null ? null : camera.screenToWorld(anchorScreen);
    _transition
      ..duration = duration
      ..forward(from: 0);
  }

  void _onTransitionTick() {
    final t = Curves.easeOutCubic.transform(_transition.value);
    final zoom = _fromZoom + (_toZoom - _fromZoom) * t;
    final anchorScreen = _anchorScreen;
    final anchorWorld = _anchorWorld;
    if (anchorScreen != null && anchorWorld != null) {
      camera.anchorAt(
        worldPoint: anchorWorld,
        screenPoint: anchorScreen,
        zoom: zoom,
      );
    } else {
      camera.jumpTo(focus: Offset.lerp(_fromFocus, _toFocus, t), zoom: zoom);
    }
  }

  void _onFlingTick() {
    final distance = _fling.value;
    final delta = distance - _flingLast;
    _flingLast = distance;
    final before = camera.focus;
    camera.panByScreen(_flingDirection * delta);
    // Stop early when the camera hits a boundary and can no longer move.
    if (delta.abs() > 1 && (camera.focus - before).distance < 0.01) {
      _fling.stop();
    }
  }
}

/// Helper for zoom factors from continuous input such as a mouse wheel.
double wheelZoomFactor(double scrollDy) {
  return math.exp(-scrollDy * GameConstants.wheelZoomSensitivity);
}
