import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/constants/app_routes.dart';
import 'package:city_builder_2040/core/constants/game_constants.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/responsive.dart';
import 'package:city_builder_2040/game/engine/map_camera.dart';
import 'package:city_builder_2040/game/engine/map_camera_controller.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';
import 'package:city_builder_2040/models/city_event.dart';
import 'package:city_builder_2040/providers/economy_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/providers/simulation_providers.dart';
import 'package:city_builder_2040/screens/game/desktop_game_layout.dart';
import 'package:city_builder_2040/screens/game/game_shortcuts.dart';
import 'package:city_builder_2040/screens/game/phone_game_layout.dart';
import 'package:city_builder_2040/widgets/app_error_view.dart';
import 'package:city_builder_2040/widgets/game_button.dart';

/// The city gameplay screen.
///
/// Owns the camera and keyboard focus, and picks a layout for the available
/// size. All layouts share the same map viewport, camera and providers; only
/// the arrangement of surrounding UI differs.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  final _focusNode = FocusNode(debugLabel: 'game-screen');
  final _viewportKey = GlobalKey();

  GameMap? _map;
  MapCamera? _camera;
  MapCameraController? _controller;

  /// The camera driving the map view. Exposed so tests can inspect it.
  @visibleForTesting
  MapCamera? get camera => _camera;

  @override
  void initState() {
    super.initState();
    // The map belongs to the city that was open when the screen was created.
    final map = ref.read(gameMapProvider);
    if (map == null) return;
    _map = map;
    _camera = MapCamera(
      worldBounds: IsoProjection.mapBounds(map.cols, map.rows),
      zoom: GameConstants.initialZoom,
    );
    _controller = MapCameraController(vsync: this, camera: _camera!);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _camera?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep simulation ticker active while GameScreen is mounted
    ref.watch(simulationTickerProvider);

    ref.listen<CityEvent?>(lastTriggeredEventProvider, (prev, next) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.celebration_rounded, color: AppColors.sunrise),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Civic Event: ${next.title}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(next.description),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.navy,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final map = _map;
    final controller = _controller;
    if (map == null || controller == null) return const _NoCityView();

    return GameShortcuts(
      controller: controller,
      focusNode: _focusNode,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return switch (GameLayoutKind.of(constraints.biggest)) {
            GameLayoutKind.desktop => DesktopGameLayout(
              map: map,
              controller: controller,
              focusNode: _focusNode,
              viewportKey: _viewportKey,
            ),
            GameLayoutKind.phoneLandscape => PhoneGameLayout(
              map: map,
              controller: controller,
              focusNode: _focusNode,
              viewportKey: _viewportKey,
              landscape: true,
            ),
            GameLayoutKind.phone => PhoneGameLayout(
              map: map,
              controller: controller,
              focusNode: _focusNode,
              viewportKey: _viewportKey,
            ),
          };
        },
      ),
    );
  }
}

/// Shown if the game screen is reached without a city (for example through
/// a stale route).
class _NoCityView extends StatelessWidget {
  const _NoCityView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppErrorView(
              title: 'No city loaded',
              message: 'Start a new game from the main menu.',
            ),
            const SizedBox(height: 16),
            GameButton(
              label: 'Main menu',
              expand: false,
              variant: GameButtonVariant.secondary,
              onPressed:
                  () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRoutes.menu, (route) => false),
            ),
          ],
        ),
      ),
    );
  }
}
