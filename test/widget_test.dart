import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/app.dart';
import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/providers/bootstrap_provider.dart';
import 'package:city_builder_2040/screens/main_menu_screen.dart';
import 'package:city_builder_2040/screens/new_game_screen.dart';
import 'package:city_builder_2040/screens/splash_screen.dart';

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [bootstrapProvider.overrideWith((ref) async {})],
      child: const CityBuilderApp(),
    ),
  );
}

void main() {
  testWidgets('splash transitions to the main menu', (tester) async {
    await pumpApp(tester);
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(AppConstants.splashMinDuration);
    await tester.pumpAndSettle();

    expect(find.byType(MainMenuScreen), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('Play opens the New Game placeholder', (tester) async {
    await pumpApp(tester);
    await tester.pump(AppConstants.splashMinDuration);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(find.byType(NewGameScreen), findsOneWidget);
  });
}
