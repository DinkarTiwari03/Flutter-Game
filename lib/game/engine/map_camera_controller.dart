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

  // Transition state: interpolates focus, zoom, and rotation, optionally anchored so a
  // chosen screen point stays put while zooming and rotating.
  Offset _fromFocus = Offset.zero;
  Offset _toFocus = Offset.zero;
  double _fromZoom = 1;
  double _toZoom = 1;
  double _fromRotation = 0;
  double _toRotation = 0;
  Offset? _anchorScreen;
  Offset? _anchorWorld;

  // Fling state.
  Offset _flingDirection = Offset.zero;
  double _flingLast = 0;

  bool get isAnimating => _transition.isAnimating || _fling.isAnimating;

  /// Target zoom of the running (or last) animation, for compounding steps.
  double get targetZoom => _transition.isAnimating ? _toZoom : camera.zoom;

  /// Target rotation in radians of running animation.
  double get targetRotation =>
      _transition.isAnimating ? _toRotation : camera.rotation;

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
    final rot = _transition.isAnimating ? _toRotation : camera.rotation;
    final delta = rot == 0
        ? screenDelta
        : MapCamera.rotateOffset(screenDelta, -rot);
    _animate(focus: _targetFocus + delta / zoom);
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

  /// Rotates the camera by [deltaRadians] around [screenPoint] (viewport center
  /// by default), animated.
  void rotateBy(
    double deltaRadians, {
    Offset? screenPoint,
    Duration duration = const Duration(milliseconds: 260),
  }) {
    final anchor = screenPoint ?? camera.viewportCenter;
    _animate(
      rotation: targetRotation + deltaRadians,
      anchorScreen: anchor,
      duration: duration,
    );
  }

  /// Rotates counterclockwise (45 degrees by default).
  void rotateLeft({double step = math.pi / 4}) => rotateBy(-step);

  /// Rotates clockwise (45 degrees by default).
  void rotateRight({double step = math.pi / 4}) => rotateBy(step);

  /// Smoothly animates camera rotation back to 0.0 (default orientation).
  void resetRotation() {
    _animate(
      rotation: 0.0,
      duration: const Duration(milliseconds: 280),
    );
  }

  /// Restores default map orientation (0 rotation) and frames the whole map.
  void resetCamera() {
    _animate(
      focus: camera.worldBounds.center,
      zoom: camera.fitZoom,
      rotation: 0.0,
      duration: const Duration(milliseconds: 420),
    );
  }

  /// Frames the whole map and resets orientation.
  void showWholeMap() => resetCamera();

  /// Zooms the camera to completely fill the viewport with terrain (no border margins).
  void fillViewport() {
    _animate(
      focus: camera.worldBounds.center,
      zoom: camera.fillZoom,
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
    double? rotation,
    Offset? anchorScreen,
    Duration duration = const Duration(milliseconds: 220),
  }) {
    _fling.stop();
    _fromFocus = camera.focus;
    _fromZoom = camera.zoom;
    _fromRotation = camera.rotation;
    _toFocus = focus ?? _targetFocus;
    _toZoom =
        (zoom ?? targetZoom).clamp(camera.effectiveMinZoom, camera.maxZoom).toDouble();

    // Use shortest angular path for smooth rotation interpolation
    final desiredRotation = rotation ?? targetRotation;
    var deltaRot = desiredRotation - _fromRotation;
    while (deltaRot > math.pi) deltaRot -= 2 * math.pi;
    while (deltaRot < -math.pi) deltaRot += 2 * math.pi;
    _toRotation = _fromRotation + deltaRot;

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
    final rotation = _fromRotation + (_toRotation - _fromRotation) * t;
    final anchorScreen = _anchorScreen;
    final anchorWorld = _anchorWorld;
    if (anchorScreen != null && anchorWorld != null) {
      camera.anchorAt(
        worldPoint: anchorWorld,
        screenPoint: anchorScreen,
        zoom: zoom,
        rotation: rotation,
      );
    } else {
      camera.jumpTo(
        focus: Offset.lerp(_fromFocus, _toFocus, t),
        zoom: zoom,
        rotation: rotation,
      );
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
