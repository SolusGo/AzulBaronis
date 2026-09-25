# Azul Baronis — One Ship Among Many

![The Azul Baronis fleet above a planetary horizon](Art/Preview/AzulBanner.png)

Azul Baronis is a deliberately asymmetric civilization for **Sid Meier's Civilization V: Brave New World** and **Community Patch 5.3.2+**. It discards the conventional military upgrade tree. Instead, named spacecraft remain in service for the whole game and refit themselves to exact statistics whenever Azul enters a new Era.

The working leader name is **The Player**. It is intentionally isolated behind `LEADER_AZUL_THE_PLAYER` and `TXT_KEY_LEADER_AZUL_THE_PLAYER`, making a later rename straightforward.

## Unique ability: One Ship Among Many

Exactly one Fighter or Destroyer is **★ Player Controlled**. That ship receives +1 Movement, +1 Sight, +25% Experience, and Afterburner—but no Combat Strength bonus. The designation can change only after the current vessel is destroyed or deliberately Self Destructs.

- Fighter Afterburner adds 2 Movement for the current turn.
- Destroyer Afterburner adds 1 Movement for the current turn.
- Afterburner consumes the ship's attack and has a persistent three-turn cooldown.
- Extra-attack promotions cannot bypass that consumption; earned promotions are restored on the next turn.
- If the Player Ship is lost, Fleet Systems highlights every surviving eligible vessel at the beginning of the next turn.

## Fleet

| Hull | First Era | Move | Range | Battlefield role |
| --- | --- | ---: | ---: | --- |
| Fighter | Ancient | 3 Ancient; 4 Classical+ | 1 | High-damage glass-cannon skirmisher, pursuit, city capture, air superiority |
| Destroyer | Renaissance | 3 | 2/3 | Mobile heavy ranged platform with two exclusive weapons |
| Testudon | Industrial | 1 | 3 | Era-capped super-heavy siege and fleet anchor |

Every traversable land or Coast tile costs one Movement. The fleet never Embarks. Ocean becomes legal at Astronomy and Mountains at Flight. Fighters ignore enemy Zone of Control; Destroyers, Testudons, and Fleet Commanders obey it normally.

Player Controlled adds +1 Movement, so the Player Fighter has 4 Movement in the Ancient Era and 5 Movement from the Classical Era onward.

### Fleet Comms

Azul's ships now have a compact, short-lived radio feed inspired by the original game's allied chatter. Fighters receive persistent `Alpha01`, `Alpha02`, … callsigns; Destroyers use `Delta01`, … and quieter Testudons use `Testudon-01`, …. Callsigns are not unit names. A ★ appears beside the current Player Controlled ship in the feed and moves with the designation, not the callsign.

Ships occasionally react to confirmed kills, damage, losses, near-defeated enemies, heavy targets, city assaults, and their special weapons. Testudons speak rarely; the Main Cannon uses a separate `FLEET SYSTEMS` voice. The feed holds up to four messages and fades after eight seconds. It appears only for the active Azul player, hides in City View, and also hides during Fleet Systems targeting or confirmation. The Fleet Systems HUD no longer has a general map-only visibility gate, so it may remain visible over other screens. Every line in this mod is newly written in the style of the original comms, not a quotation from it.

Callsigns and confirmed lifetime kills are stored under new save keys and carried across Era refits. Existing v3 saves assign identities to surviving ships on first load without recreating them; past kills cannot be reconstructed and begin at zero. The atmospheric system changes no combat statistics or rules.

Fighters receive **Dogfighter** while they retain Movement: +10% defense against ranged attacks and a 5% chance to evade one completely. They may move after attacking. Their offense is concentrated in high Ranged Combat Strength, while their deliberately low normal Combat Strength makes exposed Fighters easy to punish.

Fighters also intercept hostile aircraft through Community Patch's native system while remaining land-domain map units. Their interception radius is 3 tiles, with a 100% base chance at full health and +100% interception-only strength; damage lowers the chance under normal CP rules. A regular Fighter can intercept once per turn, and the ★ Player Controlled Fighter twice. A Player Controlled Destroyer gets no interception benefit. These air-only modifiers do not improve attacks against land or naval targets.

Destroyers choose one weapon per turn, even if another mod grants Logistics, Blitz, or extra attacks:

- **Forward Beam:** the ordinary range-2 ranged strike with line of sight and normal defenses.
- **Homing Bomb:** range 3, 115% current Ranged Strength, indirect fire, terrain-defense compensation, and a persistent three-turn cooldown.

Testudons cannot attack after moving and cannot move after attacking. **Focused Beam** compensates for half of positive defensive modifiers when attacking units while preserving the target's base strength. **Super-Heavy Siege** makes each successful ranged city attack deal at least 25%/27%/30%/33% of the city's maximum HP in the Industrial/Modern/Atomic/Information Eras. Native combat can deal more; neither the native shot nor the supplemental damage can take a city below 1 HP, so Capture City is still required. Their Super-Heavy Hull takes 20% less ranged damage, resists forced retreat, and cannot be captured or converted. Capacity is 1/2/3/4 in Industrial/Modern/Atomic/Information.

All three combat hulls remain genuine ranged units. When adjacent to a hostile city at its ranged-damage threshold, the Fleet Systems **Capture City** action invokes Civ V's conquest acquisition path, including resistance, occupation decisions, original-owner history, and diplomatic consequences.

## The Mothership

Azul's original Capital is permanently recorded as the true Mothership. Its Mothership Core is a full Palace replacement: it retains the Palace's +3 Production, +3 Science, +3 Gold, +1 Culture, and AI flavors, then adds +50 City HP, +15% City Ranged Strike Strength, +1 Sight, and two exclusive production processes.

**Charge Main Cannon** converts the Capital's exact production—including fractional hundredths—into a persistent Era-scaled battery. At full charge, **Fire Main Cannon** can instantly destroy a visible hostile combat unit within five tiles. Cities, civilians, Great People, and based aircraft are invalid targets. Firing empties the battery and consumes the Capital's city attack.

The Main Cannon's Era requirements are 260/360/500/700/950/1,275/1,675/2,175 Production from Ancient through Information.

**Construct Defensive Turret** fills a second exact-production meter. One completed turret may be stored and manually deployed on a confirmed legal tile within three tiles of the Mothership. Turrets are physical, stationary, destroyable, era-scaling range-2 units that can fire once each turn, with a maximum of four.

If the original Mothership is captured, both meters reset, all deployed turrets are destroyed, and the emergency Capital receives an ordinary Palace. The civilization, fleet refits, and Player Ship system continue. Retaking the original city restores its Core with empty batteries.

## Fleet Commander and military restrictions

The **Fleet Commander** replaces the Great General without changing its aura, generation, stacking, or Citadel rules. It has 3 Movement and Azul traversal, but cannot fight or capture cities.

When the optional Super Civs DC pack is active, Azul excludes Joker's ordinary Clown from the Community Patch's earned-General selection. This does not change Joker's units or require the DC pack, and works with existing Azul v3 saves; Clowns already spawned in a save remain as they are.

Azul may build ordinary civilian, trade, religious, archaeological, and economic Great Person units. Conventional military, recon, naval, air, nuclear, Great Admiral, and modded combat-tree units are filtered out by default. The normal starting escort becomes exactly one Ancient Fighter; the standard Settler remains.

## Era statistics

### Fighter

| Era | CS | RCS | Production |
| --- | ---: | ---: | ---: |
| Ancient | 4 | 8 | 65 |
| Classical | 5 | 12 | 85 |
| Medieval | 8 | 18 | 115 |
| Renaissance | 11 | 26 | 150 |
| Industrial | 16 | 37 | 205 |
| Modern | 24 | 55 | 285 |
| Atomic | 34 | 77 | 385 |
| Information | 47 | 105 | 510 |

### Destroyer

| Era | CS | RCS | Production |
| --- | ---: | ---: | ---: |
| Renaissance | 28 | 36 | 360 |
| Industrial | 40 | 52 | 475 |
| Modern | 58 | 74 | 630 |
| Atomic | 82 | 104 | 825 |
| Information | 110 | 138 | 1,060 |

### Testudon

| Era | CS | RCS | Production | Capacity | Minimum city HP damage |
| --- | ---: | ---: | ---: | ---: | ---: |
| Industrial | 65 | 85 | 900 | 1 | 25% |
| Modern | 90 | 118 | 1,175 | 2 | 27% |
| Atomic | 120 | 158 | 1,500 | 3 | 30% |
| Information | 155 | 205 | 1,875 | 4 | 33% |

## Installation

1. Install Brave New World and Community Patch 5.3.2 or newer.
2. Open `AzulBaronis.civ5proj` in ModBuddy and choose **Build Solution** (or use the checked-in `.modinfo` package source directly).
3. Confirm **Azul Baronis — One Ship Among Many (v 3)** appears in the Civ V `MODS` folder.
4. Enable Community Patch first, then Azul Baronis, and begin a new game.

The mod is single-player only because its custom target selectors and save-data state are not network synchronized for multiplayer.

## Repository map

- `SQL/00_Azul_Core.sql` — civilization, hulls, exact stats, Palace/processes, promotions, AI flavors.
- `SQL/10_Azul_Text.sql` — English UI, Civilopedia, diplomacy, and strategy text.
- `Lua/Azul_Gameplay.lua` — persistent mechanics, battle hooks, era replacement, AI, restrictions.
- `UI/Azul_FleetPanel.*` — dashboard, targeting, confirmation, highlighting, and actions.
- `Art/Icons` and `Art/Loading` — Civ V-compatible DDS civilization, leader, hull, ability, process, map, and Dawn of Man textures.
- `Art/README.md` — atlas index assignments and source-art manifest.
- `IMPLEMENTATION_NOTES.md` — technical design and engine integration details.
- `TESTING.md` — manual in-game regression matrix.
- `Tools/build_art.py` — deterministic PNG-to-DDS atlas builder for the supplied artwork.
- `Tools/build_unit_flags.py` — rebuilds the separate 32px Fighter, Destroyer, and Testudon map-flag atlas from `Art/Sources/Flags`.
- `Tools/validate_database.py` — database, art, project, and package validation against a Civ V debug DB.

The mod ships a complete custom 2D presentation: civilization and alpha symbols, The Player, every fleet hull, ability/process portraits, Mothership panels, and Dawn of Man. Fighter, Destroyer, and Testudon also have separate custom map unit-flag silhouettes; their large production/Civilopedia portraits remain unchanged. No new 3D meshes are shipped; the Fighter, Destroyer, Testudon, and turret reuse the Jet Fighter, Missile Cruiser, Battleship, and Mobile SAM art definitions respectively while remaining map-moving land-domain ranged units.
