# Crystal-AiO: controls and UI

This guide covers every way Crystal-AiO changes how you control Pokémon Crystal
and what its menus look like. It was checked against the code on the 1.0.0
branch.

> **Name note.** Until 1.0.0 the mod was called **Gen2-AIO**. The settings row
> on the START and OPTION menus is **CRYSTAL-AIO** in 1.0.0. If the Modern START
> menu is off, the row reads **CRYS-AIO**, because Crystal's own START box only
> fits 8 letters. On the released 0.9.x builds the same row is **GEN2-AIO**.
> Below, "CRYSTAL-AIO > TOUCH CONTROLS" means: open that row, then that page.

---

## Contents

1. [Overview: base game vs. Crystal-AiO](#1-overview-base-game-vs-crystal-aio)
2. [The on-screen touch controls in depth](#2-the-on-screen-touch-controls-in-depth)
3. [Touch in menus](#3-touch-in-menus)
4. [Overworld HUD, quick menu and key item wheel](#4-overworld-hud-quick-menu-and-key-item-wheel)
5. [Battle controls](#5-battle-controls)
6. [The Modern UI, screen by screen](#6-the-modern-ui-screen-by-screen)
7. [Themes, scaling and layout settings](#7-themes-scaling-and-layout-settings)
8. [Keyboard and gamepad reference](#8-keyboard-and-gamepad-reference)
9. [Quick reference cheat sheet](#9-quick-reference-cheat-sheet)

---

## 1. Overview: base game vs. Crystal-AiO

**The base game.** Crystal on the Gen1Recomp engine uses the Game Boy's
buttons: the **D-pad**, **A**, **B**, **START** and **SELECT**. Every menu is
the cart's own 160×144 window.

- A confirms, and B cancels or backs out.
- START opens the START menu, and SELECT uses your registered key item.
- On touch screens, the engine draws a standard on-screen pad with those
  buttons, plus its own "•••" quick-menu (KEY BAR) button.

**What Crystal-AiO adds.** There are three input methods. Every one of them
ends up pressing the same Game Boy buttons, through the engine's public input
path.

| Input | What changes |
|---|---|
| **Touch** (phones, tablets, foldables) | The stock pad is replaced by **floating controls** (KIM Touch): touch anywhere for a D-pad, tap anywhere for A, and B / START / SELECT on one side. You can also tap menus, battle commands and moves directly, hold for info cards and drag things around. |
| **Keyboard** | The cart's button meanings are kept. A few additions sit on buttons Crystal left unused, such as **SELECT = quick Poké Ball** in wild battles and **START = SORT** in the PACK. See [section 8](#8-keyboard-and-gamepad-reference). |
| **Gamepad** | Same as keyboard. |

Under the touch layer, the mod redraws almost every screen as a **Modern UI**
window: themed panels, a shared footer, a close (X) or back (arrow) button,
tappable rows and lists you can swipe. The game logic underneath is unchanged.

- A tap only moves the screen's own cursor and then presses A (or B, or a
  direction), just as the D-pad would.
- Crystal's own rules always apply, for example "no TOSS for key items" or
  "can't deposit your last healthy Pokémon".
- With **MODERN UI** off (CRYSTAL-AIO > DISPLAY & MENUS), the native screens
  come back unchanged.

The main test device was a **Samsung Galaxy Z Fold**. Its cover screen is
1080×2520 (tall and narrow). Its inner screen is 2184×1968 (nearly square). A
lot of the layout logic below exists because of those two shapes.

---

## 2. The on-screen touch controls in depth

All settings in this section are on **CRYSTAL-AIO > TOUCH CONTROLS**.

### 2.1 When the floating controls are active

The floating controls replace the stock pad when all of these are true:

- the engine's touch controls are active (a touch device);
- **FLOATING CONTROLS** is ON (the default);
- no custom engine touch skin is in use;
- the engine's touch-layout editor (preview) is not open.

Otherwise you get the standard engine pad. The stock pad's D-pad, A, B, START,
SELECT, L and R are moved off-screen, so they neither draw nor catch touches.

- The engine's "•••" button is left alone. Its own **KEY BAR** setting in
  OPTION still controls it.
- There is **no L or R** on the floating controls. The screens that use L/R
  (the PC box pages) have tappable arrows instead.

### 2.2 The layout

| Element | Shape and place |
|---|---|
| **D-pad ring** | Not drawn until you slide. It appears where your finger went down, once you slide past the dead zone. |
| **B** | A round button near the screen edge on your **BUTTON SIDE**, at your **BUTTON HEIGHT**. |
| **START / SELECT** | Two small pills just above B. START sits nearer the edge and SELECT further in. |
| **Poké Ball** (wild battles only) | A round button showing the ball a throw would use and how many you have. Normally it is inside the battle panel (see [section 5](#5-battle-controls)). It only floats beside B when the panel cannot carry it, for example with **TAP MENUS** off. |

Sizes all scale with the screen's **short side** and **CONTROL SIZE**:

- B's radius is 8.5% of the short side × CONTROL SIZE;
- the edge margin is 3.5% of the short side;
- the pills are 1.5× B's radius wide.

Hit areas are a little larger than the drawing: 15% beyond a circle's radius,
and 35% of a pill's height around a pill.

Held buttons light up in your UI theme's highlight colour. Buttons and the
ring use the theme's colours and the mod's UI font. Each press gives a short
buzz through the engine's touch haptics.

### 2.3 The D-pad ring (movement)

- **Put a finger down anywhere** that isn't a button or a tappable item.
- **Slide past the dead zone** and the ring appears under the start point. The
  arm nearest your slide lights up, and that direction is held.
  - It is **4-way**: the larger of the horizontal and vertical slide wins.
  - The dead zone is `short side × (3.5% / 5% / 7%) × CONTROL SIZE` for
    **DRAG DEAD ZONE** SMALL / MEDIUM / LARGE.
- **The ring follows your thumb.** Its radius is 2.6× the dead zone. If you
  slide further than that, the ring's centre is dragged along behind your
  finger, so turning around is always a short move.
- **Lift to stop.**
- **Hold to repeat in menus:** while a menu or battle screen is open, a held
  direction steps once, waits **0.5 s**, then repeats every **0.24 s** (about
  4 rows a second). On the overworld, a held direction simply keeps walking,
  as on the cart.
- **FAR DRAG HOLDS B** (default OFF): on the overworld, dragging to the very
  edge of the ring (98% of its radius or more) also holds **B**. Pull back and
  B is released. This is for running mods: the bundled **SPRINT** holds B by
  default (see [section 8](#8-keyboard-and-gamepad-reference)).

### 2.4 A, B, START and SELECT

| Control | What it does |
|---|---|
| **Tap anywhere** (a quick touch, no slide, under 0.45 s) | **A**. This includes empty space beside a POKéMON / PACK / START popup, where a tap is A. The exception is the naming keyboard, where a tap that misses every key does nothing. |
| **Hold on an open text box** (overworld dialogue, LONG PRESS on) | After 0.45 s, A is **held** for as long as your finger stays down. Crystal speeds text up while A is held. |
| **B button** | B. Holding the button holds B. |
| **START / SELECT pills** | START / SELECT, with one exception: on the open overworld with **LONG PRESS** on, they wait for your finger. A **tap** is START / SELECT. A **hold (0.45 s)** opens the **QUICK MENU** (START) or the **KEY ITEM WHEEL** (SELECT). See [section 4](#4-overworld-hud-quick-menu-and-key-item-wheel). |

### 2.5 When buttons hide

The floating buttons hide wherever the screen has its own controls for the same
job:

| Situation | B | START / SELECT | Why |
|---|---|---|---|
| Overworld, overworld dialogue, battle messages and animations | shown | shown | Nothing else covers B there. |
| A Modern menu window showing its **close (X) / back (arrow)** button | hidden | hidden, except in **PACK**, **POKéMON** and **POKéDEX** | That button *is* B. Those three screens use START / SELECT (PACK: SELECT moves an item, START sorts; POKéMON: SELECT switches; POKéDEX: START = search, SELECT = options). |
| Battle **command menu** (FIGHT / PKMN / PACK / RUN), Modern panel, TAP MENUS on | hidden | hidden | B and START do nothing there in Crystal. In wild battles the Poké Ball button is inside the panel. |
| Battle **move list** / **forget-a-move list** | hidden | hidden | The panel has its own **back arrow** (B). Reordering moves is a drag instead of SELECT. |
| Battle **YES / NO** (nickname, switch Pokémon, forget a move, ...) | hidden | hidden | The NO button is B. |
| **Naming keyboard** | hidden | hidden | The keyboard covers the whole screen and has its own **lower / DEL / END** keys. |

When you switch between two menus (a fade, or the first frame of the next
window), the buttons keep the previous menu's state for a moment instead of
flashing on and off.

When START / SELECT stay up next to a close button in a **bottom** corner, they
move clear of it: below it if there is room, otherwise above.

### 2.6 Placement rules

**BUTTON SIDE**: RIGHT (default) or LEFT. This picks the screen edge for B and
the pills. In battle it also picks the side of the battle panel's ball / back
column.

**BUTTON HEIGHT**: LOW, MID (default) or HIGH. This sets how far down the
screen B's centre sits:

| Screen shape | LOW | MID | HIGH |
|---|---|---|---|
| Portrait (normal) | 84% | 74% | 60% |
| Landscape | 62% | 50% | 38% |
| **Tall portrait** (more than 1.9× taller than wide, e.g. the Fold cover), in battle | 94% | 91.5% | 88% |
| Tall portrait, outside battle | 94% | 91.5% | the taller the screen, the higher: `max(66%, 88% − (height/width − 1.9) × 30%)`. That is about 75% on the Fold cover. |

On tall screens the battle panel sits in the bottom third (see
[section 5](#5-battle-controls)), so in battle the buttons go **below** it.

The buttons then move to avoid what the mod draws:

- **Overworld HUD** (portrait): if B or its pills would overlap the HUD, the
  cluster moves up above it.
- **Battle HP cards**: if the cluster would cover either card, it moves above
  that card. If there is no room above, it goes below.
- **Battle panel** (portrait): the panel keeps one height for the whole battle.
  If the cluster would sit on it, it moves down below the panel when the screen
  has room. Because the panel never moves, the buttons stay in the same spot
  in every battle phase.
- The **floating Poké Ball** (when used) takes the first free spot of: beside
  B, above the pills, below B. A spot must be clear of both HP cards and the
  command panel.

### 2.7 One layout per screen shape

**BUTTON SIDE, BUTTON HEIGHT, CONTROL SIZE, CONTROL OPACITY** and **DRAG DEAD
ZONE** are saved **per screen shape**. There are four shapes:

- portrait or landscape;
- "narrow" (more than 1.9:1) or "wide".

If you change one of these on the Fold's cover screen, only the cover screen
keeps it. Folding, unfolding or rotating loads that screen's own layout, and
the settings rows update to show it. A shape with no saved layout yet starts
from the current values. Layouts are stored per device, not per save file.

The **overworld ZOOM** works the same way, with two slots: "tall" (more than
1.9:1) and "regular". The engine's ZOOM row, hotkey and wheel change only the
screen you are on. The first time a tall screen is seen, its zoom is computed
so it shows about the same area of the world as the inner screen.

### 2.8 All touch settings

**CRYSTAL-AIO > TOUCH CONTROLS**:

| Setting | Choices | Default | What it does |
|---|---|---|---|
| **FLOATING CONTROLS** | ON / OFF | ON | Dragon Quest-style controls. OFF brings back the standard on-screen pad. |
| **BUTTON SIDE** | RIGHT / LEFT | RIGHT | Edge for B, START and SELECT (and the battle panel's ball / back column). *Per screen shape.* |
| **BUTTON HEIGHT** | LOW / MID / HIGH | MID | How high up the edge B sits (table above). *Per screen shape.* |
| **CONTROL SIZE** | 50%–200% in 5% steps | 100% | Size of the ring, B, the pills and the dead zone. *Per screen shape.* |
| **CONTROL OPACITY** | 40 / 55 / 70 / 85 / 100% | 70% | How see-through the controls are. *Per screen shape.* |
| **DRAG DEAD ZONE** | SMALL / MEDIUM / LARGE | MEDIUM | How far a finger must slide before it is a direction instead of a tap. *Per screen shape.* |
| **TAP MENUS** | ON / OFF | ON | Tap menu entries directly: battle commands, the Poké Ball, moves, Pokémon, PACK items and pockets, and every other Modern list. OFF: rows, cells and the battle panel's own buttons are not tappable, and a tap there is A. The close / back button, the overworld HUD and the floating buttons still work. |
| **LONG PRESS** | ON / OFF | ON | Hold gestures: move info, battle HUD card info, party / PC drag, pinning PACK items, hold START / SELECT on the overworld, and hold to speed up text. |
| **FAR DRAG HOLDS B** | ON / OFF | OFF | Dragging well past the ring on the overworld also holds B. |

Related settings elsewhere:

- **MENU BUTTON** (DISPLAY & MENUS): the corner for the close / back button.
- **QUICK MENU** and **KEY ITEM WHEEL** (QUALITY OF LIFE): what holding START
  and SELECT opens.
- **HUD BUTTONS** (DISPLAY & MENUS).

---

## 3. Touch in menus

Everything in this section needs **TAP MENUS** ON. The close button works
either way.

### 3.1 Gestures

| Gesture | Effect |
|---|---|
| **Tap a row, tab or button** | Moves that screen's cursor there, then presses the button the screen asks for. Usually that is A. Some cells only select (see below). A tap counts only if you lift **on the same cell** and the same screen is still up. |
| **Tap empty space** | A, as on the overworld. In a "sub" screen (the naming keyboard) a miss does nothing. |
| **Drag a list up / down** (past 60% of a row) | **Scrolls.** Finger up = further down the list, like a phone. A swipe never presses A. |
| **Flick** | On "free scroll" lists the list follows your finger like a web page without moving the selection. A flick keeps it gliding and slowing (capped at 60 rows a second). Touch the list to stop it. On other lists, each row-height you travel steps the cursor one row. |
| **Drag sideways** (past 45% of a cell's width) | Steps LEFT / RIGHT, for pockets, pages and values. |
| **Hold (0.45 s)** | A long press (see the table in [3.4](#34-long-press-and-drag-in-menus)). It never also counts as a tap. Sliding off the cell before 0.45 s cancels it. |
| **Hold a direction on the ring** | Repeats about 4 rows a second after 0.5 s (see [2.3](#23-the-d-pad-ring-movement)). |

Free-scroll lists include the START menu, the PACK, the Pokédex species list,
the OPTION / CRYSTAL-AIO / QUICK MENU pages and the Area Dex.

**Settings rows** (OPTION and every CRYSTAL-AIO page) behave like this:

- a row that opens a page opens on tap;
- on a value row, tapping the **label** (the left ~58%) only highlights it;
- tapping the **value** side (the right ~42%) steps it to the next value, as
  RIGHT does.

The selected row's help text shows at the bottom of each CRYSTAL-AIO page.

### 3.2 The close (X) / back (arrow) button

Every full Modern menu window draws one button for "B":

- a **back arrow** when B steps back *inside* the same screen;
- an **X** when B closes the screen.

Back-arrow cases include:

- a POKéMON popup or a SWITCH in progress;
- a PACK submenu, quantity box or YES/NO;
- a Pokédex entry, area map or search;
- a POKéGEAR card or phone call;
- the Mart BUY / SELL list or quantity;
- the item PC's lists;
- the PC box's context menu or MOVE cursor;
- a settings sub-page;
- the battle move list.

**On a touch screen, tapping it is exactly B.**

- It counts when you lift on it and the same screen is still on top.
- Its tap area is generous. With MENU BUTTON = TOP RIGHT it extends well up
  and to the right of the button.
- The button's own square always wins over a floating button.
- The extra margin gives way to a key or row underneath it, for example the
  naming keyboard's top-right letters.

**MENU BUTTON** (CRYSTAL-AIO > DISPLAY & MENUS) picks the corner:

| Choice | Where |
|---|---|
| **TOP RIGHT** (default) | The window's title row. |
| **BOTTOM RIGHT** / **BOTTOM LEFT** | Inside the footer band, with a margin all round. The footer grows to hold it. These are easier to reach one-handed. |

Dialogue boxes, YES/NO prompts and the battle command menu have no close
button. The battle move list's back arrow is the same button, drawn inside the
battle panel.

### 3.3 Footers

Every Modern menu has the same footer along the bottom: screen info on the
left, then the button hints (for example `◀▶ POCKET  A CHOOSE  START SORT  B
BACK`). B always reads **BACK**.

With the floating controls up, the **B BACK** hint is left out, because the
floating B is hidden there and the close / back button does that job.

### 3.4 Long press and drag in menus

| Where | Hold (0.45 s) | Drag |
|---|---|---|
| **POKéMON screen** (outside battle, 2+ Pokémon) | Picks the Pokémon up. | Drag onto another slot and let go: Crystal's own SWITCH. Let go on its **own** row: opens its STATS. |
| **POKéMON screen in battle** | An info card: level, types, HP, stats, held item and moves with PP. No reordering in battle. | — |
| **PACK** | Pins / unpins the item on the **KEY ITEM WHEEL** and shows a card saying which slot. Items the wheel can't use say so. | — |
| **PC box** (Modern grid) | Picks the Pokémon up. A small slide picks it up too, before it can become a swipe. | Drag it to the party, another slot or another page. Hold it on a page arrow for 0.6 s to turn the page. See [6.5](#65-pc-box-bills-pc). |

Info cards close on your next touch, and that touch does nothing else.

---

## 4. Overworld HUD, quick menu and key item wheel

### 4.1 The overworld HUD

Setting: **OVERWORLD HUD** (DISPLAY & MENUS, default ON).

The HUD is a compact themed panel that shows **only while you are free to walk**.
It hides during dialogue, menus, battles, scripted scenes and while the key
item wheel is open. It has two parts:

- **The clock and party panel.**
  - The game clock (HH:MM) plus six little Poké Balls, one per party slot.
  - The top half of each ball is coloured by HP: green above half, yellow at
    half or below, red at a fifth or below, grey when fainted.
  - An empty slot is a faint outline.
  - **Tap the panel to open the POKéMON screen.**
- **A row of shortcut buttons** (up to six) with code-drawn icons that stay
  sharp at any size.

**HUD POSITION** (DISPLAY & MENUS, default TOP RIGHT): TOP RIGHT, TOP MIDDLE,
TOP LEFT, BOTTOM MIDDLE, BOTTOM LEFT or BOTTOM RIGHT. At the bottom, the clock
panel sits on the bottom edge with the buttons above it. The HUD respects the
phone's safe area.

**How a HUD tap works:**

- Press, then lift on the same button to activate it. Sliding off cancels it.
- A HUD touch never turns into A or walking.
- A tap made mid-step runs on the next safe frame.
- HUD buttons have no long-press action.
- Mouse clicks work on the HUD as well.

### 4.2 HUD BUTTONS

Choose them in **CRYSTAL-AIO > DISPLAY & MENUS > HUD BUTTONS** or **QUICK MENU >
HUD BUTTONS**.

- Each row cycles with LEFT / RIGHT or A: **OFF**, then **#1, #2, ...** (its
  place in the row, 1 = leftmost).
- There are at most **6** buttons.
- **RESET TO DEFAULT** gives GEAR, AREA, BIKE, ITEMS.

| Editor name | HUD label | Action | When it can't act (dimmed; a tap says why) |
|---|---|---|---|
| POKéGEAR | **GEAR** | Opens the POKéGEAR. | No POKéGEAR yet. |
| AREA DEX | **AREA** | Opens the Area Dex for this map. | — |
| BICYCLE | **BIKE** | Uses the Bicycle, which also registers it as your SELECT item. | No Bicycle yet. |
| KEY ITEMS | **ITEMS** | Opens the key item wheel. | Wheel turned off, or no usable key items. |
| POKéDEX | **DEX** | Opens the POKéDEX. | No POKéDEX yet. |
| QUICK HEAL | **HEAL** | Heals the party from the bag the cheapest way: revives first, then the cheapest matching status cure, then the cheapest potion that covers the missing HP. It never uses bitter herbs and says what it used. | Party already healthy. |
| FLY / DIG / ROPE | **FLY / DIG / ROPE** | Outdoors: the real Fly map. In a cave or dungeon you can leave: DIG, or an Escape Rope. | No Fly user, or no Dig user and no rope. |
| QUICK MENU | **QUICK** | Opens the quick menu. | QUICK MENU turned off. |
| NUZLOCKE TRACKER | **TRACK** | The Nuzlocke ENCOUNTERS page. A **red dot** means this area's encounter is still open. | Nuzlocke off, or this run has no Nuzlocke rules. |
| PC BOX | **BOX** | Your PC boxes (Modern grid) from anywhere. | No Pokémon yet. |

A chosen button **always shows**. When it can't act right now it is dimmed,
and tapping it shows the reason.

### 4.3 QUICK MENU

Setting: **QUICK MENU** (QUALITY OF LIFE, default ON). To open it:

- **Touch:** hold **START** on the overworld for 0.45 s. A quick tap is still
  the START menu.
- **Any controller:** **START > QUICK**. That row is shown while **QUICK IN
  START MENU** (QUALITY OF LIFE, default ON) is on.
- The HUD's **QUICK** button.

The menu holds:

- **POKéGEAR** (if you have one);
- **FLY** (the real Fly map, with Crystal's own badge, outdoor and party
  checks);
- **AREA DEX**;
- **DAY-CARE** (both Pokémon, levels gained, the price, how well they get
  along, any egg, and steps left on party eggs);
- **TODAY** (this week's events for today and tomorrow);
- **QUICK HEAL**;
- **HUD BUTTONS**;
- **KEY ITEMS** (a list you can use from).

### 4.4 KEY ITEM WHEEL

Setting: **KEY ITEM WHEEL** (QUALITY OF LIFE, default ON).

- **Touch:** hold **SELECT** on the overworld. The wheel opens in the middle of
  the screen.
  - **Drag to an item and let go** to use it.
  - **Let go in the middle** and the wheel stays open: tap an item to use it,
    or tap outside the wheel to close it.
- The HUD's **ITEMS** button opens it too.
- It holds up to **8** items: your **pinned** items first (a dot marks them),
  then your other usable key items in bag order.
- **Pin an item** by holding it in the PACK. Hold it again to unpin it.
- The item you use also becomes your **SELECT item**, as if you had REGISTERED
  it.
- With nothing usable it says "No KEY ITEMS can be used from here."

---

## 5. Battle controls

### 5.1 What the base buttons do in a Crystal battle

| Button | Command menu | Move list | Messages |
|---|---|---|---|
| A | choose | use move | next line |
| B | nothing | back to the command menu | — |
| START | nothing | nothing | — |
| SELECT | nothing (cart) / **quick Poké Ball** (Crystal-AiO, wild battles) | mark a move to **swap** order | — |
| D-pad | move cursor | move cursor (2×2 with MOVE LAYOUT = GRID) | — |

This is why, with touch, B / START / SELECT are **hidden** in the command menu,
the move list and YES/NO. The panel itself carries everything those buttons
would do there.

### 5.2 The Modern battle panel

Setting: **MODERN BATTLE UI** (BATTLE page, default ON).

It replaces the cart's lower battle box with one themed panel:

- the command menu (FIGHT / POKéMON / PACK / RUN, or PARK BALL in the
  Bug-Catching Contest);
- the move list;
- the forget-a-move list;
- messages;
- YES/NO.

**The panel keeps one fixed rect for the whole battle.** Its height is the
tallest any phase needs, so choosing FIGHT, throwing a ball or answering a
question never shifts:

- the panel;
- the HP cards sitting on top of it;
- the touch buttons placed around it.

The panel's place depends on the screen:

- **Portrait:** in the free band just below the battle field.
- **Tall portrait (Fold cover) with floating controls:** moved down into the
  **bottom third**, leaving a strip under it for B / START / SELECT.
- **Landscape:** anchored to the bottom of the touch-safe playfield.

**MODERN battle HUD cards** (BATTLE HUD = MODERN, default) replace the tile HP
boxes:

- the enemy card is top left;
- your card is on the right, sitting just above the panel;
- a party ball row comes with each card (yellow for a status).

### 5.3 Touch in battle (TAP MENUS on)

**Command menu.** Tap **FIGHT / POKéMON / PACK / RUN** to choose it (the cursor
moves there, then A).

- **Wild battles:** a **Poké Ball button** sits in a column inside the panel,
  on your BUTTON SIDE.
  - It shows the HD icon of the ball a throw would use, with a count badge.
  - Tap it to throw.
  - It is dimmed with a 0 when you have no ball it would throw.
- A tap on empty space is A.

**Move list.**

| Gesture | Effect |
|---|---|
| **Tap a move** | Use it. |
| **Hold a move still (0.45 s)** | An info card: TYPE, PHYSICAL / SPECIAL / STATUS, POWER, ACC, PP and Crystal's description. It closes on your next touch. |
| **Drag a move past the dead zone onto another move** | **Swaps their order**, using Crystal's own SELECT swap. The picked-up move is outlined while you drag. Letting go anywhere else drops it, with no A. This works straight away or after the info card came up. It needs 2+ moves and a battle that allows swapping. |
| **Back arrow** (the column on your BUTTON SIDE) | B: back to the command menu. |

**Forget-a-move list.** Tap the move to forget. The back arrow is B.

**YES / NO.** This covers nickname, switch Pokémon, forget or stop learning,
and "use next Pokémon". It appears **inside the panel** once the question has
finished typing:

- the prompt sits on the left and two big **YES / NO** buttons on the right;
- if the prompt is too wide, the buttons go in a row along the bottom;
- tap one to answer;
- the D-pad, A and **B (= NO)** work as before.

**HUD cards.**

- **Hold** your card or the enemy's for an info card.
  - Enemy: level, types, HP %, base stats, and whether you've caught one.
  - Yours: HP, stats, held item, and moves with PP.
- A **short tap** on a card is A.

**During messages and animations**, the floating B / START / SELECT are shown,
always clear of both HP cards and the panel.

**With TAP MENUS off:**

- the panel draws no ball or back column;
- the battle cells aren't tappable;
- the floating B / START / SELECT stay up;
- in a wild battle's command menu, a floating **Poké Ball** button appears
  beside B.

### 5.4 The quick Poké Ball rules

The same rules apply to SELECT and to both ball buttons:

- **Only** in a wild battle's command menu, once the panel has slid in.
- **Not** in the tutorial, the Bug-Catching Contest or the Battle Tower.
- **Which ball:**
  1. The **last ball you threw**, from the PACK or here, if any are left.
  2. Otherwise the next tier **down** from it, then up. The order is ULTRA,
     GREAT, the Apricorn balls (LEVEL, LURE, MOON, FRIEND, LOVE, HEAVY, FAST),
     then POKé.
  3. It **never** uses a MASTER BALL (or PARK BALL). If only a Master Ball is
     left, it says so.
- The throw goes through the same call the PACK uses, so Nuzlocke and every
  vanilla check still apply.

### 5.5 Level-up STATS card

"X grew to level N!" and the **STATS card** (ATTACK, DEFENSE, SPCL. ATK, SPCL.
DEF, SPEED) appear **together on one screen**. One A press continues, instead
of the cart's two screens. During a multi-level gain, the middle lines stay
card-less, as on the cart.

### 5.6 STOP EVOLUTION

On the cart, B only stops an evolution if it is pressed during the short pauses
between flashes. In the Modern evolution window:

- a **STOP EVOLUTION** button sits inside the window (it reads STOPPING...
  once pressed);
- a **B press at any moment** of the text, cry or flashes is remembered, and
  Crystal's own check stops the evolution at its next pause;
- the header reads "B or STOP EVOLUTION to stop it";
- **stone evolutions** still can't be stopped ("Evolution cannot be stopped").

### 5.7 Battle display settings (BATTLE page)

| Setting | Choices (default) |
|---|---|
| MODERN BATTLE UI | ON / OFF (ON) |
| BATTLE UI MODE | OG (160×144 surface) / WIDE (304×144) (WIDE) |
| BATTLE UI SIZE | 60–150% (100%). The panel stays bottom-anchored. |
| BATTLE UI OPACITY | 25–100% (100%), panel background only |
| BATTLE TEXT SIZE | 50–200% in 25% steps (100%) |
| MOVE LAYOUT | GRID (2×2, and the D-pad moves in the grid) / VERTICAL (GRID) |
| MOVE INFO | ON / OFF (ON): the selected move's type, PP, power and accuracy. In portrait it sits below the moves. |
| MOVE TYPE COLORS | ON / OFF (ON): each move's cell is tinted in its type colour |
| EFFECTIVENESS HINT | ON / OFF (OFF): SUPER / WEAK / NO EFFECT on each move |
| BATTLE HUD | MODERN / NATIVE (MODERN) |

---

## 6. The Modern UI, screen by screen

Settings on DISPLAY & MENUS:

- **MODERN UI** is the master switch;
- **MENU UI** covers menus;
- **DIALOGUE UI** covers text boxes, choices and YES/NO;
- **POKEMON SCREENS** covers the party, Pokédex and trainer card;
- **HIDE ORIGINAL UI**.

With any of these off, that group of screens is the cart's own, unchanged.

Every full Modern window has the theme panel, the shared **footer**, the
**close / back button** and (with touch) tappable rows. **MENU DIM** (default
ON) darkens the world behind menus outside battle. **MENU TRANSITIONS** sets
the fade between menus:

- **DARK** (default): a short fade through your theme;
- **WHITE**: Crystal's own fade to white with its pause.

### 6.1 Dialogue and choices

- **Text box:** sized to Crystal's own text lines and kept one width for the
  whole message. Tap anywhere for A. Hold on the box to speed text up (LONG
  PRESS).
- **YES / NO inside the box:** two big buttons at the right end of the text box
  instead of a separate window above it. This applies to ordinary
  conversations, the Mart and the Day-Care. Tap one to answer. **B is NO** and
  the D-pad moves the cursor as before.
- **Script menus** (multiple-choice windows) have tappable rows.
- **Naming keyboard:** real key caps sized to the screen, plus an entry field
  with one slot per letter and a blinking cursor.
  - Tap a key to type it.
  - Use **lower/UPPER**, **DEL** and **END** at the bottom.
  - A tap that misses every key does nothing.
  - No floating buttons show here.

### 6.2 START menu

- Tap a row to open it. YES/NO over the START menu (QUIT, END CONTEST) is
  tappable.
- **START MENU FAST JUMP** (default ON): **LEFT / RIGHT jump five rows**. The
  cart has no such shortcut.
- New rows:
  - **QUICK** (the quick menu);
  - **PC** (Bill's PC from anywhere; setting **PC IN START MENU**, default ON);
  - **CRYSTAL-AIO** (the settings hub; CRYS-AIO with the Modern START menu off,
    GEN2-AIO on 0.9.x).
- Sizing: **START MENU UI SIZE**, **START MENU TEXT SIZE** (60–200%) and
  **SIDE MENU INSET** (moves the card toward the centre on wide screens).

### 6.3 POKéMON (party)

- Bigger HD icons, and the SWITCH / STATS / ITEM popups as a centred modal.
- Tap a Pokémon to open its popup. Tap a popup option to choose it.
- **Long-press drag to reorder** (outside battle); let go on its own row for
  STATS. See [3.4](#34-long-press-and-drag-in-menus).
- ITEM > GIVE / TAKE keeps the party on screen, with modern messages and
  YES/NO.
- **RELEARN** in a Pokémon's menu (outside battle) opens a Modern move list
  with levels and move stats.
- START / SELECT stay on screen here (SELECT is Crystal's switch).

### 6.4 PACK (redesigned in 0.9.92)

- **A dense list** (about twice the rows) with a scroll bar.
  - The quantity is a badge.
  - The item registered to SELECT is tagged **SEL**.
- **Pocket tabs** (ITEMS / POKé BALLS / KEY ITEMS / TM/HM) each have an icon and
  an item count. Tap a tab to switch pockets.
- **SORT**, in the title row (tap it) or with **START**:
  - cycles **A–Z → TYPE → COUNT**;
  - reorders the pocket itself, so the order is saved with your game;
  - the TM/HM pocket keeps Crystal's TM-number order and has no SORT;
  - START is otherwise unused in the cart's PACK.
- **Detail panel:**
  - a category tag (MEDICINE, BERRY, BATTLE, HOLD, BALL, KEY, TM, HM, MAIL or
    OTHER);
  - the sell price and where the item works;
  - for a TM, its move's type, power, accuracy and PP;
  - who is holding the item;
  - **USE / GIVE / TOSS / REGISTER** buttons. They open the PACK's own item
    menu on that action and press A, so every cart rule applies (no TOSS for
    key items, only USE in battle, eggs, mail). Only the actions that menu
    offers are drawn. A chooser pack (selling, depositing, giving) gets one
    **CHOOSE**.
- **Party strip:** for a TM/HM, who can learn it (CAN LEARN / CAN'T / KNOWS).
  For medicine, who it would help. Otherwise, who is holding it.
- Tap an item row to select it and press A (the item menu). **Hold an item** to
  pin it to the key item wheel.
- Keys and pad work as on the cart. SELECT still moves an item.

### 6.5 PC box (Bill's PC)

WITHDRAW, DEPOSIT, MOVE PKMN, START > PC and the HUD's BOX button all open the
same screen.

- **All boxes as one paged grid:** PAGE n / 14, a 5×4 grid of HD sprites per
  page, with your party as a strip across the top. The selected Pokémon's
  picture, level, HP, types and moves sit below the grid on tall screens, or
  to its right on wide ones.
- **Tap a Pokémon** (or press A) for Crystal's usual menu: WITHDRAW / DEPOSIT /
  MOVE, STATS, RELEASE.
- **Drag a Pokémon** to move it:
  - party to page (deposit) or page to party (withdraw);
  - within a page, or within the party;
  - to another page: hold it on a page arrow for 0.6 s per page turn.
- **Turn pages** by tapping the arrows or the page dots.
- **Buttons:** the D-pad moves across the strip and grid. LEFT / RIGHT off a
  page edge turns the page, and **L / R** turn it too.
- Crystal's rules apply: a full box or party, your last healthy Pokémon, mail.

### 6.6 Poké Mart

- BUY / SELL / QUIT rows, the buy list and the sell list are all tappable. A
  tap on a row selects it and presses A.
- **Quantity box:** tap its **left half for −1** and its **right half for +1**.
  A confirms.
- **SELL VALUABLES** (sell list): one YES/NO for the total, then every
  sell-only treasure goes at once (Nuggets, Pearls, Big Pearls, Stardust, Star
  Pieces, the mushrooms, Slowpoke Tails, Brick Pieces, Silver / Gold Leaves).
  It pays exactly what selling them one by one would.
- **ALL (n)** in the sell quantity picker sets the whole stack. The usual price
  question follows.
- While selling, the quantity screen names and describes the item you are
  selling.
- YES/NO is inside the message box.

### 6.7 Pokédex, POKéGEAR, summary and trainer card

- **Pokédex:**
  - Tap a species to highlight it, then tap it again to open its entry.
  - The entry's **PAGE / AREA / CRY / PRINT** tabs are tappable.
  - On the area map, tap a half to switch region, or tap the title to go back.
  - The option and search lists are tappable.
  - START (search) and SELECT (options) stay on screen.
- **POKéGEAR:**
  - Card tabs are tappable.
  - CLOCK card: a 24-hour dial coloured by time of day.
  - PHONE: tap a contact to select it, then tap again to call. Submenu rows
    are tappable, and incoming calls show caller ID.
  - **Fly map:** LEFT / RIGHT switch between Johto and Kanto when the other
    region has an unlocked destination. The engine's Fly picker otherwise
    ignores LEFT / RIGHT.
- **SUMMARY** and **TRAINER CARD:** Modern windows. With **PARTY SCROLL**
  (QUALITY OF LIFE, default ON), Up / Down in STATS cycles through your party.

### 6.8 Other screens given a Modern window (0.9.75)

These screens get a themed, tappable window with the close button and footer.
A tap sets the screen's own cursor and presses its button:

- **Move learning:** FORGET A MOVE outside battle (type pills, PP and the new
  move), the Move Deleter, the PP-item move pick, and the **Move Tutor**
  (ABLE / NOT ABLE / KNOWS IT).
- **Item PC** (with quantity buttons and MOVE), **Mom's bank** (a keypad with
  up / down per digit), the **mailbox**, held mail, and reading and writing
  mail.
- **Day-Care** conversation, **NPC trades**, phone prompts.
- **Game Corner** prize counters and coin seller, the **Bug-Catching Contest**
  swap, the **Battle Tower** level list, bedroom **decorations**,
  **elevators**, **Buena's password** and prizes, and the **photo studio**.
- **Story screens:**
  - Hall of Fame (the PC viewer has NEXT / NEXT TEAM);
  - the Diploma;
  - egg hatching (the native shell animation, then the HD hatchling);
  - the Unown printer and puzzle.
- **Area Dex:** every wild Pokémon on the map, with odds and levels.

### 6.9 Other UI changes

- **AREA SIGN** (OVERWORLD & 3D, default MODERN): town and route names on a
  themed plaque, top left. NATIVE keeps the cart's sign.
- **Settings hub:** CRYSTAL-AIO has nine pages: GAMEPLAY, NUZLOCKE & RULES,
  BATTLE, OVERWORLD & 3D, DISPLAY & MENUS, QUALITY OF LIFE, WILD POKEMON &
  FOLLOWERS, TOUCH CONTROLS and ADVANCED.
  - The **SETUP WIZARD** is the first row, and it also opens on NEW GAME. Its
    LOOK step offers CRYSTAL, HEARTGOLD, JOHTO NIGHT, GEN 3, LEAD POKEMON or
    ORIGINAL.
  - It is also reachable from OPTION and the engine's MOD MANAGER.

---

## 7. Themes, scaling and layout settings

All on **CRYSTAL-AIO > DISPLAY & MENUS** unless noted.

| Setting | Choices (default) | Notes |
|---|---|---|
| **UI THEME** (first row, opens a list) | GEN1 MODERN, HEARTGOLD, SOULSILVER, JOHTO NIGHT, CLASSIC MONO, CRIMSON, CRIMSON GLASS, MODERN GLASS, POCKET GREEN, MIDNIGHT, MIDNIGHT GLASS, FROST, LIGHT, DARK, CRYSTAL, GOLD, SILVER, POKEGEAR, HIGH CONTRAST, **TYPE (LEAD POKEMON)**, **TYPE LIGHT (LEAD POKEMON)**, GEN 3 (FRLG), **CUSTOM** (GEN1 MODERN) | The theme colours every Modern window, the battle panel and cards, the HUD and the touch controls. The two LEAD POKEMON themes are tinted by your lead Pokémon's type and change when your lead does. TYPE LIGHT uses light panels. |
| CUSTOM BORDER / CUSTOM BACKING / CUSTOM BORDER COLOR | border: GEN 3, FRAME 1–3, SOFT, PLAIN; 11 backings; 11 border colours | Shown only for UI THEME = CUSTOM. |
| UI FRAME STYLE / PIXEL FRAME / PIXEL FRAME SCALE | THEME, PIXEL, SOFT, PLAIN (PIXEL) | Hidden for the GEN 3 and CUSTOM themes. |
| **UI FONT** | PIXEL OPERATOR / KIM ORIGINAL (PIXEL OPERATOR) | Also used for touch labels. |
| **UI SCALE** | AUTO, 75–150% in 5s, 175–400% in 25s (100%) | Modern panel and control size. |
| **FONT SCALE** | AUTO, 80–200% (100%) | Text, separately from panels. |
| UI DENSITY | AUTO / COMPACT / COMFORTABLE (AUTO) | Row spacing. |
| LAYOUT STYLE | ADAPTIVE / FLOATING / FULL SCREEN (ADAPTIVE) | |
| PANEL OPACITY / TEXT / LINE OPACITY | 0–100% (100%) | |
| DIALOGUE TEXT SCALE | INHERIT, 110–200% (INHERIT) | Dialogue, choices, quantities and YES/NO. |
| START MENU UI SIZE / TEXT SIZE, SIDE MENU INSET, START MENU FAST JUMP | see 6.2 | |
| MINIMAL UI | ON / OFF (OFF) | |
| MENU BUTTON | TOP RIGHT / BOTTOM RIGHT / BOTTOM LEFT (TOP RIGHT) | See 3.2. |
| MENU TRANSITIONS, MENU DIM | see section 6 | |
| HOLD TO SCROLL | ON / OFF (OFF) | Holding UP / DOWN in a menu repeats after 22 frames, then every 8 (about 7 rows a second). The touch ring has its own repeat (see 2.3). |
| INSTANT TEXT | ON / OFF (OFF) | |
| OVERWORLD HUD, HUD POSITION, HUD BUTTONS | see section 4 | |
| MODERN UI, MENU UI, DIALOGUE UI, POKEMON SCREENS, HIDE ORIGINAL UI | ON (each) | See section 6. |

The overworld **ZOOM** (the engine's own row) is kept per screen shape; see
[2.7](#27-one-layout-per-screen-shape).

---

## 8. Keyboard and gamepad reference

Keys and pads press the same Game Boy buttons as always (mapped by the engine),
and **every cart meaning is kept**. The additions below only use buttons, or
moments, that Crystal leaves unused, or they are opt-in.

| Where | Button | Base Crystal | Crystal-AiO |
|---|---|---|---|
| Overworld | START | START menu | Same. The menu gains **QUICK**, **PC** and **CRYSTAL-AIO**. |
| Overworld | SELECT | use registered item | Same. Items picked from the key item wheel or the BIKE HUD button become the SELECT item. |
| Overworld | B (held) | — | **Sprint** while held (QUALITY OF LIFE: SPRINT default ON, button B or SELECT, 1.5× / 2× / 3×). |
| START menu | LEFT / RIGHT | nothing | **Jump 5 rows** (START MENU FAST JUMP). |
| Menus | held UP / DOWN | one row per press | Repeats with **HOLD TO SCROLL** ON. |
| PACK | START | nothing | **SORT** (A–Z → TYPE → COUNT), Modern PACK, not TM/HM. |
| PC box (Modern) | L / R, or LEFT / RIGHT at a page edge | box-specific | Turn the page. |
| POKéGEAR Fly map | LEFT / RIGHT | nothing | Switch Johto / Kanto. |
| Battle, command menu (wild) | SELECT | nothing | **Quick Poké Ball** (rules in 5.4). |
| Battle, command menu | B | nothing | With **B FOR QUICK FLEE** (BATTLE, default OFF): moves the cursor to RUN, and A confirms. Not in trainer battles. |
| Battle, move list | D-pad | 4-row list | 2×2 grid navigation with MOVE LAYOUT = GRID. |
| Battle, move list | SELECT | mark / swap move | Same. The marked move is outlined in the Modern list. |
| Battle | — | cursor resets each turn | **REMEMBER CURSOR** and **REMEMBER MOVE** (BATTLE, both default ON) keep the menu and move cursor where you left them. |
| Evolution | B | stops only in short pauses | **Any** B during the animation stops it (not stone evolutions). |
| Level up | A | two screens | One A: line and STATS card together. |
| Mart sell quantity | — | — | ALL and SELL VALUABLES are touch / pointer buttons. With keys, sell as usual. |

On a touch device, the floating controls give you all of the same buttons
except **L / R**.

---

## 9. Quick reference cheat sheet

### Touch

| Do this | Get this |
|---|---|
| Touch and slide anywhere | D-pad (4-way); the ring follows your thumb |
| Quick tap anywhere | A |
| Hold on a text box | Hold A (fast text) |
| B button | B |
| START / SELECT pills | START / SELECT |
| Hold START (overworld) | QUICK MENU |
| Hold SELECT (overworld) | KEY ITEM WHEEL: drag to an item and let go, or let go and tap |
| Far drag (overworld, FAR DRAG HOLDS B on) | Also holds B (run) |
| Tap a HUD button / clock panel | Shortcut / POKéMON screen |
| Tap a menu row, tab or button | Select it (and usually A) |
| Tap the X / back arrow | B |
| Drag a list | Scroll (flick to glide, touch to stop) |
| Hold a direction in a menu | Repeat about 4 rows a second after 0.5 s |
| Hold a Pokémon (party, outside battle) | Pick up, drop on a slot to switch, or on its own row for STATS |
| Hold / drag a Pokémon (PC box) | Move between party, slots and pages |
| Hold a PACK item | Pin / unpin on the key item wheel |
| Battle: tap command / move | Choose it |
| Battle: hold a move | Move info card |
| Battle: drag a move onto another | Swap their order |
| Battle: Poké Ball in the panel | Quick throw (wild only) |
| Battle: back arrow | B |
| Battle: hold an HP card | Pokémon info card |
| YES / NO buttons | Answer (B = NO) |
| Evolution: STOP EVOLUTION | Stop it (not stone evolutions) |

### Where the settings are

| Page | Control and UI settings |
|---|---|
| TOUCH CONTROLS | FLOATING CONTROLS, BUTTON SIDE, BUTTON HEIGHT, CONTROL SIZE, CONTROL OPACITY, DRAG DEAD ZONE, TAP MENUS, LONG PRESS, FAR DRAG HOLDS B |
| DISPLAY & MENUS | UI THEME, MODERN UI / MENU UI / DIALOGUE UI / POKEMON SCREENS, UI FONT, UI SCALE, FONT SCALE, START MENU sizes and FAST JUMP, HOLD TO SCROLL, MENU TRANSITIONS, MENU DIM, MENU BUTTON, OVERWORLD HUD, HUD POSITION, HUD BUTTONS |
| BATTLE | MODERN BATTLE UI, BATTLE UI MODE / SIZE / OPACITY, BATTLE TEXT SIZE, MOVE LAYOUT, MOVE INFO, MOVE TYPE COLORS, EFFECTIVENESS HINT, BATTLE HUD, REMEMBER CURSOR, REMEMBER LAST MOVE, B FOR QUICK FLEE |
| QUALITY OF LIFE | SPRINT (and its button), PC IN START MENU, QUICK MENU, QUICK IN START MENU, KEY ITEM WHEEL, PARTY SCROLL |
