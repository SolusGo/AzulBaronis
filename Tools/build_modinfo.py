"""Generate the checked-in Civ V .modinfo with current MD5 hashes."""

from __future__ import annotations

import hashlib
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Azul Baronis — One Ship Among Many (v 1).modinfo"

FILES = [
    ("SQL/00_Azul_Core.sql", 0),
    ("SQL/10_Azul_Text.sql", 0),
    ("Lua/Azul_Gameplay.lua", 0),
    ("UI/Azul_FleetPanel.xml", 0),
    ("UI/Azul_FleetPanel.lua", 0),
    ("README.md", 0),
    ("CHANGELOG.md", 0),
    ("IMPLEMENTATION_NOTES.md", 0),
    ("TESTING.md", 0),
    ("Tools/validate_database.py", 0),
    ("Tools/build_modinfo.py", 0),
]


def md5(relative: str) -> str:
    return hashlib.md5((ROOT / relative).read_bytes()).hexdigest().upper()


def main() -> int:
    missing = [relative for relative, _ in FILES if not (ROOT / relative).is_file()]
    if missing:
        raise SystemExit(f"missing package files: {missing}")

    file_nodes = "\n".join(
        f'    <File md5="{md5(relative)}" import="{imported}">{escape(relative)}</File>'
        for relative, imported in FILES
    )
    document = f'''<?xml version="1.0" encoding="utf-8"?>
<Mod id="8d3f20a4-cb82-4f3b-91ad-72fbcc357e61" version="1">
  <Properties>
    <Name>Azul Baronis — One Ship Among Many</Name>
    <Stability>Alpha</Stability>
    <Teaser>One persistent fleet. One Player Controlled vessel. One irreplaceable Mothership.</Teaser>
    <Description>An asymmetric Community Patch civilization whose Fighter, Destroyer, and Testudon hulls replace the normal military tree and modernize every Era.</Description>
    <Authors>SolusGo</Authors>
    <SpecialThanks>Community Patch Project</SpecialThanks>
    <HideSetupGame>0</HideSetupGame>
    <Homepage>https://github.com/SolusGo/AzulBaronis</Homepage>
    <AffectsSavedGames>1</AffectsSavedGames>
    <MinCompatibleSaveVersion>0</MinCompatibleSaveVersion>
    <SupportsSinglePlayer>1</SupportsSinglePlayer>
    <SupportsMultiplayer>0</SupportsMultiplayer>
    <SupportsHotSeat>0</SupportsHotSeat>
    <SupportsMac>0</SupportsMac>
    <ReloadAudioSystem>0</ReloadAudioSystem>
    <ReloadLandmarkSystem>0</ReloadLandmarkSystem>
    <ReloadStrategicViewSystem>1</ReloadStrategicViewSystem>
    <ReloadUnitSystem>1</ReloadUnitSystem>
  </Properties>
  <Dependencies>
    <Mod id="d1b6328c-ff44-4b0d-aad7-c657f83610cd" minversion="150" maxversion="999" title="(1) Community Patch" />
  </Dependencies>
  <References />
  <Blocks />
  <Files>
{file_nodes}
  </Files>
  <Actions>
    <OnModActivated>
      <UpdateDatabase>SQL/00_Azul_Core.sql</UpdateDatabase>
      <UpdateDatabase>SQL/10_Azul_Text.sql</UpdateDatabase>
    </OnModActivated>
  </Actions>
  <EntryPoints>
    <EntryPoint type="InGameUIAddin" file="Lua/Azul_Gameplay.lua">
      <Name>Azul Gameplay Controller</Name>
      <Description>Runs era refits, traversal, combat abilities, conquest, Mothership batteries, turret limits, and AI support.</Description>
    </EntryPoint>
    <EntryPoint type="InGameUIAddin" file="UI/Azul_FleetPanel.xml">
      <Name>Azul Fleet Systems</Name>
      <Description>Player Ship, weapon, Mothership, turret, and Testudon-cap dashboard.</Description>
    </EntryPoint>
  </EntryPoints>
</Mod>
'''
    OUTPUT.write_text(document, encoding="utf-8", newline="\n")
    print(f"wrote Civ V modinfo with {len(FILES)} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
