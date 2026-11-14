import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/providers/settings_provider.dart';
import 'package:city_builder_2040/widgets/game_card.dart';
import 'package:city_builder_2040/widgets/game_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return GameScaffold(
      title: 'Settings',
      subtitle: 'Tune your experience',
      child: Column(
        children: [
          GameCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sound effects'),
                  value: settings.soundEnabled,
                  onChanged: notifier.setSoundEnabled,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Music'),
                  value: settings.musicEnabled,
                  onChanged: notifier.setMusicEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Preferences are kept in memory for now and will be saved in a '
            'later phase.',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
