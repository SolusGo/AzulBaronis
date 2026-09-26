# Art manifest

The checked-in DDS files are Civ V-ready derivatives of the supplied Azul Baronis PNGs. Run `Tools/build_art.py <source-directory>` with Pillow 12 or newer to rebuild the original portrait/loading textures. Run `Tools/build_unit_flags.py` to rebuild the three separate unit-map-flag symbols from the checked-in `Art/Sources/Flags` references.

## Atlas assignments

| Artwork | In-game assignment | Atlas index |
| --- | --- | ---: |
| Civilization Icon | Civilization color and alpha symbols | 0 |
| Leader Icon | The Player and Mothership Core | 0 |
| Fighter | Every Fighter Era row | 0 |
| Destroyer | Every Destroyer Era row | 1 |
| Testudon (`10_Tetsudon.png`) | Every Testudon Era row | 2 |
| Fighter map flag (`Art/Sources/Flags/Fighter.png`) | Every Fighter Era row, `AZUL_UNIT_FLAG_ATLAS` only | 0 |
| Destroyer map flag (`Art/Sources/Flags/Destroyer.png`) | Every Destroyer Era row, `AZUL_UNIT_FLAG_ATLAS` only | 1 |
| Testudon map flag (`Art/Sources/Flags/Testudon.png`) | Every Testudon Era row, `AZUL_UNIT_FLAG_ATLAS` only | 2 |
| Defensive Turret | Every Defensive Turret Era row and construction process | 3 |
| Fleet Commander | Fleet Commander | 4 |
| Main Cannon / Big Laser | Charge Main Cannon process | 0 |
| Player Controlled UA | Player Controlled promotion | 1 |
| Afterburner | One-turn Afterburner Engaged marker | 2 |
| Destroyer Homing Bomb | Homing Bomb firing promotion | 3 |
| Dawn of Man Loading Art | Dawn of Man and civilization map panels | n/a |

The circular source portraits are stored as uncompressed 32-bit RGBA atlases with transparent corners. This is required for reliable rendering of Civ V's non-power-of-two 45px UI sheets. The full-screen loading textures remain DXT5. The tintable civilization alpha atlas is derived from the supplied crest. The separate 32px map-flag atlas uses white alpha silhouettes fitted within Civ V's circular flag area; the game supplies the player colours. The original PNGs are not added to the runtime package; the generated DDS textures are the authoritative game assets.

## 3D world models

Fighter keeps the base Jet Fighter art reference. Destroyer uses Azul-specific copies of the Stealth Bomber art rows. Testudon uses Azul-specific copies of the American B-17 art rows, retaining its three-member formation with each member scaled from 0.10 to 0.15 (1.5×). These entries reuse Firaxis meshes and animations without editing base-game definitions. They do not change any portrait or map-flag atlas assignment.
