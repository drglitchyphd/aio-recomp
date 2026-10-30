# Crystal-AiO features

Crystal-AiO (formerly Gen2-AIO) is one mod for **Pokémon Crystal** on the
Gen1Recomp engine. It bundles Kanto in Motion, a 3D voxel overworld, Kenney
battle scenes, Wilds of Kanto Revival, Nuzlocke, KIM Touch, QoL Toggles and
Gen1Wild QOL. It also adds its own Crystal-specific work on top. This page walks
through what you get as a player and where each feature lives in the menus. For
who made each part, see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
Version-by-version changes are in
[README_CRYSTAL_AIO.md](README_CRYSTAL_AIO.md).

Everything here changes how the game looks or adds conveniences around it.
Battles, catching, items, saves and scripts still run through Crystal's own
code. Almost every feature can be switched off, and turning a Modern UI
screen off brings back Crystal's original one.

**Contents:** [Getting around the settings](#getting-around-the-settings) ·
[Setup wizard](#setup-wizard) · [3D voxel world](#3d-voxel-world) ·
[Weather and time](#weather-and-time) · [Battles](#battles) ·
[Overworld HUD](#overworld-hud-and-quick-menu) · [Modern UI](#modern-ui-screens) ·
[Themes](#themes-and-look) · [Nuzlocke](#nuzlocke) ·
[Wild Pokémon and followers](#wild-pokemon-and-followers-wilds-of-kanto) ·
[Quality of life](#quality-of-life) · [Difficulty and gameplay](#difficulty-and-gameplay) ·
[Touch controls](#touch-controls-kim-touch) · [Advanced](#advanced-performance-and-diagnostics)

---

## Getting around the settings

- **CRYSTAL-AIO hub.** Open it from **START → CRYSTAL-AIO** (**CRYS-AIO** when
  Crystal's own START box is showing), **OPTION → CRYSTAL-AIO** or the engine's
  **MOD MANAGER**. Every bundled part's settings are filed into
  nine topic pages:
  - GAMEPLAY
  - NUZLOCKE & RULES
  - BATTLE
  - OVERWORLD & 3D
  - DISPLAY & MENUS
  - QUALITY OF LIFE
  - WILD POKÉMON & FOLLOWERS
  - TOUCH CONTROLS
  - ADVANCED
- Each setting is on exactly one page. The selected row's help text is shown
  at the bottom of the page.
- Rows that would do nothing with your other settings are hidden. For example,
  the weather rows are hidden while WEATHER is OFF.
- Settings that make a Nuzlocke easier say so in their help text.
- The WILDS OF KANTO, NUZLOCKE, QUALITY OF LIFE and QOL TOGGLES switches sit
  at the top of their pages and load or unload that whole part. After a change
  they read **(NEXT LAUNCH)** until you restart the game.
- The pages use the Modern UI theme, are tappable, and scroll with a swipe.

## Setup wizard

- Opens when you start a **NEW GAME**. You can also open it at any time from
  **CRYSTAL-AIO → SETUP WIZARD** (the first row).
- **One-tap profiles:** RECOMMENDED, CASUAL, NUZLOCKE, HARDCORE NUZLOCKE and
  CLASSIC CRYSTAL.
- **STEP BY STEP:** seven short questions, each with 3–5 choices plus KEEP AS IS:
  - DIFFICULTY
  - NUZLOCKE (off / normal / hardcore / solo)
  - LOOK (Crystal, HeartGold, Johto Night, Gen 3, lead Pokémon, original)
  - BATTLES (HD + painted, HD + 3D scenes, lighter HD, original)
  - WORLD (3D diorama, 3D tilted, classic 2D)
  - WILD POKÉMON
  - CONVENIENCE
- Each choice is marked **CURRENT** or **SUGGESTED**.
- A REVIEW page lists every answer. Nothing changes until START GAME or APPLY,
  so you can back out safely with B.
- **SKIP** keeps your settings as they are.
- Turn off the automatic wizard on new games with
  **ADVANCED → SETUP WIZARD ON NEW GAME**.

## 3D voxel world

*(gmarcs Gen 2 Voxel Mod. Settings: OVERWORLD & 3D, plus some on ADVANCED.)*

- **VOXEL** turns the overworld into a 3D diorama: real geometry, depth, cast
  shadows and day/night lighting. Walking behind a building really hides you.
  - Camera steps: OFF, FULL, 15°, 35°, 50°, 75°, plus **1ST** (first person)
    and **3RD** (over the shoulder).
  - On 1ST and 3RD you walk freely in the direction the camera faces. Warps,
    encounters, ledges and scripts still behave as normal.
  - Keyboard hotkey: **3**.
- **Look settings:**
  - **T-SHIFT:** tilt-shift miniature blur.
  - **V-GRID:** tile seams.
  - **V-CURVE:** world curvature.
  - **WATER:** FULL / SKY / OFF.
  - **FOREST FX:** light shafts and drifting motes.
  - **AA:** anti-aliasing. Only shown with PERFORMANCE = QUALITY.
- **Edges of the map:**
  - **WORLD EDGE FILL** repeats the map's own border (trees, water, walls) out
    to the horizon instead of showing a black void.
  - **VOXEL EDGE** continues forest canopy and walls as low 3D blocks before the
    flat fill takes over.
- **Building areas ahead of time:**
  - **VOXEL PRECACHE** pre-builds the areas behind nearby doors in the
    background.
  - **VOXEL DISK CACHE** saves each built area to storage, so later visits and
    restarts load it instead of rebuilding it. This works on phones and
    tablets too. Visiting everything can use roughly 0.5–2 GB.
  - **BUILD 3D CACHE** (ADVANCED, or offered once when you are out in the world
    with 3D on) builds every area into the disk cache in one go. You can stop
    it and resume later. A restart is recommended once it finishes.
- **Signs and loading:**
  - Town and route name signs show in 3D.
  - A plain LOADING card covers the screen until the first 3D frame is ready.
- **Pokémon in the world.** Wilds' wild Pokémon, followers and NPC Pokémon of
  any size are drawn in 3D.
- **Zoom on foldables.** ZOOM is kept separately for tall, narrow screens (such
  as a Fold's cover screen) and regular screens. It switches automatically when
  you fold or unfold.

## Weather and time

*(OVERWORLD & 3D page; the battle weather rows are on BATTLE.)*

- **WEATHER** can be ON, LITE or OFF. It is drawn over the 2D and 3D world and
  over battles:
  - **PLACE WEATHER:** snow outside Mt. Silver, frost in the Ice Path, mist on
    the Lake of Rage, embers in the Burned Tower, and more.
  - **RANDOM RAIN:** rain on outdoor routes, set by Crystal's clock so it is the
    same everywhere at a given time.
  - **MOVE WEATHER:** shows Rain Dance, Sunny Day and Sandstorm while they are
    active.
  - **WEATHER IN BATTLE:** battles keep the weather of the place they happen in.
- **TIME OF DAY** sets one clock for palettes, the voxel sky, encounter tables,
  Wilds' spawns, NPC schedules and weekday events:
  - SYNC: this device's clock.
  - MORNING, DAY, EVENING or NIGHT: hold that time.
  - CYCLE 30 or CYCLE 60: a full day every 30 or 60 minutes.
  - CRYSTAL CLOCK: the clock set in your save.
- **TIME FADE** dims smoothly into and out of the day/night colour switch
  instead of snapping.

## Battles

*(Kanto in Motion, gmarc 3D battles, Stadium 2 Importer's Kenney scenes and
Crystal-AiO additions. Settings: BATTLE page.)*

**HD art and backgrounds**

- **HD Pokémon:** Kanto in Motion's animated HD battle sprites for all 251
  Pokémon, front and back, normal and shiny. This includes every Unown letter.
  - BATTLE SPRITES turns them on.
  - The large HD pack is downloaded once from **ADVANCED → ASSET MANAGER** and
    kept between updates.
- **ANIMATED SPRITES** can be ON, BATTLE ONLY or OFF.
- **BATTLE BACKGROUND** sets what the battlers stand on:
  - **KIM HD:** painted HD scenes picked to match your location, with
    sunrise/day/sunset/night variants. Tune them with KIM HD BG ALIGN / FILL /
    OFFSET.
  - **KENNEY HD:** a live, painted 3D scene for the place (woodland, cave, lake,
    town, ocean and more), built from Kenney's CC0 kits.
    - Tune it with 3D BG RESOLUTION, 3D BG STYLE (Stadium or watercolor),
      3D BG EFFECTS and 3D BG WEATHER.
    - If a scene can't be built, it falls back to KIM HD.
  - **VOXEL WORLD:** fight on the 3D map itself.
  - **DEFAULT:** Crystal's plain battle background.
- **3D battle options:**
  - BATTLE CAMERA (LOCKED or FREE).
  - PLAYER INTRO SPRITE.
  - 3D SPRITE DETAIL (1X–4X).
  - ENEMY PKMN SIZE (80–200%).
  - PKMN SHADOWS with shadow opacity.
  - On tall screens, your Pokémon is sized automatically to stay on screen.

**Modern battle UI**

- **MODERN BATTLE UI** gives you a themed FIGHT / PKMN / PACK / RUN panel and
  move list:
  - BATTLE UI MODE: OG or WIDE.
  - BATTLE UI SIZE: 60–150%.
  - Opacity and text size.
  - MOVE LAYOUT: GRID or VERTICAL.
- **MOVE INFO** shows the move's type, PP, power and accuracy.
- **MOVE TYPE COLORS** tints each move in its type colour.
- **EFFECTIVENESS HINT** (off by default) shows SUPER, WEAK or NO EFFECT against
  the current foe.
- **BATTLE HUD = MODERN** replaces Crystal's name and HP boxes with themed
  cards. The party rows on these cards are small Poké Balls coloured by HP.
  - NATIVE keeps the original HUD and unlocks HUD COLOR, EXP BAR and the caught
    indicator.
- **Long-press info** (touch):
  - Hold a move for its type, category, power, accuracy, PP and description.
  - Hold a HUD card for that Pokémon's types, stats, moves and whether you have
    caught it.
- **Reorder moves:** drag a move onto another to swap them, as SELECT does on
  the cartridge. The move picked for a swap is outlined.

**Throws, animations and messages**

- **HD POKÉ BALLS:** every Crystal ball is drawn as its own item icon during
  the throw, bounces and wobbles.
- **Quick ball:** in a wild battle, SELECT on a controller throws your last-used
  ball. It never picks a Master Ball.
  - On touch, a round **Poké Ball button** in the battle panel shows which ball
    will be thrown and how many you have.
- **Multi-hit moves** (Double Kick, Fury Attack, …) play their animation on every
  hit, as on the cartridge.
- **HIT FLICKER = STEADY** keeps your Pokémon visible through the brief blank
  frames inside some animations.
- **Level-up:** the "grew to level N!" message and the STATS card appear
  together, and one press continues. This also applies to Pokémon that level
  up from the bench.
- **Evolution:** a **STOP EVOLUTION** button sits in the evolution window. A B
  press or tap at any moment is remembered. Stone evolutions still can't be
  stopped, as on the cartridge.
- **Disobedience explained:** a traded Pokémon that won't obey gets one extra
  line saying which badge raises its obedience level.
- **Low-HP alarm:** ONCE, a set number of beeps, or Crystal's nonstop alarm.
- **Battle QoL** (from QoL Toggles):
  - REMEMBER CURSOR and REMEMBER LAST MOVE.
  - B FOR QUICK FLEE and INSTANT FLEE.
  - ANIM SKIP.
  - HEAL AFTER BATTLE.

## Overworld HUD and quick menu

*(DISPLAY & MENUS page.)*

- **OVERWORLD HUD:** a compact, themed panel shown only while you walk. It has
  a game clock, your party as six small Poké Balls coloured by HP, and a row
  of shortcut buttons.
  - Tap the clock or party panel to open the POKéMON screen.
  - **HUD POSITION** offers six corners and edges.
- **HUD BUTTONS** editor (here or in the QUICK MENU): choose up to six buttons
  and their order.
  - **GEAR:** opens the POKéGEAR.
  - **AREA:** opens the Area Dex.
  - **BIKE:** gets on the Bicycle.
  - **ITEMS:** opens the key item wheel.
  - **DEX:** opens the POKéDEX.
  - **HEAL:** quick heal. It uses revives first, then the cheapest matching
    status cure, then the cheapest potion that covers the missing HP. It never
    uses bitter herbs.
  - **FLY / DIG:** FLY outdoors. In caves it uses DIG or an Escape Rope.
  - **QUICK:** opens the quick menu.
  - **TRACK:** opens the Nuzlocke encounter tracker. A red dot means you haven't
    had this area's encounter yet.
  - **BOX:** opens your PC boxes from anywhere.
- A button that can't be used right now is dimmed. Tapping it tells you why.
- **QUICK MENU:** hold START on the overworld (touch), or use START → QUICK.
  - It has POKéGEAR, FLY (the real Fly map), AREA DEX, DAY-CARE, TODAY, QUICK
    HEAL, HUD BUTTONS and KEY ITEMS.
  - **DAY-CARE** shows both Pokémon, the levels they gained, the price, how
    well they get along, any egg and the steps left on eggs.
  - **TODAY** lists this week's events (contest, Week Siblings, Lapras, …).
- **AREA DEX:** every wild Pokémon on the current map, grouped by time of day,
  surfing, each rod, Headbutt trees and Rock Smash, with odds and levels.
  Unseen Pokémon appear as silhouettes, and caught ones are marked with a
  ball.
- **KEY ITEM WHEEL:** hold SELECT on the overworld (touch) and drag to an item.
  Hold an item in the PACK to pin it to the wheel. The item you pick also
  becomes your SELECT item.
- **AREA SIGN = MODERN:** town and route names appear on a themed plaque in
  2D and 3D.

## Modern UI screens

*(Kanto in Motion's Modern UI, extended by Crystal-AiO. Turn screens on or off on
DISPLAY & MENUS with MODERN UI, MENU UI, DIALOGUE UI and POKéMON SCREENS.)*

Every full menu has the same footer and a close (X) or back (arrow) button.
Choose its corner with **MENU BUTTON**. Lists scroll with a swipe like a phone,
and rows are tappable.

- **Title and NEW GAME:** the title menu, the CONTINUE card, the intro and the
  naming keyboard (with real key caps), plus the clock setup.
- **START menu**, with START MENU UI SIZE and TEXT SIZE, plus **PC** and
  **CRYSTAL-AIO** entries.
- **POKéMON (party):** big HD icons and SWITCH / STATS / ITEM popups.
  - Long-press and drag a Pokémon to move it.
  - **RELEARN** opens a move reminder.
- **SUMMARY**, **PACK** (pockets, quantities, item descriptions), **POKéGEAR**
  (a time-of-day clock dial, phone cards and incoming caller ID), **TRAINER
  CARD** (Johto and Kanto Gym Leader pages with animated badges), and
  **POKéDEX** (list, entries, area map and search).
- **PC box:** every box as one paged 5×4 grid of HD sprites, with your party as
  a strip and a detail panel.
  - Drag a Pokémon between the party, pages and slots.
  - Crystal's own rules still apply (a full box or party, your last healthy
    Pokémon, mail).
- **Poké Mart:** BUY and SELL with tappable lists and quantity buttons.
  - **QUICK SELL:** a SELL VALUABLES button sells every sell-only item
    (Nuggets, Pearls, Stardust, mushrooms, Slowpoke Tails, …) after one YES/NO.
  - The quantity picker has an **ALL** button.
- **Moves:** FORGET A MOVE (with type pills and stats), the Move Deleter, PP
  restore, and the **Move Tutor** (ABLE / NOT ABLE / KNOWS IT per Pokémon).
- **Item PC, Mom's bank and mail:** withdraw, deposit and toss with quantity
  buttons; a keypad for the bank; the mailbox; and reading and writing mail.
- **Day-Care conversation**, **NPC trades** and **phone** prompts.
- **Game Corner** prize counters and coin seller, the **Bug-Catching Contest**
  swap, the **Battle Tower** level list, bedroom **decorations**, elevators,
  **Buena's password** and Blue Card prizes, and the photo studio.
- **Story screens:**
  - The **Hall of Fame** (with HD sprites; the PC viewer has NEXT / NEXT TEAM).
  - The **Diploma**.
  - **Egg hatching** (the native shell animation, then the HD hatchling).
  - The **Unown printer and puzzle** (tap or drag the panels).
- **Dialogue** box sized to Crystal's text, with tappable YES/NO and menus.
- **MENU DIM** darkens the world behind menus.
- **MENU TRANSITIONS** can be DARK (a short themed fade) or WHITE (Crystal's
  original).

## Themes and look

*(DISPLAY & MENUS page.)*

- **UI THEME** (first row) opens a list of themes:
  - GEN1 MODERN, HEARTGOLD, SOULSILVER, JOHTO NIGHT
  - CRYSTAL, GOLD, SILVER, POKEGEAR, HIGH CONTRAST
  - CLASSIC MONO, CRIMSON, CRIMSON GLASS, MODERN GLASS, POCKET GREEN
  - MIDNIGHT, MIDNIGHT GLASS, FROST, LIGHT, DARK
  - **TYPE (LEAD POKéMON)** and **TYPE LIGHT (LEAD POKéMON)**: coloured by your
    lead Pokémon's type, changing when your lead does.
  - **GEN 3 (FRLG)**
  - **CUSTOM:** pick a border (GEN 3, FRAME 1–3, SOFT, PLAIN), a backing colour
    and a border colour, 11 colours each.
- **UI FONT:** Pixel Operator or KIM ORIGINAL (with an optional pixel art font).
- **Sizes and layout:** font scale, UI scale, density, layout style, frames and
  panel opacity.
- **MENU SPRITES:** KIM HD or VANILLA.
- **POKéMON ICONS:** HD menu icons.

## Nuzlocke

*(Nuzlocke mod, adapted for Crystal. Settings: NUZLOCKE & RULES page.)*

- **Rules for the run** are set by the setup wizard at NEW GAME and fine-tuned in
  **NUZLOCKE & RULES → RUN RULES**, a themed and tappable page:
  - Permadeath.
  - First catch per area and failed encounters.
  - Dupes Clause (species or family) and Shiny Clause.
  - Nickname rule.
  - Gift and trade rules, and no legendaries or mythicals.
  - Item, shop, Pokémon Center and escape restrictions.
  - Whiteout ends the run.
  - World-building flavour text.
  - **LOCK RULES** makes the page read-only for the rest of the run.
- **Level caps:** **LEVEL CAP SCOPE** can be NONE, GYMS, E4, CHAMP or POSTGAME.
  - Caps follow the Johto and Kanto badges in your save.
  - After a battle, one "LEVEL CAP REACHED" message names every capped Pokémon.
- **Encounter tracker (ENCOUNTERS)** has LOG and MAP tabs:
  - Totals for caught, fainted and failed, plus the next level cap.
  - One row per area with the Pokémon's icon and a status: PARTY, CAUGHT,
    FAINTED, FAILED or OPEN.
  - Open it from the **TRACK** HUD button.
- **Area Dex** (see the HUD section) shows what each area can still give you.
- Crystal support comes from Nuzlocke's Gold (GSC) paths. Some Gold rules are
  still marked experimental upstream.

## Wild Pokémon and followers (Wilds of Kanto)

*(Wilds of Kanto Revival. Settings: WILD POKéMON & FOLLOWERS page.)*

- **Visible wild Pokémon:** they roam the grass, caves and water, and touching
  one starts the battle.
  - **CLASSIC ENC** keeps random step encounters as well.
  - **SILHOUETTE** blacks out undiscovered or all wilds.
  - **GRASS** draws them above the grass or partly hidden in it.
- **TOWN POKéMON:** peaceful Pokémon in towns and interiors.
- **Followers:** up to six party Pokémon walk behind you.
  - **FOLLOWER IS PARTY LEAD** makes the follower your first healthy Pokémon,
    updated as soon as you reorder, deposit or faint.
- **GFX STYLE:** Poké Followers / GSC (16×16, Crystal-style) or HGSS / PokeMMO
  (true-size).
- **WILDS NPC POKéMON:** Pokémon that stand in the world as characters use
  Wilds' sprites in your style, in 2D and 3D, sized like your follower. This
  covers Azalea's Slowpoke, the Charcoal Kiln's Farfetch'd, the Red Gyarados,
  Snorlax, the legendary beasts and the Day-Care Pokémon.
- **SHINY RATE:** from Off and 1/8192 up to Always. A shiny shows on the
  overworld, is shiny in battle, and stays shiny once caught.
- Talking to a follower or town Pokémon can show a PMDCollab dialogue portrait.

## Quality of life

*(Gen1Wild QOL, QoL Toggles and Crystal-AiO. Settings: QUALITY OF LIFE page unless
noted.)*

- **Moving around:**
  - **SPRINT** while holding a button (with surf and bike options).
  - **EASY HM USE:** press A facing a tree, boulder, rock or whirlpool.
  - **WATER INTERACTION:** fish first or surf first.
  - **AUTO CUT.**
- **Field moves:**
  - **FIELD MOVES ALL:** any party Pokémon that can learn a field move can use
    it. TM-only moves such as Rock Smash or Dig need the TM in your bag.
  - **BADGELESS HMs** and **HM ITEM REQUIRED.**
- **Pokémon Centers and healing:**
  - **QUICK NURSE** and **TURN AWAY (NURSE).**
  - **HEAL ON MAP CHANGE.**
- **REPELS:** OFF, ASK, AUTO or INFINITE.
- **Access from anywhere:**
  - **PC IN START MENU:** Bill's PC from anywhere.
  - **QUICK MENU** and **KEY ITEM WHEEL.**
- **TMs and HMs:**
  - **REUSABLE TMS** and **FORGET HM MOVES** (off by default).
  - **REMEMBER MOVES:** the move reminder.
- **Saving:** **AUTO SAVE** and **AUTO CONTINUE.**
- **Menus:**
  - **MENU LAYOUT** editor: reorder or hide START and PC menu rows.
  - **RENAME**, **PARTY SCROLL** and **BULK MART.**
- **Text and scrolling** (DISPLAY & MENUS):
  - **INSTANT TEXT.**
  - **HOLD TO SCROLL.**
  - **BATTERY INDICATOR.**
- **LIGHTS ON** (OVERWORLD & 3D): dark caves without Flash.

## Difficulty and gameplay

*(GAMEPLAY page.)*

- **TRAINER LEVELS:**
  - ORIGINAL.
  - **MATCH** raises a trainer's strongest Pokémon to your strongest Pokémon's
    level.
  - MATCH +2.
  - MATCH -1/-2.
  - MATCH -5 TO 0, picked per trainer.
  - Trainers are never lowered below Crystal's levels, and hand-picked movesets
    are kept.
- **ALL 251 CATCHABLE** (on by default):
  - Crystal's 33 missing species become obtainable. Base forms go into rare wild
    slots, using HeartGold/SoulSilver locations first.
  - Legendaries and mythicals appear only after the Elite Four.
  - **Trade evolutions** happen by level-up (Lv 37, or while holding the trade
    item). Real trades still work.
- **Obedience:** traded Pokémon keep Crystal's badge-based obedience. Renaming
  one doesn't make it yours.
- **QoL Toggles gameplay switches:**
  - **PERFECT DVS:** keeps shininess, gender and Unown letters.
  - **EXP MULT**, **MONEY MULT**, **CATCH GIVES EXP**, **KEEP MONEY.**
  - **POKEBALL BONUS**, **ALWAYS CATCH**, **FULL HEAL CATCH.**
  - **INFINITE HELD ITEM**, **INSTANT HATCH**, **INSTANT FISH**, **SAND FREE.**
  - **NO ENCOUNTER DUPES**, **POISON SAVE.**
  - **MODERN TYPES:** Steel no longer resists Ghost and Dark.
  - Switches that make a Nuzlocke easier ship OFF.
- **EXP SHARE** (Gen 5+ style) and **trainer rematches** (with optional prize
  money).

## Touch controls (KIM Touch)

*(Android and other touch screens. Settings: TOUCH CONTROLS page. The layout is
saved separately for each screen shape — outer or inner, portrait or landscape —
and loads when you fold, unfold or rotate.)*

- **FLOATING CONTROLS:**
  - Touch anywhere for a D-pad ring under your thumb, and tap anywhere for A.
  - B, START and SELECT sit on one side.
  - Choose **BUTTON SIDE**, **BUTTON HEIGHT** (LOW / MID / HIGH, kept clear of
    the HUD), **CONTROL SIZE** (50–200%), **CONTROL OPACITY** and **DRAG DEAD
    ZONE**.
- **TAP MENUS:** tap battle commands, moves, Pokémon, PACK items and pocket
  tabs, POKéGEAR tabs, phone contacts, Pokédex entries, Mart lists, YES/NO
  boxes, the naming keyboard and the settings rows.
- **Battle touch:**
  - The Poké Ball and back buttons are part of the battle panel.
  - The floating buttons stay clear of both HP boxes.
  - B stays on screen during animations so you can skip them.
- **LONG PRESS:**
  - Move info and HUD card info in battle.
  - Drag to reorder the party and the PC box.
  - Pin PACK items to the key item wheel.
  - Hold START for the QUICK MENU and SELECT for the KEY ITEM WHEEL.
- **Swipe to scroll** any list, with flick momentum. **Hold to repeat** in menus.
  **Hold to fast-forward** text.
- **Close buttons:** while a menu shows its own X or back button, the floating
  B (and usually START and SELECT) hide. The X or back button does the same
  job. MENU BUTTON can move it to a bottom corner for one-handed use.
- **FAR DRAG HOLDS B** (off by default): dragging well past the ring also holds
  B.
- **Desktop and controllers:** everything also works with keys and pads.
  - SELECT throws the quick ball.
  - START → QUICK opens the quick menu.

## Advanced, performance and diagnostics

*(ADVANCED page.)*

- **PERFORMANCE:**
  - **BALANCED** (default) holds the frame rate at 60, turns voxel AA off and
    lowers FOREST FX. It runs cooler and saves battery.
  - **QUALITY** restores your own settings.
- **ASSET MANAGER:** download, repair or remove Kanto in Motion's HD Pokémon
  and background pack.
- **VOXEL PRECACHE**, **VOXEL DISK CACHE** and **BUILD 3D CACHE** (see the 3D
  voxel world section).
- **DIAGNOSTICS** (off by default) shows short status lines on screen for bug
  reports. They cover the battle background, voxel build timing and disk
  cache, Wilds, followers, NPC Pokémon, quick nurse, performance and the GPU.
- **MOD LIST:** the engine's own list of installed mods.
- **Updates:** install and update through the launcher's custom mod index
  (see [README_CRYSTAL_AIO.md](README_CRYSTAL_AIO.md#installing-and-updating)).
  Settings, the HD cache and the 3D cache carry over between updates. Coming
  from Gen2-AIO, Crystal-AiO imports its settings and data on first launch.
