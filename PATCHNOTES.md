# Patch Notes

## Fighter air superiority — package v3 — 2026-09-25

- Azul Fighters intercept hostile aircraft within 3 tiles, with 100% base chance at full health and +100% interception-only strength. A regular Fighter intercepts once per turn; the Player Controlled Fighter intercepts twice.
- No new promotion IDs or save keys. Existing Fighters gain the role when loading a v3 save; normal combat stats and package version are unchanged.

## Testudon city-siege scaling — package v3 — 2026-09-24

- City attacks now gain +10%/+20%/+35%/+50% temporary Ranged Strength in the Industrial/Modern/Atomic/Information Eras.
- Normal-unit attacks, unit stats, saved state, and the package version are unchanged.

## Joker Great General interoperability — package v3 — 2026-09-24

- Fixed earned Azul Great Generals appearing as Joker's ordinary Clown when the Super Civs DC pack is enabled.
- The fix is Azul-only and conditional; Joker gameplay, existing units, save keys, and the package version are unchanged.

## Unobstructed deployment selector — package v3 — 2026-09-23

- The large Fleet Systems dashboard now collapses while choosing a turret tile or other target.
- The compact selector sits at the upper-right instead of covering the camera-centered map position.
- Confirm, Cancel, and Escape restore the prior panel state; saves and the package version are unchanged.

## Defensive Turret deployment hotfix — package v3 — 2026-09-23

- Fixed completed Defensive Turrets failing to spawn because `UnitAITypes` is not exposed in every Community Patch Lua context.
- Fixed Fleet Systems target selectors repeatedly failing when the optional `Vector2` UI constructor is unavailable.
- Stored completed turrets and existing saves remain compatible; the package version was not changed.

## Fighter glass-cannon pass — package v3 — 2026-09-22

- Shifted Fighter power from normal Combat Strength into Ranged Combat Strength across all eight Eras.
- Reduced Dogfighter to +10% ranged defense and 5% complete evasion.
- Preserved all Fighter mobility, move-after-attacking, Ignore ZOC, traversal, Afterburner, range, production, and Player Controlled mechanics.
- No package-version or save-key changes.

## Package v3 reliability pass — 2026-09-21

- Enabled Azul's required Community Patch event groups, including the global `CanMoveInto` dispatch needed by Ocean and Mountain gates.
- Hardened fleet city capture, abnormal battle cleanup, and transactional Era refits.
- Era refits now preserve compatible third-party unit `ScriptData`.
- Added automated coverage for the new runtime contracts without changing balance, save keys, or the package version.

## Version 1 — Player-only civilization selection — 2026-09-06

- Set Azul Baronis to remain human-playable while preventing the AI from selecting it.
