# Phase 01 Handoff: Foundation and Architecture

## Project structure
```
lib/
  main.dart, app.dart, app_router.dart
  core/
    constants/  app_constants.dart, app_routes.dart
    theme/      app_colors.dart, app_spacing.dart, app_theme.dart
    utils/      responsive.dart, app_exception.dart, error_handler.dart, id_generator.dart
  models/       app_settings.dart, city.dart, building.dart, resource_ledger.dart,
                mission_progress.dart, player_progress.dart
  repositories/ city_, building_, resource_, mission_, player_progress_repository.dart (interfaces)
    memory/     memory_*_repository.dart (non-persistent implementations)
  providers/    storage_provider.dart, bootstrap_provider.dart, settings_provider.dart,
                repository_providers.dart
  services/     storage_service.dart, city_service.dart
  screens/      splash_screen.dart, main_menu_screen.dart, new_game_screen.dart, settings_screen.dart
  widgets/      game_button, game_card, game_scaffold, responsive_center,
                city_backdrop, city_logo (CityLogo + GameTitle), app_error_view, about_game_dialog
  game/
    components/ skyline_painter.dart
    engine/, map/, buildings/   (empty, .gitkeep)
assets/  images/, buildings/, icons/, sounds/   (empty, .gitkeep, declared in pubspec)
docs/    PROJECT_MASTER.md, HANDOFFS/PHASE_01.md
test/    widget_test.dart, core/breakpoints_test.dart,
         repositories/memory_repositories_test.dart, services/city_service_test.dart
```

## Packages and dependencies
| Package | Version | Purpose |
|---|---|---|
| flutter_riverpod | 3.3.2 | State management |
| hive | 2.2.3 | Local storage |
| hive_flutter | 1.1.0 | Hive Flutter init (pulls in path_provider) |
| cupertino_icons | 1.0.8 | From template |
| flutter_lints (dev) | 5.0.0 | From template |

## Architecture decisions
- **State:** Riverpod `Notifier` (settings) and `FutureProvider` (bootstrap). Retry is disabled on `bootstrapProvider` (`retry: (_, __) => null`) so failures surface immediately with a manual retry.
- **Startup:** `StorageService.init()` runs inside `bootstrapProvider` during splash. The splash waits for both a minimum display time and bootstrap success before navigating to the menu.
- **Navigation:** named routes via `AppRouter.onGenerateRoute` with fade transitions; unknown routes show an error page.
- **Errors:** `ErrorHandler.init()` installs `FlutterError.onError` and `PlatformDispatcher.onError`; typed `AppException`s; `AppErrorView` for UI.
- **Theme:** Material 3, deep blue and teal palette in `AppColors`, light dashboard backgrounds, rounded cards. Spacing and radii in `AppSpacing`/`AppRadius`.
- **Responsive:** `Breakpoints` (600 / 1024) and `context.responsive(...)`; `ResponsiveCenter` caps content width.
- **Graphics:** `SkylinePainter` (CustomPainter) behind splash and menu, wrapped in `RepaintBoundary`.
- **Typography:** system font, to avoid network or asset dependencies.

## Screens implemented
- **Splash:** animated logo and title, progress bar, error and retry state.
- **Main menu:** title, Play, Continue (disabled placeholder), Settings, About (dialog).
- **New Game:** placeholder card with a back button.
- **Settings:** placeholder with Sound and Music switches (in memory only).

## Commands executed
```
flutter --version
flutter create . --project-name city_builder_2040 --org com.citybuilder --platforms android,windows
flutter pub add flutter_riverpod hive hive_flutter
flutter pub get
flutter analyze
flutter test
flutter devices
flutter build windows --debug
flutter doctor -v
flutter build apk --debug
flutter install --debug -d 6b5e656f
```
Also edited: `AndroidManifest.xml` (label), `windows/runner/main.cpp` and `Runner.rc` (name), `android/app/build.gradle.kts` (`ndkVersion = "27.0.12077973"`), `android/gradle/wrapper/gradle-wrapper.properties` (restored to `gradle-8.10.2-all.zip`, see Known issues).

Attempted and interrupted by the user (no result): a rebuild after the wrapper revert (`flutter build apk --debug`) and `flutter run -d 6b5e656f --no-resident`.

## Test results
- `flutter pub get`: success.
- `flutter analyze`: **No issues found** (final run). An earlier run flagged an unnecessary `dart:ui` import, since fixed.
- `flutter test`: **3 tests passed** at the end of the original Phase 1 work (splash to menu, Play opens New Game, breakpoints). After the repository addendum: **24 tests passed** (3 original + 21 new: model JSON round trips, memory repositories, `CityService`). `flutter analyze` was also clean after the addendum.
- `flutter build apk --debug`: **success**. The NDK mismatch warning was fixed by pinning NDK 27.0.12077973.
- `flutter install --debug` on a physical phone (23021RAAEG, Android 15): **installed successfully** on the second attempt. The first attempt failed with "not enough space" on the phone.
- `flutter build windows --debug`: **failed**: "Unable to find suitable Visual Studio toolchain". `flutter doctor` reports Visual Studio Build Tools 2019 as incomplete. This is a machine setup issue, not a code issue.
- `flutter run`: not completed (interrupted by the user). The APK was built and installed with `flutter build apk --debug` and `flutter install --debug` instead. Launch on the device was not observed by the agent.
- After the Gradle wrapper was restored to 8.10.2, the project was not rebuilt (interrupted). The earlier successful APK build used Gradle 8.10.2, so the restored configuration is the one that was verified.

## Known issues
- `android/gradle/wrapper/gradle-wrapper.properties` was changed outside this work to `gradle-9.7.1-bin.zip` (likely an IDE Gradle upgrade prompt or a `gradle wrapper` command). Gradle 9 is incompatible with the template's AGP 8.7.0, Kotlin plugin 1.8.22 and Flutter 3.29.1, so it was restored to `gradle-8.10.2-all.zip`. Do not accept IDE prompts to upgrade Gradle or AGP until Flutter is upgraded.
- Windows desktop cannot be built until Visual Studio (Desktop development with C++ workload) is installed or repaired.
- `flutter doctor` reports unaccepted Android licenses (`flutter doctor --android-licenses`) and several duplicate or broken Android Studio entries on this machine. The Gradle build still works.
- Settings are not persisted. Continue is always disabled. There is no audio (`assets/sounds` is empty).
- Debug APK is large; devices with little free storage may fail to install it.
- No automated tests for `StorageService` (needs Hive test setup) or the error-retry splash state.
- Dependencies are not on the latest versions (`flutter pub outdated` lists 36 newer, incompatible versions).

## Addendum: Repository pattern (data architecture)

Added after the original Phase 1 handoff. No existing Phase 1 module was rewritten. The only edits to existing files were: extra exception types in `app_exception.dart`, two constants in `app_constants.dart`, and a doc comment on `StorageService`. The full description (diagram, interface table, decisions, roadmap) is in `docs/PROJECT_MASTER.md` under "Data architecture (Repository Pattern)".

**What was added**
- Models: `City`, `Building`, `ResourceLedger`, `MissionProgress`, `PlayerProgress` (immutable, `copyWith`, `toJson`/`fromJson`, UTC `updatedAt`).
- Interfaces in `lib/repositories`: `CityRepository`, `BuildingRepository`, `ResourceRepository`, `MissionRepository`, `PlayerProgressRepository`.
- Non-persistent implementations in `lib/repositories/memory/`.
- `CityService` (create with validation, `latestCity`, `hasSavedCity`, cascading `deleteCity`) depending on interfaces only.
- `repository_providers.dart`: the single place where implementations are chosen.
- `RepositoryException`, `ValidationException`, and `IdGenerator` (client-side string ids).

**Key decisions**
- Future-based interfaces, so memory, SQLite and network backends all fit.
- Business rules in services; repositories only store and load their own data.
- Cloud-ready by design: client-generated string ids, `updatedAt` on every entity, JSON-serialisable entities, stable string ids for content instead of enums, failures wrapped in `RepositoryException`.
- `StorageService` (Hive) is limited to small key-value preferences.

**Explicitly not done (by requirement)**
- No Firebase, authentication, cloud database or multiplayer code or dependencies.
- No SQLite/Drift code or dependencies; the local database implementation is reserved for Phase 7.
- Memory repositories do not persist across restarts, so Continue stays a disabled placeholder.

**Extending later**
- Phase 7: add `lib/repositories/local/` implementing the same interfaces, register them in `repository_providers.dart`, and run the same repository tests against them.
- V3: add cloud implementations (or a sync layer over the local ones) and an auth service; wiring changes only. Additive methods such as `watch*` streams do not break existing callers.

## Phase 2 requirements (proposal, pending your approval)
Scope: game engine core and a first playable map view, started from New Game.
0. **Persistence rules (apply to everything below):** the game never talks to a database. Create cities via `cityServiceProvider`, and read or write game data only through the repository providers in `lib/providers/repository_providers.dart`. Do not import anything from `lib/repositories/memory/` outside that file.
1. **Models** (`lib/models`): `TileType`, `Tile`, `GameMap` (fixed-size grid, e.g. 32x32), `BuildingType` (an enum in game code that maps to the persisted `Building.typeId` string), and a runtime `CityState`. `City`, `Building` and `ResourceLedger` already exist as persisted models; do not duplicate them.
2. **Engine** (`lib/game/engine`): `GameLoop` driven by a `Ticker` with pause and speed controls; tick updates `CityState` via a provider.
3. **Map** (`lib/game/map`): isometric or top-down tile projection helpers and a `MapPainter` (CustomPainter) drawing the grid, with `RepaintBoundary`.
4. **Camera:** pan and pinch-zoom (`GestureDetector` or `InteractiveViewer`), tile hit-testing from screen position.
5. **Buildings** (`lib/game/buildings`): `BuildingPainter`s for at least road, residential and power plant, plus a build-mode selection and placement through a `CityNotifier`.
6. **Providers:** `cityProvider` (Notifier), `gameLoopProvider`, `selectedToolProvider`. They use the existing repository providers and `CityService`.
7. **Screens and widgets:** `GameScreen` with the map canvas, top HUD (money, population, day) and bottom build toolbar; New Game creates a city through `CityService.createCity` and routes to it.
8. **Tests:** unit tests for the grid and placement rules and for the loop tick; a widget test for GameScreen.
9. **Acceptance:** `flutter analyze` clean, `flutter test` green, and the app runs on the Android device with a pannable and zoomable map where buildings can be placed.
