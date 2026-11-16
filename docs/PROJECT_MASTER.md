# City Builder 2040: Project Master

Flutter smart-city simulation game. Android is the primary platform; Windows desktop is secondary.

## Stack
- Flutter 3.29.1 / Dart 3.7.0
- `flutter_riverpod` 3.3.2 (state management)
- `hive` 2.2.3 + `hive_flutter` 1.1.0 (small key-value preferences only; game data goes through repositories, see Data architecture)
- `CustomPainter` for game graphics, Flutter's native animation system
- No other runtime packages (system font, no `google_fonts`)

## Architecture
- `lib/core/constants`: app constants, route names.
- `lib/core/theme`: `AppColors`, `AppSpacing`/`AppRadius`, `AppTheme`.
- `lib/core/utils`: responsive helpers (`Breakpoints`, `context.responsive`), `AppException`, `ErrorHandler`.
- `lib/models`: plain immutable data classes with `toJson`/`fromJson` (`City`, `Building`, `ResourceLedger`, `MissionProgress`, `PlayerProgress`, `AppSettings`, `CityStats`, `GameSection`, `SimulationSpeed`).
- `lib/repositories`: repository interfaces (persistence contracts). `memory/` holds non-persistent implementations.
- `lib/providers`: Riverpod providers and notifiers (`activeCityProvider`, `gameProviders`, `settingsProvider`, `repositoryProviders`, `storageProvider`, `bootstrapProvider`).
- `lib/services`: business logic and infrastructure with no UI (`CityService`, `StorageService`).
- `lib/screens`, `lib/widgets`: UI only; screens compose reusable widgets. Responsive desktop and phone layouts in `screens/game/`, reusable game components in `widgets/game/`.
- `lib/game/{engine,map,buildings,components}`: game code. `map/` holds isometric projection math, procedural generator and grid storage; `engine/` holds camera math and animation controller; `components/` holds chunked isometric painters and terrain art.
- `lib/app.dart`, `lib/app_router.dart`, `lib/main.dart`: app shell, named-route navigation, entry point.

## Conventions
- Package imports only (`package:city_builder_2040/...`).
- Colors, spacing, radii and durations come from `core/`; no repeated literals in screens.
- Business logic lives in providers and services, never in widgets.
- Startup work runs in `bootstrapProvider` while the splash is visible; failures show `AppErrorView` with a retry.
- Game code, services, providers and screens depend on repository **interfaces** only. Only `providers/repository_providers.dart` may import a concrete repository.

## Data architecture (Repository Pattern)

```
screens / widgets / game engine
        |  (read state, call services)
   providers  ->  services (business rules)
                      |  (interfaces only)
                lib/repositories/*.dart   <- the seam
                      |
        implementations (swapped in repository_providers.dart)
          V1 now:   memory/   (non-persistent)
          Phase 7:  local database
          V3:       cloud-backed / local + sync
```

### Repository interfaces
| Interface | Scope | Methods |
|---|---|---|
| `CityRepository` | Saved cities (save slots) | `listCities`, `getCity`, `saveCity`, `deleteCity` |
| `BuildingRepository` | Buildings per city | `getBuildings`, `saveBuilding`, `saveBuildings`, `removeBuilding`, `deleteByCity` |
| `ResourceRepository` | Resource ledger per city | `getLedger`, `saveLedger`, `deleteByCity` |
| `MissionRepository` | Mission progress per city | `getProgress`, `saveProgress`, `deleteByCity` |
| `PlayerProgressRepository` | Account-wide progression | `getProgress`, `saveProgress` |

Shared contract (documented on `CityRepository`):
- `save*` is an upsert by id; `get*` returns `null` or an empty list when nothing is stored.
- `delete*`/`deleteByCity` are idempotent.
- Failures surface as `RepositoryException`; backend-specific exceptions (SQL, Firebase) never leak to game logic.
- A repository manages only its own data. Rules spanning repositories live in services (for example `CityService.deleteCity` removes buildings, resources and missions, then the city record last so a failed delete can be retried).

### Decisions
1. **Interfaces are `abstract interface class`** and all methods are `Future`-based, so synchronous (memory), SQLite and network backends all fit without changing callers.
2. **Business logic is separate from persistence.** `CityService` validates and orchestrates; it never touches Hive, SQL or Firebase.
3. **Cloud-ready entities.** Ids are `String`s generated on the client (`IdGenerator`), so records can be created offline and synced later without id collisions. Every entity carries a UTC `updatedAt` for last-write-wins conflict handling. Entities serialise to plain JSON maps, reusable by SQLite and Firestore mappers.
4. **Stable string ids for content** (`Building.typeId`, resource ids, `missionId`, unlock ids) instead of Dart enums, so stored data does not depend on in-game code. The game layer maps ids to its own types. `MissionStatus` is the one persisted enum, stored by name.
5. **Mission definitions are not persisted**; only per-city `MissionProgress` is.
6. **Single local player in V1.** `PlayerProgress.localPlayerId = 'local'`; a cloud account id replaces it in V3.
7. **Backend choice is centralised.** Implementations are selected in `repository_providers.dart` (or by `ProviderScope` overrides). Swapping a backend does not touch services, providers, screens or game code.
8. **`StorageService` (Hive) is for small key-value preferences only**, not game data.
9. **Memory repositories are not a database.** They are the V1 default until Phase 7 and remain as test doubles.
10. **Scope limits.** Firebase, authentication, cloud databases and multiplayer are not part of V1. No SQLite/Drift code or dependency exists; the local database implementation is reserved for Phase 7.

### Roadmap
| When | Work | Impact on existing code |
|---|---|---|
| Phase 2+ | Game engine and UI use `cityServiceProvider` and the repository providers. | None to the data layer. |
| Phase 7 | Add `lib/repositories/local/` (SQLite/Drift) implementing the same interfaces and register them in `repository_providers.dart`. Reuse the repository tests against them. | Provider wiring only. |
| V3 | Add `lib/repositories/cloud/` (Firebase) implementations, or a sync layer wrapping the local ones (local-first, push/pull by `updatedAt`). Add an auth service and map `playerId` to the account id. | Provider wiring; new service for auth/sync. Additive interface methods (for example `watch*` streams) can be added without breaking callers. |

### Known limitations (V1)
- Nothing is saved between launches until Phase 7; memory repositories reset on restart.
- The Continue button is still a disabled placeholder. `CityService.hasSavedCity()` / `latestCity()` are ready for it once persistence exists.
- Settings are still in memory (`settingsProvider`); a `SettingsRepository` can be added later if settings need cloud sync.
- No streaming (`watch*`) APIs yet; they can be added later without breaking callers.

## Environment notes
- Android build uses Gradle 8.10.2, AGP 8.7.0, Kotlin 1.8.22, NDK 27.0.12077973. Do not upgrade Gradle (9.x is incompatible) or accept IDE upgrade prompts without upgrading Flutter first.
- Windows desktop builds need the Visual Studio "Desktop development with C++" workload (currently incomplete on the dev machine).
- Dev phone: 23021RAAEG (Android 15), device id `6b5e656f`. Debug APK needs several hundred MB of free storage.

## Phase status
| Phase | Status |
|-------|--------|
| 01 Foundation and architecture | Complete (Windows desktop run blocked by local Visual Studio install, see handoff) |
| 01 addendum: Repository pattern | Complete (interfaces, models, memory implementations, `CityService`, tests, docs) |
| 02 Responsive Game UI & Isometric City Map | Complete (isometric terrain renderer, camera controller, responsive phone & desktop layouts, HUD, controls, shortcuts, tests, docs) |
| 03 Cross-platform building placement system | Complete (19 building definitions, 6 categories, placement validation, isometric building art, depth-sorted renderer, ghost preview, inspector panel, upgrade/demolish, tests, docs) |
| 04 Resource management and economy system | Complete (6 core resources, deterministic simulation loop, income/expense breakdown, building resource properties, transaction handling, HUD & warning integration, tests, docs) |
| 05 City simulation engine | Complete (Simulation clock, 24h day/night diurnal cycle with atmospheric map tinting, pause/1x/2x/3x speeds, demographics, labor & housing capacity simulation, building behaviors, positive civic events, tests, docs) |
| 06 Missions, challenges and progression system | Complete (Missions across 4 categories, milestone challenges, player XP & level progression, building unlock gating, achievements, duplicate reward prevention, UI panels, tests, docs) |
| 07 Persistence, polish and platform optimization | Complete (Local SQLite database via Drift, concrete local repositories, autosave on lifecycle and simulation loop, app restart recovery, first-time player tutorial, settings persistence, tests, docs) |
| 08 Final testing, exhibition mode and release | Complete (Exhibition demo mode with isolated demo city, 204/204 automated tests, Android release APK verified, Windows toolchain documented, final release report) |
| Visual Upgrade: Real Isometric Buildings | Complete (54 Kenney CC0 building sprites across all 6 categories, multi-tile footprint anchoring, ghost preview, procedural fallback) |
| Urban Life Simulation | Complete (Pedestrian walking with stride animations, 19 vehicle types, right-hand lane physics, road graph pathfinding, day/night headlights, tests, docs) |

## Handoffs
- [Phase 01](HANDOFFS/PHASE_01.md)
- [Phase 02](HANDOFFS/PHASE_02.md)
- [Phase 03](HANDOFFS/PHASE_03.md)
- [Phase 04](HANDOFFS/PHASE_04.md)
- [Phase 05](HANDOFFS/PHASE_05.md)
- [Phase 06](HANDOFFS/PHASE_06.md)
- [Phase 07](HANDOFFS/PHASE_07.md)
- [Phase 08](HANDOFFS/PHASE_08.md)
- [Final Release Report](FINAL_RELEASE_REPORT.md)
- [Visual Building Assets](HANDOFFS/VISUAL_BUILDING_ASSETS.md)
- [Urban Life Simulation](HANDOFFS/URBAN_LIFE_SIMULATION.md)
