import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/repository_providers.dart';
import 'package:city_builder_2040/providers/settings_provider.dart';
import 'package:city_builder_2040/services/exhibition_service.dart';
import 'package:city_builder_2040/widgets/game_card.dart';
import 'package:city_builder_2040/widgets/game_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsValueProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    final activeCity = ref.watch(activeCityProvider);

    return GameScaffold(
      title: 'Settings',
      subtitle: 'Tune your experience',
      child: SingleChildScrollView(
        child: Column(
          children: [
            // --- Exhibition Demo Controls (active only when demo city is open) ---
            if (activeCity?.id == ExhibitionService.demoCityId) ...[
              GameCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.teal,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Exhibition Demo Controls',
                          style: textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Reset this demonstration city back to its initial layout, Level 5 unlocks, and 25,000 coin treasury.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reset Demo City'),
                      onPressed: () async {
                        final exhibition = ref.read(exhibitionServiceProvider);
                        final resetCity = await exhibition.resetDemoCity();
                        ref.read(activeCityProvider.notifier).open(resetCity);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Exhibition demo city reset to default showcase layout!',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // --- Sound & Music ---
            GameCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.sm,
                      bottom: AppSpacing.xs,
                    ),
                    child: Text('Audio', style: textTheme.titleMedium),
                  ),
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
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Master volume')),
                        Expanded(
                          flex: 2,
                          child: Slider(
                            value: settings.masterVolume,
                            onChanged: notifier.setMasterVolume,
                            divisions: 10,
                            label: '${(settings.masterVolume * 100).round()}%',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // --- Display ---
            GameCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.sm,
                      bottom: AppSpacing.xs,
                    ),
                    child: Text('Display', style: textTheme.titleMedium),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show grid'),
                    subtitle: const Text('Overlay grid lines on the map'),
                    value: settings.showGrid,
                    onChanged: notifier.setShowGrid,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // --- Tutorial ---
            GameCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tutorial', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          settings.tutorialCompleted
                              ? 'Tutorial completed.'
                              : 'Tutorial not yet completed.',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await notifier.resetTutorial();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tutorial reset. It will show on next new city.'),
                              ),
                            );
                          }
                        },
                        child: const Text('Reset tutorial'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // --- Danger zone ---
            GameCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reset',
                    style: textTheme.titleMedium?.copyWith(color: AppColors.coral),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Reset all settings to their defaults.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Reset settings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.coral,
                      side: const BorderSide(color: AppColors.coral),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Reset settings?'),
                          content: const Text(
                            'All preferences will be reset to defaults. '
                            'Your cities and progress are not affected.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Reset'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await notifier.resetAll();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settings reset to defaults.')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
