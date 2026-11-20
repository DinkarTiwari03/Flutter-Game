# Handoff: Immediate Building-Driven Urban Life Simulation

## Overview
This feature transforms the urban life simulation from milestone/population-delayed activation into **immediate construction-driven life**. As soon as the player constructs even a single building (e.g., small house, retail shop, or factory), pedestrians and vehicles immediately spawn and navigate the connected road network.

---

## Key Behaviors

### 1. Instant Activation on First Placement
- **No Population Threshold Required**: Previously, empty cities or initial construction had zero registered demographic population, delaying activity. The simulation now adopts an effective population formula:
  $$\text{effectivePopulation} = \max(\text{residentialBuildings} \times 4, \text{population})$$
- Minimum entity caps are bound to active non-road structures:
  - $\text{minVehicles} = \text{nonRoadCount.clamp}(1, 3)$
  - $\text{minPedestrians} = \text{nonRoadCount.clamp}(2, 5)$

### 2. Category-Specific Staggered Spawn Burst
When `UrbanSimulationService.notifyBuildingPlaced` is invoked, the service identifies the nearest road tile and enqueues staggered spawn events over 0.5–4.0 seconds:
- **Residential**:
  - 2–3 Citizens walking on sidewalks
  - 1 Bicycle or Motorcycle
  - 1 Personal Sedan
- **Commercial**:
  - 1 Shopper or Office Worker
  - 1 Commercial Delivery Van
- **Industrial**:
  - 1 Construction Worker
  - 1 Cargo Truck or Flatbed Truck
- **Civic (Public Services)**:
  - Hospital $\rightarrow$ Ambulance
  - Police Station $\rightarrow$ Police Cruiser
  - Fire Station $\rightarrow$ Fire Engine
  - School $\rightarrow$ 2 Students + City School Bus
- **Environment**:
  - 2 Park Visitors walking near green spaces

### 3. Graceful Demolition & Natural Lifecycle
- When a building is demolished (`notifyBuildingDemolished`), the internal activity record is cleaned up.
- Already-spawned entities continue along their road path and despawn naturally rather than abruptly popping out of existence.
- Demolished roads prune vehicles and pedestrians occupying that specific deleted tile.

---

## Architectural Changes

1. **`UrbanSimulationService`** (`lib/game/urban/urban_simulation_service.dart`):
   - Added `_BuildingActivity` internal tracking for entity attribution per building.
   - Added `_PendingSpawn` queue with `_drainPendingSpawns(dt)` executing staggered spawn events without blocking the 60 FPS update loop.
   - Added `notifyBuildingPlaced(Building building)` and `notifyBuildingDemolished(String buildingId)`.
   - Updated `_attemptSpawns` with building-driven effective population and minimum entity caps.

2. **`CityBuildingsNotifier`** (`lib/providers/building_providers.dart`):
   - Hooked `ref.read(urbanSimulationProvider).notifyBuildingPlaced(placed)` into `placeBuilding`.
   - Hooked `ref.read(urbanSimulationProvider).notifyBuildingDemolished(buildingId)` into `demolishBuilding`.

---

## Automated Verification

Test file: `test/game/building_driven_urban_simulation_test.dart`
- **Scenario 1**: Placing small house immediately enqueues staggered spawns; after simulation ticks, personal vehicles (bicycle/motorcycle/sedan) and citizens are walking.
- **Scenario 2**: Placing second house scales population/activity with unique IDs.
- **Scenario 3**: Placing shop spawns shopper and delivery van.
- **Scenario 4**: Placing factory spawns worker and cargo/flatbed truck.
- **Scenario 5**: Placing civic structures (hospital, school) spawns emergency vehicles and buses.
- **Scenario 6**: Demolition removes activity tracking while maintaining natural entity movement.
- **Scenario 7**: Cities with only roads and no buildings do not trigger non-road building minimums.
