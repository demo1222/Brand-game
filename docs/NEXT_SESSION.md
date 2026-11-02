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
- "Claude Design" means the Artifact design canvas. Canvases:
  - https://claude.ai/artifact/MRRHqKZZeK878v1eSp7MaM (HUD on the dock, HUD while diving, Bag
    window, Diver window, icon set: the older "instrument panel" look)
  - https://claude.ai/artifact/6qAehNiFLfragFYkXfpUVb (phase 3.2 game-style windows: Upgrades,
    Shop, Bag & Dock, Codex, Quests). Add the remaining windows here as artboards.

## First task next session: finish the modal redesign from screenshots

Done in phase 3.2: Shop, Bag & Dock, Upgrades, Codex, Quests & Tide Pass. Done in 3.3:
Resurface (Rebirth), Leaderboards, Players, Settings (see below). Still to do, as the owner
sends screenshots (they can attach 5 per message): Trade, Diver, the reveal card, offers and
the death, robbed and offline popups (`OfferController`). For each one:

1. Say what's wrong: hierarchy, density, "website-ness", unclear actions, broken icons.
2. Propose the game-like version on the design canvas first (one artboard per screen).
3. Implement it in Luau, keeping the window API (`UIController.RegisterWindow`).

## Kit v4 (phase 3.2): the game-UI building blocks

Use these instead of flat cards and thin outlines:

- `T.Outline` (near-black) is the outline colour for every slab, button, bar and title.
  `T.Slab` is the default raised tile colour.
- `Kit.GameCard(color, props, onClick?)` returns `container, face`. It's a raised slab with a
  dark lip, sized by UDim2 so it works in grids and lists. With `onClick`, the whole card is
  the button and presses down onto its lip. Use it for anything the player taps: upgrades,
  shop items, quest rows.
- `Kit.PricePlate(text, color, icon?, props)` is the chunky price strip inside a GameCard. It
  is a label, not a button: the card is the button.
- `Kit.Button` now has a bevelled bottom lip (`Kit.Bevel`), a 2 px outline and outlined light
  text. Its bottom `UIPadding` lifts the text, so children are laid out in a slightly
  shorter box.
- `Kit.Title` outlines light text with a contextual `UIStroke`. Pass `Outline = false` to
  skip it. Never add a second `UIStroke` to the same object: only one is drawn, so the border
  stroke wins. Light text on buttons and plates uses `TextStroke*` instead.
- `Kit.Tabs`: a dark tray of raised tabs. `Kit.Card`: 2 px dark outline. `Kit.Header`: outlined
  Fredoka caps in the section colour. `Kit.Bar`: outlined, glossy fill.
- Window chrome (`UIController.RegisterWindow`): a title band in the window's colour
  (`Icons.Colors`, shared with the HUD rail), an outlined title, a red pressable close button,
  a thick dark outline and an inner rim in the window colour.
- Grids that should fill the width use `fitGrid` in MenuController (Bag, Codex).
- Windows that refresh on `Coins` (+N/s, every second) must not rebuild unless something
  visible changed. Use a signature, as `renderUpgrades` and `renderBag` do. Otherwise a card
  is replaced under the player's finger and the tap is lost.

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
- **Phase 3.2** (latest patch, on top of `8198032` "phase 3.1"):
  - Kit v4 and the new window chrome (above). Every window picks up the chunkier look.
  - **Upgrades fixed and rebuilt.** It crashed after the zone pips: it indexed a `TextLabel`
    that drawn icons don't have. So only the suit card showed, and its tiny "customise"
    button was the only thing to press. Now there is a suit hero card (tap to buy the next
    suit, plus a labelled Customize button), then one whole-card button per stat in three
    sections (Dive gear, Dock, Dock defense). Each card shows the level, a level bar, the
    effect now → next (e.g. "Dive time 78s → 84s") and a green price plate when affordable.
    The Laser Gate "Activate" card sits in Dock defense. Rebuilds only on a visible change.
  - Shop: a two-line VIP banner (the old one overlapped its text), seven colour-coded tabs
    that fit without scrolling, and whole-card buy tiles with price plates.
  - Bag & Dock: no gap beside the Sort button, a proper empty state (the old one was squashed
    into a 112 px grid cell), a detail placeholder with an icon, and a grid that fills the
    width.
  - Codex: a zone progress strip (count, wide bar, "100% = +5% luck" pill) and a grid that
    fills the width.
  - Quests: whole-row claim cards. The right side is CLAIM! (pulsing), DONE, or a percent
    readout instead of a grey "In progress" button. Login tiles show CLAIM! on today's tile,
    and claimed tiles use the drawn check icon instead of a check glyph.
  - StyLua reformatted the four controllers it touched (HUD, Menu, Shop, UI), which were not
    StyLua-clean before.
- **Phase 3.3** (on top of `4e4b27a` "changes", which is 3.2 applied):
  - **Diving board = a real dive.** Jumping off a board no longer lets the default Roblox
    jump flail into the water. `SwimController` takes over with a scripted swan dive:
    - In the air: a ballistic arc out to sea (`DIVE_OUT`, `DIVE_LAUNCH`, `DIVE_GRAVITY`). The
      body rotates so the head follows the arc: upright, then horizontal at the top, then
      head-first down for a near-vertical entry.
    - Entry: a big splash.
    - Underwater: a fast streamlined glide that curves from straight down to forward-down,
      slowing to swim speed at the board depth, then hands over to normal swimming.
    - It runs through the swim LinearVelocity/AlignOrientation, so other players see it.
      `SwimAnimController` adds a streamlined pose (arms locked overhead, legs together,
      dolphin kick), worked out from the body's tilt (air) or a steep fast plunge (water),
      so it also shows on every client.
    - Needs a Studio check: arc length off a raised dock, R6 arm direction, camera feel.
  - Resurface: stat slabs with luck and token pills and a drawn arrow. Requirements use
    tick/cross icon tiles (the old ✓/✗ glyphs rendered as boxes). The RESURFACE button is a
    big gold slab when ready and a locked slate one otherwise. Keep/resets are pill clouds.
    Talents are whole-card buttons with token price plates and level pips. Rebuilds only on a
    visible change (LifetimeCoins ticks every second).
  - Leaderboards: the podium is taller (the #1 medal was clipped at the top), with GameCard
    blocks and a crown for first. Ranks 4–10 always show, open spots dimmed, and your own row
    is outlined.
  - Players: a perks strip with pills. "Leave party" only shows when you're in a party
    (party names are kept from `PartyUpdated`); otherwise "Invite friends" opens Roblox's
    invite sheet. There's an empty-state card, and party members are outlined.
  - Settings: rows with coloured icon tiles, a 10-segment volume meter with a percent
    readout, a chunky ON/OFF switch, and controls shown as key caps. `settingRow` takes a
    `reserve` width (the Diver window passes 112).
  - New drawn icons: `arrow`, `music`, `keyboard`.
- **UI round 2, part A (icons):** `Icons.Assets` maps 58 of the 89 `Icons.Names` keys to the
  147-icon set (`docs/images/Stylized_Game_Essentials_147_Icons.zip`, folder `All_Icons`). The
  other 31 keep the drawn fallback. The owner has uploaded the set and pasted the IDs into
  `Icons.Images` (58 keys, 48 files). The full table is in `docs/icon_map.md`. Judgement calls
  to confirm: Pearls, Tokens, Diver, Shop, Bag. At 16 px, Coins and Tokens look alike and Boost
  and GateRecharge look alike.
- **UI round 2, part A2 (rail and fallbacks):** the HUD rail is icon-first: a 58 px round medal
  with a colour ring, a 44 px icon and a short label under it (no raised button face; SHOP keeps
  a gold medal). Up uses the Up mapping. Lock, Vault, VaultLock, Alert, error and Up reuse
  uploaded files. Sonar, Track_Sonar, Flare, Flares5, Clean, BarnacleClean and Track_Board map
  to four new files (`target`, `fireball`, `trash_bin`, `wood_planks`), which need uploading and
  an ID in `Icons.Images`.
- **UI round 2, part A3 (generated icons):** all 15 new icons live in `docs/images/icons/generated/`
  as 512 px PNGs with the background removed. They are mapped in `Icons.Assets`: down_arrow
  (Down), oxygen_tank (Oxygen, DoubleOxygen, Track_Oxygen), sonar (Sonar, Track_Sonar),
  depth_gauge (Depth), display_stand (Display, Track_Display), drone, radio, skull (Death),
  huge_star (Huge), signpost (RenameDock), fast_forward (SkipPity), coral (Reef), seaweed (Kelp),
  shipwreck (Wrecks), deep_abyss (Abyss), ocean_trench (Trench). Each needs uploading in Studio
  and an ID in `Icons.Images`. The Down button uses `Icons.Get("Down")`. The Depth key has no
  drawn icon in the HUD yet, so depth_gauge shows once it is wired into the depth band.
- **UI round 2, part A (finished, mapping complete):** every one of the 89 `Icons.Names` keys
  now has an `Icons.Assets` file. The A3 mappings are now in the code too (they were only in
  the doc). Still to upload and paste into `Icons.Images`: the 13 generated files above, plus
  `fireball` (Flare, Flares5) and `trash_bin` (Clean, BarnacleClean). The raw Canva exports
  in `docs/images/icons/generated/temp/` are not used and can be deleted. At 16 px, Coins and
  Tokens look alike, Codex, Leaderboards and Rebirth lose detail, and some keys share one file
  (Lock, Vault, Gate and Track_Gate use `locked_gate`). Check 24 px as the minimum in tabs.
- **UI round 2, part B (swim animation, `SwimAnimController`):** the freestyle now has a pull
  and a recovery per arm, with an elbow bend in the pull. The torso rolls about its spine (the
  Waist Y axis), and the pulling shoulder drops. The head turns to breathe on every second stroke,
  held for 0.4 s. The kick shares the stroke phase (6-beat). Pose tables are built once per rig.
  R6 gets arms and legs only: no waist, and the neck axes are not verified on R6. Splash: a
  surface ripple now plays when you break the surface going up (`splash(pos, 12, 0.35)`). Not
  checked in Studio: every item above, and the cost at 20 swimmers (not measured).
- **UI round 2, part C (diving board):** the jump is one config block, `Upgrades.Dive`:
  Launch 34 studs/s, Out 20 studs/s, Gravity 85, and +3 launch and +3 out per Board level. Level
  10 is Launch 64 and Out 50. The plunge depth is unchanged (20 m + 15 m per level, to 170 m). The
  skin steps every 2 levels: Plank, Varnish, Brass (level 4), Copper, Gold (level 8), Pearl. The
  card reads "Launch and dive: 34 studs, 20m to 37 studs, 35m". The owner's example
  ("Launch 34 to 40 studs, dive 65 m to 80 m") needs a two-line effect row. The glide timeout is
  now 8 s, so the deepest board reaches its depth. Checked with a numeric run of the dive
  formulas for levels 0 to 10 (3 start heights, 2 swim speeds): every dive enters the water and
  reaches its depth. Not run in Studio.
- **UI round 2, part C2 (board card):** the Diving Board card has two effect rows, inside
  the existing 164 px card: "Launch 34 → 37 studs" and "Dive depth 20m → 35m". The plunge and the
  launch keep their per-level steps from `Upgrades.Dive`. Not checked in Studio: the label
  widths and truncation on phones.
- **UI round 2, part E (relic fixes):** nine relics reworked in `shared/RelicArt`:
  R003 snorkel (thicker, banded), R013 Reef Idol (new seated idol, `reefidol`), R027 cannonball
  (iron band, rust patch), R036 figurehead (bigger head, eyes on the face), R039 pebble (glowing
  vein), R045 totem (three-spike crown), R052 tooth (rounded root), R057 Vent Idol (new basalt
  idol, `ventidol`), R059 gauntlet (shorter wrist, proportioned fingers). Checked by reading only
  (the block structure). Not rendered: three.js and Lune were not available. Render the sheet
  and run `lune run tools/relic_art_check` before the owner judges them. The mesh hook and
  export spec are still proposals.

## Still to do (priority order)

1. **Modal redesign** for the remaining windows, from the owner's screenshots (above).
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
   - the icon set into `Icons.Images` (mapping is in `Icons.Assets`; owner pastes the IDs)
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
