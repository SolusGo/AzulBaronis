# Changelog

All notable changes to Azul Baronis are documented here.

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
