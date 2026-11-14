import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/core/constants/app_routes.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/error_handler.dart';
import 'package:city_builder_2040/providers/bootstrap_provider.dart';
import 'package:city_builder_2040/widgets/app_error_view.dart';
import 'package:city_builder_2040/widgets/city_backdrop.dart';
import 'package:city_builder_2040/widgets/city_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _minDisplayTimer;
  bool _minTimeElapsed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.slowAnimation,
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _minDisplayTimer = Timer(AppConstants.splashMinDuration, () {
      _minTimeElapsed = true;
      _tryContinue();
    });
  }

  @override
  void dispose() {
    _minDisplayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _tryContinue() {
    if (!mounted || _navigated || !_minTimeElapsed) return;
    if (ref.read(bootstrapProvider).hasValue) {
      _navigated = true;
      Navigator.of(context).pushReplacementNamed(AppRoutes.menu);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boot = ref.watch(bootstrapProvider);
    ref.listen<AsyncValue<void>>(
      bootstrapProvider,
      (previous, next) => _tryContinue(),
    );
    final failed = boot.hasError && !boot.isLoading;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CityBackdrop(
        child: SafeArea(
          child: Center(
            child: failed
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: AppErrorView(
                      message: ErrorHandler.messageFor(
                        boot.error ?? 'Unknown error',
                      ),
                      onRetry: () => ref.invalidate(bootstrapProvider),
                    ),
                  )
                : FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CityLogo(size: 96),
                          const SizedBox(height: AppSpacing.lg),
                          const GameTitle(),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            AppConstants.tagline,
                            style: textTheme.bodyLarge?.copyWith(
                              color: AppColors.textOnDark,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SizedBox(
                            width: 120,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: const LinearProgressIndicator(
                                minHeight: 4,
                                color: AppColors.aqua,
                                backgroundColor: AppColors.onDarkTrack,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
