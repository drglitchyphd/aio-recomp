# Credits and third-party notices

Crystal-AiO (`crystal-aio`, called Gen2-AIO / `gen2-aio` before 1.0.0) is a
bundle. Almost everything in it is someone else's work: mods, art, fonts, 3D
kits and research. The bundle adapts that work to Crystal. This file credits
each source as its own files in this repository credit it. Crediting a source
does not mean it endorses this bundle, and it does not transfer ownership of
anyone's work.

For what the bundle does, see [FEATURES.md](FEATURES.md).

Pokémon and all related names, characters and artwork are trademarks and
copyrights of Nintendo, Creatures Inc. and GAME FREAK inc. (The Pokémon
Company). Crystal-AiO is an unofficial, fan-made mod. It is not
affiliated with or endorsed by any of them, and it contains no ROM.

---

## Engine

**Gen1Recomp** — bryanthaboi
https://github.com/bryanthaboi/gen1recomp

Crystal-AiO is a mod for this engine and runs on its mod API. Several bundled
parts also credit **pret** (https://github.com/pret) for the disassemblies the
engine and the mods build on. Crystal-AiO's ALL 251 CATCHABLE placement was
computed from, and checked against, pret/pokecrystal's wild tables.

## Bundled mods

### Kanto in Motion — HaseoSora

Root folder (`kim_main.lua`, `lib/`, `data/`, `assets/`). Version 1.7.6 is the
base of this bundle (see `mod.card`).

- Repository: https://github.com/HaseoSora/Kanto-in-Motion
- HD asset pack (downloaded by the in-game ASSET MANAGER, not shipped in the
  ZIP): https://github.com/HaseoSora/Kanto-in-Motion-Assets
- Provides HD animated Pokémon, the Modern UI, the modern battle panel, HD
  battle backgrounds, the Trainer Card and the HD menu icons.
- Kanto in Motion itself builds on the community work listed under
  [Art and assets](#art-and-assets) and [Integrated code](#integrated-code)
  below.

### gmarcs Gen 2 Voxel Mod — gmarcs

`gmarc/` (version 1.0.7, modified for this bundle). It provides the 3D voxel
overworld and the 3D battle stage. According to its README, it was "inspired by
Dramatic Shape (Gen 1 voxel mod)". The bundle's 0.9.0 notes credit "gmarcs, from
Dramatic Shape". No link is recorded in the bundle.

### Pokémon Stadium 2 Importer — Deftones565

`stadium2/` (only the Kenney scene renderer is used, for KENNEY HD battle
backgrounds). The author is named in `mod.card` and in the bundle's 0.9.0
credits. Its companion mod is
[Stadium 2 UI](https://github.com/Deftones565/Stadium-2-UI) (not bundled).

Its README says its research into Stadium 2's formats and effects builds on
these decompilation projects:

- [pret/pokestadiumgs](https://github.com/pret/pokestadiumgs): the original
  Pokémon Stadium 2 decompilation and its contributors.
- [michiiik/pokestadiumgs](https://github.com/michiiik/pokestadiumgs): the
  continued decompilation work.

No Stadium 2 ROM or ROM-derived model is shipped. The Stadium 2 model import
was removed in 0.9.1, and its remaining code is not reachable from any setting.

### Wilds of Kanto Revival — poooooby, from YoDrehDenSwagAuf's Wilds of Kanto

`wilds/` (version 2.8.1). It is licensed under MIT; see `wilds/LICENSE`:
"Copyright (c) 2026 YoDrehDenSwagAuf; Modifications Copyright (c) 2026
poooooby". It provides visible wild Pokémon, followers, town Pokémon, NPC
Pokémon sprites and the shiny rate.

- This fork: https://github.com/poooooby/wilds-of-kanto-gen-3
- Original: https://github.com/YoDrehDenSwagAuf/overworld-spawn-mod

The MIT License covers Wilds' code and original assets only. Third-party art
keeps its own terms. See `wilds/README.md` (Collaborators),
`wilds/THIRD_PARTY_NOTICES.md` and `wilds/THIRD_PARTY_ASSETS.md`. In summary:

- **This fork:**
  - poooooby (maintainer).
  - **MegaMan-Omega**: original GSC sprites.
  - **FrenchOrange**: custom GSC sprites.
  - **Wooble**: recolouring of those sprites.
- **Original project, through v2.2.0:**
  - **YoDrehDenSwagAuf**: Wilds of Kanto, overworld systems and integration.
  - **masterwebx (WEX)**: Followers EX and follower systems.
  - **TheRhysWyrill (TRW)**: PokéPC, follower selection and Poke Followers /
    GSC sprites.
  - **gamecorner-033**: original PokéPC, overworld catching and follower
    concepts.
  - **ShockSlayer / Pokémon Crystal Clear team**: the GSC-style sprite work
    that Poke Followers / GSC is based on.
- **Follower concepts:** adapted from
  [Followers EX](https://github.com/masterwebx/gen1recomp-followers-ex)
  (masterwebx) and
  [PokéPC Followers](https://github.com/gamecorner-033/PokePCFollowers)
  (gamecorner-033). Wilds says those projects' assets are not bundled.
- **Shiny Pokemon** ([masterwebx](https://github.com/masterwebx/gen1recomp-shiny-pokemon),
  MIT): Wilds' SHINY RATE and SHINY SPARKLE reimplement its design.
- **Pokémon Wilds** ([SheerSt](https://github.com/SheerSt/pokewilds)): the
  additional GSC-style overworld walker sprites (`assets/enhanced_overworld/Pokewilds/`).
- **HGSS / PokeMMO style overworld sprites:** from the
  [Gen 9 Resource Pack](https://eeveeexpo.com/resources/1101/) artists. Wilds
  credits them by name:
  - MissingLukey, help-14, Kymoyonian, cSc-A7X, 2and2makes5, Pokegirl4ever,
    Fernandojl, Silver-Skies, TyranitarDark, Getsuei-H, Kid1513, Milomilotic11,
    Kyt666, kdiamo11, Chocosrawlooid, Syledude, Gallanty, Gizamimi-Pichu,
    Zyon17, LarryTurbo, spritesstealer
  - princess-pheonix, LunarDusk, Wolfang62, TintjeMadelintje101, piphybuilder88
  - SageDeoxys, tammyclaydon, Boonzeet, DarkusShadow, Ezeart, WolfPP, Azria,
    EduarPokeN, Carmanekko, StarWolff, Caruban
- **Pokémon Tower ghost** overworld sprite: Nuclear-Blizzard (DeviantArt).
- **PMDCollab / SpriteCollab** dialogue portraits
  (https://github.com/PMDCollab/SpriteCollab). These are licensed under **CC BY-NC
  4.0** (https://creativecommons.org/licenses/by-nc/4.0/): non-commercial use only,
  attribution required. Per-artist credits are in
  `wilds/assets/pmdcollab/CREDITS.txt`, and the license is in
  `wilds/assets/pmdcollab/LICENSE.txt`.

### Nuzlocke — bryanthaboi

`nuzlocke/` (Nuzlocke Rules 2.0.0-beta.25, adapted so Crystal uses its Gold
paths). Its README says: "Original Nuzlocke mod and repository: **bryanthaboi**."
No separate link is recorded in the bundle.

### Gen1Wild QOL — wild1walker

`qol/` (version 1.35.0). Its bundling is MIT (`qol/LICENSE`, "Copyright (c) 2026
wild1walker"), and each tracked module keeps its own MIT license under
`qol/modules/<Feature>/`. Suite: https://github.com/wild1walker/Gen1Wild ·
Releases: https://github.com/wild1walker/Gen1WildQOL/releases/latest

| Module in `qol/modules/` | Source |
|---|---|
| Gen1Sprint (SPRINT) | https://github.com/wild1walker/Gen1Sprint (MIT, wild1walker) |
| Gen1AutoSave (AUTO SAVE) | https://github.com/wild1walker/Gen1AutoSave (MIT, "Wild") |
| Gen1AutoContinue (AUTO CONTINUE) | https://github.com/wild1walker/Gen1AutoContinue (MIT, "Wild") |
| Gen1SoundQOL (low HP alarm) | https://github.com/wild1walker/Gen1SoundQOL (MIT, wild1walker) |
| Gen1Remember (REMEMBER MOVES / move reminder) | https://github.com/wild1walker/Gen1Remember (MIT, wild1walker) |
| Gen1MenuManager (MENU LAYOUT) | https://github.com/wild1walker/Gen1MenuManager |
| Gen1ModMenu | https://github.com/wild1walker/Gen1ModMenu (MIT, wild1walker) |
| ExpShare (EXP SHARE) | originally [exp_share](https://github.com/ShaneMcGovernIE/exp_share) by **ShaneMcGovernIE** |
| QualityOfLife (caught marker, area banner, easy HM use, NPC walk) | originally [Quality of Life](https://github.com/unxpected-uxp/pokemon-gen1-recomp-mod-qol) by **unxpected-uxp** |
| Gen1Rematch, Gen3QOL, FORGET HM MOVES, REUSABLE TMS | maintained in the Gen1Wild QOL repository |

The Gen1Wild QOL README also credits the following. Their modules are not
included in this bundle; they were removed in 0.9.8.

- **Antigravity, gamecorner33** and the PokéPC / Followers EX lineage
  (ShockSlayer, the Pokémon Crystal Clear team): Gen1Follower.
- **Wowabox (Darklinkduck)**: *All Pokémon Catchable 151*.

### Quality of Life — unxpected-uxp

https://github.com/unxpected-uxp/pokemon-gen1-recomp-mod-qol ("Quality of
Life", id `quality_of_life`). Later-generation quality-of-life features: the
caught-Pokémon indicator in battle, area name banners, using HMs and fishing
rods straight from the overworld, and the battle EXP bar. Its caught marker,
area banner, easy HM use and NPC walk reach this bundle through Gen1Wild QOL's
QualityOfLife module (see the table above). No license file is included in
its repository.

### QoL Toggles

`qoltoggles/` (version 1.31.1). It provides quick nurse, repels, field moves,
EXP and money multipliers, instant text, hold to scroll and more. Its changelog
thanks [@ProprietaryWeakness](https://github.com/ProprietaryWeakness) for
suggesting MODERN TYPES. The author and repository are **not recorded** in the
bundled files.

### KIM Touch ("Kanto in Motion: Touch", `KIM_TOUCH`)

`touch/` (version 0.3.0). It provides the floating D-pad, tap menus, long press
and the battle touch buttons. The author and repository are **not recorded** in
the bundled files. It was written as a companion to Kanto in Motion / KIM Arena.

### Crystal-AiO itself

The host (`main.lua`) and `lib/crystal_aio/` are Crystal-AiO's own code: the hub,
setup wizard, overworld HUD, quick menu, Modern UI extensions, weather, time
of day, voxel cache tools, ALL 251 CATCHABLE, trainer levels and more.
Repository: https://github.com/drglitchyphd/aio-recomp

## Art and assets

### Battle Sprites Reloded — JDChaos

https://forums.pokemmo.com/index.php?/topic/142585-battle-sprites-reloded/

This is the source of Kanto in Motion's HD animated Pokémon battle sprites:
front and back, normal and shiny, and male/female variants where available.
They are delivered through the HD asset pack, which is downloaded rather than
shipped in the ZIP. The shiny menu icons in `assets/menu_icons/shiny/` are
generated from this shiny battle art.

### HD Rescaled Pokémon menu icons — LockeGriss and contributors

https://forums.pokemmo.com/index.php?/topic/183919-hd-rescaled-icons/

- Shipped in `assets/menu_icons/`.
- **HaseoSora** made the non-flying Charizard icon and the Cyndaquil-family
  flame edits:
  https://forums.pokemmo.com/index.php?/topic/183919-hd-rescaled-icons/#comment-2173491

### Trainer Card animated badges — xpixelpriorx

https://www.deviantart.com/xpixelpriorx

`assets/trainer_card/badges/`. These are used for the Kanto badges on the
Crystal Trainer Card.

### HD battle backgrounds

These are Kanto in Motion's painted 1920×950 backgrounds, delivered through the
HD asset pack (https://github.com/HaseoSora/Kanto-in-Motion-Assets). The
individual artist is not recorded in the bundle.

### Kenney 3D kits — Kenney (www.kenney.nl), CC0 1.0

`stadium2/assets/kenney_*`. These are the meshes behind the KENNEY HD battle
scenes, from Kenney Game Assets All-in-1 3.7.0:

- Nature Kit, Modular Cave Kit, City Kit (Suburban), City Kit (Industrial)
- Fantasy Town Kit, Furniture Kit, Factory Kit, Space Station Kit
- Graveyard Kit, Castle Kit, Mini Arena, Pirate Kit, Watercraft Kit
- Survival Kit

Each kit's original CC0 notice sits beside the files
(http://creativecommons.org/publicdomain/zero/1.0/).

Four textures are **not** Kenney assets. The scene READMEs say these were made
with an image-generation tool for this presentation:

- `meadow-grass.png`
- `summer-sky.png`
- `watercolor-materials.png`
- `watercolor-town.png`

### Poké Ball item icons — PokeAPI sprites

https://github.com/PokeAPI/sprites

`assets/gen2_aio/balls/`. These are the item sprites used for HD POKÉ BALLS and
the touch Poké Ball button. The item art is © Nintendo / Creatures Inc. /
GAME FREAK inc.

### Pixel Operator font — Jayvee Enaguas (HarvettFox96), CC0 1.0

`assets/fonts/pixeloperator/`. The full license text is in
`assets/fonts/pixeloperator/LICENSE.txt`.

## Integrated code

The following project is integrated into Kanto in Motion's code in this
bundle.

### Gen1 Modern UI — ArmstrongThomas

https://github.com/ArmstrongThomas/gen1-modern-ui

Kanto in Motion integrates a customized Gen1 Modern UI presentation. It is the
basis of the Modern UI and of several of the UI THEMES (Classic Mono, Crimson,
Modern Glass, Pocket Green, Midnight, Frost, Light, Dark). The Gen 1 presenter
itself was removed in 1.0.0; the Crystal Modern UI that remains is derived
from it.

### Dex Radar — Zetto22

https://github.com/Zetto22/dex_radar

Kanto in Motion includes presentation-only interoperability with the unmodified
Dex Radar mod (the Modern UI draws its screen in the Crystal theme). Dex Radar
is not bundled and keeps ownership of its own data, state and logic.

### Formerly bundled

1.0.0 made the bundle Crystal-only and removed Kanto in Motion's Gen 1
(Red/Blue/Yellow) and Gen 3 (FireRed/LeafGreen) code. Nothing derived from the
following projects remains in the mod; they are listed for the history of the
code:

- **Kanto Rework Suite — Faendra**
  (https://github.com/Faendra/kanto-rework-suite): Gen 1 move animations and
  routing, with their `PRAS-` animation sheets and `PRSFX-` sound effects.
- **Poké Ball Colorfix — keberos**
  (https://github.com/keberos/pokeball-colorfix): Gen 1 Poké Ball palette and
  presentation fixes.

## Optional external compatibility

Kanto in Motion and Wilds contain interoperability code for optional external
mods. None of these are bundled, and most are also listed as conflicts in
`manifest.json` because the bundle replaces them:

- Battle Art Voxel Gen2 (absol89 and Dramatic Shape contributors, per `mod.card`)
- Dramatic Shape and PotatoVoxel
- Typed Move Colors
- Useful Bag
- Advanced Box System
- HGSS_SPRITES
- Gen2 Clean UI
- Crystal Animated Sprites with Shiny Visuals
- Kanto Reforged
- Gold Sprites
- Translation mods

Battle Art was the bundle's second voxel engine until 0.9.1. Only Kanto in
Motion's compatibility code for it and its in-game options adapter
(`lib/crystal_aio/ingame_options.lua`) remain.

## Source not recorded in the bundle

The following are shipped in this repository, but no author, link or license is
recorded for them in the bundle. The maintainer should fill these in.

- **QoL Toggles** (`qoltoggles/`): author and repository.
- **KIM Touch** (`touch/`): author and repository.
- **gmarcs Gen 2 Voxel Mod** (`gmarc/`): repository link and license.
- **Nuzlocke** (`nuzlocke/`): repository link and license.
- **Stadium 2 Importer** (`stadium2/`): repository link and license.
- **Kanto in Motion** (root): license (the repository is now linked above).
- **Player trainer battle sprites** (`assets/battle/player-trainers-*/`): Ash,
  Brock, Bulma, Gary, Misty, Red and Gen 1–5 player sprites.
- **Pixel frames** (`assets/pixel_frame1-3.png`, `assets/gen2_aio/frames/pixel_frame_gen3.png`).
- **Shiny encounter effect** (`assets/effects/shiny_sparkle.png`, `assets/sfx/shiny.wav`).
  Kanto in Motion's notes say it "retains" these, without naming a source.
- **Wilds generated sprite sheets** (`wilds/assets/atlas/`, `wilds/assets/wilds_generated/`).
  These are derived from the third-party follower and overworld sprites credited
  above. Wilds says they inherit those sprites' terms.
