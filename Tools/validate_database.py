"""Validate Azul SQL, project metadata, UI XML, and packaged hashes."""

from __future__ import annotations

import hashlib
import re
import sqlite3
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "SQL" / "00_Azul_Core.sql"
TEXT = ROOT / "SQL" / "10_Azul_Text.sql"
MODINFO = ROOT / "Azul Baronis — One Ship Among Many (v 3).modinfo"

CP_COLUMNS = {
    "Units": {
        "SendCanMoveIntoEvent": "BOOLEAN DEFAULT 0",
    },
    "Buildings": {
        "CityRangedStrikeRange": "INTEGER DEFAULT 0",
        "CityIndirectFire": "BOOLEAN DEFAULT 0",
        "RangedStrikeModifier": "INTEGER DEFAULT 0",
    },
    "UnitPromotions": {
        "ChangeDamageValue": "INTEGER DEFAULT 0",
        "DamageTakenMod": "INTEGER DEFAULT 0",
        "CannotBeCaptured": "BOOLEAN DEFAULT 0",
        "CanCrossMountains": "BOOLEAN DEFAULT 0",
        "CanCrossOceans": "BOOLEAN DEFAULT 0",
        "ShowInUnitPanel": "BOOLEAN DEFAULT 1",
        "IsVisibleAboveFlag": "BOOLEAN DEFAULT 1",
    },
}

REQUIRED_CP_EVENT_OPTIONS = (
    "EVENTS_CAN_MOVE_INTO",
    "EVENTS_BATTLES",
    "EVENTS_UNIT_PREKILL",
    "EVENTS_UNIT_CREATED",
)

EXPECTED_HULLS = {
    "UNIT_AZUL_FIGHTER_ANCIENT": (4, 8, 65, 3, 1),
    "UNIT_AZUL_FIGHTER_CLASSICAL": (5, 12, 85, 4, 1),
    "UNIT_AZUL_FIGHTER_MEDIEVAL": (8, 18, 115, 4, 1),
    "UNIT_AZUL_FIGHTER_RENAISSANCE": (11, 26, 150, 4, 1),
    "UNIT_AZUL_FIGHTER_INDUSTRIAL": (16, 37, 205, 4, 1),
    "UNIT_AZUL_FIGHTER_MODERN": (24, 55, 285, 4, 1),
    "UNIT_AZUL_FIGHTER_ATOMIC": (34, 77, 385, 4, 1),
    "UNIT_AZUL_FIGHTER_INFORMATION": (47, 105, 510, 4, 1),
    "UNIT_AZUL_DESTROYER_RENAISSANCE": (28, 36, 360, 3, 2),
    "UNIT_AZUL_DESTROYER_INDUSTRIAL": (40, 52, 475, 3, 2),
    "UNIT_AZUL_DESTROYER_MODERN": (58, 74, 630, 3, 2),
    "UNIT_AZUL_DESTROYER_ATOMIC": (82, 104, 825, 3, 2),
    "UNIT_AZUL_DESTROYER_INFORMATION": (110, 138, 1060, 3, 2),
    "UNIT_AZUL_TESTUDON_INDUSTRIAL": (65, 85, 900, 1, 3),
    "UNIT_AZUL_TESTUDON_MODERN": (90, 118, 1175, 1, 3),
    "UNIT_AZUL_TESTUDON_ATOMIC": (120, 158, 1500, 1, 3),
    "UNIT_AZUL_TESTUDON_INFORMATION": (155, 205, 1875, 1, 3),
    "UNIT_AZUL_TURRET_ANCIENT": (8, 9, -1, 1, 2),
    "UNIT_AZUL_TURRET_CLASSICAL": (11, 14, -1, 1, 2),
    "UNIT_AZUL_TURRET_MEDIEVAL": (16, 20, -1, 1, 2),
    "UNIT_AZUL_TURRET_RENAISSANCE": (24, 30, -1, 1, 2),
    "UNIT_AZUL_TURRET_INDUSTRIAL": (34, 43, -1, 1, 2),
    "UNIT_AZUL_TURRET_MODERN": (50, 62, -1, 1, 2),
    "UNIT_AZUL_TURRET_ATOMIC": (72, 88, -1, 1, 2),
    "UNIT_AZUL_TURRET_INFORMATION": (98, 120, -1, 1, 2),
}

COLOR_SIZES = (256, 128, 80, 64, 45, 32)
ALPHA_SIZES = (128, 64, 48, 32, 24, 16)
DDS_EXPECTED: dict[str, tuple[int, int]] = {
    **{f"Art/Icons/AzulCivColor{size}.dds": (size, size) for size in COLOR_SIZES},
    **{f"Art/Icons/AzulCivAlpha{size}.dds": (size, size) for size in ALPHA_SIZES},
    **{f"Art/Icons/AzulLeader{size}.dds": (size, size) for size in COLOR_SIZES},
    **{f"Art/Icons/AzulUnits{size}.dds": (size * 4, size * 2) for size in COLOR_SIZES},
    **{f"Art/Icons/AzulAbilities{size}.dds": (size * 4, size) for size in COLOR_SIZES},
    "Art/Icons/AzulUnitFlags32.dds": (96, 32),
    "Art/Loading/AzulDawnOfMan.dds": (1024, 768),
    "Art/Loading/AzulMap512.dds": (512, 512),
}


def add_missing_cp_columns(database: sqlite3.Connection) -> None:
    """Mirror only CP columns touched by this mod when a debug DB is vanilla."""
    for table, columns in CP_COLUMNS.items():
        existing = {row[1] for row in database.execute(f'PRAGMA table_info("{table}")')}
        for name, declaration in columns.items():
            if name not in existing:
                database.execute(f'ALTER TABLE "{table}" ADD COLUMN "{name}" {declaration}')


def remove_existing_rows(database: sqlite3.Connection) -> None:
    """Make a copied live DB repeatable even if an earlier Azul build was active."""
    tables = [
        row[0]
        for row in database.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        )
    ]
    for table in tables:
        safe = table.replace('"', '""')
        columns = [row[1] for row in database.execute(f'PRAGMA table_info("{safe}")')]
        if not columns:
            continue
        filters = [f'CAST("{column.replace(chr(34), chr(34) * 2)}" AS TEXT) LIKE ?' for column in columns]
        database.execute(
            f'DELETE FROM "{safe}" WHERE ' + " OR ".join(filters),
            ["%AZUL%"] * len(filters),
        )


def require_one(database: sqlite3.Connection, table: str, type_name: str) -> None:
    count = database.execute(f"SELECT COUNT(*) FROM {table} WHERE Type=?", (type_name,)).fetchone()[0]
    if count != 1:
        raise AssertionError(f"{table}.{type_name} count is {count}, expected 1")


def validate_package() -> None:
    tree = ET.parse(MODINFO)
    root = tree.getroot()
    if root.attrib.get("id") != "8d3f20a4-cb82-4f3b-91ad-72fbcc357e61":
        raise AssertionError("unexpected mod id")
    if root.attrib.get("version") != "3":
        raise AssertionError("unexpected mod version")
    packaged = set()
    for node in tree.findall("./Files/File"):
        relative = (node.text or "").replace("\\", "/")
        packaged.add(relative)
        target = ROOT / relative
        if not target.is_file():
            raise AssertionError(f"modinfo references missing file: {relative}")
        actual = hashlib.md5(target.read_bytes()).hexdigest().upper()
        expected = (node.attrib.get("md5") or "").upper()
        if actual != expected:
            raise AssertionError(f"stale modinfo hash for {relative}: {expected} != {actual}")
        if relative.endswith(".dds") and node.attrib.get("import") != "1":
            raise AssertionError(f"DDS is not imported into VFS: {relative}")
    missing_art = set(DDS_EXPECTED) - packaged
    if missing_art:
        raise AssertionError(f"modinfo is missing DDS art: {sorted(missing_art)}")
    if "Art/Preview/AzulBanner.png" not in packaged:
        raise AssertionError("modinfo is missing the README banner")
    print("PASS package: all files exist and MD5 hashes match")


def validate_art_files() -> None:
    for relative, expected_size in DDS_EXPECTED.items():
        path = ROOT / relative
        if not path.is_file():
            raise AssertionError(f"missing DDS texture: {relative}")
        header = path.read_bytes()[:128]
        if len(header) < 128 or header[:4] != b"DDS ":
            raise AssertionError(f"invalid DDS header: {relative}")
        height, width = struct.unpack_from("<II", header, 12)
        if (width, height) != expected_size:
            raise AssertionError(f"DDS size mismatch for {relative}: {(width, height)} != {expected_size}")
        pixel_flags = struct.unpack_from("<I", header, 80)[0]
        rgb_bits = struct.unpack_from("<I", header, 88)[0]
        if relative.startswith("Art/Icons/"):
            if pixel_flags & 0x40 == 0 or rgb_bits != 32 or header[84:88] != b"\x00\x00\x00\x00":
                raise AssertionError(f"icon DDS is not uncompressed 32-bit RGBA: {relative}")
        elif header[84:88] != b"DXT5":
            raise AssertionError(f"loading DDS is not DXT5: {relative}")

    project = ET.parse(ROOT / "AzulBaronis.civ5proj")
    namespace = {"msb": "http://schemas.microsoft.com/developer/msbuild/2003"}
    content = {}
    for node in project.findall(".//msb:Content", namespace):
        relative = (node.attrib.get("Include") or "").replace("\\", "/")
        vfs = node.find("msb:ImportIntoVFS", namespace)
        content[relative] = vfs.text if vfs is not None else None
    missing = [relative for relative in DDS_EXPECTED if content.get(relative) != "True"]
    if missing:
        raise AssertionError(f"project DDS VFS entries missing or false: {missing}")
    print(f"PASS art files: {len(DDS_EXPECTED)} UI-safe DDS textures with exact dimensions and VFS imports")


def validate_runtime_contracts() -> None:
    gameplay = (ROOT / "Lua" / "Azul_Gameplay.lua").read_text(encoding="utf-8")
    fleet_ui = (ROOT / "UI" / "Azul_FleetPanel.lua").read_text(encoding="utf-8")
    comms_xml = (ROOT / "UI" / "Azul_FleetPanel.xml").read_text(encoding="utf-8")
    required_gameplay = (
        "GameEvents.UnitSetXY.Add(OnUnitSetXY)",
        "GetCurrentProductionDifferenceTimes100",
        "ATTACK_BONUS_PROMOS",
        "RestoreAttackPromotions",
        "PruneTestudonQueues",
        "GetMaxDefenseStrength",
        "GameDefines.MAX_PLAYERS",
        "city:PopOrder(0, false, true)",
        "ClearTemporary(currentBattle.cannonBlockedDefender)",
        "unit.GetScriptData ~= nil",
        "newUnit.SetScriptData ~= nil",
        "local restored, restoreError = pcall(function()",
        "local committed, commitError = pcall(function()",
        "newUnit:Kill(false, -1)",
        "local DOGFIGHTER_EVADE_CHANCE = 5",
        "Game.Rand(100, 'Azul Dogfighter Evasion') < DOGFIGHTER_EVADE_CHANCE",
    )
    missing = [snippet for snippet in required_gameplay if snippet not in gameplay]
    if missing:
        raise AssertionError(f"runtime safety contracts missing from gameplay Lua: {missing}")
    if "UnitCanRangeAttackAt.Add" in gameplay:
        raise AssertionError("allow-only UnitCanRangeAttackAt hook is still registered")

    comms_start = gameplay.index("-- Fleet Comms is presentation-only")
    comms_end = gameplay.index("local function Notify", comms_start)
    comms_block = gameplay[comms_start:comms_end]
    for snippet in (
        "FIGHTER = 'Alpha'", "DESTROYER = 'Delta'", "TESTUDON = 'Testudon-'",
        "UKey('COMMS_SIGN'", "UKey('COMMS_KILLS'", "PKey(playerID, 'COMMS_NEXT_'",
        "table.sort(ships", "EnsureCallsign(playerID, unit)", "LuaEvents.Azul_CommsMessage",
        "math.random(100)", "count >= 3", "COMMS_ROUTINE_TURN",
    ):
        if snippet not in comms_block:
            raise AssertionError(f"Fleet Comms identity/throttle contract missing: {snippet}")
    if "Game.Rand(" in comms_block:
        raise AssertionError("Fleet Comms must not consume the gameplay RNG")
    for snippet in (
        "MigrateCallsigns(playerID, player)", "local callsign = EnsureCallsign(playerID, unit)",
        "SetNumber(UKey('COMMS_KILLS', playerID, unitID), commsKills)",
        "battle.commsKillCredited = true", "BattleComms(battle)",
    ):
        if snippet not in gameplay:
            raise AssertionError(f"Fleet Comms save/combat hook missing: {snippet}")
    for snippet in ("ContextPtr:SetUpdate(TickComms)", "LuaEvents.Azul_CommsMessage.Add",
                    "Controls.CommsPanel:SetHide", "UI.IsCityScreenUp"):
        if snippet not in fleet_ui:
            raise AssertionError(f"Fleet Comms UI contract missing: {snippet}")
    for index in range(1, 5):
        if f'ID="CommsLine{index}"' not in comms_xml:
            raise AssertionError(f"Fleet Comms UI line {index} is missing")
    print("PASS Fleet Comms: additive callsigns/kills, refit transfer, battle hooks, UI, and throttle")

    fighter_sync_start = gameplay.index("local function SyncFighterInterception")
    fighter_sync_end = gameplay.index("local function SelectPlayerShip", fighter_sync_start)
    fighter_sync = gameplay[fighter_sync_start:fighter_sync_end]
    for snippet in (
        "FAMILY_BY_TYPE[unit:GetUnitType()] ~= 'FIGHTER'",
        "unit:SetHasPromotion(promotionID, true)",
        "SavedNumber(PKey(playerID, 'PLAYER_SHIP'), -1) == unit:GetID()",
        "unit:SetHasPromotion(PROMO_EXTRA_INTERCEPTION, isPlayerFighter)",
        "SyncFighterInterception(player:GetID(), unit)",
        "SyncFighterInterception(playerID, newUnit)",
    ):
        if snippet not in (fighter_sync if snippet.startswith(("FAMILY_BY", "unit:", "SavedNumber")) else gameplay):
            raise AssertionError(f"Fighter interception save/refit contract missing: {snippet}")
    for promotion in (
        "PROMOTION_INTERCEPTION_IV",
        "PROMOTION_INTERCEPTION_1",
        "PROMOTION_INTERCEPTION_2",
        "PROMOTION_INTERCEPTION_3",
        "PROMOTION_SORTIE",
    ):
        if f"GameInfoTypes.{promotion}" not in gameplay:
            raise AssertionError(f"Fighter interception promotion not reconciled: {promotion}")
    select_ship = gameplay[
        gameplay.index("local function SelectPlayerShip"):
        gameplay.index("local function ClearPlayerShip")
    ]
    clear_ship = gameplay[
        gameplay.index("local function ClearPlayerShip"):
        gameplay.index("local function HasTech")
    ]
    sync_all = "for unit in player:Units() do SyncFighterInterception(playerID, unit) end"
    if not (
        select_ship.index("SetNumber(PKey(playerID, 'PLAYER_SHIP'), unitID)")
        < select_ship.index(sync_all)
        and clear_ship.index("SetNumber(PKey(playerID, 'PLAYER_SHIP'), -1)")
        < clear_ship.index(sync_all)
    ):
        raise AssertionError("Player Fighter interception count is not resynced after identity changes")

    siege_mapping = re.search(
        r"for era, percent in pairs\(\{([^}]*)\}\) do\s*"
        r"local unitType = TESTUDONS\[era\]\s*"
        r"if unitType ~= nil then TESTUDON_CITY_DAMAGE_FLOOR_BY_TYPE\[unitType\] = percent end",
        gameplay,
    )
    if siege_mapping is None:
        raise AssertionError("Testudon city-damage floor is not keyed to the active hull type")
    siege_tiers = {
        int(era): int(bonus)
        for era, bonus in re.findall(r"\[(\d+)\]\s*=\s*(\d+)", siege_mapping.group(1))
    }
    if siege_tiers != {4: 25, 5: 27, 6: 30, 7: 33}:
        raise AssertionError(f"Testudon city-damage floor tier mismatch: {siege_tiers}")
    if "TESTUDON_CITY_SIEGE_BY_TYPE" in gameplay:
        raise AssertionError("old percentage-strength city siege remains in gameplay")
    focused_start = gameplay.index(
        "if attacker ~= nil and FAMILY_BY_TYPE[attacker:GetUnitType()] == 'TESTUDON' then"
    )
    focused_end = gameplay.index(
        "if defender ~= nil and FAMILY_BY_TYPE[defender:GetUnitType()] == 'TESTUDON' then",
        focused_start,
    )
    focused_block = gameplay[focused_start:focused_end]
    city_branch = focused_block.split("elseif defender ~= nil then", 1)
    if len(city_branch) != 2 or "if battle.defender.isCity and IsAzul(attackerPlayer)" not in city_branch[0]:
        raise AssertionError("city siege and unit-target Focused Beam are not isolated")
    if "battle.testudonSiege = {" not in city_branch[0] or "damageBefore = city:GetDamage()" not in city_branch[0]:
        raise AssertionError("city siege does not snapshot city identity and pre-combat damage")
    if "ApplyBeamCompensation" in city_branch[0] or "focusedPromotion" in city_branch[0]:
        raise AssertionError("old temporary strength bonus still applies against cities")
    if "TotalPositiveDefense(defender, attacker)" not in city_branch[1] or (
        "ApplyBeamCompensation(attacker, compensation)" not in city_branch[1]
    ):
        raise AssertionError("unit-target Focused Beam compensation has changed")
    if "ChangeDamage" in focused_block or "RangeStrike(" in focused_block:
        raise AssertionError("Testudon siege bypasses native battle resolution")
    supplement_start = gameplay.index("local function TestudonCitySupplemental")
    supplement_end = gameplay.index("local function ResolveTestudonCityFloor", supplement_start)
    supplement = gameplay[supplement_start:supplement_end]
    for snippet in (
        "if after <= before or maxHP <= 1 then return 0 end",
        "local nativeDamage = after - before",
        "math.floor(maxHP * percent / 100 + 0.5)",
        "math.max(0, minimum - nativeDamage)",
        "math.max(0, maxHP - 1 - after)",
        "math.min(missing, headroom)",
    ):
        if snippet not in supplement:
            raise AssertionError(f"city-damage floor arithmetic regressed: {snippet}")
    resolve_start = supplement_end
    resolve_end = gameplay.index("local function BattleComms", resolve_start)
    resolve = gameplay[resolve_start:resolve_end]
    for snippet in (
        "not Teams[attackerPlayer:GetTeam()]:IsAtWar(defenderPlayer:GetTeam())",
        "attacker:IsDead()", "attacker:GetUnitType() ~= siege.attackerType",
        "plottedCity:GetOwner() ~= siege.cityOwner", "plottedCity:GetID() ~= siege.cityID",
        "city:GetMaxHitPoints() ~= siege.maxHP",
        "after <= siege.damageBefore", "after >= siege.maxHP",
        "TestudonCitySupplemental(siege.damageBefore, after, siege.maxHP, siege.percent)",
        "if supplemental > 0 then city:ChangeDamage(supplemental) end",
    ):
        if snippet not in resolve:
            raise AssertionError(f"city-damage floor identity/resolution guard missing: {snippet}")
    finish = gameplay[gameplay.index("local function OnBattleFinished"):gameplay.index("local function OnUnitPrekill")]
    if not (finish.index("ResolveTestudonCityFloor(battle)") < finish.index("BattleComms(battle)")):
        raise AssertionError("Fleet Comms does not inspect final post-floor city damage")

    # Exercise the mathematical contract, not just the presence of source text.
    def supplemental(before: int, after: int, max_hp: int, percent: int) -> int:
        if after <= before or max_hp <= 1:
            return 0
        native_damage = after - before
        minimum = max(1, int(max_hp * percent / 100 + 0.5))
        missing = max(0, minimum - native_damage)
        headroom = max(0, max_hp - 1 - after)
        return min(missing, headroom)

    examples = ((0, 41, 300, 33, 58), (0, 115, 300, 33, 0),
                (0, 20, 250, 33, 63), (0, 15, 200, 30, 45),
                (260, 280, 300, 33, 19), (0, 0, 300, 33, 0))
    for before, after, max_hp, percent, expected in examples:
        if supplemental(before, after, max_hp, percent) != expected:
            raise AssertionError(f"Testudon city-damage floor arithmetic failed: {before, after, max_hp, percent}")
    for max_hp in (100, 200, 250, 300, 500):
        for percent in siege_tiers.values():
            for before in range(0, max_hp, 17):
                for after in range(before, max_hp, 19):
                    added = supplemental(before, after, max_hp, percent)
                    if added < 0 or after + added > max_hp - 1:
                        raise AssertionError("Testudon floor breached the one-HP city limit")
                    if after == before and added != 0:
                        raise AssertionError("zero native damage received a city-damage floor")
                    if after - before >= int(max_hp * percent / 100 + 0.5) and added != 0:
                        raise AssertionError("native damage above the floor was modified")
    for cleanup in (
        "ClearTemporary(currentBattle.focusedAttacker)",
        "ClearTemporary(battle.focusedAttacker)",
        "GameEvents.BattleJoined.Add(OnBattleJoined)",
        "GameEvents.BattleFinished.Add(OnBattleFinished)",
    ):
        if cleanup not in gameplay:
            raise AssertionError(f"Testudon temporary modifier cleanup is missing: {cleanup}")
    print("PASS Testudon siege: hull tiers, native city damage floor, 1-HP clamp, unit branch, and Fleet Comms order")

    swap_start = gameplay.index("local function SwapHull")
    swap_end = gameplay.index("local function ReconcileProduction", swap_start)
    swap_block = gameplay[swap_start:swap_end]
    player_transfer = "SetNumber(PKey(playerID, 'PLAYER_SHIP'), newUnit:GetID())"
    old_hull_kill = "unit:Kill(true, -1)"
    old_state_cleanup = "ClearHullState(oldID)"
    if not (
        swap_block.index(player_transfer)
        < swap_block.index(old_hull_kill)
        < swap_block.index(old_state_cleanup)
    ):
        raise AssertionError("Era refit identity/kill/state-cleanup ordering regressed")

    capture_start = gameplay.index("local function CaptureCity")
    capture_end = gameplay.index("local function LegalTurretPlot", capture_start)
    capture_block = gameplay[capture_start:capture_end]
    ownership_check = "if cityAfter == nil or cityAfter:GetOwner() ~= playerID then return false end"
    if ownership_check not in capture_block:
        raise AssertionError("fleet Capture City does not verify post-AcquireCity ownership")
    if capture_block.index(ownership_check) > capture_block.index("unit:SetMadeAttack(true)"):
        raise AssertionError("fleet Capture City spends the vessel before ownership is verified")
    cannon_values = "local CANNON_BASE = {260, 360, 500, 700, 950, 1275, 1675, 2175}"
    if cannon_values not in gameplay or cannon_values not in fleet_ui:
        raise AssertionError("Main Cannon requirement arrays are not synchronized")
    for snippet in ("_X100", "FormatHundredths", "plot:IsVisible", "GameDefines.MAX_PLAYERS"):
        if snippet not in fleet_ui:
            raise AssertionError(f"runtime safety contract missing from Fleet UI: {snippet}")
    deploy_start = gameplay.index("local function DeployTurret")
    deploy_end = gameplay.index("local function SetMothershipProcess", deploy_start)
    deploy_block = gameplay[deploy_start:deploy_end]
    if "player:InitUnit(unitType, x, y, UnitAITypes." in deploy_block:
        raise AssertionError("turret deployment depends on unavailable UnitAITypes global")
    if "player:InitUnit(unitType, x, y)" not in deploy_block:
        raise AssertionError("turret deployment does not use the unit row's default AI")
    for snippet in (
        "local function PlotHex",
        "ToHexFromGrid({x = plot:GetX(), y = plot:GetY()})",
        "local function SetPlotHighlight",
    ):
        if snippet not in fleet_ui:
            raise AssertionError(f"portable selector highlight contract missing: {snippet}")
    if "ToHexFromGrid(Vector2(" in fleet_ui:
        raise AssertionError("Fleet UI still requires unavailable Vector2 constructor")
    open_selector_start = fleet_ui.index("local function OpenSelector")
    open_selector_end = fleet_ui.index("local function ConfirmTarget", open_selector_start)
    close_selector_start = fleet_ui.index("local function CloseSelector")
    close_selector_end = fleet_ui.index("local function RefreshSelector", close_selector_start)
    if "selectorOpen = true" not in fleet_ui[open_selector_start:open_selector_end] or "Controls.TargetPanel:SetHide(false)" not in fleet_ui[open_selector_start:open_selector_end]:
        raise AssertionError("target selection does not show its panel")
    if "selectorOpen = false" not in fleet_ui[close_selector_start:close_selector_end] or "Controls.TargetPanel:SetHide(true)" not in fleet_ui[close_selector_start:close_selector_end]:
        raise AssertionError("closing target selection does not hide its panel")
    for snippet in (
        "Controls.FleetButton:SetHide(false)",
        "Controls.FleetButton:SetHide(true)",
        "Controls.FleetPanel:SetHide(not panelOpen)",
        "Controls.ConfirmPanel:SetHide(false)",
        "Controls.ConfirmPanel:SetHide(true)",
        "UI.IsCityScreenUp()",
    ):
        if snippet not in fleet_ui:
            raise AssertionError(f"restored Fleet HUD behavior missing: {snippet}")
    for snippet in ("IsNormalMapView", "NON_MAP_CONTEXTS", "UIManager:GetVisibleNamedContext", "visibilityCheckElapsed", "ApplyVisibility"):
        if snippet in fleet_ui:
            raise AssertionError(f"map-only HUD reconciliation remains after rollback: {snippet}")
    print("PASS runtime contracts: precise meters, movement/attack locks, queues, HUD rollback, and AI release")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_database.py <Civ5DebugDatabase.db>")
        return 2

    source = sqlite3.connect(sys.argv[1])
    database = sqlite3.connect(":memory:")
    source.backup(database)
    source.close()
    remove_existing_rows(database)
    add_missing_cp_columns(database)
    database.execute(
        "CREATE TABLE IF NOT EXISTS Language_en_US "
        "(Tag TEXT PRIMARY KEY, Text TEXT, Gender TEXT, Plurality TEXT)"
    )

    for path in (CORE, TEXT):
        database.executescript(path.read_text(encoding="utf-8"))
        print(f"PASS SQL: {path.name}")

    for option in REQUIRED_CP_EVENT_OPTIONS:
        count, value = database.execute(
            "SELECT COUNT(*),MAX(Value) FROM CustomModOptions WHERE Name=?", (option,)
        ).fetchone()
        if count != 1 or value != 1:
            raise AssertionError(
                f"CP EVENT: {option} is not enabled (rows={count}, value={value})"
            )
    print(
        "PASS CP events: "
        + ", ".join(REQUIRED_CP_EVENT_OPTIONS)
        + " are enabled"
    )

    for table, type_name in (
        ("Civilizations", "CIVILIZATION_AZUL_BARONIS"),
        ("Leaders", "LEADER_AZUL_THE_PLAYER"),
        ("Traits", "TRAIT_AZUL_ONE_SHIP_AMONG_MANY"),
        ("Buildings", "BUILDING_AZUL_MOTHERSHIP_CORE"),
        ("Processes", "PROCESS_AZUL_CHARGE_MAIN_CANNON"),
        ("Processes", "PROCESS_AZUL_CONSTRUCT_TURRET"),
        ("UnitPromotions", "PROMOTION_AZUL_AFTERBURNER_ACTIVE"),
        ("Units", "UNIT_AZUL_FLEET_COMMANDER"),
    ):
        require_one(database, table, type_name)
    print("PASS objects: civilization, leader, trait, Core, processes, and Commander")

    expected_atlases = {
        **{("AZUL_CIV_COLOR_ATLAS", size): (f"AzulCivColor{size}.dds", 1, 1) for size in COLOR_SIZES},
        **{("AZUL_CIV_ALPHA_ATLAS", size): (f"AzulCivAlpha{size}.dds", 1, 1) for size in ALPHA_SIZES},
        **{("AZUL_LEADER_ATLAS", size): (f"AzulLeader{size}.dds", 1, 1) for size in COLOR_SIZES},
        **{("AZUL_UNIT_ATLAS", size): (f"AzulUnits{size}.dds", 4, 2) for size in COLOR_SIZES},
        **{("AZUL_ABILITY_ATLAS", size): (f"AzulAbilities{size}.dds", 4, 1) for size in COLOR_SIZES},
        ("AZUL_UNIT_FLAG_ATLAS", 32): ("AzulUnitFlags32.dds", 3, 1),
    }
    actual_atlases = {
        (row[0], row[1]): (row[2], int(row[3]), int(row[4]))
        for row in database.execute(
            "SELECT Atlas,IconSize,Filename,IconsPerRow,IconsPerColumn "
            "FROM IconTextureAtlases WHERE Atlas LIKE 'AZUL_%'"
        )
    }
    if actual_atlases != expected_atlases:
        raise AssertionError("Azul icon atlas registration mismatch")

    civilization_art = database.execute(
        "SELECT PortraitIndex,IconAtlas,AlphaIconAtlas,MapImage,DawnOfManImage,DawnOfManAudio "
        "FROM Civilizations WHERE Type='CIVILIZATION_AZUL_BARONIS'"
    ).fetchone()
    if civilization_art != (0, "AZUL_CIV_COLOR_ATLAS", "AZUL_CIV_ALPHA_ATLAS", "AzulMap512.dds", "AzulDawnOfMan.dds", None):
        raise AssertionError(f"civilization art mismatch: {civilization_art}")
    leader_art = database.execute(
        "SELECT PortraitIndex,IconAtlas FROM Leaders WHERE Type='LEADER_AZUL_THE_PLAYER'"
    ).fetchone()
    if leader_art != (0, "AZUL_LEADER_ATLAS"):
        raise AssertionError(f"leader art mismatch: {leader_art}")
    process_art = dict(database.execute(
        "SELECT Type,PortraitIndex || ':' || IconAtlas FROM Processes WHERE Type LIKE 'PROCESS_AZUL_%'"
    ))
    if process_art != {
        "PROCESS_AZUL_CHARGE_MAIN_CANNON": "0:AZUL_ABILITY_ATLAS",
        "PROCESS_AZUL_CONSTRUCT_TURRET": "3:AZUL_UNIT_ATLAS",
    }:
        raise AssertionError(f"process art mismatch: {process_art}")
    promotion_art = dict(database.execute(
        "SELECT Type,PortraitIndex || ':' || IconAtlas FROM UnitPromotions WHERE Type IN "
        "('PROMOTION_AZUL_PLAYER_CONTROLLED','PROMOTION_AZUL_AFTERBURNER_ACTIVE','PROMOTION_AZUL_HOMING_BOMB_ACTIVE')"
    ))
    if promotion_art != {
        "PROMOTION_AZUL_PLAYER_CONTROLLED": "1:AZUL_ABILITY_ATLAS",
        "PROMOTION_AZUL_AFTERBURNER_ACTIVE": "2:AZUL_ABILITY_ATLAS",
        "PROMOTION_AZUL_HOMING_BOMB_ACTIVE": "3:AZUL_ABILITY_ATLAS",
    }:
        raise AssertionError(f"ability art mismatch: {promotion_art}")
    for pattern, expected in (
        ("UNIT_AZUL_FIGHTER_%", (0, "AZUL_UNIT_ATLAS")),
        ("UNIT_AZUL_DESTROYER_%", (1, "AZUL_UNIT_ATLAS")),
        ("UNIT_AZUL_TESTUDON_%", (2, "AZUL_UNIT_ATLAS")),
        ("UNIT_AZUL_TURRET_%", (3, "AZUL_UNIT_ATLAS")),
    ):
        rows = set(database.execute(
            "SELECT PortraitIndex,IconAtlas FROM Units WHERE Type LIKE ?", (pattern,)
        ))
        if rows != {expected}:
            raise AssertionError(f"unit art mismatch for {pattern}: {rows}")
    for pattern, expected_count, expected_offset in (
        ("UNIT_AZUL_FIGHTER_%", 8, 0),
        ("UNIT_AZUL_DESTROYER_%", 5, 1),
        ("UNIT_AZUL_TESTUDON_%", 4, 2),
    ):
        rows = database.execute(
            "SELECT UnitFlagIconOffset,UnitFlagAtlas FROM Units WHERE Type LIKE ?", (pattern,)
        ).fetchall()
        if len(rows) != expected_count or set(rows) != {(expected_offset, "AZUL_UNIT_FLAG_ATLAS")}:
            raise AssertionError(f"unit flags mismatch for {pattern}: {rows}")
    commander_art = database.execute(
        "SELECT PortraitIndex,IconAtlas FROM Units WHERE Type='UNIT_AZUL_FLEET_COMMANDER'"
    ).fetchone()
    if commander_art != (4, "AZUL_UNIT_ATLAS"):
        raise AssertionError(f"Fleet Commander art mismatch: {commander_art}")
    print("PASS art database: civilization, leader, hull, process, and ability portraits")

    for unit_type, expected in EXPECTED_HULLS.items():
        actual = database.execute(
            "SELECT Combat,RangedCombat,Cost,Moves,Range FROM Units WHERE Type=?", (unit_type,)
        ).fetchone()
        if actual != expected:
            raise AssertionError(f"{unit_type}: {actual} != {expected}")
    print(f"PASS hull stats: {len(EXPECTED_HULLS)} exact era rows")

    era_unlocked_prereqs = {
        row[0]: row[1]
        for row in database.execute(
            "SELECT Type,PrereqTech FROM Units WHERE Type LIKE 'UNIT_AZUL_DESTROYER_%' "
            "OR Type LIKE 'UNIT_AZUL_TESTUDON_%'"
        )
    }
    if not era_unlocked_prereqs or set(era_unlocked_prereqs.values()) != {"TECH_AGRICULTURE"}:
        raise AssertionError(f"Era-gated hull prerequisites mismatch: {era_unlocked_prereqs}")
    print("PASS availability: Destroyer and Testudon unlock strictly by Azul Era")

    core = database.execute(
        "SELECT ExtraCityHitPoints,RangedStrikeModifier,BuildingClass FROM Buildings "
        "WHERE Type='BUILDING_AZUL_MOTHERSHIP_CORE'"
    ).fetchone()
    palace_hp = database.execute(
        "SELECT ExtraCityHitPoints FROM Buildings WHERE Type='BUILDING_PALACE'"
    ).fetchone()[0]
    if core != (palace_hp + 50, 15, "BUILDINGCLASS_PALACE"):
        raise AssertionError(f"Mothership Core mismatch: {core}")
    palace_yields = set(database.execute(
        "SELECT YieldType,Yield FROM Building_YieldChanges WHERE BuildingType='BUILDING_PALACE'"
    ))
    core_yields = set(database.execute(
        "SELECT YieldType,Yield FROM Building_YieldChanges "
        "WHERE BuildingType='BUILDING_AZUL_MOTHERSHIP_CORE'"
    ))
    expected_palace_yields = {
        ("YIELD_PRODUCTION", 3),
        ("YIELD_SCIENCE", 3),
        ("YIELD_GOLD", 3),
        ("YIELD_CULTURE", 1),
    }
    if palace_yields != expected_palace_yields or core_yields != palace_yields:
        raise AssertionError(f"Mothership Core Palace yields mismatch: {core_yields} != {palace_yields}")

    palace_flavors = set(database.execute(
        "SELECT FlavorType,Flavor FROM Building_Flavors WHERE BuildingType='BUILDING_PALACE'"
    ))
    core_flavors = set(database.execute(
        "SELECT FlavorType,Flavor FROM Building_Flavors "
        "WHERE BuildingType='BUILDING_AZUL_MOTHERSHIP_CORE'"
    ))
    if core_flavors != palace_flavors:
        raise AssertionError(f"Mothership Core Palace flavors mismatch: {core_flavors} != {palace_flavors}")
    palace_associations: list[str] = []
    for (table,) in database.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    ):
        if table in {"Buildings", "BuildingClasses", "Language_en_US"}:
            continue
        safe_table = table.replace('"', '""')
        columns = [row[1] for row in database.execute(f'PRAGMA table_info("{safe_table}")')]
        for column in columns:
            safe_column = column.replace('"', '""')
            palace_count = database.execute(
                f'SELECT COUNT(*) FROM "{safe_table}" WHERE "{safe_column}"=?',
                ("BUILDING_PALACE",),
            ).fetchone()[0]
            if palace_count:
                core_count = database.execute(
                    f'SELECT COUNT(*) FROM "{safe_table}" WHERE "{safe_column}"=?',
                    ("BUILDING_AZUL_MOTHERSHIP_CORE",),
                ).fetchone()[0]
                if core_count < palace_count:
                    raise AssertionError(
                        f"Palace association not inherited in {table}.{column}: "
                        f"{core_count} < {palace_count}"
                    )
                palace_associations.append(f"{table}.{column}")
    print("PASS Mothership Core: complete Palace economy/flavors, +50 HP, and +15% ranged strike")
    print(f"PASS Palace association audit: {', '.join(sorted(palace_associations))}")

    damage_promotions = dict(
        database.execute(
            "SELECT Type,DamageTakenMod FROM UnitPromotions WHERE Type IN "
            "('PROMOTION_AZUL_DOGFIGHTER_EVADE','PROMOTION_AZUL_TESTUDON_RANGED_REDUCTION')"
        )
    )
    if damage_promotions != {
        "PROMOTION_AZUL_DOGFIGHTER_EVADE": -100,
        "PROMOTION_AZUL_TESTUDON_RANGED_REDUCTION": -20,
    }:
        raise AssertionError(f"damage modifier promotions mismatch: {damage_promotions}")
    homing_modifier = database.execute(
        "SELECT RangedAttackModifier FROM UnitPromotions "
        "WHERE Type='PROMOTION_AZUL_HOMING_BOMB_ACTIVE'"
    ).fetchone()[0]
    if homing_modifier != 15:
        raise AssertionError(f"Homing Bomb modifier mismatch: {homing_modifier}")
    dogfighter_defense = database.execute(
        "SELECT RangedDefenseMod FROM UnitPromotions "
        "WHERE Type='PROMOTION_AZUL_DOGFIGHTER_DEFENSE'"
    ).fetchone()[0]
    if dogfighter_defense != 10:
        raise AssertionError(f"Dogfighter ranged defense mismatch: {dogfighter_defense}")
    fighter_mobility = (
        database.execute(
            "SELECT CanMoveAfterAttacking FROM UnitPromotions "
            "WHERE Type='PROMOTION_AZUL_MOVE_AFTER_ATTACK'"
        ).fetchone()[0],
        database.execute(
            "SELECT IgnoreZOC FROM UnitPromotions "
            "WHERE Type='PROMOTION_AZUL_DOGFIGHTER'"
        ).fetchone()[0],
        database.execute(
            "SELECT MovesChange FROM UnitPromotions "
            "WHERE Type='PROMOTION_AZUL_PLAYER_CONTROLLED'"
        ).fetchone()[0],
    )
    if fighter_mobility != (1, 1, 1):
        raise AssertionError(f"Fighter mobility promotions mismatch: {fighter_mobility}")
    print(
        "PASS combat modifiers: 10% Dogfighter defense, 5% evade contract, "
        "Testudon reduction, and unchanged Fighter mobility"
    )

    fighter_air = list(database.execute(
        "SELECT Type,Domain,AirInterceptRange,DefaultUnitAI FROM Units "
        "WHERE Type LIKE 'UNIT_AZUL_FIGHTER_%' ORDER BY Type"
    ))
    if len(fighter_air) != 8 or any(row[1:] != ("DOMAIN_LAND", 3, "UNITAI_RANGED") for row in fighter_air):
        raise AssertionError(f"Fighter native interception rows mismatch: {fighter_air}")
    air_promotions = {
        row[0]: row[1:]
        for row in database.execute(
            "SELECT Type,InterceptChanceChange,InterceptionCombatModifier,NumInterceptionChange "
            "FROM UnitPromotions WHERE Type IN "
            "('PROMOTION_INTERCEPTION_IV','PROMOTION_INTERCEPTION_1',"
            "'PROMOTION_INTERCEPTION_2','PROMOTION_INTERCEPTION_3','PROMOTION_SORTIE')"
        )
    }
    expected_air_promotions = {
        "PROMOTION_INTERCEPTION_IV": (100, 0, 0),
        "PROMOTION_INTERCEPTION_1": (0, 33, 0),
        "PROMOTION_INTERCEPTION_2": (0, 33, 0),
        "PROMOTION_INTERCEPTION_3": (0, 34, 0),
        "PROMOTION_SORTIE": (0, 0, 1),
    }
    if air_promotions != expected_air_promotions:
        raise AssertionError(f"CP interception promotion values mismatch: {air_promotions}")
    fighter_free_air = list(database.execute(
        "SELECT UnitType,PromotionType FROM Unit_FreePromotions "
        "WHERE UnitType LIKE 'UNIT_AZUL_FIGHTER_%' "
        "AND PromotionType LIKE 'PROMOTION_INTERCEPTION_%'"
    ))
    expected_free_air = {
        (unit_type, promotion)
        for unit_type, _, _, _ in fighter_air
        for promotion in expected_air_promotions if promotion != "PROMOTION_SORTIE"
    }
    if set(fighter_free_air) != expected_free_air or len(fighter_free_air) != len(expected_free_air):
        raise AssertionError("new Fighter interception free grants are missing or duplicated")
    if database.execute(
        "SELECT COUNT(*) FROM Unit_FreePromotions WHERE UnitType LIKE 'UNIT_AZUL_%' "
        "AND PromotionType='PROMOTION_SORTIE'"
    ).fetchone()[0] != 0:
        raise AssertionError("Sortie must be reserved for the runtime Player Controlled Fighter")
    print("PASS Fighter interception: 8 land hulls, range 3, 100% chance, +100% air-only strength, Player Sortie")

    beam_steps = database.execute(
        "SELECT COUNT(*),MIN(RangedAttackModifier),MAX(RangedAttackModifier) "
        "FROM UnitPromotions WHERE Type LIKE 'PROMOTION_AZUL_BEAM_COMP_%'"
    ).fetchone()
    if beam_steps != (400, 1, 400):
        raise AssertionError(f"beam compensation steps mismatch: {beam_steps}")
    print("PASS beam compensation: 400 one-point hidden strength steps")

    overrides = {
        row[0]: row[1]
        for row in database.execute(
            "SELECT UnitClassType,UnitType FROM Civilization_UnitClassOverrides "
            "WHERE CivilizationType='CIVILIZATION_AZUL_BARONIS'"
        )
    }
    if overrides.get("UNITCLASS_WARRIOR") != "UNIT_AZUL_FIGHTER_ANCIENT":
        raise AssertionError("starting Warrior class does not resolve to Ancient Fighter")
    if overrides.get("UNITCLASS_GREAT_GENERAL") != "UNIT_AZUL_FLEET_COMMANDER":
        raise AssertionError("Great General class does not resolve to Fleet Commander")
    joker_clown_is_competing = database.execute(
        "SELECT 1 FROM UnitClasses AS Class "
        "JOIN Unit_FreePromotions AS Promotion "
        "ON Promotion.UnitType=Class.DefaultUnit "
        "WHERE Class.Type='UNITCLASS_JOK_CLOWN' "
        "AND Class.DefaultUnit='UNIT_JOK_CLOWN' "
        "AND Promotion.PromotionType='PROMOTION_GREAT_GENERAL'"
    ).fetchone() is not None
    if joker_clown_is_competing:
        joker_blocker = database.execute(
            "SELECT COUNT(*),MAX(UnitType) FROM Civilization_UnitClassOverrides "
            "WHERE CivilizationType='CIVILIZATION_AZUL_BARONIS' "
            "AND UnitClassType='UNITCLASS_JOK_CLOWN'"
        ).fetchone()
        if joker_blocker != (1, None):
            raise AssertionError(f"Azul Joker Clown class blocker mismatch: {joker_blocker}")
    general_candidates = database.execute(
        "SELECT Unit.Type, "
        "CASE WHEN Override.UnitClassType IS NOT NULL THEN Override.UnitType "
        "ELSE Class.DefaultUnit END AS SpecificUnit "
        "FROM UnitPromotions AS Promotion "
        "JOIN Unit_FreePromotions AS FreePromotion "
        "ON FreePromotion.PromotionType=Promotion.Type "
        "JOIN Units AS Unit ON Unit.Type=FreePromotion.UnitType "
        "JOIN UnitClasses AS Class ON Class.Type=Unit.Class "
        "LEFT JOIN Civilization_UnitClassOverrides AS Override "
        "ON Override.CivilizationType='CIVILIZATION_AZUL_BARONIS' "
        "AND Override.UnitClassType=Unit.Class "
        "WHERE Promotion.GreatGeneral=1 ORDER BY Promotion.ID,Unit.ID"
    ).fetchall()
    first_general = next(
        (unit_type for unit_type, specific in general_candidates if unit_type == specific),
        None,
    )
    if first_general != "UNIT_AZUL_FLEET_COMMANDER":
        raise AssertionError(f"earned Great General would spawn {first_general}, not Fleet Commander")
    print("PASS Great General selection: Fleet Commander wins Community Patch scan")
    free_units = set(database.execute(
        "SELECT UnitClassType,UnitAIType,Count FROM Civilization_FreeUnits "
        "WHERE CivilizationType='CIVILIZATION_AZUL_BARONIS'"
    ))
    if free_units != {
        ("UNITCLASS_SETTLER", "UNITAI_SETTLE", 1),
        ("UNITCLASS_WARRIOR", "UNITAI_RANGED", 1),
    }:
        raise AssertionError(f"Azul starting units mismatch: {free_units}")

    custom_classes = list(database.execute(
        "SELECT Type,DefaultUnit FROM UnitClasses WHERE Type LIKE 'UNITCLASS_AZUL_%'"
    ))
    if len(custom_classes) != 24 or any(
        default != "UNIT_AZUL_INTERNAL_DISABLED" for _, default in custom_classes
    ):
        raise AssertionError(f"internal class defaults mismatch: {custom_classes}")
    disabled_hull = database.execute(
        "SELECT Cost,FaithCost,ShowInPedia FROM Units "
        "WHERE Type='UNIT_AZUL_INTERNAL_DISABLED'"
    ).fetchone()
    if disabled_hull != (-1, -1, 0):
        raise AssertionError(f"late-loaded civilization safety hull mismatch: {disabled_hull}")
    civilization_count = database.execute(
        "SELECT COUNT(*) FROM Civilizations WHERE Type <> 'CIVILIZATION_AZUL_BARONIS'"
    ).fetchone()[0]
    blocked_count = database.execute(
        "SELECT COUNT(*) FROM Civilization_UnitClassOverrides "
        "WHERE CivilizationType <> 'CIVILIZATION_AZUL_BARONIS' "
        "AND UnitClassType LIKE 'UNITCLASS_AZUL_%' AND UnitType IS NULL"
    ).fetchone()[0]
    if blocked_count != civilization_count * len(custom_classes):
        raise AssertionError(
            f"non-Azul internal-class blockers mismatch: {blocked_count} != "
            f"{civilization_count * len(custom_classes)}"
        )
    traversal_units = database.execute(
        "SELECT COUNT(*) FROM Units WHERE SendCanMoveIntoEvent=1 AND ("
        "Type LIKE 'UNIT_AZUL_FIGHTER_%' OR Type LIKE 'UNIT_AZUL_DESTROYER_%' OR "
        "Type LIKE 'UNIT_AZUL_TESTUDON_%' OR Type LIKE 'UNIT_AZUL_TURRET_%' OR "
        "Type='UNIT_AZUL_FLEET_COMMANDER')"
    ).fetchone()[0]
    if traversal_units != 26:
        raise AssertionError(f"CanMoveInto-enabled Azul map units mismatch: {traversal_units}")
    turret_actions = database.execute(
        "SELECT COUNT(*) FROM Units WHERE Type LIKE 'UNIT_AZUL_TURRET_%' "
        "AND Moves=1 AND Immobile=1"
    ).fetchone()[0]
    if turret_actions != 8:
        raise AssertionError(f"stationary attack-capable turret rows mismatch: {turret_actions}")
    print(
        "PASS overrides/traversal: exact Fighter start, safe late-load defaults, "
        "and 26 gated map units"
    )

    required_tags = (
        "TXT_KEY_CIV_AZUL_BARONIS_DESC",
        "TXT_KEY_TRAIT_AZUL_ONE_SHIP_AMONG_MANY",
        "TXT_KEY_UNIT_AZUL_FIGHTER",
        "TXT_KEY_UNIT_AZUL_DESTROYER",
        "TXT_KEY_UNIT_AZUL_TESTUDON",
        "TXT_KEY_UNIT_AZUL_INTERNAL_DISABLED",
        "TXT_KEY_BUILDING_AZUL_MOTHERSHIP_CORE",
        "TXT_KEY_CIV5_AZUL_BARONIS_TITLE",
        "TXT_KEY_CIVILOPEDIA_LEADERS_AZUL_THE_PLAYER_NAME",
    )
    missing = [
        tag
        for tag in required_tags
        if database.execute("SELECT COUNT(*) FROM Language_en_US WHERE Tag=?", (tag,)).fetchone()[0] != 1
    ]
    if missing:
        raise AssertionError(f"missing localization: {missing}")
    print("PASS localization: required UI and Civilopedia keys")

    for path in (ROOT / "AzulBaronis.civ5proj", ROOT / "UI" / "Azul_FleetPanel.xml"):
        ET.parse(path)
        print(f"PASS XML: {path.name}")

    project_text = (ROOT / "AzulBaronis.civ5proj").read_text(encoding="utf-8")
    for relative in ("SQL\\00_Azul_Core.sql", "Lua\\Azul_Gameplay.lua", "UI\\Azul_FleetPanel.xml"):
        if relative not in project_text:
            raise AssertionError(f"project is missing {relative}")
    validate_art_files()
    validate_runtime_contracts()
    validate_package()
    print("All Azul Baronis code-level checks passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, sqlite3.Error, ET.ParseError) as error:
        print(f"FAIL: {error}")
        raise SystemExit(1)
