# In-game testing checklist

Use Brave New World, Community Patch 5.3.2+, a new game, and Lua/database logging. Test Standard speed first, then one non-Standard speed.

## Database and setup

- [ ] Mod activates with no `Database.log` errors.
- [ ] Azul and The Player appear in civilization selection.
- [ ] Civilization selection, loading/Dawn of Man, map panel, and leader list use the Azul crest, fleet scene, and The Player portraits with no magenta or missing textures.
- [ ] Azul's Dawn of Man screen plays no inherited Washington audio or music.
- [ ] Civilopedia and production panels show custom Fighter, Destroyer, Testudon, Turret, Commander, Main Cannon, and turret-process portraits at every UI size.
- [ ] Start contains one Settler and one Fighter, no Warrior or Scout.
- [ ] Initial Fighter is automatically ★ Player Controlled.
- [ ] Conventional and modded combat-tree units are absent from production; civilian/trade/religious units remain.

## Traversal

- [ ] Fighter, Destroyer, Testudon, and Fleet Commander move across land and Coast for one Movement per tile without Embarking.
- [ ] Ocean is blocked immediately before Astronomy and legal immediately after.
- [ ] Mountains are blocked immediately before Flight and legal immediately after, including ending the turn there.
- [ ] Fighter ignores enemy Zone of Control; Destroyer, Testudon, and Fleet Commander do not.

## Player Ship and Fighter

- [ ] Player promotion grants exactly +1 Movement, +1 Sight, +25% XP, and no CS/RCS.
- [ ] Fighter Afterburner adds 2 Movement, consumes attack, and counts down 3/2/1/Ready across turns and save/load.
- [ ] Destroyer Afterburner adds 1 Movement under the same rules.
- [ ] Afterburner Engaged displays its custom promotion icon for the activation turn and clears at the next owner turn.
- [ ] Selection cannot switch freely while the Player Ship survives.
- [ ] Self Destruct asks for confirmation, kills the hull, and opens replacement selection.
- [ ] Enemy destruction opens replacement selection next turn; no eligible vessel leaves the UA dormant until one is created.
- [ ] Moving Fighter retains normal ZoC generation while ignoring enemy ZoC.
- [ ] Ranged attacks against an unmoved Fighter show Dogfighter defense; repeated trials produce zero-damage evades near 10%.

## Era refits and production

- [ ] Enter each Era by research and verify every existing hull's exact CS/RCS.
- [ ] Verify names, XP, level, promotions, damage, Movement/attack state, Player Ship, and cooldowns survive refit.
- [ ] Verify current production menu shows only the current Era hull at the stated cost.
- [ ] Cross an Era while producing a hull and verify invested Production is retained with the new total.

## Destroyer and Testudon

- [ ] Forward Beam uses range 2, line of sight, terrain defense, and permits post-attack movement.
- [ ] Homing Bomb highlights hostile combat targets within 3, fires through obstruction, gains 25% RCS, ignores tile defense, starts a 3-turn cooldown, and prevents Forward Beam that turn.
- [ ] Player Controlled and Homing Bomb display their supplied custom icons in promotion/Civilopedia contexts.
- [ ] Forward Beam prevents Homing Bomb that turn.
- [ ] Testudon cannot attack after any movement and cannot move after firing.
- [ ] Focused Beam is stronger specifically against positive terrain/fortification defense without editing base target strength.
- [ ] Testudon takes 25% less ranged damage, cannot be captured/converted, and returns to its tile after forced-retreat effects.
- [ ] Testudon production cap is 1/2/3/4 from Industrial through Information and a death reopens the slot.

## City conquest

- [ ] Ranged attacks cannot normally occupy a city.
- [ ] Adjacent Fighter/Destroyer/Testudon sees Capture City only when a hostile city is at maximum damage.
- [ ] Confirmation creates normal conquest resistance and annex/puppet/raze flow, retains original owner, and applies diplomacy/warmonger logic.
- [ ] Capturing ship loses all Movement and attack availability.

## Mothership

- [ ] Only the original Capital has Mothership Core, +50 HP, +15% ranged strike, and the extra sight ring.
- [ ] The Mothership Core retains the Palace's +3 Production, +3 Science, +3 Gold, and +1 Culture from turn 1.
- [ ] Both custom processes are visible only in that city.
- [ ] Charge Main Cannon adds full city Production and retains partial energy through order switches and save/load.
- [ ] Era/game-speed requirements match UI.
- [ ] Full cannon highlights visible hostile combat units within 5, never cities/civilians/Great People/based aircraft.
- [ ] Confirmed fire instantly kills the target, empties the battery, and consumes the city attack.
- [ ] Turret construction persists, stores exactly one ready turret, and cannot be bought.
- [ ] Deployment highlights only empty legal plots within 3, confirms before spawning, and permits Coast/Ocean/Mountain only when currently legal.
- [ ] Turrets have 0 Movement, range 2, one attack, no capture, current Era stats, and a maximum of four.
- [ ] Capturing the Mothership clears meters, destroys turrets, removes Core/sight, and leaves Azul alive if another city exists.
- [ ] Emergency Capital has ordinary Palace and no weapon systems.
- [ ] Recapture restores the Core only in the original city with empty meters and no turrets.

## AI and logs

- [ ] AI Azul expands before charging continuously in the early game.
- [ ] AI fleet trends toward Fighter/Destroyer mix and fills Testudons without exceeding cap.
- [ ] AI maintains at least two turrets, attempts four while at war, uses Homing Bombs/city capture, and fires cannon at valuable targets.
- [ ] Save, reload, advance an Era, and repeat actions with no `Lua.log` errors or duplicate units.
