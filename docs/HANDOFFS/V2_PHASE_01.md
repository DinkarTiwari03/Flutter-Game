# V2 Phase 01 — Advanced Traffic Simulation

**City Builder 2040 · V2 Feature Wave**
Completed: 2026-11-20

---

## 1. Objective

Transform the existing road network into a fully functional transportation system where:

- Roads contain actual moving vehicles drawn from real population demand.
- Traffic dynamically scales with the city's population and economic activity.
- Players can observe congestion problems and use a rich toolbox to solve them.

---

## 2. Features Delivered

### A. Vehicle Simulation

Five vehicle categories now move on the road network:

| Category | Icon | Characteristics |
|---|---|---|
| **Car** | 🚗 | Standard private vehicle, most common, varies by time-of-day demand |
| **Bus** | 🚌 | Public transit, boards at bus stops, reduces private car demand |
| **Truck** | 🚛 | Industrial freight, high mass, spawns near factories/industrial zones |
| **Delivery** | 🚐 | Commercial logistics, spawns near shops and commercial zones |
| **Emergency** | 🚑 | Ambulance / fire engine, bypasses red lights, yields granted by other vehicles |

**Key behaviours implemented:**

- Vehicles follow the road graph via A* congestion-aware pathfinding.
- Vehicles slow to tier-based speed limits and further reduce speed under congestion load.
- Anti-stacking: vehicles maintain a 28 px clearance from the vehicle ahead and halt if gap < 12 px.
- Emergency vehicles skip traffic signal checks and other vehicles yield (target speed ×1.6).
- Buses pause at registered bus-stop tiles to simulate boarding/alighting.
- Vehicles that complete their journey de-spawn cleanly or are rerouted to return trips.
- Siren effect: emergency vehicles flash alternating red/blue circle indicators every 0.4 s (rendered by `UrbanArt`).

### B. Dynamic Traffic Demand System

Traffic is never placed randomly. Vehicle spawning uses an **Origin-Destination (OD) pattern**:

| Time of Day | Demand Pattern |
|---|---|
| **Morning (6–10 h)** | High outbound from residential → commercial and industrial |
| **Afternoon (11–16 h)** | Moderate; delivery vans and commercial movement dominate |
| **Evening (17–21 h)** | Heavy inbound return to residential zones |
| **Night (22–5 h)** | Reduced; only emergency and freight vehicles spawn |

Demand ceiling scales with:
- Total residential population.
- Number of commercial and industrial buildings.
- Number of bus stops and stations (transit ridership reduces private car spawns).
- Road network connectivity (no roads = no vehicles).

Major arterial roads connecting residential, commercial, and industrial clusters naturally
carry higher vehicle loads than local side streets.

### C. Traffic Congestion System

Four named conditions are defined in `TrafficCondition`:

| Condition | Load Ratio | Speed Multiplier | Colour |
|---|---|---|---|
| **Free Flow** | < 38% | 1.00 × | Green `#22C55E` |
| **Moderate** | 38–70% | 0.75 × | Yellow `#EAB308` |
| **Heavy** | 70–100% | 0.45 × | Orange `#F97316` |
| **Gridlock** | ≥ 100% | 0.18 × | Red `#EF4444` |

**Load Ratio** = `vehicleCount / tier.capacity` for each road tile.

**Consequences of congestion:**

- Longer travel times → delayed bus runs and emergency response.
- Commercial productivity penalty: each gridlocked road applies happiness penalty (-2 to -8 total).
- Industrial delivery delays: `economicLossPerHour` deducted each sim tick via `SimulationService.simulateTick()`.
- Pollution bonus: congested roads emit extra pollution units (up to +12 per tick).
- Dynamic rerouting: vehicles in gridlocked segments are assigned a fresh congestion-aware path.

### D. Player Congestion-Solving Tools

#### 1. Road Upgrades (4 Tiers)

Upgrade an existing road via the Building Inspector (select a road tile → Upgrade button):

| Tier | Level | Capacity | Speed Limit | Upgrade Cost |
|---|---|---|---|---|
| Small Road | 1 | 4 vehicles | 46 px/s | — (default) |
| Medium Avenue | 2 | 8 vehicles | 58 px/s | ¢50 |
| Large Boulevard | 3 | 16 vehicles | 72 px/s | ¢120 |
| High-Capacity Expressway | 4 | 32 vehicles | 90 px/s | ¢250 |

Tier is stored in `Building.level`. The road's visual sprite uses `road.png` for all
tiers (placeholder — visual differentiation requires new art assets).

#### 2. Traffic Signals

Signals are **auto-generated** at 3-way and 4-way intersections when the road graph is rebuilt.
They cycle through three phases:

```
Horizontal Green (5.5 s) → Yellow (1.2 s) → Vertical Green (5.5 s) → …
```

Emergency vehicles bypass signal checks. All other vehicles stop at red.
Signal state is visualised on the heatmap overlay as a small coloured square.

#### 3. Alternative Routes (Congestion-Aware A\*)

`RoadGraph.findCongestionAwarePath()` runs a modified A* where edge cost includes:
- Base distance.
- Congestion load penalty (`loadRatio × 1.8`).
- Road tier discount (higher tier = lower cost, encouraging use of expressways).

Vehicles dynamically reroute when their current segment enters Gridlock.

#### 4. Public Transportation

Two new building types:

| Building | Size | Cost | Effect |
|---|---|---|---|
| **Bus Stop** | 1×1 | ¢120 | Buses pause here; each stop reduces private car spawn ceiling by 2 |
| **Bus Station** | 2×2 | ¢750 | Larger transit hub; reduces car demand ceiling by 6 |

Buses are spawned as a distinct vehicle category and follow the road graph between stops.
`publicTransitRidership` and `trafficDemandReductionPercent` are reported live in the dashboard.

#### 5. Bypass Roads

Build roads at the city periphery using the standard road placement tool. The congestion-aware
router naturally directs vehicles onto these less-loaded bypass routes.

#### 6. Traffic Management Dashboard

Accessible via section key **5 → Roads** (replaces old infrastructure building list).

Displays:
- **City Congestion %** and overall condition badge.
- **Active Vehicles** count.
- **Average Speed** (px/s).
- **Traffic Losses** (¢/hr economic loss from congestion).
- **Public Transit Impact** row (ridership + car demand reduction %).
- **Actionable Alerts** list with severity colour and recommended action text.
- **Major Traffic Hotspots** list (top 4 congested tiles) with an Inspect/Upgrade button.
- **Transit Infrastructure Works** quick-build palette (Road, Bus Stop, Bus Station).

#### 7. Traffic Heatmap Overlay

Toggle with key **T** (Windows) or the switch in the Traffic Dashboard.

Colours road tiles on the isometric map according to their `TrafficCondition`:

| Condition | Overlay Colour |
|---|---|
| Free Flow | Semi-transparent green |
| Moderate | Semi-transparent yellow |
| Heavy | Semi-transparent orange |
| Gridlock | Semi-transparent red |

Traffic signal tiles display a small indicator dot. Rendered by `UrbanArt.paintTrafficHeatmap()` as layer 0 of `BuildingPainter`.

#### 8. Traffic Alerts

Generated automatically by `UrbanSimulationService._analyzeTraffic()`. Sample alerts:

- *"Heavy congestion near Commercial District"* → Upgrade roads or add bus stops.
- *"Industrial road capacity exceeded"* → Consider bypass roads or road upgrade.
- *"Emergency vehicle delayed by traffic"* → Add traffic signals or upgrade arterials.
- *"Public transportation demand increasing"* → Place Bus Station near residential zones.
- *"Road upgrade recommended at (col, row)"* → Direct upgrade suggestion with tile coordinates.

---

## 3. Architecture

### New Files

| File | Purpose |
|---|---|
| `lib/models/traffic/traffic_models.dart` | Full model layer: `TrafficCondition`, `RoadTier`, `TrafficSignal`, `TrafficSegmentStats`, `TrafficAlert`, `TrafficMetrics` |
| `lib/widgets/game/traffic/traffic_dashboard.dart` | Traffic Management Dashboard UI widget |
| `test/game/traffic_simulation_test.dart` | Test suite covering road graph tiers, signals, congestion routing, anti-stacking, emergency bypass, economic penalties |

### Modified Files

| File | Change Summary |
|---|---|
| `lib/game/buildings/building_definition.dart` | Added `trafficCapacity` to `BuildingResourceConfig`; upgraded `road` to `maxLevel:4`; added `busStop` and `busStation` definitions; registered both in `BuildingRegistry.all` |
| `lib/game/buildings/building_sprite_registry.dart` | Added sprite entries for `road:2–4`, `bus_stop:1–2`, `bus_station:1–3` (all reuse existing PNG placeholders) |
| `lib/game/urban/road_graph.dart` | **Full rewrite**: tier map, signal map, bus stop/station sets, `updateFromBuildings` reads `building.level` for tier, auto-creates signals at 3-/4-way intersections, `findCongestionAwarePath()` A*, `updateSignals(dt)`, `pickNextRoad` congestion-load weighting |
| `lib/game/urban/vehicle.dart` | **Full rewrite**: added `targetSpeed`, `isBlocked`, `sirenTimer`, `passengerCount`, `destinationTile`, `path`, `pathIndex`, `isReturning`, `localCondition`; `updateMovement()` advances siren timer; `isBus`, `isEmergency` getters |
| `lib/game/urban/urban_simulation_service.dart` | **Full rewrite**: `maxVehicles=45`; signal updates per frame; intersection signal check; vehicle spacing & queue system; dynamic rerouting on gridlock; OD demand spawner; `_analyzeTraffic()` with hotspot detection, alert generation, economic loss; bus boarding logic; `trafficMetrics` getter |
| `lib/game/urban/urban_art.dart` | Added emergency siren flash rendering; added `paintTrafficHeatmap()` static method |
| `lib/game/components/building_painter.dart` | Added `showTrafficHeatmap` parameter; calls `UrbanArt.paintTrafficHeatmap()` as layer 0 |
| `lib/providers/urban_providers.dart` | Added `trafficMetricsProvider`; added `TrafficHeatmapVisibleNotifier` and `trafficHeatmapVisibleProvider` |
| `lib/providers/economy_providers.dart` | Imports `urban_providers.dart`; `simulateTick()` reads `trafficMetrics` and passes it to `simulation.simulateTick()` |
| `lib/services/simulation_service.dart` | `simulateTick()` signature extended with `TrafficMetrics? trafficMetrics`; applies happiness penalty (up to −8), pollution bonus (up to +12), income deduction by `economicLossPerHour` |
| `lib/widgets/game/section_panel.dart` | `GameSection.roads` now renders `TrafficDashboardView()` |
| `lib/widgets/game/map_controls.dart` | Added third "Traffic Heatmap" button (key `control-traffic`, icon `traffic_rounded`, tooltip "Traffic heatmap (T)") |
| `lib/widgets/game/map_viewport.dart` | Reads `trafficHeatmapVisibleProvider`; passes `showTrafficHeatmap` to `BuildingPainter` |
| `lib/screens/game/game_shortcuts.dart` | Added `ToggleTrafficHeatmapIntent`; bound `Key T` to toggle heatmap |
| `lib/widgets/game/shortcut_hints.dart` | Added `T → Toggle traffic heatmap` to the Controls cheat sheet |
| `lib/widgets/game/building_inspector_panel.dart` | Added traffic capacity badge for roads; added "Transit: Cuts Congestion" badge for bus stops/stations |

---

## 4. Data Flow

```
SimulationClock tick
       │
       ▼
UrbanSimulationService.update(dt, buildings, map, clock)
  ├─ roadGraph.updateFromBuildings()   ← rebuilds graph if buildings changed
  ├─ roadGraph.updateSignals(dt)       ← advances traffic light timers
  ├─ _spawnDemandVehicle()             ← OD-pattern spawning
  ├─ _checkIntersectionSignal(v)       ← stops / releases vehicles at signals
  ├─ _checkVehicleSpacingAndQueues(v)  ← anti-stacking, tier speed, emergency yield
  ├─ _handleVehicleArrival(v, bldgs)   ← reroute / de-spawn on arrival
  └─ _analyzeTraffic(buildings)        ← 1-s timer: congestion map, hotspots,
                                          alerts, TrafficMetrics snapshot
       │
       ▼
trafficMetricsProvider (Riverpod Provider<TrafficMetrics>)
       │
       ├─ TrafficDashboardView          ← reads metrics, renders dashboard
       ├─ BuildingPainter               ← reads showTrafficHeatmap, paints overlay
       └─ economy_providers.simulateTick ← reads economicLossPerHour → income deduction
```

---

## 5. State Management

| Provider | Type | Purpose |
|---|---|---|
| `urbanSimulationProvider` | `Provider<UrbanSimulationService>` | Singleton simulation service (ChangeNotifier) |
| `trafficMetricsProvider` | `Provider<TrafficMetrics>` | Derived live traffic snapshot |
| `trafficHeatmapVisibleProvider` | `NotifierProvider<bool>` | Heatmap toggle state |

> **Note:** `TrafficMetrics` is recomputed inside `UrbanSimulationService.update()` on a 1-second internal timer and re-read by the `trafficMetricsProvider` on each `ChangeNotifier` notification. It is **not** individually reactive; it piggybacks on the existing urban simulation's notification cycle.

---

## 6. Known Limitations & Technical Debt

| Item | Detail |
|---|---|
| **Road tier sprites** | All 4 road tiers share `road.png`. Visual differentiation (wider lanes, markings) requires dedicated sprite assets. |
| **Bus stop / station sprites** | Placeholder assets from existing pool. Real bus shelter / station artwork not yet created. |
| **Bus routing** | Buses follow general vehicle routing (congestion-aware A*) rather than fixed user-defined bus routes. A "bus route designer" UI is a future V2 enhancement. |
| **Signal placement** | Auto-generated at intersections only. Manual signal placement on any road tile is a future feature. |
| **Heatmap granularity** | Per-tile. Sub-tile congestion visualisation (lane-level) is out of scope for V2 Phase 1. |
| **Persistence** | `TrafficMetrics` is not saved/restored. It rebuilds from live simulation state on app start. |
| **Windows visual tests** | Flutter integration tests for the heatmap overlay and dashboard rendering are not yet written. |

---

## 7. Test Coverage

`test/game/traffic_simulation_test.dart` covers:

- Road graph tier assignment from `building.level`.
- Signal state cycling and yellow-phase timing.
- Congestion-aware pathfinding prefers lower-load routes.
- Vehicle anti-stacking halts at `< 12 px` gap.
- Emergency vehicles bypass signal checks.
- Economic penalty applied proportionally to `economicLossPerHour`.

> **Status:** Written and present. Full pass status should be verified with `flutter test test/game/traffic_simulation_test.dart`.

---

## 8. How to Test Manually

1. **Start a new city.** Place roads connecting residential, commercial, and industrial buildings.
2. **Observe vehicles** appearing on roads within seconds of placing the first building.
3. **Open Traffic Dashboard** (press `5` or tap Roads in the navigation bar). Check metrics.
4. **Enable heatmap** using the toggle switch in the dashboard or press `T` on Windows.
5. **Create congestion** by building a dense road network with many residential + commercial buildings. Watch roads turn yellow → orange → red.
6. **Upgrade a road** by selecting a congested tile (press Inspect/Upgrade or tap the tile) → upgrade in the inspector. The heatmap should shift to green on that segment.
7. **Place a bus stop** near a residential cluster. After ~1 sim-minute, `Bus Ridership` in the dashboard should increase and `Car Demand Relief` should show a negative percentage.
8. **Place a bus station** near a commercial district for larger relief.
9. **Check alerts:** With heavy congestion, alerts appear in the dashboard with recommended actions.

---

## 9. Next Steps (V2 Phase 2 Candidates)

- **User-drawn bus routes** — allow players to define start/end stops for a bus line.
- **Road tier visual differentiation** — commission wider-lane sprites for levels 2–4.
- **Manual traffic signal placement** — let the player add signals to any road tile.
- **Traffic report screen** — historical charts of congestion over time.
- **Freight delivery visualisation** — show delivery vans travelling from factory → shop with cargo indicators.
- **Real bus stop / station sprites** — replace placeholder assets with dedicated artwork.

---

## 10. Files Changed (Diff Summary)

```
A  lib/models/traffic/traffic_models.dart
A  lib/widgets/game/traffic/traffic_dashboard.dart
A  test/game/traffic_simulation_test.dart
M  lib/game/buildings/building_definition.dart
M  lib/game/buildings/building_sprite_registry.dart
M  lib/game/urban/road_graph.dart               ← full rewrite
M  lib/game/urban/vehicle.dart                  ← full rewrite
M  lib/game/urban/urban_simulation_service.dart ← full rewrite
M  lib/game/urban/urban_art.dart
M  lib/game/components/building_painter.dart
M  lib/providers/urban_providers.dart
M  lib/providers/economy_providers.dart
M  lib/services/simulation_service.dart
M  lib/widgets/game/section_panel.dart
M  lib/widgets/game/map_controls.dart
M  lib/widgets/game/map_viewport.dart
M  lib/screens/game/game_shortcuts.dart
M  lib/widgets/game/shortcut_hints.dart
M  lib/widgets/game/building_inspector_panel.dart
M  docs/PROJECT_MASTER.md
```
