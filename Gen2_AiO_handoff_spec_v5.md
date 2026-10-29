# Gen2-AIO — Handoff Spec v5 (build 0.9.69)

Mod ID `gen2-aio` from 0.9.50 onward. One-time full install and legacy data migration; see below.
Engine: Gen1Recomp **v0.3.95** (clone: `github.com/bryanthaboi/gen1recomp`, tag `v0.3.95`).
Device: Galaxy Z Fold (outer ~1080x2520 tall/narrow, inner ~2184x1968). Player: Steven.
Older sections below run newest-first back to 0.9.8; the spec before that is
`Gen2_AiO_handoff_spec_v2.md` (0.9.7).

## 0.9.69 (2026-10-29)

- gen2_modern_style:
  - `footerHeight` grows when `closeCorner() ~= "tr"`.
  - `footerClose(y,h)` (size, side inset, top) is shared by `closeMetrics`
    and `footerReserve`. The button is 80% of the band at most, placed a
    little above centre.
  - `Style.footer` drops B hints while `mod.exports.touch.active()`.
- touch: the `touchHotbar` row was removed and the bar is never hidden.
  REPEAT_INTERVAL is 0.24.
- qoltoggles `holdNav` defaults: delay 22, rate 8 frames.

## 0.9.68 (2026-10-29)

- Nuzlocke's title-menu SETUP row is skipped when
  `rawget(mod, "_kimArenaNoTitleSetup")`. main.lua sets it on the nz
  proxy.
- touch/main.lua `shownButtons(game)` (also exported as
  `mod.exports.shownButtons`):
  - With a live close rect (`closeTarget`), B is dropped.
  - START / SELECT are dropped too, unless the top state is PackMenu,
    PartyMenu or PokedexMenu.
  - Used by both drawing and hit testing. `draw(game)` now takes the game.
- gen2_modern_dialog_ui `drawInitClock`: the value is drawn with
  drawFittedText on one line, and cardW is min(sw*.72, 520*scale).
- Tests: menu_chrome gains clock and button-hiding checks. setup_wizard
  checks that the title menu has no SETUP row.

## 0.9.67 (2026-10-28)

- `lib/gen2_aio/setup_wizard.lua` (`mod._kimArenaWizard`): data-driven
  `STEPS` and `PROFILES`.
  - A choice has `set` (setting presets written through `Hub.write`) and/or
    `apply(game, ctx)`.
  - A step may have `available(ctx)` and `current(ctx)`. Otherwise the
    current choice is the one whose `set` matches the settings (`Hub.read`).
  - Picks are kept in `ctx.picks` and applied only at FINISH (`applyAll`).
  - Pages are hub pages marked `_kimWizard`; `closeWizard` pops them.
- Hub additions: `Hub.read` / `Hub.write` / `Hub.rootTop` (SETUP WIZARD on
  the root page). New option `setupWizard` (ADVANCED).
- NEW GAME: `MainMenu.choose` is wrapped once per process and routed through
  `MainMenu._aioWizardLive`. On "new" it opens the wizard with
  `preGame = true`; FINISH or SKIP calls the wrapped choose.
- Nuzlocke exports (preGame = the run NEW GAME is about to create):
  `prepareNewGame`, `getRuleFor` / `setRuleFor`, `applyLockePreset`,
  `stageNewGame`. FINISH re-stages, because Nuzlocke's own choose wrapper may
  have staged before the wizard ran.
- Nuzlocke `save.new_game`: with nuzlocke_enabled false and no starting
  money or balls set, the save keeps Crystal's own start.
- WORLD writes the voxel pipeline level through Pipelines.setLevel and
  syncOptions. Wilds followers go through `wilds.setFollowerCount`.
- `optionValue` in core menus: a group row with a `value` function shows it
  instead of OPEN.
- Tests: `tests/setup_wizard.lua` (37 checks). The harness accepts
  `HARNESS_STUBS`.

## 0.9.66 (2026-10-28)

Settings overhaul. The decisions are in docs/settings_audit.md.

- `lib/gen2_aio/hub.lua`:
  - `SECTIONS` is an explicit, ordered list of keys per page. Substring
    RULES are gone.
  - An entry is a key (a component's own row if one exists, otherwise a row
    built from the merged schema), `{id}` / `{id, prefix}`,
    `{qol = feature}` (opens a Gen1Wild QOL feature screen), `{modList}` or
    `{rest}`.
  - Rows no page names land on ADVANCED. `tests/settings_overhaul.lua`
    asserts that none do.
  - Visibility comes from `_kimArenaRowHidden`, which now includes main.lua
    `DEPENDS`, and from the schema's `visible_if`.
  - Each step rebuilds the open page in place and keeps the cursor on the
    same row.
- Writes go through each component's own path:
  - QOL keys use `mod.exports.qol.optionWrite` and `optionValue`. The keys
    are recorded as `_kimArenaQolKeys`.
  - `wok_` keys use the new `mod.exports.wilds.setOption`.
  - Everything else uses the ingame_options path.
- main.lua `DERIVED_OPT` wraps `realOptions.get`. `spriteAnim` answers
  `animate` / `spriteAnimation`, and `repels` answers the repel rows. Neither
  new row has a default, so the old keys migrate.
- QoL Toggles:
  - `_kimArenaQtFilter` is applied last in `sessionGet`. It handles FORCED,
    DERIVED (repel, auto_repel, exp_bar) and CYCLES decoding, which fixed
    the stored "off" multiplier.
  - quick_ssanne and bulk_coins are FORCED false.
  - unlimited_tms and forgettable_hms are unforced, default false, and
    labelled REUSABLE TMS / FORGET HM MOVES.
- Gen1Wild QOL: `optionset.read` honours `_kimArenaQolLock`. REPEL PROMPT
  follows REPELS, and rematch_scale is held false.
- `perfectDVSet` keeps the shiny pattern, gender (lowers ATK until
  `Mon.gender` matches) and Unown's middle bits. The HP DV comes from the
  low bits.
- `drawOptions` draws the selected row's `help` in a band above the footer.
- KIM adds an `gen2-aio:asset_manager` row for ADVANCED.

## 0.9.65 (2026-10-28)

- Battle-card self-shadow stripes fixed (gmarc). On GLES the pixel stage
  defaults to mediump, so Voxel3D's `vSun` and the shadow compare ran in
  fp16: about one shadow texel of quantisation, and a dFdx/dFdy plane
  gradient that underflowed. Fixes:
  - `vSun`, `sunBias`, `sunTexel`, the compare locals and ShadowMap's
    `vDepth` and pack are now `LOVE_HIGHP_OR_MEDIUMP`.
  - New `Voxel3D.cardShadow(on)` (uniform `sunCard`): a card receiver
    skips the cast layer (blue channel) and compares without extrapolation.
    BattleScene wraps the mon-card draws in it.
- Touches gmarc/lib, so the build-id changes and caches rebuild once.

## 0.9.64 (2026-10-28)

- Close button hit rect was {by - 0.9s .. by + 0.5s}: the lower half missed.
  Now centred and larger (tr: x -0.7s..+1.9s, y -1.1s..+1.5s; footer corners
  +-0.7s). Option menuClosePos tr / br / bl: bottom corners sit in the footer
  band (Style.closeCorner, footerReserve shifts info / hints; closeReserve()
  is 0 there). Top-left not offered: every screen draws its title there.
- overworld_hud: option hudPosition tr/tc/tl/bc/bl/br (row t/b, column
  l/c/r); bottom puts the status panel at the edge, buttons above; layout
  exposes statusY; safe-area bottom only trusted when consistent. Party slots
  drawn as Poke Balls (HP colour top half). Tests: overworld_hud 103,
  menu_chrome adds corner + lower-edge tap checks.

## 0.9.63 (2026-10-28) — menu chrome

- gen2_modern_style: Style.footer / footerHeight / parseHints (one footer for
  every modern menu; B always "BACK"); Style.closeButton draws the corner box
  and records it; a render.hud pass at priority 120000 draws the glyph and
  publishes mod._kimMenuClose { x,y,w,h, hit, state, time, back } (exports.
  menuCloseRect). Style.closeIsBack(game, top) picks back arrow vs X (party
  submenu/switch, HeldItemMenu, pack submenu/confirm/qty, mart buy/sell(+qty),
  pokedex view ~= list, pokegear card/phoneSubmenu/call, OptionsMenu on an
  OptionsMenu). touch/main.lua: the close rect is checked after side buttons,
  before screen/battle targets; release inside taps "b" only.
- Not converted: START menu footer (row descriptions), save/title menus,
  dialogue, YES/NO, battle, overworld HUD, Wilds preview_browser (native).
- tests/menu_chrome (15 screens x 2 sizes, touch, back/close decisions).

## 0.9.62 (2026-10-28)

- overworld_hud layout adds `targets` (cells + the clock/party panel with
  action id "party"); pointer capture uses targets. quick_menu.hudActivate
  handles "party" via pushStartMenuItem("pokemon"), with the same mid-step
  deferral. HUD harness 83 checks.

## 0.9.61 (2026-10-28)

- User confirmed on device (0.9.60): QUICK NURSE works; disk cache loads much
  faster, occasional stutter remains (next: ask for "voxel slow" lines).
- HUD: hudAction returns { disabled = true, reason } instead of nil for a
  chosen-but-unusable button; overworld_hud draws it dimmed; hudActivate says
  the reason. Users read hidden buttons as "only 2 of 4 show".
- Settings overhaul still waiting on the 10 answers (docs/settings_audit.md).

## 0.9.60 (2026-10-28)

- User's nurse screenshot "quick false (default)" was taken on 0.9.58 (before
  the qt_qt_ fix); bundle harness confirms 0.9.59 hub rows write
  qt_quick_nurse. Re-check on 0.9.60.
- quick_menu M.hudOrder(game) reads hudButtons from the live game's option
  tables (mods / save.options / options modOptions) before the host reader;
  the editor wrote correctly but the read could lag (harness reproduced).
- touch/main.lua: touchHotbar (KEY BAR (...)) moves L.hotbar off-screen in
  the TouchControls.layout wrap (the engine's "..." hotbar; its own option
  opts.hotbar is only applied by TouchControls:applyOptions at boot).

## 0.9.59 (2026-10-28) — real nurse cause

- main.lua built the hub's QoL Toggles rows with copy.key = "qt_" .. row.key,
  but namespaced().define had already renamed row.key to "qt_<key>" in place,
  so the hub read/wrote "qt_qt_<key>" for all 40 switches. Fixed; qoltoggles
  storedIn also reads the legacy "qt_qt_" value (correct key wins).
  tests/qoltoggles_relaunch.lua session 3 covers it.
- Settings audit (203 rows, proposed 9 pages, removals/merges, questions):
  docs/settings_audit.md. Overhaul waits on the user's answers.

## 0.9.58 (2026-10-28)

- Device diag on 0.9.57 showed "nurse interact: quick false, turn false" with
  the rows ON: the wraps ran, the SETTING read false. qoltoggles sessionGet now
  looks for an explicitly stored value (Game.mods.modOptions, save.options /
  options modOptions under mod.id, prefixed qt_ or bare, then own storage)
  before the default-returning public getter. Diag prints the source.
  If it still fails, the source tells which store the row writes.
- MeshStore: report() on every lookup/save ("disk cache": state, hits,
  misses, saves, failures, files for this build tag (+old), last event, last
  worker error). ChunkMesher: Budget.tick in persist/restore copy loops
  (flatQuads, model verts, cut stamps, meshFromFlat index), and "voxel slow"
  for any single resume >50 ms with its phase (lookup/restore/geometry/
  persist). Device 0.9.57 showed a 1515 ms peak slice. The header loadstring
  in MeshStore.unpack and Structures analysis are not sliced yet; if "voxel
  slow" blames restore or geometry after this, look there next.
- quick_menu: HUD_BUTTONS catalog + hudOrder (option hudButtons, default
  "gear,dex,bike,items", max 6) + HUD BUTTONS editor (Hub.extras.ui chained
  after theme_picker; QUICK MENU row). New actions: pokedex
  (pushStartMenuItem), heal (M.quickHeal via ItemEffects.useOnMon +
  consumeItem; HERBS excluded), travel (FLY in TOWN/ROUTE; DIG / ESCAPE ROPE
  in CAVE/DUNGEON with ctx.canEscapeRope), quick. tests/hud_buttons.lua.
- Settings overhaul (#1): audit in progress; awaiting user answers.

## START HERE — prepared 0.9.57 (2026-10-26)

Local changes address the six priorities from the review of GitHub issue #8
and the previous handoff. Not yet published or device-verified. Use
`DEVICE_CHECKLIST_0.9.57.md` for the acceptance pass; do not close #8 until
the phone results are in.

- `lib/gen2_aio/gsc_caps.lua`: reads per-badge `save.player.badges` and
  `kantoBadges` (ROM bit order differs from gym order). Copies event records;
  does not overwrite save badges or persist inferred gym wins. Badge tables
  override stale gym events. Missing badge stores retain event compatibility.
  Hall of Fame count/entered recovers the League; Red still uses a win event.
  The cap floor is the strongest completed Johto gym, keeping Jasmine ->
  Pryce at 35. This feeds the existing shared nextLevelCapInfo path.
- Mart text/price layout is responsive; HUD respects safe-area top;
  hd_ball captures its own sprite separately for GoldBattle's 3D effect card
  and BattleScene draws it at its projected center with equal screen scales.
- Nurse interception covers World.interact and interactBody. LIVE owns the
  current exports/settings/diagnostic sink. Quick heals hold the busy gate;
  native turn-away matches the heal VM and ignores nested callback scripts.
  Diagnostics: `nurse install`, `target`, `interact`, `machine`, `ended`, `quick`.
- Area Dex reads encounters.trees / rocks / treeSets and uses the engine's
  treeSetUsable (GS dead city/unused tables remain excluded). Rock encounters
  use only common rows. Percentages exclude per-attempt gates.
- modern_pages presents providers on Nuzlocke config/setup/tracker and Wilds
  settings lists. Native update methods remain authoritative. modern_trade
  presents NPC trades with Typer-aware YES/NO and the original movie timeline;
  modern_caller covers caller ID. Core menus draw phone submenu/call text.
- ChunkMesher visible-frame budget reduced to 4/1.5 ms; covered budget stays
  30 ms. `voxel queue` reports pending/last/peak/overruns; `voxel build` reports
  map/slot/cold-vs-disk/elapsed time. No claim of measured Android improvement
  yet. Because gmarc/lib changed, the cache fingerprint changes once.
- Added gsc_caps, area_dex, hd_ball and ui_regressions tests; strengthened
  qoltoggles_relaunch with assertions. Existing screenshot tests accept
  AIO_TEST_OUTPUT (or use TEMP / /tmp), so they run on Windows and Linux.
- Local tools and pinned engine source are under ignored `.work/`. The release
  allowlist excludes them and tests. Re-run the tests listed below plus
  `luajit tests/gsc_caps.lua`, `luajit tests/hd_ball.lua`,
  `AIO_ENGINE=/path/to/gen1recomp luajit tests/area_dex.lua`, and
  `love tests/ui_regressions` (Xvfb when needed). The area test uses the actual
  engine Encounter and GameVersion modules; it needs no ROM.

## Previous handoff after 0.9.56 (2026-10-24)

### How the project works now
- Release = merge a `manifest.json` version bump into `main`.
  `.github/workflows/auto-release.yml` creates `vX.Y.Z` (notes = README's
  `## X.Y.Z changes` section) and calls `release.yml` (now also
  `workflow_call`), which builds the full ZIP, the same-ID overlay patch and
  SHA256SUMS, then `mod-index.yml` updates `site/data/index.json` on main.
  A hand-published release still works. Doc-only merges don't release.
- Every merge to main reaches players. Bump version + README notes in the
  same PR. Any `gmarc/lib` change rebuilds every saved voxel map once
  (main.lua build-id fingerprint) — say so in the notes.
- Engine reference: `git clone --depth 1 --branch v0.3.95
  https://github.com/bryanthaboi/gen1recomp.git` (read-only; no ROM here,
  so nothing runs in the real engine).
- Android exits to the launcher and re-runs mods in the SAME Lua state.
  Engine modules (src.world.gen2.*, Battle, PartyMenu...) keep wrappers and
  flags from the previous session; the event bus and hooks are rebuilt.
  Guard module wraps per module, register events/hooks every session, and read
  settings through something repointed each session (see qoltoggles LIVE).
- Tests (run from repo root):
  `xvfb-run -a love tests/overworld_hud` (75 checks),
  `xvfb-run -a love tests/held_item_menu` (GIVE/TAKE overlay render),
  `luajit tests/qoltoggles_relaunch.lua` (simulated relaunch, nurse toggles),
  `luajit tests/touch_taps.lua` (touch/main.lua taps → A/B),
  `luajit tests/multi_hit_anims.lua`, `python3 -m unittest tests/test_distribution.py`.
  `apt-get install love luajit` if missing.
- Nothing from 0.9.52–0.9.56 is device-verified except where the user
  reported back (below).

### Open bugs (user-reported, latest first)
1. **QUICK NURSE and TURN AWAY (NURSE) still don't work on device**, even
   after 0.9.54's relaunch fix (qoltoggles/main.lua: LIVE table ~L680, early
   return replaced ~L2978, turn-away ~L4020, installQuickNurse ~L4080). The
   stub harness passes, so the real path differs. Next step: add `diag` lines
   (bundle `diagSet`) at interactBody wrap entry, nurseAt result (sprite /
   scriptKey of the faced NPC), startHealMachineAnim type and script.ended
   ctx, then ask the user for the DIAGNOSTICS screen. Suspects: the A press
   from KIM Touch / Gen1Wild "easy interactions" reaching the nurse without
   World:interactBody (qol/modules/QualityOfLife/qol_feature_easy_interactions.lua
   ~L853, wilds control_engine ~L4462, Gen1Rematch gen2.lua ~L318 wrap it —
   check order/return values); the hub toggle key (`qt_quick_nurse`) not the
   one `get` reads; Crystal nurse object fields differing from
   SPRITE_NURSE / PokecenterNurseScript; GoldFreeMove resetting facing.
2. **Outer screen: HUD buttons sit too low** ("high button height is still
   pretty low"). overworld_hud.lua M.layout `y = max(gap*2, H*.10)`; on
   1080x2520 the row is ~250 px down. Make it higher on tall screens (respect
   the safe area / ••• button at top right). Confirm with the user.
3. **Outer screen: Poké Mart text overlaps** (screenshots in the 0.9.56 chat):
   item name and price collide ("ESCAPE ROPE¥550", "PARLYZ HEAL¥200"), the
   description title wraps into the description, and the welcome text's
   wrapped lines overlap ("may I / help you"). gen2_modern_dialog_ui.lua
   `drawMart` (~L440) and martMessageLines: fixed widths and single-line
   heights on a narrow panel. Fit/ellipsize names, right-align prices in their
   own column, measure wrapped heights (font:getWrap) for title, description
   and messages.

### Requested features / work (not started)
4. **Area Dex: add HEADBUTT and ROCK SMASH Pokémon** (quick_menu.lua
   AreaDex ~L420-600 lists grass/surf/fish from `w.encounters`). Find the
   engine's tree-mon / rock-smash tables (src/world/gen2 encounters / Headbutt
   / TreeMons) and add those sections.
5. **Settings overhaul.** Audit every option (bundle main.lua schema, KIM
   kim_main.lua, gmarc, qol, qoltoggles, wilds, nuzlocke, touch) for
   conflicts, no-ops and orphans (e.g. Battle Art / PotatoVoxel rows such as
   POTATO MOBILE ENEMY SIZE, 3D PKMN SIZE that only apply to engines no longer
   bundled; QoL Toggles BULK COINS / QUICK SHIP don't work on Crystal; ANIM
   SKIP unverified). Remove orphans, merge duplicates, recategorize the hub
   (lib/gen2_aio/hub.lua RULES) into pages that make sense. **Ask the user
   when a category or removal is unclear.**
6. **Setting explanations:** long-press or SELECT on any settings row shows
   its help text; write help for rows that have none.
7. **In-game overworld HUD editor:** choose, order and toggle HUD buttons.
   Candidate buttons: GEAR, AREA DEX, BIKE, ITEMS, POKéDEX, QUICK HEAL
   (auto-use healing items the most efficient way to heal the party), FLY
   outdoors / DIG or ESCAPE ROPE indoors, and QUICK (removed in 0.9.56 because
   hold START opens it). quick_menu.lua M.hudActions is the action list.
8. **Quick sell at marts:** one action that sells items with no other use
   (NUGGET, BIG NUGGET, TINYMUSHROOM, BIG MUSHROOM, PEARL, BIG PEARL,
   STARDUST, STAR PIECE, SLOWPOKETAIL, BRICK PIECE... — check Crystal's item
   list for which exist and have no use).
9. **"Party lead" light-mode theme** (theme_picker.lua / gen2_modern_style
   themes): a light theme tinted from the party lead.
10. **Persistent voxel precache prompt** on game start: offer to pre-build
    every map into the disk cache (gmarc Prefetch.lua / MeshStore.lua,
    VOXEL PRECACHE / VOXEL DISK CACHE options) with progress and cancel.
11. **New-game wizard:** short preset flow on NEW GAME: Nuzlocke OFF by
    default, theme choice, and the other play-style choices (e.g. difficulty
    / trainer levels, QoL presets, touch layout, voxel on/off). Ask the user
    which presets they want.
12. **Convert leftover native-UI screens** to the modern UI: Nuzlocke
    TRACKER (and its rules/setup screens), Pokégear call screen, Wilds' own
    menu, title SETUP. Ask for screenshots.

### Done this session (0.9.52–0.9.56), for verification on device
HUD six-slot clock panel at button width (confirmed visually pending);
dialogue box sized to text; joystick hold-repeat 0.5 s / 0.18 s; save panel
proportions; voxel door clamp; Sprout Tower roof slots; tree shadow skirt;
multi-hit animations; QoL Toggles relaunch fix (nurse toggles still broken —
bug 1); tap-anywhere A beside popups and on battle YES/NO; modern GIVE/TAKE;
ENEMY PKMN SIZE; HUD QUICK button removed. Nuzlocke caps: Falkner 9, then
16/20/25/30/35/31(Pryce)/40 — user may want Pryce raised to 35 (offered).


## 0.9.56 — ENEMY PKMN SIZE, no HUD QUICK

- BattleScene.monMatrix takes a size factor; monCards asks the host's
  _kimArenaEnemyScale (option arenaEnemySize, default 100, BATTLE page) for
  the enemy card. Scales about the feet anchor; sun shadow uses the same
  model. KIM plate contact shadows are not rescaled.
- quick_menu.hudActions: QUICK removed (hold START = QUICK MENU). HUD harness
  expects four shortcuts.

## 0.9.55 — modern GIVE / TAKE

- gen2_modern_party_ui: engine Gen2HeldItemMenu (party ITEM) was unstyled.
  render_visible hides it; render.hud (top = HeldItemMenu, not busy) draws the
  party below via drawParty, then GIVE/TAKE popup (SWITCH/STATS look) or the
  message/confirm text box + YES/NO from Typer.text; generic tap cells with
  select + button "a". drawParty records lastLayout for overlays.

## 0.9.54 — voxel doors/roofs/tree shadows, multi-hit anims, QoL Toggles relaunch

- VoxelScene doorClamp (render-only): door cells are solid in the 3D model;
  the drawn feet stop at the doorway face (Structures.solidDoorwayAt).
- ChunkMesher roofCorners/edgeHeights: each roofed cell fills a skirt down to
  its neighbour's edge (Crystal Sprout Tower uses the detector path; the
  authored johto_sprout_tower template only matches Gold tile ids).
- Buildings.shadowSkirt: border-tree templates get shadow-only side faces
  (shade -1) under the canopy; Voxel3D discards vShade < 0, ShadowMap casts.
- lib/gen2_aio/multi_hit_anims.lua: wraps Battle:hitOnce; later hits of the
  same moveEvent queue {kind="message", moveAnim=...} (the Magnitude shape).
- qoltoggles: the process-wide Game._qolTogglesInstalled early return skipped
  the entry after an Android in-process relaunch (exit -> launcher -> Play);
  now keyed on mod.events. Settings go through Runtime._qolTogglesLive.get,
  repointed each session (bundle sets all-off when the component is off).
  Turn-away/palette/toast/keep-money registrations run every session. Still
  broken on Crystal: BULK COINS, QUICK SHIP (name matching; ROM objects have
  no names). ANIM SKIP unverified.
- touch/main.lua: a tap beside a party/pack/START popup is A again (0.9.47's
  missTap = "b" removed; generic "sub" screens still ignore misses).
  gen2_modern_dialog_ui drawBattleSpecial: ask-*/stop-learning YES/NO waits
  for messageTimer <= 0 like BattleState.drawBottom.
- Follower = party slot 1 live update: done (user confirmed).
- gmarc/lib changed: voxel disk cache rebuilds once.

## 0.9.53 — HUD six slots at shortcut width, dialogue box fits text

- overworld_hud: status strip width = shortcut row width, right edges aligned.
  Six slots spread over the space after the clock (step = room / 6, radius
  <= clockPx * .3); on a narrow row slots tighten, then the strip widens.
  Empty slot = hollow muted ring; fainted = solid grey. Harness checks width,
  alignment and that clock + six slots fit.
- gen2_modern_dialog_ui: reflowTextBoxLines removed. Engine TextBox pages are
  18-column lines and each A press reveals one or two, so reflowing put a
  whole page on one row. dialogWidth() = max(width of 18 "0"s, widest line in
  all pages) + padding, capped at the old 90%/1500*scale, cached on the box.
  Lines are drawn as the engine broke them (textBoxLines).

## 0.9.52 — HUD status width, dialogue reflow, joystick repeat, save panel

- overworld_hud: M.layout sizes the status strip to clock width (measured
  "00:00") plus one marker step per party member; markers follow the clock
  left to right. Layout exposes padding/radius/step/clockW. Harness checks it.
- gen2_modern_dialog_ui: reflowTextBoxLines joins the TextBox's visible lines
  (same shown window as textBoxLines) and greedy-wraps them to the box's inner
  width with font:getWidth; wrapping uses complete line text and is then cut
  at the typed byte count, so words do not jump rows mid-typewriter. Last two
  wrapped rows are shown. Falls back to textBoxLines if measuring fails.
- touch/main.lua repeatDirs: REPEAT_DELAY 0.5 s, REPEAT_INTERVAL 0.18 s.
- gen2_modern_core_menus drawSave: outside layoutStyle "full", w/h are reset to
  980x610 * scale, so a width-limited scale no longer leaves an over-tall panel.
  Status label moved below the prompt panel.
- No gmarc/cache change; normal same-ID update.

## 0.9.51 — walking HUD flicker / first same-ID update

- Quick.overworld checks phase/stack/world/player, battle, text/choice and busy
  script state. HUD visibility uses it rather than Quick.ready, which additionally
  checks World.acceptsMenuInput (false while player.moving mid-step).
- Quick.hudActivate reuses the pending-action queue for taps mid-step; executes
  only when ready and rechecks the shortcut's availability. Same-ID full and
  patch builds from 0.9.50; normal launcher update. No gmarc/cache change.
- HUD regression harness alternates moving/standing frames, tests deferred taps
  and changes of movement state during a gesture, plus script/choice exclusions.

## 0.9.50 — full gen2-aio identity and readable HUD clock

- ID gen2-aio, full ZIP gen2-aio-0.9.50.zip, lib/gen2_aio and assets/gen2_aio;
  all bundled require namespaces now mods.gen2-aio. README_GEN2_AIO.md.
- identity_migration.lua imports legacy settings/cache/storage on first boot,
  preserving originals and existing new values. Old identity is a conflict:
  disable old entry and install full ZIP once. No overlay patch for this change.
- Clock now max(20, short screen dimension * .038), with independent status
  width/height and larger party dots. Was capped near 15px by shortcut size.
- Index keeps its old entry until the first renamed ZIP exists, then switches
  identity; future releases use the normal same-ID overlay patches.

## 0.9.49 — overworld HUD and Kenney Fold cover-screen rendering

- Distribution: manifest.github = drglitchyphd/aio-recomp. Custom index at
  `site/data/index.json`; paste its raw GitHub URL into launcher index sources.
  Seed targets the real Initial/0.9.48 ZIP until the first canonical release.
  `.github/workflows/release.yml` packages published vX.Y.Z releases (exact
  manifest match), attaches canonical KIM_ARENA-X.Y.Z.zip plus overlay patch
  and SHA256SUMS, then calls mod-index.yml to update the listing on main.
  `tools/build_release.py` uses a runtime allowlist to exclude repo/config/test
  files; `tools/build_mod_index.py` selects canonical full ZIPs, stable first.
  Display name and settings hub renamed to Gen2-AIO; internal mod ID stays KIM_ARENA.

- `lib/kim_arena/overworld_hud.lua`, loaded after quick_menu: themed, vector-drawn
  QUICK / GEAR / AREA / BIKE / ITEMS shortcuts at the top right, game clock and
  party HP dots. `overworldHud` defaults on; Display & UI hub rule matches HUD.
- `quick_menu.hudActions(game)` supplies available actions using existing native
  Pokegear, Area Dex, registered item and wheel paths. Bike registers BICYCLE.
- Pointer hook priority 200 captures complete HUD gestures before KIM Touch;
  release activates, dragging off/cancellation/menu opening/resize cancels.
  Mouse input also selects/dismisses the key-item wheel. HUD uses Quick.ready
  plus explicit textbox and wheel exclusion, so no menus or battles underneath.
- Headless interaction/render harness: `tests/overworld_hud` (LÖVE under Xvfb).
  Device rendering and full engine integration still need in-game verification.
- No gmarc changes; no disk-cache rebuild.
- Removed backdrop.mode's forced KIM HD substitution at height > 1.9 * width.
  Real grass scene reproduction at 1080x2520: the locked camera's eye lands
  inside foreground foliage. kenney_camera.solve now uses depth ratio 2 rather
  than 1.5, and allows vertical FOV up to 85 degrees, only at that narrow aspect.
  This brings the eye inside the clearing; higher-pitch town/water cameras
  still converge. Inner-screen/desktop solver settings stay the same.
- backdrop scene rendering saves/restores graphics state, resets scissor and
  transform, and catches thrown renderer errors so existing KIM HD fallback
  works. Diagnostics adds `kenney surface` with scene name and surface sizes.
- `tests/kenney_portrait`: actual renderer/assets for all 15 scene types,
  projected foot targets, caller graphics state, Fold cover 1080x2520 at DPI 3,
  inner 2184x1968 at DPI 2, desktop 1280x720, and injected failure fallback.
  Headless preview shows clear scenes; full in-game Fold validation pending.

## 0.9.48 — free scroll, popup taps (0.9.47 was never installed; patch is 0.9.46 → 0.9.48)

- gen2_modern_core_menus: `FreeScroll` (weak-key table, `rawget(mod,"_kimFreeScroll")`) and
  `freeScroll(s, idx, scroll, maxScroll, visible, rowH, writeBack)` (`_kimFreeScrollApply`).
  Replaces the clamp-to-selection block in drawOptions / drawModOptions / drawKimSettings /
  drawPack drawRows / drawStart / field menus. While FreeScroll[state] exists and its `idx`
  (recorded on first use) equals the current index, the window = round(offset) clamped to
  maxScroll; any index change drops the entry and writes the shown scroll back (s.scroll /
  s.list.scroll) so the screen's own scroll continues from there. Sets on the tap buffer
  (KimTap.buf or _kimScreenTapTargets of that state): freeScroll, scroll, rowH, maxScroll.
  Pokedex list (both layouts) via `dexFreeScroll` (writes state.scroll). AREA DEX: offset in
  card rows → self.scroll px; up/down presses drop the entry.
- touch/main.lua: vertical swipe on a freeScroll target drags `offset = start − dy/rowH`
  (no taps); release → fling `vel` rows/s (smoothed, capped ±60, 0 if the finger rested
  >80 ms); `freeScrollStep` each frame (decay e^−3.2t, stop < 0.6). A press on a gliding list
  only stops it. Horizontal swipes and screens without the flag keep the 0.9.45 row steps.
- touch/main.lua: start targets → mode "sub" during StartMenu phase confirm/confirmContest;
  modal taps set `confirmChoice`. A miss beside a non-generic submenu taps B (was A);
  generic "sub" screens (naming keyboard) ignore misses.
- Tests: /home/claude/tests/touchq/t2.lua (10 checks: drag, no fling after rest, flick +
  glide, catch, tap select, QUIT YES, miss = B); t.lua 15 still pass.

## 0.9.47 — Pokegear / naming UI, 251 check

- gen2_modern_core_menus drawGear: strip mode now renders the highlighted card (hint "A OPEN");
  clock = 24h dial (band MORNING 4-10 / DAY 10-18 / NIGHT), weekday from clockParts (1 = SUN);
  phone = 4-row window kept (engine PHONE_ROWS = 4, cursor/scroll are the engine's), rows
  capped at body*2.3, name left / class right, EMPTY dimmed, count used/Phone.CONTACT_LIST_SIZE,
  contact card below the list; tap a row selects, tap the selected row = A (call).
- gen2_modern_dialog_ui drawNamingScreen rewritten: 9 key caps per row (keyH = min(keyW*.92,
  sh*.09)), entry slots = maxLength, panel height = content, DTap cells only on real keys.
- crystal251: OMANYTE → CIANWOOD_CITY water slot 3 only. Verified with pret/pokecrystal
  data/wild (script /home/claude/sim251.py, sparse clone /home/claude/pc): all placements land;
  MEWTWO gets MORN + NITE only (DAY Pupitar is its last slot); every displaced species keeps
  ≥1 slot. EVENT_BEAT_ELITE_FOUR = 68 confirmed.
- Not render-checked on device.

## 0.9.46 — quick menu, area dex, key wheel, Violet roofs

- New `lib/kim_arena/quick_menu.lua` (installed in main.lua before time_of_day; exported as
  `mod._kimArenaQuick`). Settings `quickMenu`, `quickInStart`, `keyWheel` (all default on;
  hub rules `quickmenu` / `quickinstart` / `keywheel` → qol).
  - `M.ready(game)`: phase play, stack empty, world:acceptsMenuInput (Game2's START gate).
  - Overworld actions are queued (`later`) and run from an input.step hook (priority 5) on the
    first ready frame (5 s timeout); `closeToWorld` pops quick pages + the StartMenu first.
  - QUICK MENU = Hub.page rows: POKeGEAR (only if StartMenu.availability().pokegear →
    `game:pushStartMenuItem("pokegear")`), FLY (FieldMoves.partyMoveUser(party,"FLY",ctx) →
    `world:useFieldMove("FLY", mon)`, engine does badge/outdoor text), AREA DEX, DAY-CARE, TODAY,
    KEY ITEMS. START -> QUICK added via ui.start_menu.items at -2e9 (inner of the hub's wrap,
    so order is QUICK, PC, ALL-IN-1, OPTION).
  - Info rows: `{label, info=true, value=fn}`; KIM's options drawer shows "B BACK" for them.
  - AREA DEX: own state (`kimAreaDex`, isOpaque false, drawn from render.hud 31000). Data =
    world:wildTables() grass[map].slots[MORN/DAY/NITE] (DARK→NITE, 30/30/20/10/5/4/1),
    water slots (60/30/10), fishGroups[map.fishGroup] (swarm via Encounter.fishGroupFor +
    Roamers.Swarm.fishing) old/good/super (cumulative chance /256; day/nite/timeGroup). Sprites:
    KIM exports.getSprite(sp,{generation="hd"}) else KIM HD menu icon; unseen drawn with
    setColor(0,0,0) = silhouette. KimTap cells (button false) so swipes scroll; tap elsewhere = A
    = close. Headbutt / rock smash not listed.
  - DAY-CARE: reads save.dayCare directly (no Breeding.dayCare mutation); Breeding.levelGrowth,
    retrievePrice, compatibility(...,{dayCare=true}) + compatibilityText, stepsToHatch.
  - TODAY: hard-coded EVENTS table (weekday 0 = Sunday, world:weekday()). Unverified rows:
    haircut brothers' days (older Tue/Thu/Sat, younger Sun/Wed) — confirm against pokecrystal.
  - KEY ITEMS / WHEEL: selectable = def.canSelect ~= false and count > 0; auto list = pocket
    KEY_ITEM sorted by item index, pins first (mod.cache `key_wheel.lua`, newline ids), max 8.
    Use = world:registerItem(id) + game:useSelectItem() (Crystal's SELECT path). Wheel geometry:
    centre (W/2, H*0.46), R = 0.30*min(W,H), slot 1 at top; release away from a slot keeps it
    open (sticky), a tap away closes.
  - Info cards: `M.monInfo(game, mon, {battle, enemy})`, `M.battleInfo(game, state, side)`.
- touch/main.lua: START/SELECT are DEFERRED only when `Q.ready(game)` at press time (tap →
  `tap(btn)` on release; hold 0.45 s → openQuick / wheelOpen). Open wheel takes every touch
  (kind "wheel"). New gesture kind "hud" from `mod._kimArenaHudRects` (modern_hud now adds
  state/time/enemyShown/playerShown; ≤0.5 s old). Party long press when partyDragOk fails
  (battle) → monInfo popup; PACK row long press → `Q.togglePin`. Harness
  `/home/claude/tests/touchq/t.lua` (plain luajit, stubbed Q): 15 checks.
- Quick module harness `/home/claude/tests/quick/t.lua` (plain luajit, real engine Breeding /
  StartMenu / FieldMoves on package.path): 37 checks.
- gen2_modern_party_ui: icon size min(rowH*.94, 54*scale) (was min(rowH*.74, 30*scale)).
- gen2_modern_pokedex_ui: taps for entry tabs (sets entryAction, presses A; newEntry page = A
  anywhere), area map (title B, halves left/right), option/search rows (`curState` upvalue
  set in drawDex). The species list taps from 0.9.41 were already there.
- gen2_modern_core_menus drawOptions: title = page.title (rawget) else "OPTIONS"; subtitle
  `kimSubtitle`.
- **Violet roofs (gmarc/lib/Structures.lua, cache rebuild):** striped roofs repeat every 2
  rows, so each column read as a 16px repeat (unit 2) and the doorway took the flatDoor
  (cliff cave mouth) path → flat striped boxes. `STRIPED_ROOF_MAPS = { VIOLET_CITY = true }`:
  a doored region there reads every column's full extent (fromRepeat false, `run.striped`),
  and the identical-top-rows "flat rooftop" rule is skipped. Test `/home/claude/tests/roof`:
  synthetic striped 4x6 house → Violet 48px (h 32 + rise 16), other maps still 16px flat.
  Cause inferred from the symptom (not checked against ROM tiles). If another town shows the
  same flat striped boxes, add its map id to the list.

## 0.9.24 — WILDS NPC POKEMON (backlog item 1, done)

`lib/kim_arena/npc_mons.lua` (installed in `main.lua` after weather; setting `npcMonSprites`,
default ON, label WILDS NPC POKEMON → hub Wilds page). Wraps `World.pooledNpc` and
`NPC.setSpriteDef` (src.world.gen2.Npc): Pokemon object events get a SpriteRenderer built from
Wilds' `exports.resolveFollowerSprite({species, shiny, game, role="npc"})`, def id
`SPRITE_KIM_NPC_MON`. `npc.spriteDef` stays native (palettes, bigFacing, variablesprite).
gmarc needs nothing: it draws NPCs from the same renderer (`pose()` / `sprite.def`) and Wilds'
variable-geometry adapter sizes the card. **No gmarc change → no disk-cache rebuild.**

- Species: `spriteType == "POKEMON_SPRITE"` rows carry `.species` (ROM SpriteMons; day-care
  defs too). Generic sheets FAIRY/BIRD/DRAGON/MONSTER/SURF/SUICUNE/ENTEI/RAIKOU: first
  `cry`/`loadwildmon`/`pokepic` in `world.scripts[npc.def.scriptKey]` (follows `cmd.script`,
  numeric ids via `world.constants.speciesOrder`); fallbacks SURF→LAPRAS, beasts by name.
- Skipped: SPRITE_SUDOWOODO (gmarc StaticProps builds it as a voxel tree), BIG_* dolls
  (`npc.bigObject`), map PLAYERS_HOUSE_2F (decoration dolls). Shiny: LAKE_OF_RAGE GYARADOS.
- MOVE.POKEMON bounce: instance `bounceFrame` → nil, `walkPhase` → bounce phase (steps in
  place on the walker sheet). Cleared on restore / sheet change.
- Re-applies on any `mod.options_changed` (gen counter) at the next render.hud (-100).
- Diagnostics line `npc mons`: "N swapped (SPECIES …); native: SPRITE_X …" per map.
- `wilds/main.lua`: added `mod.exports.require = V.require` (host reads species_geometry,
  species_assets, config, sprite_presentation).
- Unconfirmed: the full list of generic Pokemon sheets in the ROM. Any sheet not in GENERIC
  that is a Pokemon stays native and does NOT show in diagnostics; add ids to GENERIC.

## 0.9.25 — fixes from the phone

- npc_mons found 0 on the user's save: their generated `sprites.lua` predates the extractor
  writing `.species` / `spriteType` on SPRITE_POKEMON rows. Now species also comes from the
  sheet name (`SPRITE_<NAME>`), validated against `world.constants.speciesOrder`, then Wilds'
  `species_assets.idFor` (tries NAME, `__`→`_`, no underscores). Diag adds `other: …` (≤8 ids).
- hd_ball: drawn at 11px (was 16; too big beside KIM HD mons). `balls/poke.png` recoloured
  orange → red (the PokeAPI-set icon was orange and read as a Fast Ball).
- Tests: npcmons harness 30 checks (adds old-cache Slowpoke, MR__MIME, diag other).

## 0.9.26

- hd_ball: battle view transform can be non-uniform (tall screens); ball scale now measured
  with `G.transformPoint` and snapped to k×k screen px per source px (square, crisp).
  Test `/home/claude/tests/ball`: 6.75×4.5 → 54×54, 13.65×9.3 → 126×126.
- main.lua DIAGNOSTICS overlay wraps lines with `font:getWrap` to screen width − 34.

## 0.9.27

- New `lib/kim_arena/steady_hits.lua` (installed after hd_ball): wraps
  `src.ui.gen2.BattleState.animPicState`; a `hidden` younger than 0.25 s reads false, except
  picHidden[side], vanishAnim == anim (Fly/Dig), or a hide right after a pic resize
  (RETURN_MON). picBoxCleared is built on animPicState, so KIM drawPic, gen2_gsc and gmarc all
  follow. gmarc's own GoldBattle hold kept (harmless). Test `/home/claude/tests/steady/t.lua`
  (plain luajit): 22 checks.
- npc_mons: colour defs get `gbaArt = true` (SpriteRenderer's always-raw flag) — World's
  per-second OBJ palette bake was greying the art when trueColor wasn't honoured. npcmons: 32.

## 0.9.28

- npc_mons: `wildsKey()` maps engine names to Wilds' species_assets keys (tries NAME, `__`→`_`,
  no underscores) before `resolveFollowerSprite`; Farfetch'd still showed placeholder-like
  grey art in 0.9.27 (theory: "FARFETCH_D" unknown to Wilds). Diag shows `SPECIES#assetId`.
- steady_hits: still flickering on 0.9.27 per user; cause NOT confirmed. Added diag `hits`:
  "<hides> hides, <held> held; last <ms> ms (<why>)" where why ∈ held / long hide / end
  state / fly/dig / after shrink / FLICKER set. If hides stays 0 during a blink, the blink is
  not a bg.hidden hide (check monShade FLASH effects, animView:present, KIM gen2AnimBakePass).

## 0.9.29 (diagnostics only)

- 0.9.28 phone result: Farfetch'd fixed (#83). Flicker remains and NO `hits` line appeared
  after a hit → `bg.hidden` never true via animPicState; blink is another lever.
- steady_hits: diag `hits` "seam reached" on first call; diag `anim fx`: last 3 anims as
  `ID[EFFECTS] levers` (wraps the BgEffects Pool class `queue` via the bg's metatable;
  levers: hidden:/shadeXX:/size:/slide: per side, lcdc, bgpXX). Test t2.lua.

## 0.9.30 — hit flicker root cause

- 0.9.29 diag: `ENEMY_STAT_DOWN[BATTLEROBJ_1ROW,VIBRATE_MON,SHOW_MON] lcdc/size:player`, 0 hides.
- Cause: kim_main.lua's `BattleAnimView.present` wrapper (~line 6073): when
  `needsCanvas(runner)` it bakes with `gen2AnimBakePass = true` (KIM drawPic draws nothing),
  then overlays HD battlers only via `gen2CurrentBattleState`, set in KIM's drawSceneBody
  wrap. gmarc GoldBattle sideTexture calls `animView:present` directly (not in drawSceneBody)
  → no overlay → empty card for the whole scanline effect.
- Fix in steady_hits.lua: wrap `BattleState.drawSceneBody` (depth counter) and
  `BattleAnimView.present` (outer, after KIM): outside drawSceneBody, if needsCanvas, call
  `drawBg()` again after present (KIM's drawPic paints HD now). Loses only the per-scanline
  vibrate offset on the 3D card. Engine's own present call is inside drawSceneBody (untouched).
  Test t3.lua. The animPicState hold stays (harmless, covers real HIDE_MON blinks).

## 0.9.31

- gmarc 1.0.7 merged. Upstream's only real change vs 1.0.6: native variable sprite geometry —
  `SpriteBillboards.lua` taken wholesale (replaces our KIM_ARENA frame-layout edit),
  `SpriteBillboards.beginFrame()` at top of VoxelScene `posesOf`, VoxelScene drawShadow /
  drawEntity / drawGhost / castShadows + pose fingerprint use `SpriteBillboards.pose(sprite,…)`
  (our `frameFor` left, now unused), gmarc main.lua `exports.supportsVariableSpriteGeometry`
  → Wilds' adapter goes native. Every other upstream/bundle difference is our own edits.
  Host reports gmarc as 1.0.7. Pristine 1.0.7 kept at `/home/claude/new/g/`.
- PERFORMANCE `perfMode` (balanced default / quality) in main.lua: render.hud clamps
  `src.core.FrameCap` to 60 when DISPLAY or >60 (Android defaults to DISPLAY = panel Hz),
  QUALITY re-applies options.fpsCap; locks `aa`→0 and `atmos` full→low via `_kimArenaLocks`;
  `_kimArenaCardScale` ≤ 2. Diag `perf`: mode, cap, love.timer.getFPS(). Hub rule
  "performance" → world.
- Merged-gmarc check: `/home/claude/tests/sb` (real SpriteRenderer): 16x16 card 0..16, 32x32
  anchor (16,30) card x −8..24 y −2..30, displayWidth 24 honoured, old `mesh(def, frame)` API ok.

## 0.9.32 — QoL Toggles 1.31.1

- Vendored at `qoltoggles/` (main.lua, manifest, README, CHANGELOG; tests left out). One edit:
  `mod.exports.toggleSpecs = TOGGLES` (before `defaultFor`). Loaded in host main.lua after KIM
  Touch's comment block, before KIM Touch, as `namespaced(subMod("qoltoggles"), "qt_")`, setting
  `qolToggles` (default on). Manifest conflicts += `qol_toggles`.
- Host builds an options schema from toggleSpecs (toggle rows; `cycle` specs → choice rows with
  string codes "off"/"0"/"1.5"/…, decoded back in a wrapped `qt.options.get`). FORCED false, no
  row: run_hold_b, map_location, unlimited_tms, forgettable_hms, mouse_cam_lock, last_item.
  exp_bar forced false unless arenaHud == "native". DEFAULTS: catch_heal = false.
- Hub: new section `qt` "QOL TOGGLES" (rule `qt_` first); its own `qolToggles` card-menu row
  dropped. Load test `/home/claude/tests/qt` (stub host, real engine): 46 specs, 16 hooks.
- User picked these defaults from the overlap list; AUTO CUT and EASY HM USE both kept.

## 0.9.33

- `options:define` alone does NOT make Crystal OPTION rows; rows come from
  `lib/kim_arena/ingame_options.lua` `install(mod, schema, title)` (wraps ui.options.rows).
  QoL Toggles rows now installed through it on the MAIN mod with keys "qt_<key>" (choice codes
  stored as strings, decoded in qt.options.get). Hub rule `qoltoggles` → qt puts the load
  toggle on that page. Diag `qol toggles`. Adapter test /tmp/igo_t.lua (not kept).

## 0.9.34

- `_kimArenaCardScale` no longer capped by perfMode (user saw blurry KIM HD at "4X"). BALANCED =
  fps ≤ 60 + aa off + atmos full→low only.

## 0.9.35

- START -> PC: hub.lua start-menu wrap inserts `PC` before OPTION when `startMenuPc` (default on,
  QoL page via hub rule `startmenupc`): `Screens.push(game, "Gen2PcMenu", {save, bills=true,
  onClose=pop})` — what CenterPcMenu does for BILL's PC.
- Nuzlocke RULES restyled: nuzlocke/main.lua exports `ruleCategories`, `getRule(key)`,
  `setRule(key, v)` (mid-run getConfigValue/setConfigValue); its START->RULES onSelect calls
  `mod._kimArenaNuzRules(game)` first. New `lib/kim_arena/nuz_rules.lua` (installed after the
  hub) builds OptionsMenu rows (value/step; numeric labels for level_cap_scope / dupes_mode /
  world_building_tier; skips starting_* and wonderlocke; LOCK RULES one-way) and pushes them via
  new `Hub.page(game, rows, title)`. `Hub.extras[sectionId] = fn(game) -> rows` prepends rows to
  a hub page (rules: RUN RULES). SETUP (preGame) still uses NuzlockeConfigScreen.
- Backlog old-style screens left: Pokégear call screen, Nuzlocke TRACKER, Wilds' own menu,
  Pokédex taps.

## 0.9.36

- trainer_levels.lua: modes `matchm12` ([-2,-1]) and `matchm5` ([-5,0]) via RANGES; offset is a
  stable hash of (class, member, player top level), so the same trainer gets the same offset.
  The hook now passes class/member into `M.scale`. Test /tmp/tl_t.lua (not kept).
- User asked (info only, not started) about a third KIM theme closer to the native/Gen 3 look.

## 0.9.37

- KIM's "Gen 3 UI" (lib/gen3_modern_*.lua) is the FRLG/Emerald-engine presenter set and shares the
  Gen 1 palettes — not portable to Crystal screens. Instead: theme `kim_arena:gen3` (light FRLG
  palette, `frameTint`, `frameStyle="pixel"`, `frameAsset="4"`) and dynamic `kim_arena:custom`
  (THEMES metatable, from options kimArenaCustomFrame/Backing/Border; light/dark backing picks
  text/selected/accent). gen2_modern_style: `frameImage(c)` honours c.frameAsset ("4" =
  assets/kim_arena/frames/pixel_frame_gen3.png, greyscale), panel honours c.frameStyle and tints
  the PNG with c.frameTint. kim_main gen2UiTheme += GEN 3 (FRLG), CUSTOM; frameAsset += GEN 3.
- lib/kim_arena/theme_picker.lua: Hub.extras.ui rows open list pages (Hub.page); picking writes
  the option like ingame_options and pops; parent row label refreshed. Schema keys hidden by
  rowHidden. Render check /home/claude/tests/theme (real Style.panel) → /home/claude/theme_preview.png.
- time_of_day.lua TIME FADE (`timeFade`, default on): render.hud (priority 1e9, drawn before HUD
  layers) full-screen wash peaking 0.42 at the 18:00 (deep blue) and 04:00 (violet) flips, ±10 s
  real (cycle: 75 s/hour; sync: 3600), eased per frame; skipped when the current map's
  map.palette ctx.pinned. Hub rules `timefade`/"time fade" → weather.
- Not verified on device: light-theme legibility on every Crystal screen (≈120 hand-drawn
  colours in gen2_modern_*). Ask for screenshots per screen.

## 0.9.38

- hub.lua: `sectionMembers(game, id)` builds a page fresh (extras first, then matching rows);
  root rows open pages lazily; new `Hub.openSection(game, id)`.
- theme_picker.lua: first ui row = UI THEME (KIM `gen2UiTheme`, 22 entries mirroring kim_main's
  list — keep in sync) as a list; picking a theme pops the list AND the ui page and reopens it
  via Hub.openSection so the CUSTOM sub-rows (BORDER / BACKING / BORDER COLOR) appear only when
  theme == kim_arena:custom. Test /tmp/pk2.lua (not kept).

## 0.9.39

- theme_picker list entries are value rows (value ON/OFF, step/activate choose; list stays open).
  `Hub.refreshOpen(game, id)` rebuilds an open hub page in place (finds `kimSection` on
  game.stack.states; openSection tags pages). Test /tmp/pk3.lua (not kept).

## 0.9.40

- touch/main.lua LONG PRESS (`touchLongPress`): cell/screencell gestures carry t0; `checkLong`
  runs each render.hud frame (LONG 0.45 s; moving off the cell cancels). Battle move cell →
  `popup` card (moveInfo: game.data.moves[id] type/power/accuracy/description, entry.pp/maxPp,
  Gen 2 physical-by-type) drawn in touch draw() with KIM Style.panel; next press closes it and
  is swallowed. Party cell (not generic; `state.save.party == state.party`, no submenu) →
  `beginSwitch`, drag sets state.index from party cells, release → `finishSwitch` or (same row)
  `openStats`. A long press never taps A. Harness /home/claude/tests/lp (real KIM Touch + engine
  TouchControls; fake KIM targets): popup, short tap, drag 1→3, stats all pass.
- lib/kim_arena/follower_lead.lua (`followerLead`, default on): every 0.5 s on the overworld,
  first healthy party mon vs Wilds `getActiveFollowerMon(game,true)`; differs (and a follower
  is out) → Wilds `selectFollower(lead, game, true)` (live respawn path). Backlog #1 done.
- Reported, NOT fixed: some voxel houses render as flat striped boxes instead of sloped roofs
  (screenshot: brown striped house + purple flat-roof building). Structures.lua roof logic is
  unchanged vs upstream 1.0.7 (only our MeshStore support additions). Asked user: which town,
  and whether it changes with VOXEL DISK CACHE off.

## 0.9.41

- lib/kim_arena/voxel_overlays.lua: wraps World.draw outside gmarc's patch (gmarc main.lua ~861
  returns after drawing its override, skipping MapNameSign.draw + pokepic). MapNameSign.draw is
  wrapped to flag the engine path; if it did not run this frame, the sign and pokepic are drawn
  as World:draw does (liftPx via src.core.ScreenPosition, POKEPIC consts copied, fxUiLayer).
  STARTUP: while Pipelines.worldPipeline()=="voxel" and the engine flat path still ran, a black
  LOADING card covers the world until the first voxel frame (≤20 s), then never again.
- follower_lead.lua: fingerprints via Wilds `follower/selection` (ex.require), party via Wilds
  `game_compat.party`, world-like top check, diag `follower` (user reported 0.9.40 not working;
  cause unconfirmed — read the diag line).
- gen2_modern_pokedex_ui.lua: KimTap begin/finish around drawDex; list rows add cells
  (select sets state.index; tap on selected row presses A).
- Violet City flat roofs persist with disk cache off → gmarc classification (ChunkMesher gables
  only when run.rise > 0). Not investigated further yet.

## 0.9.42

- voxel_overlays.lua: MapNameSign.draw replacement draws a KIM plaque (Style.panel/theme/font,
  top-left, slide-in 8 frames / fade-out 12 frames on mapSign.timer, DURATION 60) when Modern UI
  master + dialogue presenter are on and `areaSignStyle` ~= "native"; overlays() calls the
  wrapped draw so 3D gets it too. Hub rule `areasign` → ui. Test /tmp/sign.lua (not kept).
- touch/main.lua: a plain hold (move gesture, not dragged) ≥0.45 s while `game.world.textbox` →
  press-and-hold A (g.aToken), released on release/cancel; no tap. Harness lp: "press:a release:a".
- perf diag appends love.graphics.getRendererInfo() device.
- Still open from the backlog: battle-card capture caching / PowerVR passes (needs a device),
  Violet City roofs (gmarc classification), Nuzlocke TRACKER / Wilds menu / Pokégear call /
  title SETUP restyle, party & PACK context menus, enemy HUD info, effectiveness hint, dex
  cry/area, START quick menu, GEN 3 legibility pass, vibrate wiggle, big Snorlax/Lapras/Onix.

## 0.9.43

- hub.lua: rule `diagnostics` → pseudo-section "root"; Hub.open appends sectionMembers("root")
  rows to the root page above MOD LIST (root is not in SECTIONS, so no page of its own).

## 0.9.44

- follower_lead: Gen 2 overworld = EMPTY stack (game.world is not pushed; menus push over it).
  worldTop = top==nil and game.world.player, or top==overworld/world. (Any other host code
  testing "top == game.world" for Gen 2 has the same blind spot.)
- steady_hits: BS.drawPic wrapped; during the out-of-scene redraw it translates by KIM's
  gen2HdAnimMotion equivalent (SCX/SCY + lyBackup row offset; row 28 enemy / 64 player). /tmp/t4.lua.
- npc_mons: BIG_* sheets swapped (species from SPRITE_BIG_<NAME>; bedroom via SKIP_MAPS); big
  NPCs get instance drawBig/drawBigAsym (sprite at px+8, py+16) and pose (+8,+16, matching
  gmarc's own BIG anchor). npcmons test 39.
- gen2_modern_battle_ui: typeDecor() per move cell (TYPE_RGB tint 0.24 + stripe) when
  `moveTypeColors` (default on); `moveEffectHint` (default off) prefixes SUPER/WEAK/NO EFFECT to
  the PP text via Damage.typeMultiplier(def.type, battlerTypes(enemy), matchupsAgainst(enemy)).
  Not render-checked on device.

## 0.9.45

- User confirmed: follower lead works; move tint works; disliked stripe (removed); hint did not
  show → kimOpt now reads `mod._kimArenaOpt` (host opt, rawset in main.lua right after `opt`).
- touch/main.lua: SWIPE on cell/screencell gestures (sx/sy recorded; axis lock; step = row h·0.9
  or w·0.54; finger up → "down" taps; swipe never taps A); HOLD-TO-REPEAT `repeatDirs` (menu
  only = stack top non-nil; 0.35 s delay, 0.09 s rate, 0.5 s / 0.18 s from 0.9.52; re-press the held direction). Harness lp:
  swipe → down,down.
- time_of_day.lua: CYCLES { cycle = 1800, cycle60 = 3600 }; option choices CYCLE 30 / CYCLE 60.
- NOT done yet (next): Pokégear quick HUD button (idea: long-press START opens Pokégear; engine
  TouchControls owns button presses), day-care on Pokégear, key item wheel, party/PACK long-press
  menus, enemy HUD info, Fly from map (engine already has World:openFlyMap → Gen2Pokegear fly
  mode; just needs an entry point + Storm Badge / QoL eligibility check), DexNav list,
  Violet roofs, old-style screens, GEN 3 legibility.

## PRIORITIES (after 0.9.46)

Done in 0.9.46: Pokegear quick button (QUICK MENU), day-care readout (QUICK MENU page, not a
Pokegear card), Fly from map, key item wheel, party/PACK long press, enemy info, DexNav list
(AREA DEX), daily events (TODAY), bigger party icons, Pokedex taps, Violet roofs (verify).
Still open: GEN 3 / CUSTOM legibility (screenshots), old-style screens (Pokegear call, Nuzlocke
TRACKER, Wilds menu, title SETUP — screenshots), Physical/Special split (user undecided),
PowerVR/Pixel 10 (no device), vibrate wiggle on 3D cards (0.9.44, unconfirmed on device).

## PRIORITIES (user, after 0.9.42 — not started; 0.9.42 untested by user)

Next, in order: (1) battle sprite wiggle / VIBRATE_MON offset on gmarc 3D cards (steady_hits
redraw drops the per-scanline motion; KIM's local gen2HdAnimMotion has it), (2) big
Snorlax/Lapras/Onix NPC sprites (bigObject 32x32; currently skipped by npc_mons).

HIGH
- Type hints: move rows coloured / type icon by move type (battle move list), plus
  effectiveness label vs current enemy (toggle; off for Nuzlocke by default).
- More long-press: party & PACK context menus, enemy HUD info, dex cry/area.
MEDIUM
- Better summary/party info; party screen Pokemon icons are tiny (bigger icons / Wilds sprites).
- Day-care readout on a Pokégear page + a quick POKéGEAR button on the overworld HUD.
- Fly from the town map (check whether the Pokégear map is drawn in KIM UI — not verified).
- Key item wheel (long-press SELECT): auto-filled with usable key items, optional pin order.
- Physical/Special split: explained to user, awaiting decision (optional rule if wanted).
LOW
- Battle speed toggle (user plays at 2x already; fine).
- Daily events tracker (follow the game's own weekday — World.weekday, which TIME OF DAY
  drives); add TIME OF DAY options CYCLE 30 and CYCLE 60 (time_of_day.lua CYCLE_SECONDS).
- DexNav-style area list: silhouettes for uncaught, solid for seen/caught, per current map.
BACK BURNER: PowerVR/Pixel 10 performance (no device yet).
DECLINED: PC QoL, next-goal hint, photo mode, accessibility.

## Backlog (user, after 0.9.37) — not started

1. ~~Follower = party slot 1 must update live~~ done.
2. First load: build voxels before showing anything (no 2D → 3D pop).
3. Performance / PowerVR (Pixel 10 Pro XL): cache battle card captures (recapture only on pic
   change), fewer full-screen passes (DOF/AA), GPU name in diag + PowerVR defaults, optional 3D
   resolution scale. Landscape 16:9 / 21:9 untested (ask for screenshots).
4. KIM long-press: battle move info (type/power/acc/PP/category/description), party drag to
   reorder (overworld; via SWITCH), party/PACK context menus; ideas: PC peek, enemy HUD info,
   optional effectiveness hint (off), dex cry/area, hold-to-fast-forward text, START quick menu.
5. GEN 3 / CUSTOM theme legibility pass per screen (screenshots).
6. Old-style screens: Pokégear call, Nuzlocke TRACKER, Wilds menu, Pokédex taps, title SETUP.
7. Voxel: shadow gap under short trees, edge trees after cache restore, KENNEY HD outer screen;
   font size by physical size; big Snorlax/Lapras/Onix; vibrate wiggle on 3D cards.

## Delivery notes

- The full zip is ~50 MB and sometimes fails to download on the phone. Always also ship a
  **patch zip** with only the files changed since the previous build (unzip over the mod
  folder, overwrite). Name: `Gen2_AiO_patch_<from>_to_<to>.zip`.
- Bump `manifest.json` version and add a `## 0.9.x changes` block to the top of
  `README_KIM_ARENA.md` every build.
- Any change under `gmarc/lib` or `gmarc/data` changes the voxel disk-cache fingerprint,
  so every saved map rebuilds once. Mention it in the release note.

## Layout (unchanged parts in spec v2)

| Part | Folder |
|---|---|
| Kanto in Motion 1.7.6 | root (`kim_main.lua`, `lib/gen2_modern_*.lua`) |
| gmarc voxel engine 1.0.7 (only voxel engine) | `gmarc/` |
| Stadium 2 Importer (KENNEY HD scenes only) | `stadium2/` |
| Wilds of Kanto 2.8.1 (namespaced `wok_`) | `wilds/` |
| Nuzlocke 1.0.2 (namespaced `nz_`) | `nuzlocke/` |
| KIM Touch 0.3.0 | `touch/` |
| QoL Toggles 1.31.1 (namespaced `qt_`) | `qoltoggles/` |
| Gen1Wild QOL 1.35.0 (a QOL pack, not a wilds mod) | `qol/` |
| Host + bundle modules | `main.lua`, `lib/kim_arena/*.lua` |

Removed in 0.9.8: `qol/modules/Gen1Follower`, `qol/modules/Gen151`, 19 unreachable
`stadium2/lib` files (arena_runtime, model_api, battle_router, gen1/gen2_battle, import_screen,
...). Don't reintroduce. `stadium2/lib/importer.lua` must stay (Kenney scenes require it).

## Host modules added this run (`lib/kim_arena/`)

| File | What |
|---|---|
| `hub.lua` | **ALL-IN-ONE hub.** Outermost `ui.options.rows` wrap (priority 1e9) moves every non-Crystal row out of OPTION into topic pages built from Crystal's own `src.ui.gen2.OptionsMenu` (so KIM-themed + tappable). Entries: START → `ALL-IN-1`, OPTION → `ALL-IN-ONE`, and `ManagerState` screen override (MOD MANAGER opens the hub). Rows filed by keyword `RULES` table (QOL first). `MOD LIST` row opens the engine's ManagerState. |
| `time_of_day.lua` | **TIME OF DAY** (`timeOfDay`): sync (device clock) / morning 7 / day 13 / evening 18.5 / night 23 / cycle (24h per 30 min, from `os.time`) / crystal. Patches `World.hour/minute/weekday` (src.world.gen2.World) and wraps `world.tod` + `map.palette` (priority 1e9; pinned-palette maps like Ilex keep theirs). Host exposes `voxel._kimArenaHour` → gmarc `DayNight.hours()` reads it. gmarc `daytime` locked to "sync" and its row hidden. |
| `weather.lua` | Screen-space weather (one SpriteBatch). Move weather (rain/sun/sandstorm from `battle.weather`), place weather by map-id prefix (snow Mt. Silver outside, frost Ice Path, mist Lake of Rage/Whirl/Dragon's Den/sea routes, embers Burned Tower, damp Slowpoke Well/Union Cave, dust Mt. Mortar/Rock Tunnel), random rain by weekday+3h block. render.hud priority -90000. |
| `hd_ball.lua` | **HD POKE BALLS**: wraps `BattleAnimView.drawObjects`; OAM tiles from the `BATTLE_ANIM_GFX_POKE_BALL` sheet are hidden and the thrown ball's 30px item icon (`assets/kim_arena/balls/*.png`, PokeAPI item sprites, middle 18x18) is drawn at their bbox. Ball id recorded by wrapping `BattleState:startBallAnim`. |
| `quick_ball.lua`, `menu_dim.lua`, `screen_zoom.lua`, `font.lua` | from 0.9 betas (spec v2 era); unchanged. |
| DIAGNOSTICS (in `main.lua`) | `diagnostics` toggle; `mod._kimArenaDiag(key, text)` / `voxel._kimArenaDiag`; overlay at render.hud priority 5. Lines: `wilds`, `voxel edge`, `battle bg plan`, `battle bg`, `battle 3d`, `disk cache`. **Use it to debug on the phone** — the user can't read logs. |

Other host changes: `backdrop.lua` warns to diagnostics; KENNEY HD falls back to KIM HD when
no scene matches or after 120 empty frames. **0.9.49 removes the tall-screen substitution
and uses a closer narrow-screen locked camera** (see reproduction above). Nuzlocke level-cap message is
queued and shown once after the battle (`battle.ended`). Wilds `sprite_style` pin removed (HGSS
works). KIM Touch: per-screen-shape layouts (`touch_layouts.lua` in mod.cache, keys touchHand /
ButtonHeight / Size / Opacity / Deadzone; settings rows synced on fold), MOUSE TEST MODE removed.

## Touch "tap rows" (continuity pass)

`lib/gen2_modern_core_menus.lua` (`KimTap`) and `lib/gen2_modern_dialog_ui.lua` (`DTap`)
publish generic tap targets `{generic=true, mode, phase, cells={x,y,w,h,select,button}}`;
`touch/main.lua` calls `select(state)` then presses `button` (default A; false = none;
"right"/"up"/"down"). Covered: YES/NO, script menus, Mart, title, SAVE, OPTIONS, Center/Bill's
PC, Box PC, field menus, gender, name pick, naming keyboard (mode "sub": misses do nothing),
Pokégear tabs + phone list, Summary tabs, KIM settings, mod settings, battle YES/NO prompts.
Stale targets rejected by `phase`. **Not covered:** Pokédex list, Trainer Card, clock setting.

## gmarc changes (`gmarc/lib/`)

| File | What |
|---|---|
| `MeshStore.lua` (new) | **VOXEL DISK CACHE.** Finished builds packed (main/water verts, tree instances, grass, flowers, figures, cut trees, support heights) and LZ4-written by a `love.thread` worker to `save/mod_cache/KIM_ARENA/voxel/<buildId>-<map>_<slot>_<hash>.kms`. Key = map id, slot, size, borderBlock, tileset, VOID FILL, masks, block layout. buildId = fingerprint of `gmarc/lib` code + `gmarc/data` names/sizes (computed in host at load). Loads time out after 3 s / dead thread → normal build. Needs manifest permission `compute`. |
| `ChunkMesher.lua` | ffi sink `raw()` + restore-from-buffer; `persist()` / `restore()` around `runJob`. |
| `TreeInstances.lua`, `LiveCutProps.lua`, `Structures.lua` | capture/restore hooks; `Structures.cached(mapId)`, `supportSnapshot`, `setPersistedSupport`. |
| `VoidFloor.lua` (new) | WORLD EDGE FILL plane (border image from `World:borderImageFor`, below water at y -6) + VOXEL EDGE: forest borders get 2 rows of copies of gmarc's own round-tree template (`Structures.cached(map).roundStamps[1].quads`, terrain atlas) when available, else low-poly octagon canopies; other tall borders get 16px boxes. Built time-sliced in coroutines. |
| `VoxelScene.lua` | calls `VoidFloor.draw(state, cx, cy, atlasFor(state.map))` fully pcall-wrapped. |
| `BattleScene.lua` | plate shadows; `fitArtToCards` fallback; `battle 3d` diagnostics. |
| `DayNight.lua` | `hours()` reads host `_kimArenaHour` first. |
| `GoldBattle.lua`, `GoldStadium.lua` | KIM shadow capture to plate; host Stadium model hook (Stadium 2 models later removed by v2 session). |

## Settings added (all reachable in the hub)

`timeOfDay`, `weatherFx`, `weatherPlaces`, `weatherRain`, `weatherMoves`, `weatherBattle`,
`hdBall`, `diagnostics`, `voxelDiskCache`, `voidFloor` (WORLD EDGE FILL), `voidRelief`
(VOXEL EDGE), `menuDim`, `arenaFont`, `gen2UiTheme` extra themes (kim_arena:crystal / gold /
silver / pokegear / high_contrast / type).

## Gotchas learned (read before editing)

1. **gmarc modules can't see the engine's `package.loaded`.** Use `pcall(require, "...")`,
   never `package.loaded[...]` (this silently made every border "flat" for several builds).
2. **Define locals before the functions that use them.** A forward-referenced helper became a
   nil global and killed VOXEL EDGE silently. Check with
   `luajit -bl file.lua | grep GGET` for unexpected globals.
3. Hook priority: higher = outer (called first). Draw-before-`next` = underneath.
4. `ffi` and `bit` may be missing in some environments: pcall them; keep plain-Lua fallbacks.
5. gmarc `ModSetting` values can be locked via host `voxel._kimArenaLocks` (`_kimArenaLocks`
   table: `battles`, `daytime`); hide rows with `GM_ART`.
6. Host hooks to gmarc are fields on the `voxel` proxy, read with `rawget(V.mod, name)`.
7. Crystal maps with pinned palettes (Ilex Forest, caves) stay dark at any TIME OF DAY — expected.
8. Wilds draws through gmarc; a stuck gmarc build queue looks like "Wilds broken".

## Test harnesses (rebuild in `/home/claude/tests` if lost)

Mock host (`host_test.lua`, LÖVE + engine on path, permissive stubs), hub unit test, quick
ball, touch generic taps, time-of-day, MeshStore save/load in LÖVE, Kenney scene headless
render, VoidFloor relief (`/tmp/vr`). All passed at 0.9.23; full compile check passes.
0.9.24: `/home/claude/tests/npcmons` (LÖVE under `xvfb-run -a love .`, real engine `Npc.lua` +
`SpriteRenderer`, fake World/Wilds): 27 checks pass. Engine clone at `/home/claude/engine`.

## Backlog (priority order from the user)

1. ~~NPC Pokémon overworld sprites~~ done in 0.9.24 (verify on phone; follow-ups: big
   Snorlax/Lapras/Onix are real Pokemon on some maps but stay native as 32px dolls).
2. **Native-UI screens:** Pokégear phone **call** screen (dialogue already KIM), Nuzlocke
   TRACKER and RULES screens, Wilds' own settings menu (ListMenu), Pokédex list taps.
3. ~~Shadow gap under short trees~~ done in 0.9.54 (shadow skirt; verify on phone).
4. **KENNEY HD on the outer (narrow) screen** — portrait-camera fix in 0.9.49;
   verify on the Fold. Use `battle 3d`, `battle bg`, and `kenney surface` diagnostics.
5. VOXEL EDGE: gmarc tree copies only when `Structures` is in memory (not after a disk-cache
   restore); could persist the template in MeshStore. Possibly lower-poly version of the
   real tree.
6. Performance on the phone (user reported rough in/out of battle earlier): candidates
   VOXEL PRECACHE, 3D SPRITE DETAIL, SCENE FX, KENNEY live scenes. No perf readout yet.
7. Physical (DPI) font sizing; HD ball possibly stretched on gmarc cards (not confirmed).
