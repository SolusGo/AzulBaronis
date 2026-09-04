# Implementation notes

## Runtime target

Azul Baronis targets Brave New World with Community Patch 5.3.2 (mod version 150) or newer. The CP DLL is not bundled. The dependency is declared in both ModBuddy project metadata and the generated `.modinfo`.

## Era refits

Each displayed hull is a family of Era-specific internal `Units` rows. `PlayerDoTurn` and `TeamTechResearched` reconcile the owner's current Era. Replacement snapshots and restores coordinates, custom name, damage, XP, level, earned promotions, remaining Movement, attack state, Player Ship designation, and both custom cooldowns. Queued ship production is moved to the current hull's production bucket before the head order is replaced.

Destroyer and Testudon database rows use Agriculture as a neutral prerequisite; the runtime Era gate is their sole unlock, so entering Renaissance or Industrial makes the corresponding hull available regardless of the particular technology used to cross the Era boundary. This avoids percentage-promotion drift and makes both availability and database values in the gameplay specification exact.

## Combat hooks

- Homing Bomb grants a hidden range/indirect/+25% promotion for one native `RangeStrike`, then removes it after `BattleFinished`.
- Positive tile defense is countered by generated one-percentage-point hidden ranged-strength steps. Compensation is scaled against the attacker's current effective Ranged Strength, so earned promotions are retained: Homing Bomb offsets full tile defense after its 125% modifier, while Focused Beam uses the mathematically equivalent multiplier for ignoring half of total positive tile plus fortification defense. Base target Combat Strength is never edited.
- Dogfighter's +25% ranged defense is attached between `BattleJoined` and `BattleFinished`. A pre-combat 10% roll adds CP's multiplicative `DamageTakenMod = -100` for that battle, producing a true zero-damage evade even against an otherwise lethal hit.
- A ranged attack against a Testudon temporarily applies `DamageTakenMod = -25`, yielding the exact requested damage reduction without also reducing melee damage. A surviving defender is returned to its recorded tile if a battle effect displaced it, countering CP morale-retreat mechanics.

## Traversal

All spacecraft and the Fleet Commander use `CanMoveAllTerrain` plus `FlatMovementCost`. `CanMoveInto` explicitly rejects Ocean before Astronomy and Mountains before Flight. CP `CanCrossOceans` and `CanCrossMountains` promotions are synchronized with those technologies. These are land-domain map units and never invoke Embarkation.

Naval 3D art definitions are intentionally attached to land-domain units per the specification. Firaxis naval animations can clip on steep land at some camera angles; no replacement meshes or copied art definitions are introduced.

## Mothership identity and storage

The original Capital coordinates are written once to `Modding.OpenSaveData`. The Core is normalized every turn: it is free only in that city while Azul controls it. A replacement Capital receives an ordinary Palace. Capture removes the Core's active state, empties both meters, removes the sight ring, and kills every active Azul turret. Recapture restores only the Core.

The two database `Processes` have no yield conversion rows. The controller reads current city Production while either is active and writes it to the appropriate persistent meter. Main Cannon and turret requirements use `GameSpeed.TrainPercent`.

The CP Lua API exposes the city ranged-attack flag for reading but not writing. Main Cannon therefore records an attack-consumed turn, refuses to fire after an ordinary city shot, and gives any unit targeted by a second ordinary Mothership shot zero damage for that battle. This preserves the one-effective-city-attack rule without shipping a custom DLL.

Mothership +1 Sight is implemented as a visibility-count ring exactly three plots from the original city, added only while Azul controls it and removed on loss.

## Conquest

Ranged hulls never receive a melee attack. The confirmed Capture City action verifies war, adjacency, hull eligibility, and maximum city damage, then calls `Player:AcquireCity(city, true, false)`. The `true` conquest flag is what retains the normal occupation, original owner, resistance, diplomatic, and conquest decision flow.

## AI

Database flavors favor approximately 60% Fighters and 30% Destroyers. Runtime training gates prevent either family drifting far past 66%/36% once a mixed fleet is available. Testudons use their independent Era cap, including other cities' active Testudon queues, with a creation-time hard stop as a final invariant. AI turns automatically designate a Player Ship, consider Homing Bomb targets, take defeated adjacent cities, keep two turrets in peace/four during war, charge during productive wars, and reserve the cannon for the best visible target scored by cost, strength, XP, health, and proximity.

## Save compatibility

Custom state uses stable `AZUL_*` keys in `Modding.OpenSaveData`. The mod affects saved games and should not be removed from an active campaign. Multiplayer and Hot Seat are disabled because custom UI requests are not serialized as multiplayer network missions.
