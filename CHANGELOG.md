# Changelog

All notable changes to Azul Baronis are documented here.

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
