# Crystal-AiO settings audit (as Gen2-AIO build 0.9.58, Crystal, Android/Fold)

Read-only audit. No repository file was changed. Implemented in 0.9.66 (see "Decisions" at the end).

## How this was checked

- **Booted on stubs.** I loaded the bundle's real `main.lua` on a stub engine (`luajit`, scratchpad `audit/h.lua` + `audit/dump.lua`), with generation=2 and OS=Android. Two things were then dumped:
  - the merged schema: 203 rows, every `options:define` call;
  - the real `ui.options.rows` chain, filed by `lib/crystal_aio/hub.lua`'s own `sectionOf`.
- **Hub pages below are what the hub actually builds.** They are not a hand-applied version of RULES. Raw dump: `audit/out.txt`.
- **Readers were traced by grep** in Gen-2-active files only. These are `kim_main.lua` (Gen-2 branches), `lib/gen2_modern_*.lua`, `lib/gen2_hud_color.lua`, `lib/battler_shadows.lua`, `lib/menu_icons.lua`, `lib/crystal_aio/*`, and the component folders.
  - `lib/modern_ui_integrated*.lua` was Gen 1 only and never loaded on Crystal, so reads there did not count. 1.0.0 removed it with the rest of the Gen 1 / Gen 3 code.
- **Status legend:**
  - **OK**: works on Crystal.
  - **DEPENDS**: works only when another setting has a given value.
  - **NO EFFECT**: nothing on Crystal reads it, or it is overridden.
  - **BROKEN**: it is read, but cannot work.
  - **DUP/CONFLICT**: another row drives the same behaviour, or the two fight.
  - **?**: not verified.

---

## 0. Headline findings (most important first)

1. **Every QOL TOGGLES hub row is BROKEN, because the hub writes the wrong key.** This is the real cause of the QUICK NURSE device bug.
   - `namespaced().define` rewrites `row.key` in place to `qt_<key>` (main.lua L468).
   - main.lua L966-969 then copies the rows and adds `qt_` again, so the hub rows are `qt_qt_<key>`.
   - The ingame adapter reads and writes `modOptions["crystal-aio"]["qt_qt_quick_nurse"]`.
   - QoL Toggles reads `qt_quick_nurse` or bare `quick_nurse` (qoltoggles/main.lua `storedIn` L676-694).
   - I reproduced this in the harness: toggling INSTANT TEXT on the hub writes `qt_qt_instant_text`. The row then shows ON while the component still reads OFF.
   - The 0.9.58 `sessionGet` change cannot fix this.
   - The engine's MOD LIST page uses the correct `qt_` keys. The two pages therefore show different values for the same toggle.
   - Fix: build `rowsSchema` from the already-prefixed key, without adding `qt_` a second time.
2. **REUSABLE TMS and FORGET HM MOVES are lost on Crystal.**
   - main.lua FORCED (L905) holds QoL Toggles' UNLIMITED TMs and FORGETTABLE HMs OFF, in favour of Gen1Wild QOL's versions.
   - Those versions are `games = { "gen1" }` (qol_feature_reusable_tms.lua:37, qol_feature_forget_hm.lua:56). bundle_common.lua:150 skips them on Gen 2.
   - Net effect: TMs are consumed and HMs cannot be forgotten.
   - QoL Toggles already has Gen-2 code for both (qoltoggles/main.lua L5050-5225, `installGen2TmAndHmPatches`).
   - Their two master switches in GEN1WILD QOL show but do nothing.
3. **Misfiled rows in the hub.**
   - UI FONT goes to BATTLE, because key `arenaFont` contains "arena".
   - MOVE TYPE COLORS, EFFECTIVENESS HINT, HIT FLICKER and T-SHIFT fall through to MORE.
   - MENU MANAGER lands on DISPLAY & UI.
4. **The same setting is reachable in two or three places.**
   - UI THEME: the hub picker and KIM > UI SETTINGS.
   - SHOW WILD MONS and CLASSIC ENC: the hub page and Wilds' own WILDS OF KANTO screen.
   - MENU MANAGER: the hub row and GEN1WILD QOL > MENU LAYOUT.
   - The whole schema again on MOD LIST > crystal-aio.
   - Battle UI rows are split between the BATTLE page and KIM > UI SETTINGS.
5. **Settings that silently do nothing at their default partner value.**
   - AA under PERFORMANCE=BALANCED (the default): locked to 0 (main.lua:223).
   - FOREST FX "FULL": a phone only offers LOW/OFF (gmarc/lib/ForestAtmos.lua:73).
   - REPEL PROMPT while AUTO-REPEL is on.
   - HUD COLOR, EXP BAR and POKéDEX INDICATOR unless BATTLE HUD=NATIVE.
   - PIXEL ART FONT unless UI FONT=KIM ORIGINAL.
   - UI FRAME STYLE and PIXEL FRAME when the theme is GEN 3 or CUSTOM (the theme's own frame wins, gen2_modern_style.lua:182, 240).
   - 3D SPRITE DETAIL and ENEMY PKMN SIZE when BATTLE BACKGROUND=DEFAULT (they still show).
6. **New conflict found: PERFECT DVS on Gen 2.** It sets all DVs to 15 (qoltoggles/main.lua:2285). In Gen 2 shininess, gender and Unown form come from DVs, so every caught or gifted Pokémon becomes non-shiny, and male where the species allows. It fights SHINY RATE and the Nuzlocke Shiny Clause. It is OFF by default.
7. **Battle Art / PotatoVoxel / Gen 1 KIM rows (POTATO CAMERA, POTATO MOBILE ENEMY SIZE, 3D PKMN SIZE, PLAYER PKMN SIZE, HUD SIZE/SCALE/OPACITY, SHINY ODDS, PLAYER TRAINER, ...) are not visible on Crystal.** kim_main.lua:827-828 empties `battleOptionSchema` when IS_GEN2. The Gen 1 title rows are filtered out at kim_main.lua:427-447. Only dead code and stale help text that mention them remain (section 2).

---

## 1. Every user-visible row

There are three surfaces:

- **(H) CRYSTAL-AIO hub** (START / OPTION -> CRYSTAL-AIO), including the sub-screens its rows open.
- **(K) KANTO IN MOTION screens**, opened from the hub.
- **(L) MOD LIST > crystal-aio**: the engine ManagerState. It lists all 203 merged-schema rows again and honours `visible_if`. Each row below exists there too, unless marked hidden.

The hub adapter (`lib/crystal_aio/ingame_options.lua`) ignores `visible_if`. It only honours `_kimArenaRowHidden` (main.lua:168-195).

### 1a. Hub page DISPLAY & UI (`ui`)

| Key | Label | Component | Visibility | What it does on Crystal (reader) | Status |
|---|---|---|---|---|---|
| gen2UiTheme | UI THEME: <name> (opens a list) | theme_picker.lua:95 | always | Modern UI palette (gen2_modern_style.lua:37, battle_ui:1029, dialog_ui:107 ...) | OK; DUP with K > UI SETTINGS > UI THEME |
| kimArenaCustomFrame / Backing / Border | BORDER / BACKING / BORDER COLOR (lists) | theme_picker.lua:107 | only when theme=CUSTOM; hidden from hub rows (main.lua:173), visible in L | CUSTOM theme parts (gen2_modern_battle_ui.lua:249-250) | OK |
| hudButtons | HUD BUTTONS (editor: 8 buttons, OFF/#1-6, RESET) | quick_menu.lua:1037 | always | Which overworld HUD buttons show and in what order (quick_menu.lua:923) | DEPENDS on OVERWORLD HUD |
| (submenu) | KANTO IN MOTION -> OPEN | kim_main.lua:7715 | always | Opens K (section 1j) | OK |
| overworldHud | OVERWORLD HUD | main schema | always | Tappable HUD, clock, party HP (overworld_hud.lua:11, quick_menu.lua:1054) | OK |
| menuTransitions | MENU TRANSITIONS | main | always | Dark vs white menu fades (menu_fade.lua:22) | OK |
| areaSignStyle | AREA SIGN | main | always | Modern plaque vs native sign (voxel_overlays.lua:37) | OK. QoL Toggles MAP LOCATION is forced off and Gen1Wild AREA BANNER is Gen 1 only, so this is the only live one |
| menuDim | MENU DIM | main | always | Darkens the world behind menus (menu_dim.lua:45) | OK |
| (editor) | MENU MANAGER | qol Gen1MenuManager/main.lua:654 | always | Opens the START/PC menu layout editor | DUP: same feature as GEN1WILD QOL > MENU LAYOUT |

### 1b. Hub page WEATHER & TIME (`weather`)

| Key | Label | Reader | Status |
|---|---|---|---|
| weatherFx | WEATHER (ON/LITE/OFF) | weather.lua:99, 190 | OK. Master switch: at OFF the 4 rows below do nothing but stay visible (DEPENDS) |
| weatherPlaces | PLACE WEATHER | weather.lua:110 | DEPENDS on WEATHER |
| weatherRain | RANDOM RAIN | weather.lua:74 | DEPENDS on WEATHER |
| weatherMoves | MOVE WEATHER | weather.lua:105 | DEPENDS on WEATHER |
| weatherBattle | WEATHER IN BATTLE | weather.lua:106 | DEPENDS on WEATHER. Possible CONFLICT with 3D BG WEATHER (both can rain on a Kenney battle; not verified on device) |
| timeOfDay | TIME OF DAY | time_of_day.lua:29, 73. Also drives the voxel sky (main.lua:1101, gmarc `daytime` locked to "sync", main.lua:202) | OK |
| timeFade | TIME FADE | time_of_day.lua:151 | DEPENDS on TIME OF DAY = SYNC/CYCLE |

### 1c. Hub page OVERWORLD & VOXEL (`world`)

| Key | Label | Component | Reader / notes | Status |
|---|---|---|---|---|
| pipeline:voxel | VOXEL (OFF/FULL/15/35/50/75/1ST/3RD) | gmarc engine pipeline (gmarc/main.lua:144, rows added at :640) | 3D world camera | OK. FULL removes V-GRID, V-CURVE, WATER and T-SHIFT from the menu and resets zoom (gmarc/main.lua:300-330) |
| grid | V-GRID | gmarc ModSetting | gmarc/lib/VoxelGrid.lua | OK (cosmetic wireframe) |
| curve | V-CURVE | gmarc | gmarc/lib/WorldCurve.lua | OK |
| water | WATER | gmarc | gmarc/lib/Water.lua | OK |
| atmos | FOREST FX | gmarc | ForestAtmos.lua:73 (phone ladder LOW/OFF only); main.lua:224 | OK. PERFORMANCE's "FULL to LOW" clause never applies on Android |
| aa | AA | gmarc | AntiAlias.lua; **locked to 0 while PERFORMANCE=BALANCED** (main.lua:223) | CONFLICT / NO EFFECT at default |
| voxelPrecache | VOXEL PRECACHE | main | main.lua:233 -> gmarc Prefetch | OK (advanced) |
| voxelDiskCache | VOXEL DISK CACHE | main | main.lua:236 -> MeshStore | OK (advanced) |
| perfMode | PERFORMANCE | main | main.lua:221; caps FPS at 60 (main.lua:1160-1172) | OK. CONFLICT with AA and with Crystal's own MAX FPS (overrides it while BALANCED) |
| voidFloor | WORLD EDGE FILL | main | main.lua:295 | OK |
| voidRelief | VOXEL EDGE | main | main.lua:294 | OK |

Hidden from this page (pinned by the host, still settable in L only if defined):
- gmarc `daytime` (locked to sync).
- `battles` (3D-BTL, locked by BATTLE BACKGROUND).
- `stadiumImport`.

All three are removed from the schema by GM_ART (main.lua:162, 397-407), so they do not appear in L either.

### 1d. Hub page WILD POKEMON (`wilds`)

| Key | Label | Reader | Status |
|---|---|---|---|
| allCatchable | ALL 251 CATCHABLE | crystal251.lua:57 | OK (gameplay) |
| wildsOfKanto | WILDS OF KANTO (ON/OFF) | main.lua:533 (load gate, next launch) | OK. Same label as the WILDS OF KANTO -> OPEN row below (confusing) |
| npcMonSprites | WILDS NPC POKEMON | npc_mons.lua:52 | DEPENDS on Wilds loaded |
| followerLead | FOLLOWER IS PARTY LEAD | follower_lead.lua:36 | DEPENDS on Wilds and FOLLOWERS >= 1 |
| wok_enabled | SHOW WILD MONS | wilds/lib/settings_menus.lua:600 row; spawn_logic.lua:3003 | OK; DUP (also inside WILDS OF KANTO screen) |
| wok_random_encounters | CLASSIC ENC | config.lua:757-768; settings_menus.lua:612 | OK; DUP (also inside screen) |
| (submenu) | POKE FOLLOW EX -> OPEN | settings_menus.lua:646. One row: FOLLOWERS 0-6 (`wok_follower_count`, follower/settings.lua:62) | OK. Odd name for one row |
| (submenu) | WILDS OF KANTO -> OPEN | settings_menus.lua:376-549 | see 1k |

### 1e. Hub page BATTLE (`battle`)

| Key | Label | Visibility | Reader / what it does | Status |
|---|---|---|---|---|
| trainerLevels | TRAINER LEVELS | always | trainer_levels.lua:68 (`trainer.party` hook) | OK. OVERLAP with GEN1WILD QOL > TRAINER REMATCH > MATCH LEVELS (`rematch_scale`): both raise a rematch roster (Gen1Rematch/gen2.lua:217 then trainer_levels). Gameplay, not battle display |
| arenaFont | UI FONT | always | font.lua:34 (Pixel Operator for all Modern UI) | OK but **MISFILED** ("arena" rule). Interacts with K > PIXEL ART FONT and FONT SCALE |
| hdBall | HD POKE BALLS | always | hd_ball.lua:45 | OK |
| arenaCardDetail | 3D SPRITE DETAIL | always (rowHidden only hides it on the dead non-gmarc branch, main.lua:182) | main.lua:376 | DEPENDS on BATTLE BACKGROUND != DEFAULT. Shown but NO EFFECT at DEFAULT |
| arenaEnemySize | ENEMY PKMN SIZE | always | main.lua:380 | DEPENDS (same). Help says "pair with PLAYER PKMN SIZE", a row that does not exist on Crystal |
| arenaBackground | BATTLE BACKGROUND | hidden when BATTLE SPRITES off (main.lua:184) | backdrop.lua:51 | OK |
| arenaHud | BATTLE HUD (MODERN/NATIVE) | always | modern_hud.lua:41; gates qt EXP BAR (main.lua:913) | OK. Makes K's HUD COLOR, QoL EXP BAR and POKéDEX INDICATOR no-ops at MODERN |
| arenaCamera | BATTLE CAMERA | hidden at DEFAULT bg (main.lua:116) | main.lua:277, 320 | OK. Help still says "FREE restores Battle Art's drifting camera" (stale) |
| arenaPlayerIntro | PLAYER INTRO SPRITE | hidden at DEFAULT | main.lua:282 | OK |
| kimHdAlign / kimHdFill / kimHdOffset | KIM HD BG ALIGN / FILL / OFFSET | only at KIM HD (offset only with ALIGN off) | backdrop.lua:350-353 | OK |
| arenaResolution / arenaShader / arenaExtras / arenaWeather | 3D BG RESOLUTION / STYLE / EFFECTS / WEATHER | only at KENNEY HD | pinned into stadium2 (main.lua:574-582) | OK. 3D BG WEATHER overlaps WEATHER IN BATTLE |

### 1f. Hub page RULES (`rules`)

| Key | Label | Reader | Status |
|---|---|---|---|
| (submenu) | RUN RULES | nuz_rules.lua:85; rows from nuzlocke ruleCategories (nuzlocke/main.lua:2592-2660), per-save | see 1m |
| nuzlockeMod | NUZLOCKE (ON/OFF) | main.lua:559 (load gate) | OK |

### 1g. Hub page QUALITY OF LIFE (`qol`)

| Key | Label | Reader | Status |
|---|---|---|---|
| (submenu) | GEN1WILD QOL -> "13 MODS" | qol/runtime/menu.lua:1169 | see 1l |
| qolMod | QUALITY OF LIFE (ON/OFF) | main.lua:885 (load gate) | OK. Help says "its own options are under OPTION" (stale) |
| startMenuPc | PC IN START MENU | hub.lua:215 | OK |
| quickMenu | QUICK MENU | quick_menu.lua:729, 957, 1068 | OK. Hold-START also needs TOUCH > LONG PRESS (touch/main.lua:570) |
| quickInStart | QUICK IN START MENU | quick_menu.lua:1068 | DEPENDS on QUICK MENU |
| keyWheel | KEY ITEM WHEEL | quick_menu.lua:362, 941 | OK; hold-SELECT also needs LONG PRESS |

### 1h. Hub page QOL TOGGLES (`qt`)

**All rows below except the first are BROKEN through the hub** (finding 0.1). "Works on Crystal?" describes the toggle once its key is fixed.

| Key (as stored by L) | Label | Works on Crystal? (qoltoggles/main.lua) | Notes / overlap |
|---|---|---|---|
| qolToggles | QOL TOGGLES (load) | main.lua:902 | OK |
| qt_poison_save | POISON SAVE | yes (:3958, 3992; GSC poison can faint in the field) | |
| qt_catch_heal | FULL HEAL CATCH | yes | default OFF (Nuzlocke) |
| qt_repel | INFINITE REPEL | yes (:4837) | CONFLICT: makes AUTO-REPEL and REPEL PROMPT pointless; Nuzlocke No Repels |
| qt_field_moves_all | FIELD MOVES ALL | yes | overlaps EASY HM USE / AUTO CUT |
| qt_badgeless_moves | BADGELESS HMs | yes (gen2Help) | |
| qt_hm_item_required | HM ITEM REQUIRED | yes | only meaningful with FIELD MOVES ALL |
| qt_always_catch | ALWAYS CATCH | yes | |
| qt_perfect_dvs | PERFECT DVS | yes (:2285) | **CONFLICT on Gen 2**: wipes shiny, forces male gender and Unown letter |
| qt_exp_mult | EXP MULT | yes | DUP-ish with EXP SHARE (both change EXP) |
| qt_money_mult | MONEY MULT | yes | money group: KEEP MONEY, REMATCH PRIZE, POKEBALL BONUS |
| qt_catch_exp | CATCH GIVES EXP | yes | EXP group |
| qt_instant_flee | INSTANT FLEE | yes | CONFLICT with Nuzlocke No Escape |
| qt_remember_cursor | REMEMBER CURSOR | yes | battle menu cursor |
| qt_b_to_run | B FOR QUICK FLEE | yes | |
| qt_heal_map_change | HEAL ON MAP CHANGE | yes | conflicts with Nuzlocke No PokeCenter / No Field Heal |
| qt_quick_ssanne | QUICK SHIP | **BROKEN**: matches `npc.def.scriptKey/name` (:3256); Crystal objects have none | remove or rewrite |
| qt_free_great_ball | POKEBALL BONUS | yes (:5481) | |
| qt_no_enc_dupes | NO ENCOUNTER DUPES | yes (:4846) | classic encounters only (visible Wilds spawns are their own roll, ?) |
| qt_instant_fish | INSTANT FISH | yes | |
| qt_heal_battle | HEAL AFTER BATTLE | yes | same Nuzlocke conflict |
| qt_infinite_held_item | INFINITE HELD ITEM | yes (gen2) | |
| qt_instant_hatch | INSTANT HATCH | yes (gen2) | |
| qt_turn_away_nurse | TURN AWAY (NURSE) | yes | sub-behaviour of QUICK NURSE |
| qt_quick_nurse | QUICK NURSE | yes (this is the device bug: the key) | conflicts with Nuzlocke No PokeCenter |
| qt_auto_repel | AUTO-REPEL (default ON) | yes (:4400) | CONFLICT: refills at 1 step, so Gen1Wild REPEL PROMPT never fires |
| qt_bulk_mart | BULK MART | yes | |
| qt_bulk_coins | BULK COINS | **BROKEN** (same name matcher, :3245) | remove or rewrite |
| qt_lights_on | LIGHTS ON | ? (palette checks :4342; plausible) | |
| qt_remember_move | REMEMBER MOVE | yes | **label clash** with Gen1Wild REMEMBER MOVES (move relearner) |
| qt_keep_money | KEEP MONEY | yes | |
| qt_auto_cut | AUTO CUT | yes (:4486) | overlaps EASY HM USE (A on a tree) |
| qt_battery_indicator | BATTERY INDICATOR (OFF/TOP RIGHT/START MENU) | yes | display, not QoL; may collide with OVERWORLD HUD at top right (?) |
| qt_rename | RENAME | yes | |
| qt_modern_types | MODERN TYPES | yes | gameplay (type chart) |
| qt_exp_bar | EXP BAR | forced false unless BATTLE HUD=NATIVE (main.lua:913) | DEPENDS. Battle display |
| qt_party_scroll | PARTY SCROLL | yes | |
| qt_instant_text | INSTANT TEXT | yes | display/text |
| qt_hold_to_scroll | HOLD TO SCROLL | yes | |
| qt_anim_skip | ANIM SKIP | likely: Gen-2 branches at :2865 (battle.anim) and :3575 (gen2 BattleState); not device-verified | |
| qt_sand_free | SAND FREE | yes | |

Not shown (FORCED in main.lua:905): RUN (HOLD B), MAP LOCATION, UNLIMITED TMs, FORGETTABLE HMs, MOUSE CAM LOCK, LAST ITEM (M).

### 1i. Hub page TOUCH CONTROLS (`touch`)

These are stored per screen shape on the Fold (touch/main.lua:42-121).

| Key | Label | Reader | Status |
|---|---|---|---|
| touchFloating | FLOATING CONTROLS | touch/main.lua:188 | OK (master) |
| touchHand | BUTTON SIDE | :242 | OK |
| touchButtonHeight | BUTTON HEIGHT | :244-251 | OK |
| touchSize | CONTROL SIZE | :232 | OK |
| touchOpacity | CONTROL OPACITY | :911 | OK (no help text) |
| touchDeadzone | DRAG DEAD ZONE | :387 | OK |
| touchBattleTap | TAP MENUS | :285, 338 | OK |
| touchLongPress | LONG PRESS | :491, 570 | OK; also gates hold-START QUICK MENU and hold-SELECT wheel |
| touchRunDrag | FAR DRAG HOLDS B | :736 | DEPENDS: only sprints if SPRINT > HOLD = B |

### 1j. MORE page and root

| Key | Label | Reader | Status |
|---|---|---|---|
| pipeline:tiltshift | T-SHIFT (OFF/1/2/3) | gmarc/main.lua:255 | OK, MISFILED (belongs with VOXEL); dropped at VOXEL=FULL |
| moveTypeColors | MOVE TYPE COLORS | gen2_modern_battle_ui.lua:683 | DEPENDS on MODERN BATTLE UI; MISFILED |
| moveEffectHint | EFFECTIVENESS HINT | gen2_modern_battle_ui.lua:670 | DEPENDS on MODERN BATTLE UI; MISFILED |
| hitFlicker | HIT FLICKER | steady_hits.lua:33; main.lua:275 | OK; MISFILED |
| diagnostics | DIAGNOSTICS (root page) | main.lua:1135, 1181 | OK |
| (screen) | MOD LIST (root page) | engine ManagerState | duplicate surface (Q4) |

### 1k. KANTO IN MOTION screens (K)

These are KIM ListMenu screens. They do NOT honour `visible_if`.

Main screen (kim_main.lua:7107-7138):

| Key | Label | Reader | Status |
|---|---|---|---|
| gen2MenuSpriteSource | MENU SPRITES (KIM HD/VANILLA) | kim_main.lua:1378; party_ui:271; summary_ui:189; pokedex_ui:260 | OK |
| menuIcons | POKEMON ICONS | menu_icons.lua:34; kim_main.lua:8104 | OK |
| animate | ANIMATION | kim_main.lua:1238, 1929 (battle and menus, trainer) | DUP with SPRITE ANIMATION (menu-only freeze, :1399, 2201). ANIMATION OFF makes it moot |
| gen2IntegratedModernUi | MODERN UI | kim_main.lua:857; gen2_modern_style.lua:42 | OK (master for every UI row) |
| - | UI SETTINGS -> OPEN | | |
| battleSprites | BATTLE SPRITES | kim_main.lua:1602; backdrop.lua:50 | OK. OFF forces BATTLE BACKGROUND=DEFAULT and hides that row. Battle row living on the UI page |
| battleShadowQuality | PKMN SHADOWS | battler_shadows.lua:34 | OK (battle). Help mentions Red/Blue/Yellow |
| battleShadowOpacity | SHADOW OPACITY | battler_shadows.lua:42 | OK (battle) |
| - | ASSET MANAGER | asset_download_manager | OK (advanced / downloads) |

UI SETTINGS (kim_main.lua:534-660). Every row depends on MODERN UI.

| Key | Label | Reader (gen2_modern_*) | Status |
|---|---|---|---|
| gen2UiTheme | UI THEME | style:37 | DUP of hub picker |
| frameStyle | UI FRAME STYLE | style:240 | CONFLICT: GEN 3 / CUSTOM themes override it (`c.frameStyle`) |
| frameAsset | PIXEL FRAME | style:182 | same conflict (`c.frameAsset`); also overlaps CUSTOM BORDER |
| frameScale | PIXEL FRAME SCALE | style:252 | DEPENDS on frame style PIXEL |
| density | UI DENSITY | style:109 | OK |
| uiScale | UI SCALE | style:75 | OK |
| fontScale | FONT SCALE | style:88 | OK |
| pixelFont | PIXEL ART FONT | style:89, 148 | DEPENDS on UI FONT=KIM ORIGINAL. `visible_if` is set (main.lua:61) but only L honours it; K always shows it |
| dialogueTextScale | DIALOGUE TEXT SCALE | style:103 | OK |
| layoutStyle | LAYOUT STYLE | style:116 | OK |
| panelOpacity | PANEL OPACITY | style:122 | OK |
| foregroundOpacity | TEXT / LINE OPACITY | style:127 | OK |
| hideOriginalUi | HIDE ORIGINAL UI | style:56 | OK (developer-ish: OFF shows both UIs) |
| startMenuScale | START MENU UI SIZE | core_menus:224 | OK |
| startMenuTextScale | START MENU TEXT SIZE | core_menus:543 | OK |
| startMenuFastJump | START MENU FAST JUMP | core_menus:3206 | OK (nav; near HOLD TO SCROLL) |
| startMenuInset | SIDE MENU INSET | core_menus:539 | OK |
| minimalUi | MINIMAL UI | style:83; core_menus:226 | OK (just 90% scale; overlaps UI SCALE) |
| dialogueUi | DIALOGUE UI | style:48 | OK |
| menuUi | MENU UI | style:52 | OK |
| pokemonUi | POKEMON SCREENS | style:49 | OK |
| managerUi | MOD MANAGER UI | style:50; core_menus:3256 (KIM settings and mod options screens) | OK, but niche |
| spriteAnimation | SPRITE ANIMATION | kim_main.lua:1399, 2201 | DUP with ANIMATION |
| battleUiWip | MODERN BATTLE UI | kim_main.lua:4226; battle_ui:378 | OK. Battle row on the UI page |
| gen2BattleHudColor | HUD COLOR | gen2_hud_color.lua:47 (native HUD only) | NO EFFECT at BATTLE HUD=MODERN (default) |
| battleWideUi | BATTLE UI MODE (OG/WIDE) | battle_ui:1044 | OK (battle) |
| battleUiSize | BATTLE UI SIZE | battle_ui:1078; **also modern_hud.lua:313** (HUD cards) | OK (battle); one knob sizes two things |
| battleUiOpacity | BATTLE UI OPACITY | battle_ui:1080 | OK (battle) |
| battleTextScale | BATTLE TEXT SIZE | battle_ui:1085 | OK (battle) |
| battleMoveLayout | MOVE LAYOUT | battle_ui:951, 1097 | OK (battle) |
| battleMoveInfo | MOVE INFO | battle_ui:952, 1098 | OK (battle); overlaps touch LONG PRESS move card |
| - | RESET TO DEFAULT | | keep |

### 1l. WILDS OF KANTO screen (settings_menus.lua:376-549)

| Key | Label | Reader | Status |
|---|---|---|---|
| wok_enabled | SHOW WILD MONS | spawn_logic.lua:3003 | DUP of hub row |
| wok_random_encounters | CLASSIC ENC | config.lua:757 | DUP of hub row |
| wok_shiny_rate | SHINY RATE (OFF..ALWAYS, default 1/4096) | wilds/lib/shiny.lua (Gen 2 `shiny.roll` hook) | OK. Note the default differs from Crystal's 1/8192 |
| wok_sprite_style | GFX STYLE (GSC/HGSS) | config.lua:552 | OK (L calls it "Sprite Style") |
| wok_pika_follower | PIKA FOLLOWER (costumes) | control_engine.lua:1120 (any PIKACHU follower) | OK, niche |
| wok_town_pokemon | TOWN POKEMON | config.lua:1000 | OK |
| wok_pokemon_grass_render_mode | GRASS (OVER/IN) | grass_occlusion.lua:66 | OK |
| wok_wild_silhouettes | SILHOUETTE | config.lua:853 | OK |
| wok_follower_count | FOLLOWERS 0-6 (POKE FOLLOW EX screen) | follower/settings.lua:62 | OK |

### 1m. GEN1WILD QOL ("13 MODS") feature screens

These are the qol runtime menu's own screens. They honour `visible_if`. Kept features are qol/features.lua with DROP at :628. NPC WALK and AREA BANNER are `gen1_only` and are not counted.

| Key | Label | Reader | Status |
|---|---|---|---|
| sprint_enabled | SPRINT | Gen1Sprint/src/sprint.lua:54 (`movement.speed`, fired by gen2 World) | OK. Replaces QoL RUN (forced off) |
| sprint_button | HOLD | sprint.lua:55 | OK |
| sprint_speed | SPRINT SPEED | sprint.lua:56 | OK |
| sprint_bike_speed | BIKE SPEED | sprint.lua:57 (not gated by SPRINT) | OK |
| sprint_surf | SPRINT SURFING | sprint.lua:58 | OK |
| sprint_bike | SPRINT ON BIKE | sprint.lua:59 | OK |
| interact_qol_easy_interactions | EASY HM USE / EASY INTERACTIONS | qol_feature_easy_interactions.lua:124 | OK; overlaps AUTO CUT and FIELD MOVES ALL |
| interact_qol_water_interaction | WATER INTERACTION | :130, 781 | OK |
| interact_qol_repel_prompt | REPEL PROMPT | :494, 875 (gen2 `World.repelWoreOff`) | CONFLICT: never fires while AUTO-REPEL (default ON) has repels to use |
| remember_enabled | REMEMBER MOVES (master, next launch) | install gate | OK; label clash with qt REMEMBER MOVE |
| remember_party_row / box_row / pre_evolutions / hide_empty | PARTY REMEMBER / BOX REMEMBER / PRE-EVO MOVES / HIDE WHEN EMPTY | Gen1Remember/main.lua:152, 175; screen.lua:67; main.lua:116 | OK |
| expshare_enabled | EXP SHARE (master) | install gate | OK |
| (save.options.expShare) | EXP SHARE mode, PERCENT SLOT, PERCENT, SINGLE SHARE, LEVEL UP SOUND | qol/adapters/expshare.lua:73-125; `battle.exp_award` ExpShare/main.lua:680 | OK. EXP group with EXP MULT and CATCH GIVES EXP. SINGLE SHARE: purpose not verified (?) |
| rematch_enabled / rematch_prize / rematch_scale | TRAINER REMATCH / REMATCH PRIZE / MATCH LEVELS | Gen1Rematch/main.lua:346, 311 | OK. MATCH LEVELS overlaps TRAINER LEVELS |
| caught_qol_caught_indicator | POKéDEX INDICATOR (GEN2/RED/GREY) | qol_feature_caught_indicator.lua:160, 177 | NO EFFECT at BATTLE HUD=MODERN (modern_hud.lua:257 draws its own ball) |
| forgethm_qol_forget_hm (master) | FORGET HM MOVES | feature skipped on Gen 2 (qol_feature_forget_hm.lua:56) | **NO EFFECT** (feature lost, finding 0.2) |
| reusabletms_qol_reusable_tms (master) | REUSABLE TMS | skipped on Gen 2 (qol_feature_reusable_tms.lua:37) | **NO EFFECT** |
| autosave_enabled / interval / events / onquit / heal / on_load / quiet_sync / notify / backups / keep | AUTO SAVE + 9 sub-rows | Gen1AutoSave/main.lua:230, 1246, 1823, 737, 479, 1048, 1076, 1740, 1725 | OK (has Gen 2 branches) |
| autocontinue_enabled / exit_on_b / skip_intro | AUTO CONTINUE / B EXITS GAME / SKIP INTRO | Gen1AutoContinue/main.lua:196, 243 | OK |
| sound_enabled / alarm_mode / alarm_cycles / alarm_retrigger | SOUND / LOW HP BEEP / BEEP COUNT / BEEP EACH HIT | Gen1SoundQOL/src/alarm.lua:55, 94, 80 (gen2 BattleState hook) | OK |
| menus_enabled + select_shortcut / menu_row / pc_row / hide_unusable / short_names / select_row / row_hints | MENU LAYOUT + 7 | Gen1MenuManager/main.lua:163, 562, 643, 532, 510, 619, 367 | OK (gen2 branch); DUP entry with hub MENU MANAGER |
| modmenu_enabled + presentation / sort / hide_disabled / only_options / help_line / hide_cancel / cursor_memory | MOD MANAGER + 7 | Gen1ModMenu screen.lua / menus.lua | **Probably NO EFFECT**: the hub overrides the ManagerState screen (hub.lua:246); MOD LIST pushes the undecorated engine class (hub.lua:181); `menus.lua` decorates the Gen 1 `src.ui.OptionsMenu`, while Crystal uses `src.ui.gen2.OptionsMenu`. Not device-verified |

### 1n. RUN RULES (Nuzlocke, per save)

Rows come from nuzlocke/main.lua:2592-2660 via nuz_rules.lua. Starting money, balls, candies and Wonderlocke are skipped (pre-game).

The rules: Nuzlocke (master), Permadeath, 1st Catch, Failed Encounters, Nickname Rule, Dupes Clause, Shiny Clause, Overworld, Town Catches, No Legend, No Mythic, Gift Pokemon, In-Game Trades, Level Cap Scope, Expanded Postgame, No Healing Items, No X Items, No Escape, No Repels, No Escape Rope, No Field Heal, No PP Items, No Buying, No Selling, No PokeCenter, No Mom Heal, Whiteout, Solo Only, World Building, Catch Info, Area Guide, Lock Rules (~32).

- These are OK as a group.
- **They are not enforced against QoL Toggles.** HEAL AFTER BATTLE, HEAL ON MAP CHANGE, QUICK NURSE, INSTANT FLEE, AUTO-REPEL, INFINITE REPEL, ALWAYS CATCH and PERFECT DVS can contradict No PokeCenter, No Field Heal, No Escape, No Repels and Shiny Clause. I found no cross-check, but did not search exhaustively (?).
- Some rule help text is Gen-1 flavoured: "World Building ... throughout Kanto", "Town Catches ... Pallet Town". Whether World Building does anything on Crystal is not verified (?).

---

## 2. Orphans and dead settings

**Read but never defined:**
- `hudButtons`: written by the HUD BUTTONS editor (quick_menu.lua:999). Intended; no action needed.
- `touchMouse`: read at touch/main.lua:183, but forced false at :85. The `rowHidden` check for it (main.lua:170) is dead.
- `showBattleUiRows`: main.lua:192, non-gmarc branch only. Dead.
- `arenaSprites`: main.lua:176. Dead.
- `arenaStadiumField`: OWN_VISIBLE in main.lua:105. "stadium" mode was removed (backdrop.lua:52). Dead.
- `menuSprites`: gen2_modern_summary_ui.lua:189. Never defined, so it is always true.
- Gen 1 KIM keys read only behind `not IS_GEN2` or on Potato/Battle Art paths: battleSystem, hdBattleBackgrounds, battleTrainerSprite, battleHud*, battlePlayerSize, battle3dPokemonSize, potato*, battleShinyOdds, title*, integratedModernUi, gen1MenuSpriteSource, enabled. Harmless.
- `battleBgMode`: read at kim_main.lua:1627. With no row it is always "auto". Not checked whether that path runs on Crystal (?).

**Written but never read:**
- `voxelEngine`: written into modOptions at main.lua:1201 ("bring the VOXEL ENGINE row in line"). That row no longer exists.

**Defined and visible but no effect on Crystal:**
- FORGET HM MOVES and REUSABLE TMS masters (GEN1WILD QOL).
- HUD COLOR, EXP BAR and POKéDEX INDICATOR at BATTLE HUD=MODERN.
- AA at PERFORMANCE=BALANCED.
- REPEL PROMPT while AUTO-REPEL is on.
- MOD MANAGER feature rows (probable).
- QUICK SHIP and BULK COINS (broken).
- Every hub QOL TOGGLES row (key bug).

**Dead code from removed features (main.lua):**
- `BA_ART`, `BA_UI` and every `not gmarcEngine` branch: L91-99, L177-193, L203-209, L398-404, L425-431, L535-537.
- `ENGINES` table and `engine` constant: L150-152.
- The "VOXEL ENGINE row" comments at L1186-1203.

**Stale help text:**
- QUALITY OF LIFE ("under OPTION").
- WILDS OF KANTO ("options are below").
- ENEMY PKMN SIZE ("PLAYER PKMN SIZE").
- BATTLE CAMERA ("Battle Art's drifting camera").
- PKMN SHADOWS ("Red/Blue/Yellow").
- KIM BATTLE SPRITES ("backgrounds ... remain native").
- Nuzlocke World Building and Town Catches (Kanto / Pallet).

**Rows with no help text:** CONTROL OPACITY, the gmarc rows in the hub (help only reaches the L page), RUN RULES rows that inherit long descriptions, and most KIM rows outside the ListMenu footer.

---

## 3. Proposed page structure (9 pages + root)

The root page would hold the pages, then RESET/DIAGNOSTICS, then MOD LIST (or drop MOD LIST, Q4).

Conventions:
- `->` marks a sub-screen.
- Dependent rows should hide when their master is off. That needs `visible_if` support in `ingame_options.lua`, or rowHidden rules.

### 1. GAMEPLAY

How hard the game is, and what you can catch.

- TRAINER LEVELS
- MATCH LEVELS: merge into TRAINER LEVELS (Q3)
- ALL 251 CATCHABLE
- MODERN TYPES
- EXP: EXP SHARE -> (mode, %, ...), EXP MULT, CATCH GIVES EXP
- MONEY: MONEY MULT, KEEP MONEY, POKEBALL BONUS
- CATCHING: ALWAYS CATCH, FULL HEAL CATCH, PERFECT DVS (with a warning, Q6)
- SHINY RATE (moved from Wilds)
- INFINITE HELD ITEM, INSTANT HATCH, SAND FREE, INSTANT FISH, NO ENCOUNTER DUPES, POISON SAVE
- TRAINER REMATCH, REMATCH PRIZE

### 2. NUZLOCKE & RULES

- NUZLOCKE (load)
- RUN RULES ->

### 3. BATTLE

- Scene: BATTLE SPRITES, BATTLE BACKGROUND, KIM HD BG ALIGN / FILL / OFFSET, 3D BG RESOLUTION / STYLE / EFFECTS / WEATHER, BATTLE CAMERA, 3D SPRITE DETAIL, ENEMY PKMN SIZE, PLAYER INTRO SPRITE, PKMN SHADOWS, SHADOW OPACITY, HIT FLICKER, HD POKE BALLS, WEATHER IN BATTLE, MOVE WEATHER
- Interface:
  - MODERN BATTLE UI
  - BATTLE UI MODE, BATTLE UI SIZE, BATTLE UI OPACITY, BATTLE TEXT SIZE
  - MOVE LAYOUT, MOVE INFO, MOVE TYPE COLORS, EFFECTIVENESS HINT
  - BATTLE HUD, and under it: HUD COLOR, EXP BAR, POKéDEX INDICATOR (only shown when BATTLE HUD = NATIVE)
- Flow: REMEMBER CURSOR, REMEMBER MOVE (rename to "FIGHT CURSOR MEMORY"), B FOR QUICK FLEE, INSTANT FLEE, ANIM SKIP, HEAL AFTER BATTLE, LOW HP BEEP, BEEP COUNT, BEEP EACH HIT

### 4. OVERWORLD & 3D

- VOXEL, T-SHIFT, V-GRID, V-CURVE, WATER, FOREST FX
- AA (only when PERFORMANCE=QUALITY)
- WORLD EDGE FILL, VOXEL EDGE
- TIME OF DAY, TIME FADE
- WEATHER, PLACE WEATHER, RANDOM RAIN
- LIGHTS ON, AREA SIGN

### 5. DISPLAY & MENUS

- UI THEME (picker; the CUSTOM pickers appear under it)
- MODERN UI (master) and its sub-switches MENU UI, DIALOGUE UI, POKEMON SCREENS, MOD MANAGER UI, HIDE ORIGINAL UI (or move these to ADVANCED)
- UI FONT, PIXEL ART FONT (only at KIM ORIGINAL), FONT SCALE, UI SCALE, UI DENSITY, MINIMAL UI, LAYOUT STYLE
- UI FRAME STYLE / PIXEL FRAME / PIXEL FRAME SCALE (hidden for GEN 3 / CUSTOM themes)
- PANEL OPACITY, TEXT / LINE OPACITY
- DIALOGUE TEXT SCALE, INSTANT TEXT
- START MENU UI SIZE, START MENU TEXT SIZE, SIDE MENU INSET, START MENU FAST JUMP, HOLD TO SCROLL
- MENU TRANSITIONS, MENU DIM
- MENU SPRITES, POKEMON ICONS, ANIMATED SPRITES (merged, Q2)
- OVERWORLD HUD, HUD BUTTONS ->, BATTERY INDICATOR

### 6. QUALITY OF LIFE

- Moving: SPRINT, HOLD, SPRINT SPEED, BIKE SPEED, SPRINT SURFING, SPRINT ON BIKE
- Field: EASY HM USE, WATER INTERACTION, FIELD MOVES ALL, BADGELESS HMs, HM ITEM REQUIRED, AUTO CUT
- Repels: AUTO-REPEL / REPEL PROMPT / INFINITE REPEL, merged into one REPELS choice (Q5)
- Centers: QUICK NURSE, TURN AWAY (NURSE), HEAL ON MAP CHANGE
- Menus: PC IN START MENU, QUICK MENU, QUICK IN START MENU, KEY ITEM WHEEL, MENU LAYOUT -> (the editor plus its 7 rows), RENAME, PARTY SCROLL, BULK MART, REMEMBER MOVES ->
- TMs and HMs: REUSABLE TMS and FORGET HM MOVES, re-pointed to QoL Toggles' Gen-2 code (Q1)
- Saving: AUTO SAVE ->, AUTO CONTINUE ->

### 7. WILD POKEMON & FOLLOWERS

- SHOW WILD MONS, CLASSIC ENC, TOWN POKEMON, GRASS, SILHOUETTE
- GFX STYLE (one name everywhere)
- FOLLOWERS (0-6), FOLLOWER IS PARTY LEAD, PIKA FOLLOWER, WILDS NPC POKEMON

### 8. TOUCH CONTROLS

- The 9 touch rows, unchanged.
- FAR DRAG HOLDS B help should say it needs SPRINT HOLD = B.

### 9. ADVANCED

- Components (next launch): WILDS OF KANTO, QUALITY OF LIFE, QOL TOGGLES, NUZLOCKE
- PERFORMANCE, VOXEL PRECACHE, VOXEL DISK CACHE
- ASSET MANAGER
- DIAGNOSTICS
- MOD LIST (Q4)

### Remove (with reason)

- QUICK SHIP and BULK COINS: broken on Crystal. Remove unless the matchers are rewritten (Q7).
- Gen1WILD MOD MANAGER feature (presentation and the 6 rows below it): the hub replaces that screen. Probably a no-op.
- KIM HUD COLOR: hide unless BATTLE HUD=NATIVE (or remove, Q8).
- ANIMATION + SPRITE ANIMATION: merge into one row.
- The duplicate SHOW WILD MONS and CLASSIC ENC rows at hub level (keep one copy).
- The duplicate UI THEME row in K (keep the picker).
- The duplicate MENU MANAGER entry (keep one).
- The POKE FOLLOW EX wrapper screen: fold its FOLLOWERS row into the page.
- Dead keys and dead code listed in section 2.

### Merge

- REPEL PROMPT + AUTO-REPEL + INFINITE REPEL into REPELS: OFF / ASK / AUTO / INFINITE.
- ANIMATION + SPRITE ANIMATION into ANIMATED SPRITES: ON / BATTLE ONLY / OFF.
- MATCH LEVELS into TRAINER LEVELS (Q3).
- TURN AWAY (NURSE) into QUICK NURSE as a 3-way choice: OFF / TURN AWAY / QUICK.
- Optionally UI FONT + PIXEL ART FONT into one FONT row: PIXEL OPERATOR / KIM PIXEL / KIM SYSTEM.

### Also needed

- Fix the qt key bug (finding 0.1).
- Make the hub honour `visible_if`, or add rowHidden rules, so dependent rows hide with their master.
- Replace substring RULES with an explicit key-to-page map, so labels like "arena" cannot misfile rows.

---

## 4. Questions for the user

1. **TMs and HMs.** Crystal currently has no reusable TMs and no HM forgetting, because the Gen1Wild versions are Gen 1 only. Should QoL Toggles' Gen-2 versions be turned back on?
   - (a) yes, both ON by default
   - (b) yes, but OFF by default
   - (c) leave TMs single-use like the cart
2. **Sprite animation.** Merge ANIMATION + SPRITE ANIMATION into one row?
   - (a) ON / BATTLE ONLY / OFF
   - (b) keep both
3. **Trainer levels on rematches.** TRAINER LEVELS and REMATCH > MATCH LEVELS both raise rematch levels. Pick one:
   - (a) drop MATCH LEVELS, TRAINER LEVELS covers rematches
   - (b) keep both
4. **MOD LIST.** It shows every setting a second time, as raw rows.
   - (a) remove it from the hub
   - (b) keep it under ADVANCED
5. **Repels.** Merge AUTO-REPEL, REPEL PROMPT and INFINITE REPEL into one REPELS row (OFF / ASK / AUTO / INFINITE)? If yes, which default: ASK or AUTO?
6. **Easy-mode toggles and Nuzlocke.** PERFECT DVS breaks shinies and gender on Gen 2. More generally, "easy" toggles (HEAL AFTER BATTLE, QUICK NURSE, INSTANT FLEE, ...) contradict Nuzlocke rules.
   - (a) hide or disable them while a Nuzlocke run is active
   - (b) just warn in the help text
   - (c) leave as is
7. **QUICK SHIP and BULK COINS.**
   - (a) remove them
   - (b) keep them and fix the NPC matching (coordinates or script ids)
8. **Native-HUD-only rows (HUD COLOR, EXP BAR, POKéDEX INDICATOR).**
   - (a) hide unless BATTLE HUD = NATIVE
   - (b) remove
   - (c) leave visible
9. **Page names and grouping.** Are the 9 pages above right? In particular:
   - should the EXP and money multipliers sit under GAMEPLAY, or under QUALITY OF LIFE as now?
   - should Nuzlocke share a page with GAMEPLAY?
10. **Component on/off switches** (WILDS OF KANTO, QUALITY OF LIFE, QOL TOGGLES, NUZLOCKE, which take effect next launch).
    - (a) move them to ADVANCED
    - (b) keep them at the top of each topic's page

## Files used

- Harness and raw dumps: `/tmp/claude-0/-home-user-aio-recomp/93d24e30-e7a0-544d-b874-3287c2b09229/scratchpad/audit/` (`h.lua`, `dump.lua`, `qtcheck.lua`, `out.txt`, `refs_detail.txt`).

## Decisions (2026-10-28)

1. Gen 2 REUSABLE TMS and FORGET HM MOVES: fix them, OFF by default. Unforce `unlimited_tms` / `forgettable_hms` and drop the dead Gen1Wild rows.
2. ANIMATION and SPRITE ANIMATION become one setting: ON / BATTLE ONLY / OFF.
3. Drop Gen1Rematch MATCH LEVELS (`rematch_scale`). TRAINER LEVELS covers rematches.
4. MOD LIST moves to ADVANCED.
5. One REPELS setting: OFF / ASK / AUTO / INFINITE, default ASK.
6. Easy-mode toggles: warn in the help text that they bend Nuzlocke rules. PERFECT DVS maxes stats but keeps the shiny, gender and Unown DV bits.
7. Remove QUICK SHIP and BULK COINS.
8. HUD COLOR, EXP BAR and POKéDEX INDICATOR are visible only when BATTLE HUD = NATIVE.
9. Use the 9 pages as proposed. The EXP and money multipliers go under GAMEPLAY. NUZLOCKE & RULES keeps its own page.
10. Each component on/off switch is the first row of its own page, marked "(next launch)".
