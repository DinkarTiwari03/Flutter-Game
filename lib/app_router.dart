import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/core/constants/app_routes.dart';
import 'package:city_builder_2040/screens/game_screen.dart';
import 'package:city_builder_2040/screens/main_menu_screen.dart';
import 'package:city_builder_2040/screens/new_game_screen.dart';
import 'package:city_builder_2040/screens/settings_screen.dart';
import 'package:city_builder_2040/screens/splash_screen.dart';
import 'package:city_builder_2040/widgets/app_error_view.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      AppRoutes.splash => const SplashScreen(),
      AppRoutes.menu => const MainMenuScreen(),
      AppRoutes.newGame => const NewGameScreen(),
      AppRoutes.game => const GameScreen(),
      AppRoutes.settings => const SettingsScreen(),
      _ => Scaffold(
        body: Center(
          child: AppErrorView(
            title: 'Page not found',
            message: 'No screen exists for "${settings.name}".',
          ),
        ),
      ),
    };

    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: AppConstants.mediumAnimation,
      reverseTransitionDuration: AppConstants.mediumAnimation,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }
}
