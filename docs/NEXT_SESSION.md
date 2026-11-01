# Next session: start here

A hand-off for a fresh Claude session continuing Abyss Salvage's UI and visual upgrade.
Read this first, then `docs/UI_OVERHAUL_PLAN.md` (what was built, by phase) and
`docs/IMPLEMENTATION_STATUS.md` (game systems vs. the master plan).

## How the owner works (follow these)

- **Never commit or push.** Pushing from cloud sessions is broken (a known issue the owner
  already tracks). Deliver work as a patch file, and don't spend messages on git workarounds:
  ```bash
  git add -N <new files> && git diff --binary origin/main > <scratchpad>/<name>.patch
  ```
  Verify it with `git apply --check` on a fresh `git archive origin/main` copy, then hand over
  the absolute path. The owner applies it with `git apply <file>` and commits it themselves.
- **UI is the top priority.** The owner judges by screenshots from Roblox Studio.
- **It must feel like a game, not a website.** Feedback on the instrument-panel pass: "design
  looks like a website", "vibe-coded buttons". Prefer chunky, tactile, playful game UI:
  - pressable buttons with a 3D lip (`Kit.GameButton`)
  - bold, coloured, thick-stroke icons
  - strong colour coding, clear hierarchy
  - satisfying motion

  Avoid thin outlines, flat web cards and tiny grey text.
- **No emoji anywhere.** Newer emoji render as empty boxes on Roblox. Draw icons with
  `UI/Icon` (vector primitives) or, later, uploaded images through `Icons.Images`.
- The owner likes the procedural relic models and the new suits. Keep that quality bar.
- "Claude Design" means the Artifact design canvas. Existing canvas:
  https://claude.ai/artifact/MRRHqKZZeK878v1eSp7MaM (HUD on the dock, HUD while diving, Bag
  window, Diver window, icon set). Update it, or start a new one, before big visual changes.

## First task next session: redesign every modal from screenshots

The owner will send a screenshot of every window and modal: Shop, Bag & Dock, Upgrades, Codex,
Quests & Tide Pass, Rebirth, Leaderboards, Friends, Trade, Settings, Diver, the reveal card,
offers and the death, robbed and offline popups. For each one:

1. Say what's wrong: hierarchy, density, "website-ness", unclear actions, broken icons.
2. Propose the game-like version on the design canvas first (one artboard per screen).
3. Implement it in Luau, keeping the window API (`UIController.RegisterWindow`).

## Current state (end of the previous session)

Delivered as patches, applied by the owner up to commit `205e99a` ("phase 3"):

- **Phase 1:** procedural relic art (`shared/RelicArt`, 60 relics), live 3D renders
  (`UI/RelicView`), relic cards, Bag grid + detail, Codex grid, reveal, Kit v2, HUD.
- **Phase 2:** buried loot nodes, sonar pulse, dock display animation, coin bursts, Quests,
  Tide Pass track, Rebirth, Leaderboards podium, Trade cards, modal restyle.
- **Phase 3:**
  - instrument-panel UI (Kit v3, `UI/Icon` drawn icons, new HUD, window chrome)
  - Diver window with part toggles, real suits (`shared/SuitArt`), swim animation
    (`SwimAnimController`)
  - the sea rebuilt (cliffs, shelves, spires, props, marine snow and fish)
  - template Baseplate removed (fixed the flicker)
  - world labels in studs, landmark luck, Leviathan avoidance
  - anglerfish, geysers and whirlpools, Event Tokens + Event shop, intro fly-over
- **Phase 3.1** (latest patch, on top of `205e99a`):
  - Removed the place-file "MainGui" (its ✨ toggle covered the UPGRADE button, which is why
    Upgrade "didn't work") and the orphan `ToggleController.client.lua`.
  - A window refresh error can no longer stop a window from opening (pcall + warn).
  - HUD rail: chunky `Kit.GameButton` tiles, colour-coded thick icons. It picks 1–3 columns
    from the free height, so it never overflows.
  - Round action buttons are solid with a lip. The flare and home icons are redrawn.
  - Wetsuit body: a dark base per tier with trim pieces (chest band and stripes, zipper,
    belt + buckle, arm bands, cuffs, leg stripes, knee pads), so it no longer reads as a
    recolour.
  - Diving board on every dock. Jump off it to launch, then plunge to your board depth. New
    Upgrades track "Diving Board" (+15 m per level, 20 m → 170 m). The board skin goes wood →
    brass → gold with level.
  - Preview tooling in `tools/preview` (see below), and this document.

## Still to do (priority order)

1. **Modal redesign** from the owner's screenshots (above).
2. **Game-like pass on everything else:** Kit v3 is still fairly "flat web" (thin hairline
   panels, small text). Restyle the remaining pieces with the same language as the rail:
   - panels with thicker borders, a darker inner rim and a title plate
   - bigger type
   - GameButton everywhere
   - coloured headers per window
   - item and tier colour coding
3. **Verify in Studio** (nothing has run in Roblox yet; Lune checks only):
   - HUD at phone sizes (≈800×360, 1334×750) and desktop
   - swim animation on R15 and R6
   - suit fit on different avatars and scales
   - the diving board launch and plunge
   - frame rate with the new sea (~4.4k parts) and a full Bag
4. **StreamingEnabled:** not enabled. These assume the whole world is loaded and need checking:
   `PromptController`, `FXController` (dock displays), `TutorialController`, the Sonar node
   tint and the Ambient fish. Then profile on a low-end phone.
5. **Translations:** use Roblox auto-translation; keep strings in code short and plain.
6. **Drag-and-drop** relics onto dock stands (master plan §18.2); today it's "Display on dock".
7. **Art pass** (needs the owner's uploads):
   - an icon set into `Icons.Images`
   - relic meshes (change only `RelicArt.Build`)
   - audio IDs into `AudioController.SOUND_IDS` (includes `Coins`)
8. **Pre-existing selene warnings** (unused variables) in DataService, DiveService,
   DockService and PredatorService. These are harmless; CI only fails on errors.

## How to check work without Studio

Tool binaries aren't installed in the container. Download the pinned versions from
`aftman.toml` (rojo 7.4.4, selene 0.27.1, stylua 0.20.0, lune 0.8.9) from their GitHub
releases. Selene can't fetch its Roblox API dump through the proxy, so CI is the selene check.

```bash
lune run tests/run                       # 27 unit tests
lune run tools/relic_art_check           # builds all relic models with Lune's Roblox API
lune run tools/preview/suit_dump         # all suit tiers + toggle restore
lune run tools/preview/world_dump        # the world build (part count, anchors)
lune run tools/preview/icon_sheet        # icon geometry sheet
rojo build default.project.json -o /tmp/test.rbxl
```

Visual previews (Playwright + Chromium are preinstalled in the cloud container):

```bash
cd tools/preview && npm install three@0.160.0
node render.js models out/relics.json out/relics.png
node render.js models out/suits.json out/suits.png
node render.js world '{"pos":[300,-80,-200],"at":[520,-140,-320]}' out/world.png
node render.js icons out/icons.html out/icons.png
```

Lune limits to remember:
- No `Model:PivotTo`; use `RelicArt.Place`.
- No `Part.Position`; read `CFrame.Position`.
- No property-changed signals.
- No `Random`; the dumps include a shim.
- `luau.load` environments must hold globals as direct keys; an `__index` chain is ignored.

## Code map (UI-relevant)

| Area | Files |
|---|---|
| UI kit, icons | `src/client/UI/Kit.luau` (Panel, Card, Button, GameButton, Pill, IconBadge, Tabs, Bar, Header), `UI/Icon.luau` (vector icons), `UI/Icons.luau` (key → icon) |
| 3D in UI | `UI/RelicView.luau`, `UI/RelicCard.luau`, `shared/RelicArt.luau` |
| HUD | `Controllers/HUDController.luau` (rail, capsules, depth band, actions), `FXController` (coin bursts, dock displays) |
| Windows | `UIController` (chrome, toasts, banners), `MenuController` (Bag, Upgrades, Codex, Quests, Rebirth, Leaderboards, Players, Trade, Settings, Diver), `ShopController`, `OfferController` (modals), `RevealController` |
| Diver | `shared/SuitArt.luau` (gear + wetsuit), `UpgradeService.ApplySuitVisual`, `SwimController` (movement, diving board plunge), `SwimAnimController` |
| World | `WorldService` (ocean, cliffs, spires, docks, diving board), `LootService` (nodes), `PredatorService` (Leviathan + hazards), `AmbientController`, `LightingController`, `SonarController` |
