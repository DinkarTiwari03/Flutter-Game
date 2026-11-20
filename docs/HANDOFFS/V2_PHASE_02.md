# V2 Phase 02 — Natural Disaster System

**City Builder 2040 · V2 Feature Wave**
Completed: 2026-11-20

---

## 1. Executive Summary

Phase 2 transforms City Builder 2040 into a resilient, dynamic urban simulator with realistic natural disasters. Disasters are not visual effects or isolated mini-games; they directly impact the actual city, destroy buildings, block road networks, alter traffic route planning in real-time, stress city utility capacity, and impose measurable economic and civic happiness recovery costs.

All 5 core disaster archetypes (Earthquake, Fire, Flood, Storm, Heatwave) are fully modeled with distinct physics, radius equations, damage criteria, and recovery curves. The system integrates seamlessly with the Phase 1 Traffic Simulation network and the central economic simulation ticker.

---

## 2. Disaster Lifecycle

Every disaster strictly follows a 6-stage operational lifecycle:

```
Normal Conditions
       │
       ▼
1. Warning & Risk Assessment (3 ticks)
       │ • Early detection & citizen alerts
       │ • Fire stations, hospitals & first responders alerted
       ▼
2. Disaster Occurrence (2 ticks)
       │ • Physical damage applied to buildings in epicenter radius
       │ • Roads blocked (fallen debris, flood waters, structural collapse)
       │ • Fire spreads orthogonally to adjacent building tiles
       ▼
3. Emergency Response (4 ticks)
       │ • First responders mobilized
       │ • Disaster impact report generated & damage tallied
       ▼
4. Recovery & Reconstruction (8–20 ticks depending on severity)
       │ • Debris cleared, transit corridors reopened
       │ • Repair costs amortized over time
       ▼
5. Post-Disaster Completion & Archival
       │ • Active disaster cleared
       │ • Full post-disaster summary logged in permanent city history
```

---

## 3. Disaster Archetypes & Mechanics

### A. Earthquake (Seismic Structural Damage)
- **Epicenter & Radius**: Radial impact (3–10 tiles based on Minor → Catastrophic severity).
- **Building Damage**: Proximity-based damage curve ($1 - \frac{\text{dist}}{\text{radius}}$) with $\pm 10\%$ jitter. Closer buildings take 60–100% damage; older/lower-level buildings risk total collapse.
- **Road Network Impact**: 20–60% of roads within the radius become physically blocked by fissures and rubble.
- **Economic & Happiness**: Direct coin repair losses based on building levels and happiness penalty (-5 to -25).

### B. Fire (Spreading Conflagration)
- **Origin & Spread**: Ignites at a high-risk building (industrial or heavily polluted zone) and actively spreads each tick to orthogonal (N/S/E/W) neighbors based on severity intensity factor.
- **Building Damage**: Engulfed structures take 70–100% structural damage.
- **Road Network Impact**: Roads adjacent to burning structures are closed due to smoke and emergency vehicle staging.
- **Economic & Happiness**: High coin losses (-¢80 per building level $\times$ damage%) and heavy happiness penalties (-10 to -40).

### C. Flood (Hydrological Inundation)
- **Epicenter & Radius**: Expansive low-lying flood zone (5–15 tiles).
- **Road Network Impact**: 100% of road tiles in the flood radius are submerged and rendered impassable.
- **Building Damage**: Residential structures suffer 15–40% water damage and citizen displacement. High-rise towers suffer basement electrical damage.
- **Economic & Happiness**: Municipal drainage and water pumping costs (-¢20 per blocked tile), plus citizen displacement happiness loss (-8 to -35).

### D. Storm (Severe Gale & Lightning)
- **Epicenter & Radius**: Wind corridor (4–12 tiles).
- **Road Network Impact**: Downed power lines and fallen trees cause scattered road blockages (10–60% probability per tile).
- **Building Damage**: Structural roof damage to vulnerable buildings.
- **Economic & Happiness**: Grid disruption, debris cleanup costs, and -6 to -30 happiness penalty.

### E. Heatwave (City-Wide Utility & Health Stress)
- **Scope**: Entire city (radius = 0, no physical tile collapse).
- **Utility Surge**: Air conditioning causes an immediate spike of +15% to +60% in electricity consumption.
- **Environmental Stress**: Peaking power plants emit +4 to +22 extra pollution units.
- **Public Health Mitigation**: Happiness penalty (-8 to -38) is mitigated by up to 40% if city healthcare coverage rating is high (80–100%).

---

## 4. Traffic & Urban Simulation Integration

Disaster impacts directly feed into the Phase 1 transportation system:
1. **Dynamic Blocked Tiles**: All disaster-damaged road tiles are added to `RoadGraph.blockedTiles`.
2. **A\* Pathfinding Rerouting**: `RoadGraph.findCongestionAwarePath()` immediately excludes blocked tiles from graph edges, forcing private vehicles and emergency units onto peripheral bypass roads.
3. **Vehicle Evasion & Recovery**: Roaming vehicles encountering a blocked waypoint dynamically recalculate their destination route or execute safe turnarounds.
4. **Visual Roadblock Hazard**: Heatmap overlay (`paintTrafficHeatmap()`) renders an emergency red hazard "X" barrier across closed road segments.

---

## 5. Economic & Simulation Loop Integration

In `SimulationService.simulateTick()`:
- `DisasterEffects` carries tick-level penalties:
  - `happinessPenalty` directly depresses civic approval and migration.
  - `pollutionAdd` increases ambient pollution during fires and heatwaves.
  - `coinsLostThisTick` deducts disaster reconstruction costs from city treasury.
- Clear financial audit trails recorded as `ResourceTransaction` (type `demolitionRefund`, description: *"Disaster response & emergency reconstruction"*).

---

## 6. Architecture & File Manifest

### New Files Created
- `lib/models/disaster/disaster_models.dart`: Model layer (`DisasterType`, `DisasterPhase`, `DisasterSeverity`, `DisasterRiskLevel`, `DisasterConfig`, `AffectedBuilding`, `AffectedRoad`, `DisasterReport`, `ActiveDisaster`, `DisasterNotification`).
- `lib/game/disaster/disaster_engine.dart`: Central stateful simulation engine managing lifecycle, risk estimation, and updates.
- `lib/game/disaster/earthquake_disaster.dart`: Earthquake calculation routines and formulas.
- `lib/game/disaster/fire_disaster.dart`: Fire conflagration and orthogonal spreading mechanics.
- `lib/game/disaster/flood_disaster.dart`: Flood inundation and road submersion routines.
- `lib/game/disaster/storm_disaster.dart`: Storm gale, tree collapse, and debris calculation.
- `lib/game/disaster/heatwave_disaster.dart`: Heatwave power surge, health stress, and healthcare mitigation.
- `lib/providers/disaster_providers.dart`: Riverpod state management (`disasterEngineProvider`, `activeDisasterProvider`, `disasterRisksProvider`, `disasterNotificationsProvider`, `disasterHistoryProvider`, `disasterBlockedRoadsProvider`).
- `lib/widgets/game/disaster/disaster_panel.dart`: Full disaster UI dashboard, live emergency card, risk progress bars, incident history log, and manual scenario trigger panel.
- `test/game/disaster_simulation_test.dart`: Automated test suite covering models, all 5 disaster types, engine lifecycle, and road graph bypass.

### Modified Files
- `lib/game/urban/road_graph.dart`: Added `_blockedTiles`, `setBlockedTiles()`, `isBlocked()`, filtered `neighborsOf()`, and blocked edge rejection in `findCongestionAwarePath()`.
- `lib/game/urban/urban_simulation_service.dart`: Added `disasterBlockedRoads` to `update()`, dynamic vehicle bypass on encountering disaster roadblocks.
- `lib/game/urban/urban_art.dart`: Added red hazard roadblock barrier rendering in `paintTrafficHeatmap()`.
- `lib/services/simulation_service.dart`: Added `DisasterEffects` model, applied disaster happiness penalties, extra pollution, reconstruction costs, and audit transactions.
- `lib/providers/economy_providers.dart`: Wired `disasterEngine.update()` into the simulation ticker, synchronized blocked roads, and passed `disasterEffects` to `simulateTick()`.
- `lib/models/game_section.dart`: Added `GameSection.disasters`.
- `lib/widgets/game/game_navigation.dart`: Added `Icons.warning_amber_rounded` for disasters section.
- `lib/widgets/game/section_panel.dart`: Added `DisasterPanelView` integration.
- `lib/screens/game/game_shortcuts.dart`: Added digit 6 shortcut key for Disasters section.
- `lib/widgets/game/shortcut_hints.dart`: Updated controls cheat sheet to `'1 - 6', 'Open a section'`.
- `docs/PROJECT_MASTER.md`: Added V2 Phase 02 status and handoff link.

---

## 7. Testing & Verification

Run the automated test suite:
```powershell
flutter test test/game/disaster_simulation_test.dart
```

### Manual Testing in Game:
1. Open the game and press **6** (or tap the Warning icon in navigation).
2. The Disaster Management panel displays real-time risk gauges.
3. Select an intensity in the **Scenario & Stress Testing** panel and tap any disaster (e.g. **Earthquake** or **Fire**).
4. An emergency warning banner appears with siren alerts.
5. In the **Occurring** phase, damaged buildings and blocked roads appear on the map.
6. Open the road heatmap (**T** key) to view closed roads marked with hazard indicators.
7. Notice traffic vehicles actively taking bypass routes around blocked segments.
8. In the **Recovery** phase, blocked roads reopen and a full post-disaster report is logged in the incident history.
