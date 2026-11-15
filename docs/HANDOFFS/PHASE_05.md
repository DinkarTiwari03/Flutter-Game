# Phase 05 Handoff: City Simulation Engine

## 1. Features Implemented

### Simulation Clock & Diurnal Day/Night Cycle
- **In-Game Clock (`SimulationClock`):**
  - Tracks in-game `day`, `hour`, `minute`, and total discrete elapsed `tickCount`.
  - Deterministic progression: 1 simulation tick corresponds to 1 in-game hour (60 minutes).
  - Proper 24-hour midnight rollover that advances the city calendar (`Day 1` -> `Day 2` ...).
  - Formatted time helpers: `formattedTime` (e.g. `08:00`), `formattedDay` (`Day 1`), and `formattedFull` (`Day 1 • 08:00`).
  - Serializes and deserializes to JSON for persistence readiness.
- **Diurnal Phase System (`DayPhase`):**
  - 4 distinct daily lighting phases:
    - **Dawn** (05:00 - 07:59): Morning twilight with soft golden hue (`Color(0x28FFAB40)`).
    - **Day** (08:00 - 17:59): Clear sunny daylight (unfiltered transparency).
    - **Dusk** (18:00 - 20:59): Twilight purple/sunset magenta hue (`Color(0x35E040FB)`).
    - **Night** (21:00 - 04:59): Deep navy nocturnal tint (`Color(0x550A1931)`).
  - Atmospheric ambient lighting overlay integrated directly into `MapViewport` via `AnimatedContainer` with 800ms smooth phase transitions.
  - Interactive panning, pinch-to-zoom, keyboard navigation, and tile selection remain fully fluid and unaffected by ambient diurnal transitions.
- **Simulation Clock Controls & Speeds:**
  - Integrated with `SimulationSpeed` (pause, 1x normal at 3.0s/tick, 2x fast at 1.5s/tick, 3x superFast at 0.75s/tick).
  - Reliable pause and resume via `SimulationSpeedControl` and keyboard shortcut (`Space`).
  - Wall-clock timer is deactivated in automated widget tests (`!isTestEnvironment`) to eliminate pending timer leaks while supporting deterministic manual ticks.

### Population Simulation & Demographics
- **City Demographics Model (`CityDemographics`):**
  - Tracks `totalPopulation`, `housingCapacity`, `totalJobs`, `employedCount`, `healthcareRating`, `educationRating`, `safetyRating`, `housingDemand`, `commercialDemand`, `industrialDemand`, and `migrationRate`.
  - Dynamic getters for `occupancyRate` (0-100%), `workingAgePopulation` (~65% of citizens), `employmentRate` (0-100%), `vacantJobs`, and `unemployedCount`.
- **Dynamic Growth & Migration Mechanics:**
  - Respects residential housing capacity as an absolute ceiling; population cannot exceed housing.
  - Population grows when housing capacity is available, city happiness is healthy (>= 50%), and utility satisfaction rate is high (>= 80%).
  - Population declines when severe utility deficits occur (power/water blackouts) or when unhappiness plunges below 40%.
  - When no housing exists, population migrates away.

### Building Simulation Behaviors
- **19 Configurable Building Definitions:**
  - Added `jobsProvided`, `healthcareCapacity`, `educationCapacity`, and `safetyCapacity` to `BuildingResourceConfig`.
  - Added level-scaled effective getters on `BuildingDefinition`:
    - `effectiveJobsProvided(level)`
    - `effectiveHealthcareCapacity(level)`
    - `effectiveEducationCapacity(level)`
    - `effectiveSafetyCapacity(level)`
  - Configured jobs and services across all categories:
    - **Commercial:** Retail shops (12 jobs), Shopping Malls (55 jobs), Office Towers (150 jobs).
    - **Industrial:** Manufacturing Factories (40 jobs), Heavy Industrial Complexes (100 jobs).
    - **Public Services:** Hospitals (30 jobs, 350 healthcare capacity), Schools (20 jobs, 250 education capacity), Police Stations (15 jobs, 300 safety capacity), Fire Stations (15 jobs, 300 safety capacity).
    - **Infrastructure & Utilities:** Power plants and solar plants provide essential energy and technical jobs; water pumping and treatment facilities provide municipal water and jobs.
    - **Environment:** Parks and botanical gardens mitigate pollution and provide happiness bonuses.

### City Conditions & Municipal Efficiency
- **Electricity & Water Balance:** Real-time supply vs. demand satisfaction calculations determine whether buildings remain operational and citizens stay happy.
- **Pollution Dynamics:** Industrial zones and thermal power generation produce pollution; parks, gardens, and water treatment plants scrub environmental pollution.
- **Civic Satisfaction Index:** Happiness dynamically responds to utility delivery, environmental pollution, healthcare coverage, education coverage, public safety, and unemployment rates.
- **Maintenance Upkeep:** Buildings require ongoing municipal operating expenses; net municipal cashflow is calculated and deducted deterministically per tick.

### Positive Civic Events System (V1)
- **`CityEvent` Model:**
  - Structured event schema tracking `id`, `title`, `description`, `type` (`populationGrowthBonus`, `taxIncomeBonus`, `sustainabilityReward`, `happinessBonus`), `durationTicks`, `remainingTicks`, `multiplier`, `happinessModifier`, `pollutionModifier`, and `instantCoinReward`.
  - Clear countdown with `remainingHours` and automatic expiration.
- **Balanced Positive Event Pool (`CityEventPool`):**
  - **Tech Innovation Surge:** 24-hour economic boom boosting commercial tax revenues by +25%.
  - **Baby & Migration Boom:** 18-hour population surge boosting migration attraction by +50%.
  - **Green City Initiative Grant:** Instant award of +¢2,500 coins to treasury with -10 pollution reduction.
  - **Civic Carnival & Festival:** 12-hour celebration delivering +15 happiness bonus across the entire populace.
- **Deterministic Triggering & In-Game UI Feedback:**
  - Triggered deterministically during simulation runs based on city maturity and milestones.
  - Event alerts surfaced via unobtrusive floating notification snackbar in `GameScreen`.
  - Active event duration and bonus status reflected in `CompactTopBar` and `DesktopTopBar`.
  - Strict scope enforcement: No disasters or crisis events in V1.

---

## 2. Files Created and Modified

### Created
- `lib/models/simulation_clock.dart` — Clock tracking day, hour, minute, tickCount, and diurnal phases (`Dawn`, `Day`, `Dusk`, `Night`) with atmospheric colors.
- `lib/models/city_demographics.dart` — Comprehensive demographics, jobs, healthcare/education/safety ratings, and demand indices.
- `lib/models/city_event.dart` — Timed positive civic event model and balanced event pool templates.
- `lib/services/simulation_service.dart` — Centralized simulation engine calculating labor, demographics, service coverage, active events, and cashflow.
- `lib/providers/simulation_providers.dart` — Riverpod providers for `simulationClockProvider`, `cityDemographicsProvider`, `activeCityEventsProvider`, and `lastTriggeredEventProvider`.
- `test/models/simulation_clock_test.dart` — Unit tests for clock advance, midnight rollover, diurnal phase transitions, and JSON serialization.
- `test/models/city_demographics_test.dart` — Unit tests for demographics rates, occupancy, employment, and JSON serialization.
- `test/models/city_event_test.dart` — Unit tests for event countdown, expiration, and event pool templates.
- `test/services/simulation_service_test.dart` — Integration tests for job aggregation, service capacity scaling, demographic migration, housing limits, event multipliers, and 24-hour diurnal cycling.
- `docs/HANDOFFS/PHASE_05.md` — This handoff document.

### Modified
- `lib/game/buildings/building_definition.dart` — Added `jobsProvided`, `healthcareCapacity`, `educationCapacity`, and `safetyCapacity` to `BuildingResourceConfig` and level-scaled getters; updated all 19 building definitions in `BuildingRegistry`.
- `lib/providers/repository_providers.dart` — Registered `simulationServiceProvider` injecting `EconomyService` and `ResourceRepository`.
- `lib/providers/economy_providers.dart` — Updated `CityLedgerNotifier.simulateTick()` to delegate to `SimulationService.simulateTick()`, updating clock, demographics, events, and transactions.
- `lib/screens/game_screen.dart` — Added reactive listener for `lastTriggeredEventProvider` to display celebratory floating event snackbars.
- `lib/widgets/game/map_viewport.dart` — Added day/night atmospheric ambient lighting overlay (`clock.phase.ambientColor`) with smooth animated transitions.
- `lib/widgets/game/compact_top_bar.dart` — Added `_ClockPill` with phase icon and formatted calendar time in scrollable top bar row.
- `lib/widgets/game/desktop_top_bar.dart` — Added live calendar time, day phase label, and active event badge to city header subtitle.
- `docs/PROJECT_MASTER.md` — Updated Phase status and roadmap to reflect Phase 5 completion.

---

## 3. Architecture & Data Flow

```
[ SimulationTickerNotifier ]
          │ (Tick interval: 3.0s / 1.5s / 0.75s / paused)
          ▼
[ CityLedgerNotifier.simulateTick() ]
          │
          ├─► Reads: activeCity, ResourceLedger, Buildings, SimulationClock, Demographics, ActiveEvents
          │
          ▼
[ SimulationService.simulateTick() ]
   ├─► 1. Advance SimulationClock (+60 mins / tick, 24h day rollover)
   ├─► 2. Process & Tick ActiveEvents (decrement remainingTicks, calculate multipliers)
   ├─► 3. Infrastructure & Utilities (Electricity & Water balance)
   ├─► 4. Happiness & Service Coverage (Healthcare, Education, Safety, Employment)
   ├─► 5. Demographics & Migration (Growth constrained by Housing Capacity)
   ├─► 6. Economy & Cashflow (Residential tax + Commercial + Industrial - Upkeep)
   └─► 7. Create SimulationTickResult
          │
          ├─► Save updated ResourceLedger to ResourceRepository
          ├─► Update simulationClockProvider (SimulationClock)
          ├─► Update cityDemographicsProvider (CityDemographics)
          ├─► Update activeCityEventsProvider (List<CityEvent>)
          ├─► Notify lastTriggeredEventProvider (if new civic event triggered)
          └─► Record ResourceTransactions to transactionHistoryProvider
```

---

## 4. Test Suite & Verification Results

All tests across the entire application pass cleanly with exit code 0:

```
$ flutter test
00:19 +154: All tests passed!
```

### Key Test Coverage Areas:
- **Simulation Clock:** Initial state, 60-minute discrete increments, 24-hour midnight rollover, day count increment, and diurnal phase transitions (`dawn`, `day`, `dusk`, `night`).
- **Demographics:** Working-age citizens calculation, labor demand, employment rate, housing capacity constraints, occupancy rate, and migration response to happiness and utility deficits.
- **Service Capacity:** Healthcare capacity scaling on hospitals, education capacity on schools, and safety coverage on police and fire stations.
- **Simulation Engine:** Deterministic calculations independent of camera panning or zoom; active event duration countdown and income multiplier application; 24-tick diurnal cycle consistency.
- **Widget Integration:** Phone and desktop HUD rendering with calendar time and day phase; low-resource warning alerts; interactive map viewport ambient overlay with zero pointer interference.

---

## 5. Known Issues / Limitations

- In-memory persistence: All cities, buildings, ledgers, and simulation stats remain in-memory default repositories for V1 until SQLite/Drift persistence is added in Phase 7.
- Traffic and vehicle pathfinding: Basic road connectivity is validated during placement, but advanced traffic simulation is reserved for V2/V3 per scope guidelines.
- Disasters and crisis management: Disasters are intentionally excluded from V1 scope; only positive civic bonus events are active.

---

## 6. Instructions for Phase 6 (Progression, Objectives & Audio/Polish)

When approved to start **Phase 6**:
1. Review `docs/PROJECT_MASTER.md` and this handoff document.
2. Implement city milestones, level progression requirements, and unlock thresholds.
3. Connect mission system to `MissionRepository` and track objectives.
4. Add audio manager and sound effects / ambient soundscapes.
5. Provide overall UI/UX polish and transitions.
6. Await explicit user approval before starting Phase 6.
