"""Validate Azul SQL, project metadata, UI XML, and packaged hashes."""

from __future__ import annotations

import hashlib
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

EXPECTED_HULLS = {
    "UNIT_AZUL_FIGHTER_ANCIENT": (6, 7, 50, 4, 1),
    "UNIT_AZUL_FIGHTER_CLASSICAL": (8, 11, 70, 4, 1),
    "UNIT_AZUL_FIGHTER_MEDIEVAL": (12, 16, 95, 4, 1),
    "UNIT_AZUL_FIGHTER_RENAISSANCE": (18, 24, 130, 4, 1),
    "UNIT_AZUL_FIGHTER_INDUSTRIAL": (26, 34, 180, 4, 1),
    "UNIT_AZUL_FIGHTER_MODERN": (38, 50, 250, 4, 1),
    "UNIT_AZUL_FIGHTER_ATOMIC": (55, 70, 340, 4, 1),
    "UNIT_AZUL_FIGHTER_INFORMATION": (75, 95, 450, 4, 1),
    "UNIT_AZUL_DESTROYER_RENAISSANCE": (28, 36, 320, 3, 2),
    "UNIT_AZUL_DESTROYER_INDUSTRIAL": (40, 52, 420, 3, 2),
    "UNIT_AZUL_DESTROYER_MODERN": (58, 74, 560, 3, 2),
    "UNIT_AZUL_DESTROYER_ATOMIC": (82, 104, 740, 3, 2),
    "UNIT_AZUL_DESTROYER_INFORMATION": (110, 138, 960, 3, 2),
    "UNIT_AZUL_TESTUDON_INDUSTRIAL": (65, 85, 800, 1, 3),
    "UNIT_AZUL_TESTUDON_MODERN": (90, 118, 1050, 1, 3),
    "UNIT_AZUL_TESTUDON_ATOMIC": (120, 158, 1350, 1, 3),
    "UNIT_AZUL_TESTUDON_INFORMATION": (155, 205, 1700, 1, 3),
    "UNIT_AZUL_TURRET_ANCIENT": (8, 9, -1, 0, 2),
    "UNIT_AZUL_TURRET_CLASSICAL": (11, 14, -1, 0, 2),
    "UNIT_AZUL_TURRET_MEDIEVAL": (16, 20, -1, 0, 2),
    "UNIT_AZUL_TURRET_RENAISSANCE": (24, 30, -1, 0, 2),
    "UNIT_AZUL_TURRET_INDUSTRIAL": (34, 43, -1, 0, 2),
    "UNIT_AZUL_TURRET_MODERN": (50, 62, -1, 0, 2),
    "UNIT_AZUL_TURRET_ATOMIC": (72, 88, -1, 0, 2),
    "UNIT_AZUL_TURRET_INFORMATION": (98, 120, -1, 0, 2),
}

COLOR_SIZES = (256, 128, 80, 64, 45, 32)
ALPHA_SIZES = (128, 64, 48, 32, 24, 16)
DDS_EXPECTED: dict[str, tuple[int, int]] = {
    **{f"Art/Icons/AzulCivColor{size}.dds": (size, size) for size in COLOR_SIZES},
    **{f"Art/Icons/AzulCivAlpha{size}.dds": (size, size) for size in ALPHA_SIZES},
    **{f"Art/Icons/AzulLeader{size}.dds": (size, size) for size in COLOR_SIZES},
    **{f"Art/Icons/AzulUnits{size}.dds": (size * 4, size * 2) for size in COLOR_SIZES},
    **{f"Art/Icons/AzulAbilities{size}.dds": (size * 4, size) for size in COLOR_SIZES},
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
    print("PASS Mothership Core: +50 HP and +15% ranged strike")

    damage_promotions = dict(
        database.execute(
            "SELECT Type,DamageTakenMod FROM UnitPromotions WHERE Type IN "
            "('PROMOTION_AZUL_DOGFIGHTER_EVADE','PROMOTION_AZUL_TESTUDON_RANGED_REDUCTION')"
        )
    )
    if damage_promotions != {
        "PROMOTION_AZUL_DOGFIGHTER_EVADE": -100,
        "PROMOTION_AZUL_TESTUDON_RANGED_REDUCTION": -25,
    }:
        raise AssertionError(f"damage modifier promotions mismatch: {damage_promotions}")
    print("PASS combat modifiers: exact evade and Testudon ranged reduction")

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
    if len(custom_classes) != 24 or any(default is None for _, default in custom_classes):
        raise AssertionError(f"internal class defaults mismatch: {custom_classes}")
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
    print("PASS overrides: Settler + Fighter start, Fleet Commander, and Azul-exclusive era classes")

    required_tags = (
        "TXT_KEY_CIV_AZUL_BARONIS_DESC",
        "TXT_KEY_TRAIT_AZUL_ONE_SHIP_AMONG_MANY",
        "TXT_KEY_UNIT_AZUL_FIGHTER",
        "TXT_KEY_UNIT_AZUL_DESTROYER",
        "TXT_KEY_UNIT_AZUL_TESTUDON",
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
    validate_package()
    print("All Azul Baronis code-level checks passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, sqlite3.Error, ET.ParseError) as error:
        print(f"FAIL: {error}")
        raise SystemExit(1)
