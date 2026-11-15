import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/constants/game_constants.dart';
import 'package:city_builder_2040/game/engine/map_camera_controller.dart';
import 'package:city_builder_2040/models/game_section.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';

class PanViewIntent extends Intent {
  const PanViewIntent(this.direction);

  /// Unit direction in screen space; (1, 0) moves the view to the right.
  final Offset direction;
}

class ZoomViewIntent extends Intent {
  const ZoomViewIntent({required this.zoomIn});

  final bool zoomIn;
}

class ShowWholeMapIntent extends Intent {
  const ShowWholeMapIntent();
}

class ClearSelectionIntent extends Intent {
  const ClearSelectionIntent();
}

class ToggleGridIntent extends Intent {
  const ToggleGridIntent();
}

class TogglePauseIntent extends Intent {
  const TogglePauseIntent();
}

class OpenSectionIntent extends Intent {
  const OpenSectionIntent(this.section);

  final GameSection section;
}

/// Keyboard shortcuts for the game screen, wired to the camera controller and
/// game state. Also owns keyboard focus for the screen: [focusNode] is
/// autofocused, and tapping the map hands focus back to it.
class GameShortcuts extends ConsumerWidget {
  const GameShortcuts({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.child,
  });

  final MapCameraController controller;
  final FocusNode focusNode;
  final Widget child;

  static final Map<ShortcutActivator, Intent> _bindings = {
    for (final key in [LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA])
      SingleActivator(key): const PanViewIntent(Offset(-1, 0)),
    for (final key in [LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD])
      SingleActivator(key): const PanViewIntent(Offset(1, 0)),
    for (final key in [LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW])
      SingleActivator(key): const PanViewIntent(Offset(0, -1)),
    for (final key in [LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS])
      SingleActivator(key): const PanViewIntent(Offset(0, 1)),
    for (final key in [
      LogicalKeyboardKey.equal,
      LogicalKeyboardKey.add,
      LogicalKeyboardKey.numpadAdd,
    ])
      SingleActivator(key): const ZoomViewIntent(zoomIn: true),
    for (final key in [
      LogicalKeyboardKey.minus,
      LogicalKeyboardKey.numpadSubtract,
    ])
      SingleActivator(key): const ZoomViewIntent(zoomIn: false),
    const SingleActivator(LogicalKeyboardKey.home): const ShowWholeMapIntent(),
    const SingleActivator(LogicalKeyboardKey.keyG): const ToggleGridIntent(),
    const SingleActivator(LogicalKeyboardKey.space): const TogglePauseIntent(),
    const SingleActivator(LogicalKeyboardKey.escape):
        const ClearSelectionIntent(),
    for (final section in GameSection.values)
      SingleActivator(_digitKeys[section.index]): OpenSectionIntent(section),
  };

  static final _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: _bindings,
      child: Actions(
        actions: <Type, Action<Intent>>{
          PanViewIntent: CallbackAction<PanViewIntent>(
            onInvoke: (intent) {
              controller.panBy(
                intent.direction * GameConstants.keyboardPanStep,
              );
              return null;
            },
          ),
          ZoomViewIntent: CallbackAction<ZoomViewIntent>(
            onInvoke: (intent) {
              if (intent.zoomIn) {
                controller.zoomIn();
              } else {
                controller.zoomOut();
              }
              return null;
            },
          ),
          ShowWholeMapIntent: CallbackAction<ShowWholeMapIntent>(
            onInvoke: (_) {
              controller.showWholeMap();
              return null;
            },
          ),
          ToggleGridIntent: CallbackAction<ToggleGridIntent>(
            onInvoke: (_) {
              ref.read(showGridProvider.notifier).toggle();
              return null;
            },
          ),
          TogglePauseIntent: CallbackAction<TogglePauseIntent>(
            onInvoke: (_) {
              ref.read(simulationSpeedProvider.notifier).togglePause();
              return null;
            },
          ),
          ClearSelectionIntent: CallbackAction<ClearSelectionIntent>(
            onInvoke: (_) {
              if (ref.read(placementProvider).isPlacing) {
                ref.read(placementProvider.notifier).cancelPlacement();
              } else if (ref.read(selectedBuildingIdProvider) != null) {
                ref.read(selectedBuildingIdProvider.notifier).clear();
              } else if (ref.read(selectedTileProvider) != null) {
                ref.read(selectedTileProvider.notifier).clear();
              } else {
                ref.read(activeSectionProvider.notifier).close();
              }
              return null;
            },
          ),
          OpenSectionIntent: CallbackAction<OpenSectionIntent>(
            onInvoke: (intent) {
              ref.read(activeSectionProvider.notifier).open(intent.section);
              return null;
            },
          ),
        },
        child: Focus(focusNode: focusNode, autofocus: true, child: child),
      ),
    );
  }
}
