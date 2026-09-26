# Changelog

All notable changes to Azul Baronis are documented here.

## Azul airborne world models — package v3 (2026-09-26)

### Changed

- Destroyers now use an Azul-only copy of the Stealth Bomber world-art chain instead of Missile Cruiser art. Testudons use an Azul-only copy of the three-member American B-17 heavy-bomber chain instead of Battleship art; each B-17 model is 1.5× its original scale (0.10 → 0.15).
- Jet Fighter world art, custom unit flags, large portraits, base-game art definitions, gameplay rows, save keys, mod ID, and package version remain unchanged. Existing Azul v3 saves can reuse their current units with the new art references.

## Event-driven Azul HUD visibility — package v3 (2026-09-26)

### Fixed

- Fleet Systems and Fleet Comms now hide for City View, leader diplomacy, popup-backed overviews and screens, Civilopedia bulk-UI mode, and city plot/purchase interface modes, then restore on return to the map.
- Removed idle HUD polling. Screen changes are handled by Civ V events; controls change visibility only when their state differs. Fleet Comms runs its frame callback only while a message is fading.
- Entering another screen safely closes transient targeting/confirmation while retaining the dashboard's open state. Gameplay, save keys, mod ID, and package version remain unchanged.

## Rollback of map-only Azul HUD — package v3 (2026-09-26)

### Changed

- Restored the prior Fleet Systems visibility behavior and removed the 0.1-second scan of other UI contexts after a reported FPS regression while panning the normal map.
- Kept the Testudon siege HUD text and all gameplay, unit art, Fleet Comms, save keys, mod ID, and package version unchanged. The HUD may again remain visible over some alternate screens.

## Main-map-only Azul HUD — package v3 (2026-09-26)

### Fixed

- Fleet Systems, targeting/confirmation panels, the Testudon count, and Fleet Comms now hide outside the normal map view and return when the player exits city, diplomacy, policy, culture, technology, Civilopedia, overview, menu, or popup screens.
- A shared visibility gate preserves Azul-player eligibility and open-panel state. No gameplay data, persistent save keys, mod ID, or package version changed.

## Custom fleet map flags — package v3 (2026-09-25)

### Changed

- Fighter, Destroyer, and Testudon now use supplied custom white-alpha silhouette symbols on their in-game unit flags across every Era row.
- Their large production, unit-panel, tooltip, and Civilopedia portraits are unchanged. No gameplay fields, unit Type names, save keys, mod ID, or package version changed; existing v3 saves retain their ships.

## Super-Heavy Siege city damage floor — package v3 (2026-09-25)

### Changed

- Replaced the prior percentage-based Testudon city Ranged Strength bonus, which underperformed against extremely strong cities, with a minimum of 25%/27%/30%/33% of city max HP removed per successful Industrial/Modern/Atomic/Information ranged shot.
- Native ranged combat remains authoritative when it deals more. Only the missing city HP is added, capped so a city never falls below 1 HP from the supplemental effect; Azul's Capture City action remains necessary.
- Unit-target Focused Beam and all Testudon stats, costs, movement restrictions, caps, and AI behavior are unchanged. Existing package-v3 saves gain the new runtime rule without changing units, saved keys, or package version.

## Fleet Comms — package v3 (2026-09-25)

### Added

- Short, contextual, newly written allied radio chatter for ship damage, losses, confirmed kills and milestones, near-defeated enemies, heavy contacts, city assaults/capture, Homing Bomb, Afterburner, Testudon fire, Main Cannon fire, and confirmed aircraft interceptions.
- Persistent `Alpha##`, `Delta##`, and `Testudon-##` callsigns and per-ship lifetime confirmed-kill totals. The ★ marker follows the Player Controlled designation without changing the ship's callsign.
- A four-line Fleet Comms feed that fades after eight seconds and hides during city management, Fleet Systems targeting, and non-Azul turns. Routine chatter is throttled to one line per Azul turn; all chatter is capped at three lines per turn.
- Additive first-load migration for existing v3 ships; callsigns, kills, and chatter cooldowns transfer through Era refits. Previous kills cannot be reconstructed, so migrated ships start at zero.

No combat values, gameplay RNG, database identifiers, or package version changed.

## Fighter air superiority — package v3 (2026-09-25)

### Added

- All Azul Fighters are native land-domain interceptors with radius 3, 100% full-health base interception chance, +100% interception-only strength, and one interception per turn.
- The ★ Player Controlled Fighter gains a second interception through CP's existing Sortie promotion; Player Controlled Destroyers do not.
- Existing Fighters receive the required CP promotions on save load, creation, and refit. Ground combat, Fighter IDs, saved `AZUL_*` keys, and package version remain unchanged.

## Joker Great General interoperability — package v3 (2026-09-24)

### Fixed

- Azul opts out of Joker's ordinary Clown unit class when the DC pack supplies it with a Great General promotion. This prevents the Community Patch's unit-order scan from spawning a Clown in place of an earned Fleet Commander.
- Joker's units, promotions, and own civilization remain unchanged; the fix is conditional and adds no DC pack dependency.
- Existing saves remain compatible under the same package version. Already-spawned Clowns are not changed retroactively.

## Unobstructed deployment selector — package v3 (2026-09-23)

### Changed

- Fleet Systems now collapses its large dashboard while selecting a turret tile or other confirmed target.
- Repositioned and compacted the target selector at the upper-right so the camera-centered candidate remains visible.
- Confirming, cancelling, or pressing Escape restores the dashboard exactly when it was previously open.

Package/ModBuddy version remains **v3**; gameplay, database identifiers, and save data are unchanged.

## Defensive Turret deployment hotfix — package v3 (2026-09-23)

### Fixed

- Restored Defensive Turret deployment in Community Patch UI contexts where the `UnitAITypes` global is unavailable. Turrets now initialize using their database-defined `UNITAI_RANGED` default.
- Made Fleet Systems target highlighting independent of the optional `Vector2` constructor and tolerant of a missing `Vector4` constructor, keeping turret, Main Cannon, Homing Bomb, and city-capture selectors functional.
- Added regression validation for both runtime compatibility failures.

Package/ModBuddy version remains **v3** and all existing save keys, including stored completed turrets, are unchanged.

## Fighter glass-cannon rebalance — package v3 (2026-09-22)

### Changed

- Rebalanced Fighter CS/RCS to 4/8, 5/12, 8/18, 11/26, 16/37, 24/55, 34/77, and 47/105 from Ancient through Information.
- Reduced Dogfighter ranged defense from +25% to +10% and complete evasion from 10% to 5%.
- Reframed the Fighter as a high-damage glass-cannon skirmisher whose offense comes primarily from Ranged Combat Strength and whose low normal Combat Strength punishes exposure.

### Unchanged

- Fighter Movement, move-after-attacking, Ignore ZOC, traversal, Afterburner, production costs, range, and Player Controlled bonuses are unchanged.
- Package/ModBuddy version remains **v3** and existing `AZUL_*` save keys are unchanged.

## Reliability maintenance — package v3 (2026-09-21)

### Fixed

- Explicitly enables the Community Patch event groups required for Azul movement gating, battle modifiers, unit-death cleanup, and unit-creation enforcement.
- Verifies fleet city capture ownership after `AcquireCity` before consuming the capturing vessel or displaying a success message.
- Clears the Main Cannon's temporary ordinary-shot blocker when an unfinished battle is superseded by another battle.
- Preserves guarded unit `ScriptData` during Era refits for better compatibility with external mods.
- Makes Era refits transactional: a partially restored replacement is removed while the original hull and saved UnitID state remain intact.
- Clarifies Ancient versus Classical+ Fighter Movement and effective Player Controlled Movement in the README.

### Validation

- Adds hard failures for disabled/missing required CP event switches and source-contract checks for capture ownership, abnormal battle cleanup, ScriptData migration, and safe refit ordering.

Package/ModBuddy version remains **v3** and existing `AZUL_*` save keys are unchanged.

## Balance maintenance — package v3 (2026-09-05)

### Changed

- Ancient Fighter Movement reduced from 4 to 3; later Fighter refits retain 4 Movement.
- Fighter Production increased to 65/85/115/150/205/285/385/510 by Era.
- Destroyer Production increased to 360/475/630/825/1,060 by Era.
- Testudon Production increased to 900/1,175/1,500/1,875 by Era.
- Homing Bomb reduced from 125% to 115% Ranged Strength.
- Testudon ranged damage reduction reduced from 25% to 20%.
- Main Cannon requirements increased to 260/360/500/700/950/1,275/1,675/2,175 by Era.

Existing v3 save keys and meter migration are unchanged; no package/mod version was bumped.

## [1.1.2] - 2026-09-04

This maintenance release remains **ModBuddy/package v3**; no version number was changed.

### Fixed

- Enables Community Patch `CanMoveInto` dispatch on every live Azul map unit, closing the `CanMoveAllTerrain` loophole that allowed Ocean and Mountain entry before Astronomy and Flight.
- Gives immobile Defensive Turrets one internal action point so they can make their range-2 attack while still being unable to move.
- Replaces every internal class's live default with one hidden, untrainable safety row, preventing later-loaded civilizations from inheriting Azul hulls.
- Stores Main Cannon and turret construction in hundredths of Production, preserving fractional city output exactly and migrating existing v3 whole-point meters automatically.
- Makes Destroyer weapons and Afterburner consume the entire attack allowance for the turn, including attacks granted by Logistics, Blitz, or other modded promotions; suppressed earned promotions return next turn and survive Era refits/save-load.
- Restricts Homing Bomb and AI target selection to visible units and includes hostile city-states and barbarians in eligible target scans.
- Enforces Testudon's no-attack-after-moving rule from the actual movement event instead of an allow-only ranged-attack hook.
- Calculates Focused Beam against total positive defensive strength modifiers, including promotions and other non-terrain bonuses.
- Audits entire Testudon order queues and cancels excess orders above the Era cap instead of checking only each city's head order.
- Stops AI Mothership processes when their current strategic condition ends, preventing permanent turret/cannon production lock-in.
- Dismisses illegally granted Great Admirals instead of converting them into duplicate Fleet Commanders with copied Admiral state.
- Avoids empty Player Ship prompts while no eligible vessel exists and opens selection immediately when a replacement is created.
- Makes the starting escort deterministic across rulesets by excluding any inherited Warrior row before adding exactly one Warrior-class Fighter.

### Validation

- Adds explicit checks for action-capable immobile turrets, all 26 movement-gated Azul units, late-load-safe internal defaults, every Palace-associated secondary table, and the unchanged v3 package identity.

## [1.1.1] - 2026-09-04

### Fixed

- Explicitly grants Azul a Warrior-class starting escort, which resolves to the Ancient Fighter under Community Patch configurations where the America template supplies only a Settler.
- Re-encodes every icon atlas as uncompressed 32-bit RGBA DDS, fixing blank portraits in Civ V's 45px production interface.
- Gives internal Era classes concrete default units and null overrides for non-Azul civilizations, preventing Community Patch's production tooltip from indexing a missing default while keeping the hulls Azul-exclusive.
- Removes the inherited Washington Dawn of Man audio so Azul's loading screen is silent.
- Restores the Mothership Core's complete Palace-linked economy and AI flavors, including +3 Production, +3 Science, +3 Gold, and +1 Culture.

### Changed

- ModBuddy/package version advanced to **v 3** so Civ V installs the corrected release separately from the cached v2 build.

## [1.1.0] - 2026-09-04

### Added

- Full supplied-art integration through native DXT5 atlases for the civilization, alpha symbol, leader, Fighter, Destroyer, Testudon, Defensive Turret, Fleet Commander, Main Cannon, Player Controlled ability, Afterburner, and Homing Bomb.
- Custom 1024×768 Dawn of Man and 512×512 civilization map textures derived from the fleet loading artwork.
- One-turn **Afterburner Engaged** promotion marker so the Afterburner portrait appears as live gameplay feedback.
- Deterministic `Tools/build_art.py` atlas generator, art manifest, README fleet banner, and exact DDS header/dimension validation.

### Changed

- ModBuddy/package version advanced to **v 2**, with all 32 DDS runtime textures imported into Civ V's virtual file system.
- Mothership Core, custom processes, all Era hulls, and signature promotions now use Azul-specific portraits instead of Firaxis placeholder icons.

## [1.0.0] - 2026-09-04

### Added

- Complete ModBuddy-ready Azul Baronis civilization and working leader identity.
- One Ship Among Many Player Ship designation, transfer flow, confirmed Self Destruct, bonuses, and persistent Afterburner cooldown.
- Eight Fighter, five Destroyer, four Testudon, and eight Defensive Turret internal Era hulls with exact requested statistics and invisible state-preserving refits.
- Hover traversal across land and Coast, Astronomy-gated Ocean, Flight-gated Mountains, flat tile cost, no Embarkation, and class-specific Zone of Control behavior.
- Fighter Dogfighter ranged defense and pre-combat 10% evasion.
- Exclusive Destroyer Forward Beam/Homing Bomb weapon flow with native ranged combat, 125% strength, range 3, indirect fire, defense compensation, and cooldown.
- Testudon Focused Beam, ranged damage reduction, anti-retreat restoration, anti-capture protection, no attack after moving, and Era capacity limits.
- Proper conquest-based Capture City action for all three ranged hulls.
- Original-city-bound Mothership Core, +50 HP, +15% city ranged strength, +1 sight, loss/recapture lifecycle, and ordinary emergency Capitals.
- Production-powered persistent Main Cannon and Defensive Turret meters, confirmed targets/placement, four-turret limit, and instant-kill cannon.
- Fleet Commander Great General replacement with original aura/Citadel behavior and Azul traversal.
- Conventional military filtering, Fighter starting escort, Great Admiral conversion prevention, AI fleet-ratio guidance, automatic AI weapons, cannon, and turret support.
- Compact Fleet Systems dashboard with live cooldowns, meters, capacity, selected-vessel actions, map highlighting, and confirmations.
- Community Patch dependency, project/package metadata, database validator, implementation notes, and full test checklist.
