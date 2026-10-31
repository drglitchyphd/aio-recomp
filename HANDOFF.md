# Hand-off: Crystal-AiO (formerly Gen2-AIO), 2026-10-31

## Where things stand

| | |
|---|---|
| **Live release** | **0.9.91** on `main` (origin/main `9e7ee41`). Players are on this. |
| **Work branch** | `ccr-e074fdc7-7otw01` (head `feb1fbe`), pushed. It carries the unreleased 1.0.0. |
| **1.0.0 PR** | **#45, DRAFT, do not merge yet.** Merging to `main` auto-publishes the release (`.github/workflows/auto-release.yml`). It is held until the credits are complete. |
| **Repo** | `drglitchyphd/aio-recomp` |

### What is on the 1.0.0 branch (all tests pass)

- **Crystal-only:** the Gen 1 / Gen 3 code and assets were removed (373 files, about 12 MB). `main.lua` returns on any generation other than 2.
- **Rename:** Gen2-AIO became **Crystal-AiO**, and the mod id changed from `gen2-aio` to **`crystal-aio`**. Docs, the folder (`lib/crystal_aio/`) and the mod index are renamed. `gen2-aio` is listed in `conflicts`.
- **Migration:** `lib/crystal_aio/identity_migration.lua` imports `gen2-aio` and `KIM_ARENA` data.
  - Options, `save.modData` and `mod.storage` are copied at start-up.
  - The HD asset pack copies in the background through `core.update`.
  - Originals are never overwritten or deleted.
- **Full-install release pipeline:** `tools/build_release.py --full-install`, with auto-detection of an id change or a major version bump in `release.yml`.
- **Prize money fix:** a legacy QoL Toggles `money_mult` key was honoured while the row showed OFF. The row now shows the value really in effect, and 0X moved to the end of the MULT cycle. Verified fixed on device by the user.
- **gmarc upstream merge:** gmarcs Gen 2 Voxel Mod 1.0.17 (upstream `e51b53a`, merge base `037555a`).
  - New: mountain stone edges, Cherrygrove terraces, Route 39 fence, tree and roof polish, iOS orientation, companion region profiles.
  - Upstream's `battleSprites` option was renamed `voxelBattleSprites`, hidden and locked to "native".
  - The disk cache pauses while a companion profile is registered.
  - `voxel_heights.lua` was re-converted to compact edit strings; the result was verified identical (441 templates, 2,408,453 edits).
- **Credits added** (`THIRD_PARTY_NOTICES.md`):
  - Kanto in Motion repo: https://github.com/HaseoSora/Kanto-in-Motion
  - gmarc repo: https://github.com/gmarcmods/gmarcs_gen2_voxel_mod
  - Quality of Life (unxpected-uxp): its own entry
  - QoL Toggles: ShaneMcGovernIE, https://github.com/ShaneMcGovernIE/qol_toggles

## In flight / not done

1. **A worker agent was applying the user's gmarc merge decisions** (it may not have finished; check for its worktree branch `worktree-agent-*` or redo it):
   - **Black/White (Gen 5) imported battle sprites:** offer them as a BATTLE SPRITES choice ("BLACK/WHITE (IMPORTED)").
     - Declare the engine's shared pack `gen5_bw` / `battle_sprites` in `manifest.json`. The engine's Import screen builds it from the player's BW dump (`src/import/Importers.lua`, `src/import/gen5/BwImport.lua`); gmarc reads it via `mod.packs` (`gmarc/lib/ImportedBattleSprites.lua`).
     - Drive the hidden `voxelBattleSprites` lock from that choice, and fall back to KIM HD when the pack is missing.
   - **Revert to upstream:** remove our **door precache** (`gmarc/lib/Prefetch.lua`, setting `voxelPrecache`) and **world edge fill** (`gmarc/lib/VoidFloor.lua`, setting `voidFloor`) everywhere, including main.lua, hub, docs and tests.
   - **Keep the rest of ours:** door-walk fix, ledge hops, locked/Kenney battle camera, TIME OF DAY sky, tall-screen battle sprite fit, battle backgrounds, and all performance and cache code.
2. **PACK screen redesign, requested, not started.** The user wants it shipped as **0.9.92** (a normal release, before 1.0.0). The user chose:
   - **Denser list + pocket polish:**
     - shorter rows, about twice as many visible, with a scroll bar;
     - quantity as a pill badge;
     - icons and item counts on the pocket tabs;
     - a mark on the item registered to SELECT;
     - a SORT button (A–Z / type / count).
   - **Richer detail panel:**
     - a category tag (MEDICINE / BERRY / BATTLE / HOLD / KEY);
     - sell price;
     - which party Pokémon hold the item;
     - tappable USE / GIVE / TOSS buttons.
   - **Party compatibility strip:** six party icons. For TMs/HMs, a ✓/✗ for who can learn it; for medicine, who it would help.
   - **Not wanted:** item icons.
   - **Where:** the pack presenter is in `lib/gen2_modern_core_menus.lua`. That file is at Lua's 200-local main-chunk limit, so put new code in a new module.
   - **Branching:** 0.9.92 must be built from `origin/main` (0.9.91), not from the 1.0.0 branch. That means a separate branch, so **ask the user for permission** to push one, or ship the pack work inside 1.0.0 instead.
3. **Credits still missing before 1.0.0 can publish:**
   - KIM Touch (`touch/`): author and repository
   - Nuzlocke and Stadium 2 Importer: repository links
   - licences for Kanto in Motion, gmarc, Nuzlocke and Stadium 2
   - trainer battle sprite source, and whether to keep the Bulma and anime sprites
   - sources for the pixel frames, the shiny sparkle and its sound
   - Open list: "Source not recorded in the bundle" in `THIRD_PARTY_NOTICES.md`.

## How to work on it

- **Engine source** (read-only, needed by tests): `/tmp/claude-0/-home-user-aio-recomp/93d24e30-e7a0-544d-b874-3287c2b09229/scratchpad/engine/src`. It is lost if the container resets. It is the Gen1Recomp engine source.
- **Run every suite:**
  ```sh
  E=<engine>/src
  for f in tests/*.lua; do AIO_ENGINE=$E AIO_ENGINE_SRC=$E luajit $f; done
  for d in tests/*/; do [ -f $d/main.lua ] && AIO_ENGINE_SRC=$E xvfb-run -a love $d; done
  python3 tests/test_distribution.py
  ```
- **Releasing:**
  1. Bump `manifest.json`.
  2. Add a "## X.Y.Z changes" section at the top of the README notes (`README_GEN2_AIO.md` on main, `README_CRYSTAL_AIO.md` on 1.0.0) and a "## X.Y.Z (date)" entry in the handoff spec.
  3. Open a PR to `main` and merge it; auto-release publishes `vX.Y.Z` and updates the mod index.
- **Conventions:**
  - Commits end with the Co-Authored-By / Claude-Session lines.
  - Never commit `.claude/`.
  - Engine modules are wrapped once per process (Android relaunches reuse the Lua state); session state goes in a "live" function.
  - Sub-mod proxies use `__index` to the main mod, so read the main mod's fields with a normal lookup, not rawget.
  - Overlay patch releases cannot delete files; only full installs can.
- **User's device:** Galaxy Z Fold (cover screen 1080x2520, inner 2184x1968), Android, touch, Adreno 840. The mod runs inside the engine sandbox, which denies ffi, love.filesystem, and love.thread without the "compute" permission.
