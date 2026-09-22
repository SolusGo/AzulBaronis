# Patch Notes

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
