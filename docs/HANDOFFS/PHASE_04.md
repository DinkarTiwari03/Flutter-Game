# Phase 04 Handoff: Resource Management and Economy System

## 1. Features Implemented

### Core Resources System
- **6 Core Resources (`CityResourceType`):**
  - **Coins:** Currency for construction, maintenance, and upgrades. Initial value: 25,000. Clamped min: 0.
  - **Population:** City residents, dynamically growing or declining based on happiness, housing capacity, and utility availability.
  - **Electricity:** Power generation in kW (power plant, solar plant) vs. consumption. Calculates satisfaction rate (0-100%).
  - **Water:** Water pumping and treatment in kL vs. consumption. Calculates satisfaction rate (0-100%).
  - **Happiness:** City contentment rating (0-100%). Initial value: 75%. Influenced by services (hospital, school, police, fire), environment (parks, gardens), utility shortages, and pollution.
  - **Pollution:** Environmental degradation rating (0-100%). Produced by heavy industry and thermal plants; scrubbed by parks, gardens, and water treatment plants.

### City Economy & Financial Modeling
- **Income Channels:**
  - Residential taxes collected per housed citizen, scaled by housing tier.
  - Commercial revenue from retail shops, malls, and corporate office towers.
  - Industrial revenue from manufacturing plants and heavy complexes.
- **Operating Expenses:**
  - Building upkeep per structure, scaled by upgrade level.
  - Road network and transit maintenance.
  - Electricity and water generation maintenance costs.
- **Transaction Processing:**
  - Deducts construction costs when placing buildings.
  - Deducts tiered upgrade costs when leveling up buildings.
  - Deposits 50% demolition refunds on building destruction.
  - Hard constraint: prevents construction and upgrades if available coins are insufficient (`ValidationException`).
  - Immutable transaction logging (`ResourceTransaction`) tracking transaction types, amounts, and timestamps.

### Data-Driven Building Resource Behavior
- **Configurable Resource Properties (`BuildingResourceConfig`):**
  - Extensible properties added to all 19 buildings across all 6 categories:
    - Housing capacity and tax rate per resident.
    - Commercial and industrial direct revenue.
    - Operating maintenance costs.
    - Electricity and water production/consumption.
    - Pollution generation and mitigation.
    - Happiness bonuses.
  - Deterministic tier scaling methods on `BuildingDefinition`:
    - `effectiveHousingCapacity`, `effectiveCommercialIncome`, `effectiveIndustrialIncome`
    - `effectiveResidentialTax`, `effectiveMaintenance`
    - `effectiveElectricityProduction`, `effectiveElectricityConsumption`
    - `effectiveWaterProduction`, `effectiveWaterConsumption`
    - `effectivePollutionOutput`, `effectivePollutionReduction`, `effectiveHappinessBonus`

### Centralized Economy Service & Simulation Loop
- **`EconomyService` (`lib/services/economy_service.dart`):**
  - Pure, deterministic calculation engine separate from UI widgets.
  - Calculates housing capacity, income, expenses, utility balances, pollution, happiness, and population growth/decline.
  - Deterministic simulation tick (`simulateTick`) running discrete simulation steps independent of render framerates.
- **Riverpod State Layer (`lib/providers/economy_providers.dart`):**
  - `cityLedgerProvider`: AsyncNotifier managing the active city's persistent `ResourceLedger`.
  - `cityEconomySnapshotProvider`: Reactive provider emitting `CityResourcesSnapshot` to the HUD.
  - `transactionHistoryProvider`: Sliding window buffer of recent economic transactions.
  - `simulationTickerProvider`: Ticker controller bound to `simulationSpeedProvider` (normal, fast, superFast, paused).
  - Wired directly into `cityStatsProvider` in `game_providers.dart`.

### Visual Resource HUD & Warning States
- **Top Bar Integration (`CompactTopBar` & `DesktopTopBar`):**
  - Added **Pollution** indicator with severity-based coloring (`pollutionStyle`: aqua -> sunrise -> coral).
  - Clear visual feedback for low or insufficient resources:
    - Low coins (< 500) highlighted in coral with warning outline.
    - Power deficit (< 100% satisfaction) styled with warning indicators.
    - Water deficit (< 100% satisfaction) styled with warning indicators.
    - Unhappy city (< 50%) styled in coral with unhappy icon.
    - High pollution (>= 50%) styled in coral with smog alert.
  - Desktop dashboard displays live net cashflow per tick (`+¢120/t` or `-¢45/t`) and population capacity (`pop/capacity`).
- **Interactive Validation in Building Panels:**
  - `BuildingSelectionMenu`: Shows "(Low coins)" warning and disables button if player cannot afford cost.
  - `PlacementHud`: Displays "Insufficient Coins" in status pill and disables "Construct" button when funds are lacking.
  - `BuildingInspectorPanel`: Displays building resource outputs (power, water, income, upkeep, pollution, happiness) and disables upgrades with an "(Insufficient Coins)" warning when funds are low.

---

## 2. Files Created, Modified and Deleted

### Created
- `lib/models/city_resource.dart` — Core resource models (`CityResourceType`, `UtilityBalance`, `IncomeBreakdown`, `ExpenseBreakdown`, `CashflowSummary`, `ResourceWarnings`, `CityResourcesSnapshot`).
- `lib/models/resource_transaction.dart` — Immutable transaction ledger record (`ResourceTransaction`, `TransactionType`).
- `lib/services/economy_service.dart` — Centralized economic simulation service for income, expenses, utilities, pollution, happiness, population, and transactions.
- `lib/providers/economy_providers.dart` — Riverpod providers for `cityLedgerProvider`, `cityEconomySnapshotProvider`, `transactionHistoryProvider`, and `simulationTickerProvider`.
- `test/models/city_resource_test.dart` — Unit tests for resource balance, cashflow, transaction serialization, and warning thresholds.
- `test/services/economy_service_test.dart` — Unit tests for income, expenses, electricity/water balances, pollution, happiness, population growth, and simulation ticks.
- `test/widgets/resource_hud_test.dart` — Widget tests for compact and desktop HUDs, 6-resource display, and low-resource warning states.
- `docs/HANDOFFS/PHASE_04.md` — This handoff document.

### Modified
- `lib/models/resource_ledger.dart` — Added initial ledger factory, standard resource keys (`coinsKey`, `populationKey`, `happinessKey`, `pollutionKey`), and immutable `updateAmounts`.
- `lib/models/city_stats.dart` — Added `pollution`, `housingCapacity`, `netIncome`, `electricityProduced/Consumed`, `waterProduced/Consumed`, and warning getters.
- `lib/game/buildings/building_definition.dart` — Added `BuildingResourceConfig`, level-scaling calculation methods, and data-driven resource configurations for all 19 buildings.
- `lib/services/building_service.dart` — Integrated `EconomyService` and `ResourceRepository`: enforces coin checks, deducts construction/upgrade costs, and deposits demolition refunds.
- `lib/services/city_service.dart` — Initializes and saves starting `ResourceLedger` upon city creation.
- `lib/providers/repository_providers.dart` — Registered `economyServiceProvider` and injected into `buildingServiceProvider`.
- `lib/providers/game_providers.dart` — Connected `cityStatsProvider` directly to `cityEconomySnapshotProvider`.
- `lib/providers/building_providers.dart` — Reloads `cityLedgerProvider` after building construction, upgrade, or demolition.
- `lib/widgets/game/resource_chip.dart` — Added `pollutionStyle` helper and `isWarning` visual alert styling.
- `lib/widgets/game/compact_top_bar.dart` — Added pollution chip and dynamic warning feedback across chips.
- `lib/widgets/game/desktop_top_bar.dart` — Added pollution card with progress bar, net cashflow display, and warning highlights.
- `lib/widgets/game/building_inspector_panel.dart` — Added resource behavior breakdown badges and insufficient coins upgrade prevention.
- `lib/widgets/game/placement_hud.dart` — Validates available coins and shows "Insufficient Coins" error status.
- `lib/widgets/game/building_selection_menu.dart` — Converted to `ConsumerWidget` with dynamic coin affordability styling.
- `lib/screens/game_screen.dart` — Keeps simulation ticker provider active during gameplay.
- `test/services/building_service_test.dart` — Added tests for coin deductions, upgrade costs, demolition refunds, and insufficient coin rejections.
- `test/game/building_definition_test.dart` — Added tests for level-scaled resource behaviors.
- `test/services/city_service_test.dart` — Added verification of initial ledger creation.
- `docs/PROJECT_MASTER.md` — Updated phase status and roadmap.

### Deleted
- None.

---

## 3. Architecture Decisions

1. **Deterministic Discrete Simulation Ticks:**
   - Resource calculations do not rely on per-frame `deltaSeconds` floats or UI rendering frame rates. Simulation runs in discrete, deterministic ticks, guaranteeing identical outcomes across devices and test environments.
2. **Centralized Business Rules:**
   - Widgets perform zero financial or resource calculations. All income, expense, utility satisfaction, pollution, and happiness formulas are encapsulated in `EconomyService`.
3. **Repository Pattern Adherence:**
   - Persistence operations go strictly through `ResourceRepository` and `BuildingRepository` interfaces. Memory implementations remain fully swappable for future SQLite/Drift (Phase 7) or cloud backends.
4. **Test-Safe Ticker Architecture:**
   - Wall-clock periodic timers are skipped in automated widget test bindings, preventing pending timer leaks while allowing instantaneous, deterministic test verification via `tick()` / `simulateTick()`.

---

## 4. Dependencies Added

No runtime packages added. The stack remains clean:
- `flutter_riverpod` (3.3.2)
- `hive` (2.2.3)
- `hive_flutter` (1.1.0)
- `cupertino_icons` (1.0.8)

---

## 5. Tests Performed and Results

- **Complete Test Suite (`flutter test`):**
  - **135 passed, 0 failed!**
  - Unit tests covering models, repositories, camera, projections, definitions, validators, services, and widgets all pass cleanly.
- **Deterministic Economy Verification:**
  - Income calculation (residential, commercial, industrial): **Passed**.
  - Expense calculation (buildings, roads, utilities): **Passed**.
  - Construction & upgrade coin deductions: **Passed**.
  - Demolition refunds: **Passed**.
  - Insufficient coin rejections: **Passed**.
  - Power and water balance & deficit calculations: **Passed**.
  - Pollution output and green mitigation: **Passed**.
  - Citizen happiness rating & penalties: **Passed**.
  - Dynamic population growth & emigration: **Passed**.
  - Resource HUD display and visual warnings: **Passed**.

---

## 6. Known Issues

- None in Phase 4 code.
- Windows desktop native compilation requires Visual Studio C++ workload (Android APK build verified).

---

## 7. Instructions for Phase 5

Phase 5: **City Progression, Goals, and Milestone Systems**
1. Implement city achievement, mission, and milestone systems building on `MissionRepository` and `PlayerProgressRepository`.
2. Introduce unlocked building tiers based on city level and population milestones.
3. Integrate city objective notifications and celebration overlays.
4. Connect mission rewards directly to `EconomyService` and `cityLedgerProvider`.
