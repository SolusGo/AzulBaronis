# In-game testing checklist

Use Brave New World, Community Patch 5.3.2+, a new game, and Lua/database logging. Test Standard speed first, then one non-Standard speed.

## Event-driven Fleet HUD visibility (manual in-game verification)

- [ ] Load the same Azul v3 save used before the rollback and pan the normal map; compare FPS and frame pacing with the reverted build. No idle visibility timer or repeated context scan should run.
- [ ] Open and close Fleet Systems; enter and exit City View. The HUD hides and restores once, retaining the dashboard's open state.
- [ ] Repeat for diplomacy/leader, Tech Tree, policies/ideologies, Culture/Tourism, Religion, Espionage, Military/Economic/Trade/Victory overviews, and Civilopedia.
- [ ] Open/close each supported major popup repeatedly and nest two supported screens where Civ V permits it. The HUD remains hidden until the last supported major screen closes.
- [ ] Open ordinary notifications, minor popups, and a mod-added popup while on the map; they must not strand Fleet Systems hidden. If a supported popup close event is missed, the next Azul turn or active-player change recovers the button.
- [ ] Start Main Cannon, turret, Homing Bomb, city-capture, and Player Ship targeting, then open another supported screen. Target highlights clear, the selector closes, and the dashboard returns after the screen closes. Repeat with self-destruct confirmation and ensure it cannot fire unexpectedly afterward.
- [ ] Trigger Player Ship selection while a screen is open; the selector appears when normal map view returns.
- [ ] End a turn, change selected units, and switch to a non-Azul player; no HUD overlap or Lua error appears. A non-Azul player does not see Fleet Systems.
- [ ] Confirm that Fleet Comms still fades after eight seconds but the frame callback is inactive when no messages exist. The game menu may overlap the HUD because it has no reliable paired event here.

## Fleet Comms (manual in-game verification)

- [ ] New Fighters, Destroyers, and Testudons receive unique `Alpha##`, `Delta##`, and `Testudon-##` callsigns without changing visible unit names; dead signs are not reused.
- [ ] Load an older v3 save containing several ships. Existing ships receive missing signs exactly once, in UnitID order, without respawn, changed UnitID, cooldown reset, or changed Player Ship designation. Save/reload and confirm identities persist.
- [ ] Refit all three hull families; verify callsigns and confirmed-kill totals transfer. Force a failed refit in a disposable test copy and verify the old hull retains both fields.
- [ ] Change Player Controlled designation after loss. The ★ marker follows the new designated ship while both physical callsigns remain stable.
- [ ] Confirm a normal combat kill increments only the actual attacking ship's lifetime count; a defensive kill credits the defender. Main Cannon fire does not count as a ship kill. Non-combat deaths do not create false kill credit.
- [ ] Exercise heavy and critical damage, nearby ally assistance, allied Fighter/Destroyer/Testudon loss, nearly destroyed enemy, heavy target, city assault/near defeat/capture, Homing Bomb, Afterburner, Testudon fire/kill, and Main Cannon. Confirm each line matches its actual event and Testudon messages remain rare.
- [ ] Successfully intercept an aircraft with an Azul Fighter and verify chatter only if the aircraft actually takes damage. Failed interception and unrelated air-defense fire do not claim a kill.
- [ ] One combat sequence creates at most one line; routine chatter is at most once per Azul turn, total chatter at most three lines per turn, and consecutive lines from a category are not identical.
- [ ] The four-line feed fades after eight seconds, stays out of normal map interaction, and hides in city management and Fleet Systems/target selection. AI Azul or a non-Azul active human never sees AI chatter.
- [ ] Compare CS/RCS, movement, production, promotions, weapon behavior, and combat odds before/after; Fleet Comms changes no balance values and does not consume Civ V gameplay RNG.

## Database and setup

- [ ] Load an existing Azul v3 save with each hull. Fighter still uses Jet Fighter world art; Destroyer uses a single Stealth Bomber instead of Missile Cruiser; Testudon uses the enlarged three-B-17 heavy-bomber formation instead of Battleship. Compare their apparent sizes and inspect hills, coast, adjacent units, and combat for severe clipping.
- [ ] Refit Destroyer and Testudon across an Era; the same new world-art family persists while name, XP, promotions, cooldowns, Player Ship designation, and Testudon cap remain unchanged.
- [ ] In the same game, base-game Stealth Bomber and American B-17 art remains at normal scale. Confirm the unit Types, icons, flags, and production/Civilopedia portraits are unchanged.
- [ ] On the map, Fighter, Destroyer, and Testudon show their distinct supplied Azul silhouettes in the small unit flags. Check an existing v3 save and an Era-refitted hull for each family.
- [ ] Confirm production, unit panel, tooltips, and Civilopedia still show the original large colour portraits, not the new white flag symbols.

- [ ] Mod activates with no `Database.log` errors.
- [ ] `CustomModOptions` shows `EVENTS_CAN_MOVE_INTO`, `EVENTS_BATTLES`, `EVENTS_UNIT_PREKILL`, and `EVENTS_UNIT_CREATED` enabled after database activation.
- [ ] Azul and The Player appear in civilization selection.
- [ ] Civilization selection, loading/Dawn of Man, map panel, and leader list use the Azul crest, fleet scene, and The Player portraits with no magenta or missing textures.
- [ ] Azul's Dawn of Man screen plays no inherited Washington audio or music.
- [ ] Civilopedia and production panels show custom Fighter, Destroyer, Testudon, Turret, Commander, Main Cannon, and turret-process portraits at every UI size.
- [ ] Start contains one Settler and one Fighter, no Warrior or Scout.
- [ ] Initial Fighter is automatically ★ Player Controlled.
- [ ] Conventional and modded combat-tree units are absent from production; civilian/trade/religious units remain.
- [ ] A civilization loaded after Azul cannot train or display any internal Azul Era class.
- [ ] An externally granted Great Admiral is removed and does not become an extra Fleet Commander.
- [ ] With Super Civs DC enabled, earn a Great General as Azul: a Fleet Commander appears, never Joker's ordinary Clown. Reload an existing Azul v3 save and repeat; existing Clowns remain untouched.
- [ ] Without Super Civs DC enabled, Azul still earns a Fleet Commander and loads without a Joker dependency.

## Traversal

- [ ] Fighter, Destroyer, Testudon, and Fleet Commander move across land and Coast for one Movement per tile without Embarking.
- [ ] Ocean is blocked immediately before Astronomy and legal immediately after.
- [ ] Mountains are blocked immediately before Flight and legal immediately after, including ending the turn there.
- [ ] Repeat both gate tests with Fighter, Destroyer, Testudon, Turret, and Fleet Commander; `CanMoveAllTerrain` must not bypass either restriction.
- [ ] Fighter ignores enemy Zone of Control; Destroyer, Testudon, and Fleet Commander do not.

## Player Ship and Fighter

- [ ] Player promotion grants exactly +1 Movement, +1 Sight, +25% XP, and no CS/RCS.
- [ ] Fighter Afterburner adds 2 Movement, consumes attack, and counts down 3/2/1/Ready across turns and save/load.
- [ ] Destroyer Afterburner adds 1 Movement under the same rules.
- [ ] Grant Logistics/Blitz through FireTuner, activate Afterburner, and verify no native or alternate attack remains; verify the granted promotion returns next turn and after save/load/refit.
- [ ] Afterburner Engaged displays its custom promotion icon for the activation turn and clears at the next owner turn.
- [ ] Selection cannot switch freely while the Player Ship survives.
- [ ] Self Destruct asks for confirmation, kills the hull, and opens replacement selection.
- [ ] Enemy destruction opens replacement selection next turn; no eligible vessel leaves the UA dormant until one is created.
- [ ] Moving Fighter retains normal ZoC generation while ignoring enemy ZoC.
- [ ] Ranged attacks against an unmoved Fighter show exactly +10% Dogfighter defense; repeated trials produce zero-damage evades near 5%.
- [ ] A full-health Fighter within 3 tiles natively intercepts a hostile Fighter, Bomber, Jet Fighter, or Stealth Bomber air strike; a damaged Fighter has reduced interception chance under CP rules. At 4 tiles it does not intercept.
- [ ] A normal Fighter intercepts at most once per turn; the Player Controlled Fighter intercepts twice and the third eligible air strike is not intercepted by that same unit.
- [ ] Transfer Player Controlled identity to a new Fighter after loss: the old Fighter loses Sortie and the new Fighter receives it. Designate a Destroyer instead: it never receives Fighter interception promotions or Sortie.
- [ ] Load an existing v3 save containing Fighters; before any refit, confirm they gain range-3 interception and the current Player Controlled Fighter has two interceptions. Refit and repeat.
- [ ] Fighters remain land-domain range-1 map units with unchanged CS/RCS, movement, Afterburner, Dogfighter, traversal, and normal attacks against land/naval targets. AI Fighters also intercept automatically; based aircraft remain untargetable by direct ground fire.

## Era refits and production

- [ ] Enter each Era by research and verify Fighter CS/RCS is exactly 4/8, 5/12, 8/18, 11/26, 16/37, 24/55, 34/77, and 47/105 from Ancient through Information.
- [ ] At Renaissance 11/26 and Modern 24/55, verify Fighters hit hard at range but take severe damage when exposed; confirm movement, move-after-attacking, Ignore ZOC, and Afterburner are unchanged.
- [ ] Verify every Destroyer, Testudon, and turret retains its prior exact CS/RCS.
- [ ] Verify names, XP, level, promotions, damage, Movement/attack state, Player Ship, and cooldowns survive refit.
- [ ] Assign non-empty unit `ScriptData` through FireTuner and verify it survives both an ordinary and Player Ship Era refit; repeat with empty data.
- [ ] Force a refit restoration error in a disposable test copy and verify the partial replacement is removed while the original hull, Player Ship identity, cooldowns, attack lock, and suppressed-promotion state remain.
- [ ] Verify current production menu shows only the current Era hull at the stated cost.
- [ ] Cross an Era while producing a hull and verify invested Production is retained with the new total.

## Destroyer and Testudon

- [ ] Forward Beam uses range 2, line of sight, terrain defense, and permits post-attack movement.
- [ ] Homing Bomb highlights hostile combat targets within 3, fires through obstruction, gains 15% RCS (115% total), ignores tile defense, starts a 3-turn cooldown, and prevents Forward Beam that turn.
- [ ] Player Controlled and Homing Bomb display their supplied custom icons in promotion/Civilopedia contexts.
- [ ] Forward Beam prevents Homing Bomb that turn.
- [ ] Logistics/Blitz cannot produce a second Forward Beam or allow Forward Beam after Homing Bomb; the earned promotion returns next turn.
- [ ] Homing target selection excludes units in fog but includes visible hostile city-state and Barbarian units.
- [ ] Testudon cannot attack after any movement and cannot move after firing.
- [ ] Focused Beam is stronger against positive terrain, fortification, and promotion-based defense without editing base target strength.
- [ ] A successful Industrial/Modern/Atomic/Information Testudon shot removes at least 25%/27%/30%/33% of city max HP respectively, rounded to nearest integer and subject to the 1-HP city limit.
- [ ] Test 300-HP/33% (99 damage), 250-HP/33% (83), and 200-HP/30% (60). Compare city damage before and after, not combat strength or the UI's approximate prediction.
- [ ] Repeat against an extremely high-strength city, one with flat city-damage reduction, and one with a garrison absorbing damage. Each resolved shot still removes the floor amount of actual *city* HP unless the city is already within 1 HP of defeat.
- [ ] When native city damage exceeds the floor, verify no extra damage is added. When it falls short, verify only the shortfall is added.
- [ ] Attack a nearly defeated city. Supplemental damage never takes it below 1 HP; Capture City remains required and still produces normal conquest choices/resistance.
- [ ] Abort an attack, target an invalid/non-hostile city, change ownership before resolution in a disposable test, remove the attacker during combat, or cause zero native city damage: none receives a siege top-up.
- [ ] Fire several Testudons at the same city. Each qualifying shot independently applies its own floor, without a second fake attack or extra movement/attack allowance.
- [ ] Repeat with AI-controlled Azul Testudons; the same floor applies without special AI decisions.
- [ ] Compare attacks against ordinary units before/after the update: damage and Focused Beam's terrain/fortification/positive-defense compensation are unchanged, with no city-HP floor.
- [ ] After a city attack and after an interrupted battle, verify no hidden `PROMOTION_AZUL_BEAM_COMP_*` was applied for city siege and a later unit attack uses only the usual Focused Beam calculation.
- [ ] Load an existing package-v3 save with a Testudon, attack a city, then refit into the next Era and confirm the correct hull-tier floor applies without unit respawn, changed UnitID except the ordinary refit, or saved-state loss.
- [ ] A Testudon city shot produces at most the usual single Fleet Comms line, with CITY_NEAR based on final post-floor city HP. No supplemental-damage event creates kill credit.
- [ ] Testudon takes 20% less ranged damage, cannot be captured/converted, and returns to its tile after forced-retreat effects.
- [ ] Testudon production cap is 1/2/3/4 from Industrial through Information; queue several in multiple cities on the same turn and verify excess queued orders are cancelled without deleting legal progress.

## City conquest

- [ ] Ranged attacks cannot normally occupy a city.
- [ ] Adjacent Fighter/Destroyer/Testudon sees Capture City only when a hostile city is at maximum damage.
- [ ] Confirmation creates normal conquest resistance and annex/puppet/raze flow, retains original owner, and applies diplomacy/warmonger logic.
- [ ] Capturing ship loses all Movement and attack availability.
- [ ] In a disposable test copy, force `AcquireCity` to throw or return without transfer and verify the ship keeps its action and no success notification is shown.

## Mothership

- [ ] Only the original Capital has Mothership Core, +50 HP, +15% ranged strike, and the extra sight ring.
- [ ] The Mothership Core retains the Palace's +3 Production, +3 Science, +3 Gold, and +1 Culture from turn 1.
- [ ] Both custom processes are visible only in that city.
- [ ] Charge Main Cannon adds exact city Production, including fractional hundredths, and retains partial energy through order switches and save/load from both old and new v3 saves.
- [ ] Era/game-speed requirements match UI.
- [ ] Full cannon highlights visible hostile combat units within 5, never cities/civilians/Great People/based aircraft.
- [ ] Confirmed fire instantly kills the target, empties the battery, and consumes the city attack.
- [ ] Turret construction persists, stores exactly one ready turret, and cannot be bought.
- [ ] Deployment highlights only empty legal plots within 3, confirms before spawning, and permits Coast/Ocean/Mountain only when currently legal.
- [ ] Turrets are immobile, can make one range-2 attack on turns after deployment, cannot capture, use current Era stats, and have a maximum of four.
- [ ] Capturing the Mothership clears meters, destroys turrets, removes Core/sight, and leaves Azul alive if another city exists.
- [ ] Emergency Capital has ordinary Palace and no weapon systems.
- [ ] Recapture restores the Core only in the original city with empty meters and no turrets.

## AI and logs

- [ ] AI Azul expands before charging continuously in the early game.
- [ ] AI fleet trends toward Fighter/Destroyer mix and fills Testudons without exceeding cap.
- [ ] AI maintains at least two turrets, attempts four while at war, uses Homing Bombs/city capture, and fires cannon at valuable targets.
- [ ] When peace begins, turret cap is met, a ready turret cannot deploy, or a cannon battery fills without a target, AI exits the obsolete custom process and resumes ordinary production.
- [ ] Save, reload, advance an Era, and repeat actions with no `Lua.log` errors or duplicate units.
- [ ] Interrupt a battle callback sequence, begin another battle, and verify no stale Dogfighter, Focused Beam, Testudon reduction, Homing Bomb, or Main Cannon blocker promotion remains.
