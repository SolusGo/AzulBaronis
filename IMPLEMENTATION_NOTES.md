# Implementation notes

## Runtime target

Azul Baronis targets Brave New World with Community Patch 5.3.2 (mod version 150) or newer. The CP DLL is not bundled. The dependency is declared in both ModBuddy project metadata and the generated `.modinfo`.

Database activation explicitly enables the four opt-in CP event groups the controller requires: `EVENTS_CAN_MOVE_INTO`, `EVENTS_BATTLES`, `EVENTS_UNIT_PREKILL`, and `EVENTS_UNIT_CREATED`. Other registered hooks used by Azul are base or always-available CP hooks and do not have a separate `CustomModOptions` switch.

## Art pipeline

The 12 supplied PNGs are converted by `Tools/build_art.py` into five native atlas families plus Dawn of Man and map panels. UI portraits use uncompressed 32-bit RGBA DDS so Civ V can reliably load non-power-of-two 45px sheets; the large loading panels use DXT5. The civilization crest also produces a luminance-derived white alpha atlas for Civ V's tintable map and score-list symbol contexts.

The Dawn of Man panel deliberately sets `DawnOfManAudio` to `NULL`; no Firaxis leader narration or inherited Washington music is played over Azul's loading artwork.

Atlas dimensions match the Firaxis sizes used by each database object: civilization color 256/128/80/64/45/32, civilization alpha 128/64/48/32/24/16, and leader/unit/ability sizes 256/128/80/64/45/32. Unit portraits occupy indexes 0–4 (Fighter, Destroyer, Testudon, Turret, Commander); ability portraits occupy indexes 0–3 (Main Cannon, Player Controlled, Afterburner, Homing Bomb). All 32 DDS files have `ImportIntoVFS=True`.

Afterburner applies a stat-neutral visible promotion when used and clears it at the start of the owner's next turn. Attack-granting promotions are temporarily recorded and suppressed when Afterburner is engaged, then restored on the next owner turn. The lock state and promotion record use stable save keys and transfer across an Era refit.

## Era refits

Each displayed hull is a family of Era-specific internal `Units` rows. `PlayerDoTurn` and `TeamTechResearched` reconcile the owner's current Era. Replacement snapshots and restores coordinates, custom name, damage, XP, level, earned promotions, remaining Movement, attack state, temporary attack lock, Player Ship designation, both custom cooldowns, and guarded unit `ScriptData` used by compatible external mods. The replacement is restored inside a protected transaction; if creation or restoration fails, the partial replacement is removed and the original hull and persistent keys remain intact. Player Ship identity moves immediately before the original is removed, and old UnitID keys are cleared only after the refit commits. Queued ship production is moved to the current hull's production bucket before the head order is replaced.

Every internal `UNITCLASS_AZUL_*` points at one hidden, cost-`-1` safety unit by default. Azul exposes its live hull through civilization overrides; already-loaded non-Azul civilizations receive explicit null overrides. A civilization loaded after Azul therefore resolves the inert default instead of inheriting a trainable spacecraft.

Destroyer and Testudon database rows use Agriculture as a neutral prerequisite; the runtime Era gate is their sole unlock, so entering Renaissance or Industrial makes the corresponding hull available regardless of the particular technology used to cross the Era boundary. This avoids percentage-promotion drift and makes both availability and database values in the gameplay specification exact.

Fighter balance is intentionally asymmetric: normal Combat Strength remains well below Ranged Combat Strength in every Era, making the hull a high-damage skirmisher that is severely punished when exposed. Movement, move-after-attacking, Ignore ZOC, traversal, and the Player Controlled movement bonus are unchanged.

## Combat hooks

### Fleet Comms

Fleet Comms uses `Modding.OpenSaveData` with new per-player `COMMS_NEXT_*` counters and per-unit `COMMS_SIGN`, `COMMS_KILLS`, and `COMMS_LAST_TURN` keys. Existing saved ships are scanned in UnitID order on initialization; existing callsigns are preserved, counters advance past them, and only missing signs are assigned. The refit transaction copies these fields to the replacement before killing the old hull, then retires the old UnitID's fields only after commit. A failed refit leaves the original state intact. Physical ship death retires its callsign; counters never decrement. No visible unit name is edited.

Confirmed-kill credit comes from battle-participant identities at `UnitPrekill`, matching the dying combat unit against the current defender or attacker and crediting only the opposing surviving Azul ship (including an interceptor if CP supplies role 2). The lifetime count increments independently of whether a line is shown. Damage, city assault, and successful interception chatter compare pre/post battle damage; failed air interceptions do not speak. Because CP battle roles and callback ordering can vary by attack type, kills outside a matched battle callback are deliberately not guessed or reconstructed. Main Cannon kills are system announcements, not ship kills.

Line selection and frequency use Lua's separate `math.random`, not `Game.Rand`, to avoid perturbing gameplay RNG. Routine chatter is at most one per Azul turn with a 30% base chance; Testudons have a 9% routine chance. Important chatter has a higher chance, but total messages are capped at three per turn and each ship may speak once per turn. The feed is ephemeral, keeps four lines for eight seconds, and hides while the dashboard/selector/confirmation/city screen is open. Chatter is emitted only for the active human Azul player; AI Azul still receives persistent callsigns and kill totals. All new lines are original writing inspired by, not copied from, the original game's radio style.

- Homing Bomb grants a hidden range/indirect/+15% promotion for one native `RangeStrike`, then removes it both on return and at `BattleFinished` as a defensive fallback. Targets must be visible because the native CP range-strike path rejects unrevealed units even when indirect fire is active.
- Positive defense is countered by generated one-percentage-point hidden ranged-strength steps. Compensation is scaled against the attacker's current effective Ranged Strength, so earned promotions are retained: Homing Bomb offsets full positive tile defense after its 115% modifier, while Focused Beam derives total defense from `GetMaxDefenseStrength` and uses the mathematically equivalent multiplier for ignoring half of all positive defensive modifiers. Base target Combat Strength is never edited.
- A Testudon attacking a city uses the same temporary strength-step promotions for a city-only +10%/+20%/+35%/+50% siege modifier. The amount is keyed to the attacking hull's Industrial/Modern/Atomic/Information unit type, including after an Era refit; attacks against units continue to use only the existing Focused Beam defense formula. Native ranged-city combat resolves the hit. `BattleFinished` or the interrupted-battle cleanup removes the temporary promotion, so it cannot affect a later attack. Human and AI Testudons share this path.
- Afterburner and either Destroyer weapon call one attack-exhaustion path. It records and removes any `Blitz`/`ExtraAttacks` promotion for the rest of the turn, preventing promotion stacking from violating weapon exclusivity, and restores those promotions at the next owner turn.
- Dogfighter's +10% ranged defense is attached between `BattleJoined` and `BattleFinished`. A pre-combat 5% roll adds CP's multiplicative `DamageTakenMod = -100` for that battle, producing a true zero-damage evade even against an otherwise lethal hit.
- Fighter air superiority uses the CP land-interceptor path: `AirInterceptRange=3` on the existing eight Fighter rows, plus existing `PROMOTION_INTERCEPTION_IV` (100% chance at full health) and `PROMOTION_INTERCEPTION_1/2/3` (+100% interception-only strength). CP gives units one interception by default and scales chance with current HP. Because land interceptors use normal Combat Strength rather than Ranged Combat Strength for interception damage, the three combat-only promotions counter the Fighter's deliberately low CS without changing its ground attacks. The Player Controlled Fighter alone receives existing `PROMOTION_SORTIE` for one extra interception. No new promotion types are inserted, avoiding shifts to saved promotion IDs. Free grants cover new Fighters; `SyncFighterInterception` repairs existing saved Fighters on initialization/turn/creation/refit and transfers Sortie on Player Ship changes. The unit remains `DOMAIN_LAND` and `UNITAI_RANGED`; no manual aircraft damage or Air Patrol action is used.
- Starting a new battle defensively clears every temporary participant from an unfinished prior battle, including the Main Cannon's ordinary-city-shot blocker, so a missed `BattleFinished` callback cannot leak temporary immunity.
- A ranged attack against a Testudon temporarily applies `DamageTakenMod = -20`, yielding the exact requested damage reduction without also reducing melee damage. A surviving defender is returned to its recorded tile if a battle effect displaced it, countering CP morale-retreat mechanics.
- Testudon movement is recorded through `UnitSetXY`, which fires before the DLL deducts movement points. A real coordinate change exhausts attacks immediately; this avoids relying on `UnitCanRangeAttackAt`, an allow-only Community Patch hook that cannot veto an otherwise legal strike.

## Traversal

All spacecraft and the Fleet Commander use `CanMoveAllTerrain` plus `FlatMovementCost`. Because the DLL otherwise short-circuits impassability when `CanMoveAllTerrain` is present, every live Azul map-unit row sets `SendCanMoveIntoEvent=1` and the database enables CP's global `EVENTS_CAN_MOVE_INTO` switch. `CanMoveInto` then explicitly rejects Ocean before Astronomy and Mountains before Flight. CP `CanCrossOceans` and `CanCrossMountains` promotions are synchronized with those technologies. These are land-domain map units and never invoke Embarkation.

Defensive Turrets use `Moves=1` with `Immobile=1`. Civ V requires positive remaining moves before a ranged unit is allowed to attack; `Immobile` prevents relocation while the internal action point permits one ranged strike. Deployment sets remaining moves to zero so a newly placed turret cannot fire immediately.

Naval 3D art definitions are intentionally attached to land-domain units per the specification. Firaxis naval animations can clip on steep land at some camera angles; no replacement meshes or copied art definitions are introduced.

## Mothership identity and storage

The original Capital coordinates are written once to `Modding.OpenSaveData`. The Core is normalized every turn: it is free only in that city while Azul controls it. A replacement Capital receives an ordinary Palace. Capture removes the Core's active state, empties both meters, removes the sight ring, and kills every active Azul turret. Recapture restores only the Core.

Cloning the primary `Buildings` row is not sufficient to inherit a Palace. The Core also clones every live `Building_YieldChanges` and `Building_Flavors` row attached to `BUILDING_PALACE`. Under the supported Community Patch database this preserves +3 Production, +3 Science, +3 Gold, +1 Culture, and the Palace's Gold/Science/Culture AI priorities before Azul's unique defenses and systems are applied.

The two database `Processes` have no yield conversion rows. The controller reads `GetCurrentProductionDifferenceTimes100` while either is active and writes the exact hundredths to the appropriate persistent meter. Main Cannon requirements are 260/360/500/700/950/1,275/1,675/2,175 Production by Era; turret requirements are unchanged. Existing v3 whole-point save keys migrate to hundredths on first access and remain as a compatibility mirror.

The CP Lua API exposes the city ranged-attack flag for reading but not writing. Main Cannon therefore records an attack-consumed turn, refuses to fire after an ordinary city shot, and gives any unit targeted by a second ordinary Mothership shot zero damage for that battle. This preserves the one-effective-city-attack rule without shipping a custom DLL.

Mothership +1 Sight is implemented as a visibility-count ring exactly three plots from the original city, added only while Azul controls it and removed on loss.

## Conquest

Ranged hulls never receive a melee attack. The confirmed Capture City action verifies war, adjacency, hull eligibility, and maximum city damage, then calls `Player:AcquireCity(city, true, false)`. It re-reads the city plot and verifies the city now belongs to Azul before consuming the vessel's attack/movement or announcing success. The `true` conquest flag is what retains the normal occupation, original owner, resistance, diplomatic, and conquest decision flow.

## AI

Database flavors favor approximately 60% Fighters and 30% Destroyers. Runtime training gates prevent either family drifting far past 66%/36% once a mixed fleet is available. Testudons use their independent Era cap; the full order queue of every city is audited each turn and excess orders are cancelled, with a creation-time hard stop as a final invariant. AI turns automatically designate a Player Ship, consider visible Homing Bomb targets from every hostile player slot (including city-states and barbarians), take defeated adjacent cities, keep two turrets in peace/four during war, charge during productive wars, and reserve the cannon for the best visible target scored by cost, strength, XP, health, and proximity. Custom production is popped from the head queue when its strategic condition is no longer true so the Mothership cannot remain trapped in an obsolete process.

Great Admirals are prohibited by the training filter. If an external mod or event grants one anyway, the runtime dismisses it rather than converting it into a second Fleet Commander and accidentally carrying Great Admiral promotions or state into the Great General replacement.

With the optional Super Civs DC pack, the Community Patch's earned-General scan can encounter Joker's ordinary `UNIT_JOK_CLOWN` before `UNIT_AZUL_FLEET_COMMANDER`: the Clown is the default unit of `UNITCLASS_JOK_CLOWN` and has `PROMOTION_GREAT_GENERAL`. Azul conditionally adds a NULL override for that class, so `GetSpecificUnitType` rejects it for Azul while the later Fleet Commander remains eligible. The Joker database rows and existing saved units are not altered. This depends on the DC pack's class being loaded before Azul's SQL, as in the tested mod stack; no hard dependency is declared.

## Save compatibility

Custom state uses stable `AZUL_*` keys in `Modding.OpenSaveData`. Balance changes and reliability fixes do not rename or rescale any saved key; Fighter CS/RCS and Dogfighter values are database/runtime constants and apply safely when an existing save loads the updated mod. Era refits continue migrating `AFTERBURNER`, `HOMING`, `ATTACK_LOCK`, suppressed attack-promotion records, and `PLAYER_SHIP` from the old UnitID to the new one. The 1.1.2 maintenance fixes retain package version 3 and migrate earlier v3 meter values automatically. The mod affects saved games and should not be removed from an active campaign. Multiplayer and Hot Seat are disabled because custom UI requests are not serialized as multiplayer network missions.

The Testudon city-siege bonus is runtime-only: it does not add database rows, alter saved `AZUL_*` state, respawn existing units, or change refit identity. Existing v3 saves acquire the city-only effect on the next qualifying attack after loading the updated mod.
