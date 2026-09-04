# Implementation notes

## Runtime target

Azul Baronis targets Brave New World with Community Patch 5.3.2 (mod version 150) or newer. The CP DLL is not bundled. The dependency is declared in both ModBuddy project metadata and the generated `.modinfo`.

## Art pipeline

The 12 supplied PNGs are converted by `Tools/build_art.py` into five native atlas families plus Dawn of Man and map panels. UI portraits use uncompressed 32-bit RGBA DDS so Civ V can reliably load non-power-of-two 45px sheets; the large loading panels use DXT5. The civilization crest also produces a luminance-derived white alpha atlas for Civ V's tintable map and score-list symbol contexts.

The Dawn of Man panel deliberately sets `DawnOfManAudio` to `NULL`; no Firaxis leader narration or inherited Washington music is played over Azul's loading artwork.

Atlas dimensions match the Firaxis sizes used by each database object: civilization color 256/128/80/64/45/32, civilization alpha 128/64/48/32/24/16, and leader/unit/ability sizes 256/128/80/64/45/32. Unit portraits occupy indexes 0–4 (Fighter, Destroyer, Testudon, Turret, Commander); ability portraits occupy indexes 0–3 (Main Cannon, Player Controlled, Afterburner, Homing Bomb). All 32 DDS files have `ImportIntoVFS=True`.

Afterburner applies a stat-neutral visible promotion when used and clears it at the start of the owner's next turn. Attack-granting promotions are temporarily recorded and suppressed when Afterburner is engaged, then restored on the next owner turn. The lock state and promotion record use stable save keys and transfer across an Era refit.

## Era refits

Each displayed hull is a family of Era-specific internal `Units` rows. `PlayerDoTurn` and `TeamTechResearched` reconcile the owner's current Era. Replacement snapshots and restores coordinates, custom name, damage, XP, level, earned promotions, remaining Movement, attack state, temporary attack lock, Player Ship designation, and both custom cooldowns. Queued ship production is moved to the current hull's production bucket before the head order is replaced.

Every internal `UNITCLASS_AZUL_*` points at one hidden, cost-`-1` safety unit by default. Azul exposes its live hull through civilization overrides; already-loaded non-Azul civilizations receive explicit null overrides. A civilization loaded after Azul therefore resolves the inert default instead of inheriting a trainable spacecraft.

Destroyer and Testudon database rows use Agriculture as a neutral prerequisite; the runtime Era gate is their sole unlock, so entering Renaissance or Industrial makes the corresponding hull available regardless of the particular technology used to cross the Era boundary. This avoids percentage-promotion drift and makes both availability and database values in the gameplay specification exact.

## Combat hooks

- Homing Bomb grants a hidden range/indirect/+15% promotion for one native `RangeStrike`, then removes it both on return and at `BattleFinished` as a defensive fallback. Targets must be visible because the native CP range-strike path rejects unrevealed units even when indirect fire is active.
- Positive defense is countered by generated one-percentage-point hidden ranged-strength steps. Compensation is scaled against the attacker's current effective Ranged Strength, so earned promotions are retained: Homing Bomb offsets full positive tile defense after its 115% modifier, while Focused Beam derives total defense from `GetMaxDefenseStrength` and uses the mathematically equivalent multiplier for ignoring half of all positive defensive modifiers. Base target Combat Strength is never edited.
- Afterburner and either Destroyer weapon call one attack-exhaustion path. It records and removes any `Blitz`/`ExtraAttacks` promotion for the rest of the turn, preventing promotion stacking from violating weapon exclusivity, and restores those promotions at the next owner turn.
- Dogfighter's +25% ranged defense is attached between `BattleJoined` and `BattleFinished`. A pre-combat 10% roll adds CP's multiplicative `DamageTakenMod = -100` for that battle, producing a true zero-damage evade even against an otherwise lethal hit.
- A ranged attack against a Testudon temporarily applies `DamageTakenMod = -20`, yielding the exact requested damage reduction without also reducing melee damage. A surviving defender is returned to its recorded tile if a battle effect displaced it, countering CP morale-retreat mechanics.
- Testudon movement is recorded through `UnitSetXY`, which fires before the DLL deducts movement points. A real coordinate change exhausts attacks immediately; this avoids relying on `UnitCanRangeAttackAt`, an allow-only Community Patch hook that cannot veto an otherwise legal strike.

## Traversal

All spacecraft and the Fleet Commander use `CanMoveAllTerrain` plus `FlatMovementCost`. Because the DLL otherwise short-circuits impassability when `CanMoveAllTerrain` is present, every live Azul map-unit row sets `SendCanMoveIntoEvent=1`. `CanMoveInto` then explicitly rejects Ocean before Astronomy and Mountains before Flight. CP `CanCrossOceans` and `CanCrossMountains` promotions are synchronized with those technologies. These are land-domain map units and never invoke Embarkation.

Defensive Turrets use `Moves=1` with `Immobile=1`. Civ V requires positive remaining moves before a ranged unit is allowed to attack; `Immobile` prevents relocation while the internal action point permits one ranged strike. Deployment sets remaining moves to zero so a newly placed turret cannot fire immediately.

Naval 3D art definitions are intentionally attached to land-domain units per the specification. Firaxis naval animations can clip on steep land at some camera angles; no replacement meshes or copied art definitions are introduced.

## Mothership identity and storage

The original Capital coordinates are written once to `Modding.OpenSaveData`. The Core is normalized every turn: it is free only in that city while Azul controls it. A replacement Capital receives an ordinary Palace. Capture removes the Core's active state, empties both meters, removes the sight ring, and kills every active Azul turret. Recapture restores only the Core.

Cloning the primary `Buildings` row is not sufficient to inherit a Palace. The Core also clones every live `Building_YieldChanges` and `Building_Flavors` row attached to `BUILDING_PALACE`. Under the supported Community Patch database this preserves +3 Production, +3 Science, +3 Gold, +1 Culture, and the Palace's Gold/Science/Culture AI priorities before Azul's unique defenses and systems are applied.

The two database `Processes` have no yield conversion rows. The controller reads `GetCurrentProductionDifferenceTimes100` while either is active and writes the exact hundredths to the appropriate persistent meter. Main Cannon requirements are 260/360/500/700/950/1,275/1,675/2,175 Production by Era; turret requirements are unchanged. Existing v3 whole-point save keys migrate to hundredths on first access and remain as a compatibility mirror.

The CP Lua API exposes the city ranged-attack flag for reading but not writing. Main Cannon therefore records an attack-consumed turn, refuses to fire after an ordinary city shot, and gives any unit targeted by a second ordinary Mothership shot zero damage for that battle. This preserves the one-effective-city-attack rule without shipping a custom DLL.

Mothership +1 Sight is implemented as a visibility-count ring exactly three plots from the original city, added only while Azul controls it and removed on loss.

## Conquest

Ranged hulls never receive a melee attack. The confirmed Capture City action verifies war, adjacency, hull eligibility, and maximum city damage, then calls `Player:AcquireCity(city, true, false)`. The `true` conquest flag is what retains the normal occupation, original owner, resistance, diplomatic, and conquest decision flow.

## AI

Database flavors favor approximately 60% Fighters and 30% Destroyers. Runtime training gates prevent either family drifting far past 66%/36% once a mixed fleet is available. Testudons use their independent Era cap; the full order queue of every city is audited each turn and excess orders are cancelled, with a creation-time hard stop as a final invariant. AI turns automatically designate a Player Ship, consider visible Homing Bomb targets from every hostile player slot (including city-states and barbarians), take defeated adjacent cities, keep two turrets in peace/four during war, charge during productive wars, and reserve the cannon for the best visible target scored by cost, strength, XP, health, and proximity. Custom production is popped from the head queue when its strategic condition is no longer true so the Mothership cannot remain trapped in an obsolete process.

Great Admirals are prohibited by the training filter. If an external mod or event grants one anyway, the runtime dismisses it rather than converting it into a second Fleet Commander and accidentally carrying Great Admiral promotions or state into the Great General replacement.

## Save compatibility

Custom state uses stable `AZUL_*` keys in `Modding.OpenSaveData`. The balance nerfs change only database costs/modifiers and the mirrored cannon requirement arrays; they do not rename, clear, or rescale any saved key. The 1.1.2 maintenance fixes retain package version 3 and migrate earlier v3 meter values automatically. The mod affects saved games and should not be removed from an active campaign. Multiplayer and Hot Seat are disabled because custom UI requests are not serialized as multiplayer network missions.
