import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/core/constants/app_routes.dart';

import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/core/utils/error_handler.dart';
import 'package:city_builder_2040/game/map/map_config.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/repository_providers.dart';
import 'package:city_builder_2040/providers/settings_provider.dart';
import 'package:city_builder_2040/providers/tutorial_provider.dart';
import 'package:city_builder_2040/widgets/game_button.dart';
import 'package:city_builder_2040/widgets/game_card.dart';
import 'package:city_builder_2040/widgets/game_scaffold.dart';
import 'package:city_builder_2040/widgets/map_size_selector.dart';

class NewGameScreen extends ConsumerStatefulWidget {
  const NewGameScreen({super.key});

  @override
  ConsumerState<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends ConsumerState<NewGameScreen> {
  static const _defaultName = 'New Harbor';

  final _nameController = TextEditingController(text: _defaultName);
  MapSizePreset _size = MapSizePreset.medium;
  String? _error;
  bool _starting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final city = await ref
          .read(cityServiceProvider)
          .createCity(
            name: _nameController.text,
            mapWidth: _size.size,
            mapHeight: _size.size,
          );
      if (!mounted) return;
      ref.read(activeCityProvider.notifier).open(city);
      final settings = ref.read(settingsValueProvider);
      if (!settings.tutorialCompleted) {
        ref.read(tutorialProvider.notifier).start();
      }
      await Navigator.of(context).pushReplacementNamed(AppRoutes.game);
    } on ValidationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (error, stack) {
      ErrorHandler.report(error, stack, source: 'new-game');
      if (mounted) setState(() => _error = ErrorHandler.messageFor(error));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GameScaffold(
      title: 'New Game',
      subtitle: 'Found your city',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GameCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('City name', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  key: const ValueKey('city-name-field'),
                  controller: _nameController,
                  maxLength: AppConstants.maxCityNameLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _start(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    errorText: _error,
                    prefixIcon: const Icon(Icons.location_city_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Map size', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                MapSizeSelector(
                  selected: _size,
                  onChanged: (value) => setState(() => _size = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Larger maps give more room to grow but are heavier to '
                  'draw.',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GameButton(
            label: _starting ? 'Creating...' : 'Start city',
            icon: Icons.rocket_launch_rounded,
            onPressed: _starting ? null : _start,
          ),
          const SizedBox(height: AppSpacing.sm),
          GameButton(
            label: 'Back to menu',
            icon: Icons.arrow_back_rounded,
            variant: GameButtonVariant.secondary,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
