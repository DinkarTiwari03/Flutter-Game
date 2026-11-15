import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:city_builder_2040/core/constants/game_constants.dart';
import 'package:city_builder_2040/game/components/building_painter.dart';
import 'package:city_builder_2040/game/components/iso_map_painter.dart';
import 'package:city_builder_2040/game/components/iso_map_renderer.dart';
import 'package:city_builder_2040/game/components/map_overlay_painter.dart';
import 'package:city_builder_2040/game/engine/map_camera.dart';
import 'package:city_builder_2040/game/engine/map_camera_controller.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';

/// Interactive view of the isometric map.
///
/// Input handling is done with raw pointer events rather than gesture
/// recognizers, so touch, mouse and trackpad all behave consistently:
///
/// - One finger or the left mouse button drags the map. A press that moves
///   less than a small slop is a tap and selects a tile; once it moves farther
///   it becomes a drag and can never select (no accidental selection).
/// - Right and middle mouse buttons always drag.
/// - Two fingers pinch-zoom and pan together around their midpoint.
/// - The mouse wheel zooms around the cursor; trackpad pan/zoom is supported.
/// - Lifting a touch drag with speed flings the map with inertia.
class MapViewport extends ConsumerStatefulWidget {
  const MapViewport({
    super.key,
    required this.map,
    required this.controller,
    this.focusNode,
  });

  final GameMap map;
  final MapCameraController controller;

  /// Focused when the map is pressed, so keyboard shortcuts keep working.
  final FocusNode? focusNode;

  @override
  ConsumerState<MapViewport> createState() => _MapViewportState();
}

class _MapViewportState extends ConsumerState<MapViewport>
    with SingleTickerProviderStateMixin {
  late IsoMapRenderer _renderer;
  late final AnimationController _pop;
  final _selected = ValueNotifier<GridPoint?>(null);
  final _hovered = ValueNotifier<GridPoint?>(null);
  final _cursor = ValueNotifier<MouseCursor>(MouseCursor.defer);

  // Active pointers by id, in the order they went down.
  final Map<int, Offset> _pointers = {};

  // Single-pointer state.
  int? _tapPointer;
  Offset _tapStart = Offset.zero;
  bool _tapCandidate = false;
  bool _dragging = false;
  bool _hadMultiTouch = false;
  VelocityTracker _velocity = VelocityTracker.withKind(PointerDeviceKind.touch);

  // Pinch state.
  Offset _pinchFocal = Offset.zero;
  double _pinchDistance = 0;

  // Trackpad pan/zoom state.
  Offset _trackpadPan = Offset.zero;
  double _trackpadScale = 1;

  MapCamera get _camera => widget.controller.camera;

  @override
  void initState() {
    super.initState();
    _renderer = IsoMapRenderer(widget.map);
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
    _selected.value = ref.read(selectedTileProvider);
  }

  @override
  void didUpdateWidget(MapViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.map != widget.map) {
      _renderer.dispose();
      _renderer = IsoMapRenderer(widget.map);
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    _pop.dispose();
    _selected.dispose();
    _hovered.dispose();
    _cursor.dispose();
    super.dispose();
  }

  // --- helpers --------------------------------------------------------

  GridPoint _tileAt(Offset local) =>
      IsoProjection.worldToGrid(_camera.screenToWorld(local));

  void _beginDrag(PointerDeviceKind kind) {
    _dragging = true;
    _tapCandidate = false;
    _hovered.value = null;
    if (kind == PointerDeviceKind.mouse) {
      _cursor.value = SystemMouseCursors.grabbing;
    }
  }

  void _resetGesture() {
    _tapPointer = null;
    _tapCandidate = false;
    _dragging = false;
    _hadMultiTouch = false;
    _cursor.value = MouseCursor.defer;
  }

  void _resetPinchBaseline() {
    final points = _pointers.values.take(2).toList();
    _pinchFocal = (points[0] + points[1]) / 2;
    _pinchDistance = (points[0] - points[1]).distance;
  }

  void _handleTap(Offset local) {
    final tile = _tileAt(local);
    final placement = ref.read(placementProvider);
    if (placement.isPlacing) {
      if (placement.previewOrigin == tile &&
          (placement.validation?.isValid ?? false)) {
        ref.read(placementProvider.notifier).confirmPlacement();
      } else {
        ref.read(placementProvider.notifier).updatePreview(tile);
      }
      return;
    }

    final occupied = ref.read(buildingOccupancyProvider);
    final building = occupied[tile];
    if (building != null) {
      ref.read(selectedBuildingIdProvider.notifier).select(building.id);
      ref.read(selectedTileProvider.notifier).clear();
      return;
    } else {
      ref.read(selectedBuildingIdProvider.notifier).clear();
    }

    final notifier = ref.read(selectedTileProvider.notifier);
    if (widget.map.contains(tile)) {
      if (ref.read(selectedTileProvider) != tile) notifier.select(tile);
    } else {
      notifier.clear();
    }
  }

  // --- pointer events -------------------------------------------------

  void _onPointerDown(PointerDownEvent event) {
    widget.focusNode?.requestFocus();
    widget.controller.stop();
    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length == 1) {
      _tapPointer = event.pointer;
      _tapStart = event.localPosition;
      _hadMultiTouch = false;
      _dragging = false;
      final primary =
          event.kind != PointerDeviceKind.mouse ||
          event.buttons == kPrimaryButton;
      _tapCandidate = primary;
      _velocity = VelocityTracker.withKind(event.kind)
        ..addPosition(event.timeStamp, event.localPosition);
      if (!primary) _beginDrag(event.kind);
    } else {
      _hadMultiTouch = true;
      _beginDrag(event.kind);
      _resetPinchBaseline();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length >= 2) {
      _updatePinch();
      return;
    }

    if (!_dragging) {
      final slop =
          event.kind == PointerDeviceKind.mouse
              ? GameConstants.mouseTapSlop
              : GameConstants.touchTapSlop;
      if ((event.localPosition - _tapStart).distance <= slop) {
        final placement = ref.read(placementProvider);
        if (placement.isPlacing) {
          final tile = _tileAt(event.localPosition);
          if (widget.map.contains(tile)) {
            ref.read(placementProvider.notifier).updatePreview(tile);
          }
        }
        return;
      }
      _beginDrag(event.kind);
    }
    _camera.panByScreen(event.localDelta);
    _velocity.addPosition(event.timeStamp, event.localPosition);
  }

  void _updatePinch() {
    final points = _pointers.values.take(2).toList();
    final focal = (points[0] + points[1]) / 2;
    final distance = (points[0] - points[1]).distance;
    if (_pinchDistance > 0 && distance > 0) {
      _camera.anchorAt(
        worldPoint: _camera.screenToWorld(_pinchFocal),
        screenPoint: focal,
        zoom: _camera.zoom * distance / _pinchDistance,
      );
    }
    _pinchFocal = focal;
    _pinchDistance = distance;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointers.remove(event.pointer) == null) return;

    if (_pointers.isEmpty) {
      final isTap =
          _tapCandidate &&
          !_dragging &&
          !_hadMultiTouch &&
          event.pointer == _tapPointer;
      if (isTap) {
        _handleTap(event.localPosition);
      } else if (_dragging &&
          !_hadMultiTouch &&
          event.kind != PointerDeviceKind.mouse) {
        _velocity.addPosition(event.timeStamp, event.localPosition);
        widget.controller.fling(_velocity.getVelocity().pixelsPerSecond);
      }
      _resetGesture();
    } else if (_pointers.length == 1) {
      // One finger left after a pinch: keep dragging, never select.
      _beginDrag(event.kind);
    } else {
      _resetPinchBaseline();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.isEmpty) _resetGesture();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      widget.controller.zoomBy(
        wheelZoomFactor(scroll.scrollDelta.dy),
        screenPoint: scroll.localPosition,
      );
    });
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    widget.focusNode?.requestFocus();
    widget.controller.stop();
    _trackpadPan = Offset.zero;
    _trackpadScale = 1;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final panDelta = event.pan - _trackpadPan;
    final factor = event.scale / _trackpadScale;
    _trackpadPan = event.pan;
    _trackpadScale = event.scale;
    _camera.panByScreen(panDelta);
    if (factor != 1) _camera.zoomAt(event.localPosition, _camera.zoom * factor);
  }

  void _onHover(PointerHoverEvent event) {
    if (_pointers.isNotEmpty) return;
    final tile = _tileAt(event.localPosition);
    final isInside = widget.map.contains(tile);
    _hovered.value = isInside ? tile : null;

    final placement = ref.read(placementProvider);
    if (placement.isPlacing && isInside) {
      ref.read(placementProvider.notifier).updatePreview(tile);
    }
  }

  void _onExit(PointerExitEvent event) => _hovered.value = null;

  // --- build ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.listen<GridPoint?>(selectedTileProvider, (previous, next) {
      _selected.value = next;
      if (next != null) _pop.forward(from: 0);
    });
    final showGrid = ref.watch(showGridProvider);
    final buildings = ref.watch(cityBuildingsProvider).value ?? const [];
    final placement = ref.watch(placementProvider);
    final selectedBuildingId = ref.watch(selectedBuildingIdProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        _camera.setViewport(constraints.biggest, notify: false);

        final layers = Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: IsoMapPainter(renderer: _renderer, camera: _camera),
              ),
            ),
            RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: BuildingPainter(
                  camera: _camera,
                  buildings: buildings,
                  placement: placement,
                  selectedBuildingId: selectedBuildingId,
                ),
              ),
            ),
            RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: MapOverlayPainter(
                  renderer: _renderer,
                  camera: _camera,
                  selected: _selected,
                  hovered: _hovered,
                  pop: _pop,
                  showGrid: showGrid,
                ),
              ),
            ),
          ],
        );

        return Semantics(
          label:
              'City map. Drag to move, pinch or scroll to zoom, '
              'tap a tile to inspect it.',
          child: ValueListenableBuilder<MouseCursor>(
            valueListenable: _cursor,
            child: layers,
            builder:
                (context, cursor, child) => MouseRegion(
                  cursor: cursor,
                  onHover: _onHover,
                  onExit: _onExit,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerCancel,
                    onPointerSignal: _onPointerSignal,
                    onPointerPanZoomStart: _onPanZoomStart,
                    onPointerPanZoomUpdate: _onPanZoomUpdate,
                    child: child,
                  ),
                ),
          ),
        );
      },
    );
  }
}
