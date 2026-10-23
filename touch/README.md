# Kanto in Motion: Touch (KIM_TOUCH) 0.3.0

Dragon Quest smartphone-style controls for Crystal. Requires **KIM_ARENA 0.7.1+**.

## Controls

| Gesture | Does |
|---|---|
| Touch anywhere and slide | A D-pad ring appears under your finger; slide to hold up/down/left/right. The ring follows your thumb. Lift to stop. |
| Quick tap anywhere | A |
| Side button | B (hold works) |
| START / SELECT pills | START / SELECT |
| Battle: tap a command or move | Moves the cursor there and presses A |
| Battle: tap anywhere during text | A |
| POKéMON screen: tap a Pokémon | Selects it (opens its menu / switches) |
| PACK: tap an item or CANCEL | Selects it |
| PACK: tap a pocket tab | Switches pocket |
| SWITCH / STATS, USE / TOSS, YES / NO, quantity | Tap an option to choose it; a tap elsewhere does nothing while one is open |

The engine's quick-menu button ("•••") is unchanged. KIM's own menus keep
their touch handling; only touches they don't use reach these controls.

## Settings

FLOATING CONTROLS (off = standard pad), BUTTON SIDE, BUTTON HEIGHT, CONTROL
SIZE (50–200% in 5% steps), CONTROL OPACITY, DRAG DEAD ZONE, TAP MENUS, FAR DRAG HOLDS B
(running mods), MOUSE TEST MODE (try it on PC with the mouse).

## Notes

- Uses the engine's public `mod.input` and `input.pointer`; battle taps only
  move the menu cursor, then press A.
- The stock pad is hidden by moving its buttons off-screen while floating
  controls are on. A custom touch skin, the touch-layout editor, or turning
  FLOATING CONTROLS off restores it.
- In landscape, BUTTON HEIGHT uses its own values to stay clear of KIM's panel.
