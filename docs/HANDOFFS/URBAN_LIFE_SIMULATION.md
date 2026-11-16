# Phase Handoff: Pedestrian, Traffic & Urban Life Simulation

## 1. Overview
The **Urban Life Simulation** transforms City Builder 2040 from a static city grid into a vibrant, living metropolis. As citizens move in and buildings are constructed, pedestrians walk along sidewalks, cars cruise down avenues, buses and delivery vans transport goods and citizens, and specialized municipal vehicles (ambulances, police cars, fire engines) respond to city needs.

---

## 2. Core Features Implemented

### A. Pedestrian Simulation
- **6 Citizen Archetypes (`PedestrianType`):**
  - **Citizen:** Regular city dwellers in residential districts.
  - **Office Worker:** Business professionals walking between transit and commercial towers.
  - **Student:** Youth walking to and from schools during daylight hours.
  - **Shopper:** Consumers visiting shops and shopping malls.
  - **Park Visitor:** Relaxing citizens walking in city parks and botanical gardens.
  - **Construction Worker:** High-visibility workers operating near construction and upgraded sites.
- **Dynamic Behaviors:**
  - **Sidewalk Snapping:** Pedestrians offset laterally (`sidewalkOffset = 11.0` px) from road tile centers, walking along sidewalks rather than the middle of the street.
  - **Walking Animation:** 3-frame animated stride cycle (~0.36s frequency) with directional sprite sheets.
  - **Building Transitions:** Smooth alpha fading (fade-in on exit, fade-out on enter) simulating entering and leaving buildings.
  - **Idle Pauses:** Periodic pauses at scenic locations, street corners, and shop entrances.

### B. Vehicle & Traffic Simulation
- **19 Vehicle Types across 5 Categories (`VehicleType` & `VehicleCategory`):**
  - **Personal Transport:** Sedan, Sports Car, SUV, Motorcycle, Bicycle.
  - **Public Transit:** City Bus, Taxi.
  - **Commercial & Logistics:** Delivery Van, Flatbed Delivery, Utility Van, Cargo Truck, Flatbed Truck, City Sanitation (Garbage Truck).
  - **Emergency & Municipal:** Police Cruiser, Ambulance, Fire Engine.
  - **Construction Transport:** Bulldozer (Tractor), Excavator, Cement Mixer.
- **Road Network & Pathfinding (`RoadGraph`):**
  - Reconstructs orthogonal adjacency graph dynamically from placed `road` tiles.
  - Breadth-First Search (BFS) pathfinding between origin and destination structures.
  - Smart wandering turn resolution: favors straight-ahead travel, resolves intersections, and eliminates erratic 180-degree U-turns unless reaching dead ends.
- **Traffic Physics & Etiquette:**
  - **Right-Hand Lane Offset:** Computed perpendicular to movement vector via `CompassDirection.rightHandOffset` (offsetting vehicles ~5.0 px to the right-hand lane).
  - **Following Distance & Anti-Collision:** Trailing vehicles monitor vehicles ahead in the same lane and decelerate or brake when approaching slower traffic.
  - **Intersection Yielding:** Vehicles yield briefly (0.4–1.2s pause) at busy 3-way and 4-way intersections.

### C. Building-Specific Urban Activity
- **Residential Spawns:** Citizens and personal vehicles originate from houses, apartments, and residential towers.
- **Commercial Spawns:** Shoppers and delivery vans travel to shops, supermarkets, and malls.
- **Industrial Spawns:** Cargo trucks, flatbeds, and sanitation trucks circulate around factories and industrial facilities.
- **Civic Spawns:**
  - **Hospitals:** Periodically deploy high-priority Ambulances with custom flashing beacons.
  - **Schools:** Generate student pedestrian traffic and transit vehicles during daytime hours.
  - **Police & Fire Stations:** Deploy emergency response vehicles.
  - **Parks:** Draw park visitors into adjacent sidewalks and green spaces.

### D. Day & Night Diurnal Cycles
- Connected to `SimulationClock` (`DayPhase`):
  - **Morning / Daytime:** Peak traffic and pedestrian activity; students commute; commercial delivery vehicles active.
  - **Evening / Dusk:** Commuters return home; nightlife shifts around commercial districts.
  - **Night:** Traffic density drops; active vehicles turn on illuminated radial headlight beams and red glowing taillights rendered onto the isometric road surface.

---

## 3. Architecture & File Structure

| File | Purpose |
|---|---|
| `lib/game/urban/compass_direction.dart` | 4 cardinal 2.5D directions (`ne`, `nw`, `se`, `sw`), grid deltas, right-hand lane normal vectors, and velocity angle mapping. |
| `lib/game/urban/road_graph.dart` | Orthogonal adjacency graph of road tiles, intersection detection, BFS shortest path, and turn resolution. |
| `lib/game/urban/vehicle.dart` | `Vehicle` model with lane offset, cruising speed, wait timers, and 2.5D world position interpolation. |
| `lib/game/urban/pedestrian.dart` | `Pedestrian` model with walk stride frame timing, idle timers, entrance/exit alpha fading, and sidewalk positioning. |
| `lib/game/urban/urban_sprite_registry.dart` | Maps vehicle types, directions, and pedestrian animation frames to bundled asset paths. |
| `lib/game/urban/urban_sprite_cache.dart` | Asynchronous image cache preventing UI thread stalls when loading sprites. |
| `lib/game/urban/urban_art.dart` | Canvas rendering utility handling vehicle and pedestrian sprite draw calls, night headlights/taillights, and procedural geometric fallbacks. |
| `lib/game/urban/urban_simulation_service.dart` | Centralized `ChangeNotifier` service executing vehicle/pedestrian updates, spacing logic, and building-proximity spawns. |
| `lib/providers/urban_providers.dart` | Riverpod provider exposing `UrbanSimulationService`. |
| `lib/game/components/building_painter.dart` | Unified depth-sorted painter interleaving buildings, vehicles, and pedestrians in correct isometric z-order. |
| `lib/widgets/game/map_viewport.dart` | Ticker-driven per-frame urban simulation loop integrated with viewport repaint. |

---

## 4. Visual Assets & Licensing

All sprites are bundled locally in the application without runtime network downloads:
- **Vehicle Assets (`assets/vehicles/`):**
  - **Kenney Car Kit (v1.4, CC0):** Sedan, Sports Car, SUV, Taxi, Delivery Van, Flatbed Delivery, Cargo Truck, Flatbed Truck, Garbage Truck, Utility Van, Tractor/Bulldozer, Excavator, Police, Ambulance, Firetruck (4 isometric angles each).
  - **Custom Pixel Sprites:** Bus, Motorcycle, Bicycle, Cement Mixer (4 isometric angles each).
- **Pedestrian Assets (`assets/pedestrians/`):**
  - 72 custom isometric citizen sprites (6 archetypes × 4 directions × 3 walk animation frames).
- **Procedural Fallback:** In the event an image is loading or unavailable, `UrbanArt` renders crisp isometric vector graphics with shadows and role-based coloring.

---

## 5. Performance & Constraints

- **Centralized Tick:** Single ticker in `MapViewport` updates all entities at clamped delta time ($0.001 \le dt \le 0.05$s).
- **Pooled Capacities:** Configured caps (`maxVehicles = 22`, `maxPedestrians = 35`) guarantee 60 FPS on mobile (Android) and desktop (Windows).
- **Unified Depth Sorting:** Single `O(N log N)` sort in `BuildingPainter` renders terrain, buildings, vehicles, and pedestrians with zero z-fighting or popping.
- **Zero External Dependencies:** Implemented purely in Flutter/Dart CustomPainter without third-party physics or game engine libraries.
