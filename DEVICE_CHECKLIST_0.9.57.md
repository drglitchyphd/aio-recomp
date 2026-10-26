# Gen2-AIO 0.9.57 device checklist

Prepared locally on October 26, 2026. This is an acceptance checklist, not a
record of tests already passed on Android. Local regression tests use source,
stubs and render harnesses; they cannot verify the real ROM/device integration.

## Install and baseline

- [ ] Keep a copy of the current save, install `dist/gen2-aio-0.9.57.zip`, and
  fully close/reopen the app once. Confirm 0.9.57 in the launcher.
- [ ] Continue the existing save: party, items, money, progress and settings
  should match. This build keeps the same mod ID.
- [ ] Check both Fold cover and inner screens. Also fold/unfold while a menu
  is open and confirm the next tap selects the correct visible row.
- [ ] Expect each map's voxel cache to rebuild once after this update. Let
  that finish before judging repeat-visit performance.

## 1. Nuzlocke progression (highest priority)

- [ ] Load an existing game with badges. The cap should immediately match
  the next undefeated gym without needing to defeat another leader first.
  Compare tracker, Trainer Card, Gym Guide and actual EXP enforcement.
- [ ] Defeat the next gym, receive its badge, then check the cap again. Save
  and reload; exit to the launcher and press Play; the cap must remain right.
- [ ] If practical, use a save with Chuck/Jasmine/Pryce beaten out of order.
  Each badge must count for its own leader. A stronger completed gym must not
  cause the next cap to drop (Jasmine before Pryce keeps at least 35).
- [ ] With scope GYMS, eight badges should remove the gym cap. With scope E4,
  the next cap should be WILL 42, then KOGA 44, BRUNO 46 and KAREN 47 as cleared.
  Scope CHAMP includes LANCE 50; scope POST includes the Kanto gyms and RED 81.
- [ ] Load a save already inducted into the Hall of Fame: it must not demand
  another first-time Will victory. Check Kanto badge recognition if available.
- [ ] With caps disabled, EXP remains unrestricted. Check a battle EXP award
  and Rare Candy at the cap with caps enabled; neither should bypass enforcement.

Normal Johto route: Falkner 9 -> Bugsy 16 -> Whitney 20 -> Morty 25 -> Chuck
30 -> Jasmine 35 -> Pryce 35 (floor from Jasmine) -> Clair 40.

## 2. Fold layout and HD balls

- [ ] HUD shortcuts are higher, clear of the notch/launcher menu, and all
  four buttons and the clock/party strip remain tappable on both screens.
- [ ] Mart welcome text has no overlapping wrapped lines.
- [ ] Browse ESCAPE ROPE / PARLYZ HEAL and other long item names. Names and
  prices occupy separate columns; the description starts below its title.
- [ ] Buy quantity 1 and several items; confirm YES and NO. Sell an item and
  cancel a sale. Quantities, totals, money and inventory must remain correct.
- [ ] Repeat at your preferred UI/dialogue font scales, including a larger
  font setting. Check that quantity panels and messages remain inside the screen.
- [ ] With HD BALL on, throw a Poké Ball and another ball type. Check the
  toss, impact, failed catch, shakes and successful catch. The ball should be
  smaller and round throughout, and land on the opponent.
- [ ] Repeat in your usual 3D battle background and with 3D battles off, on
  both screens. Toggle HD BALL off and confirm the native animation appears.

## 3. Nurse settings

- [ ] QUICK NURSE on: interact across the counter. No conversation; the
  machine animation completes once; HP, status and every move's PP recover.
  The player turns away and control returns.
- [ ] Tap A repeatedly and try movement/START during healing. The animation
  must not restart, open another menu or leave the player stuck afterward.
- [ ] QUICK NURSE off + TURN AWAY on: use the normal nurse dialogue. Turn
  away only after the farewell, with healing still working.
- [ ] Both off: normal conversation, with no forced turn afterward.
- [ ] Change the switches, exit to launcher and press Play again. The new
  settings must apply. Repeat at another Pokémon Center if convenient.
- [ ] If anything fails, enable DIAGNOSTICS and capture the `nurse` lines
  immediately after interacting. Include the map/Center and switch values.

## 4. Area Dex

- [ ] In a Headbutt area (for example Azalea Town), open AREA DEX. Common
  and rare tree sections should appear when the map has those engine tables.
- [ ] At Cianwood's encounter rocks, check ROCK SMASH includes KRABBY and
  SHUCKLE. Confirm a map without encounter rocks has no Rock Smash section.
- [ ] Grass, surfing and each fishing rod still appear as before. Check
  scrolling, seen/unseen sprites and level ranges. Percentages are conditional
  on an encounter: they do not include a tree's gate or a rock's 40% gate.

## 5. Cache stutter measurements

- [ ] Enable DIAGNOSTICS and keep VOXEL PRECACHE / VOXEL DISK CACHE on.
  Visit a route and a building, waiting for the build queue to drain.
- [ ] Capture `voxel queue`, `voxel build` and `disk cache` after a first
  visit. Note any walking/door-transition stalls and missing geometry.
- [ ] Walk away and revisit. Then fully restart the app and revisit again.
  Capture the same lines; disk hits should increase where matching cache files
  exist. Record whether stutter improves and how long geometry takes to appear.
- [ ] Check door transitions, connected routes, roofs, tree shadows and battle
  entry. Shorter slices should not leave permanently missing map pieces.
- [ ] Report the worst visible stall and diagnostic peak; this instrumentation
  does not prove the remaining cost is mesh building rather than GPU/upload work.

## 6. Modern UI and input

- [ ] TRACKER: LOG/MAP tabs, long area/species names, scrolling and the cap
  reminder. With Area Guide off, no MAP page action should be offered.
- [ ] RULES: change a permitted rule, save, reopen, lock/unlock and confirm
  locked rules cannot change. Check help and numeric digit editing where offered.
- [ ] Title SETUP: theme matches the modern menus; numeric editing, presets,
  save feedback and B work. Merely viewing setup must not modify an existing run.
- [ ] NPC trading: decline, offer a wrong species, then perform a valid trade
  if available. Confirm readable dialogue and tappable YES/NO only after typing.
  Watch or B-skip the movie; verify exactly one exchange and the correct received
  Pokémon. Speaking again should show the completed-trade response.
- [ ] Wilds settings submenus: navigate with touch and controls, cycle values,
  return, and reopen to confirm settings persisted.
- [ ] Pokégear: open CALL/CANCEL and CALL/DELETE/CANCEL prompts where available;
  cancel deletion, place/end a call, and receive an incoming call. Caller ID and
  dialogue should be modern and readable, without covering each other.
- [ ] Turn MODERN UI off temporarily: the original screens should work. Restore
  it afterward and confirm the modern screens return.

For any failure, include the screen (cover/inner), map/menu, settings, steps,
expected/actual result, and a screenshot or short clip if useful. The nurse and
cache checks particularly benefit from DIAGNOSTICS captures.
