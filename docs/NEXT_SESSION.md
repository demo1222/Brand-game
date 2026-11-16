# Next session: start here

A hand-off for a fresh Claude session continuing Abyss Salvage's UI and visual upgrade.
Read this first, then `docs/UI_OVERHAUL_PLAN.md` (what was built, by phase) and
`docs/IMPLEMENTATION_STATUS.md` (game systems vs. the master plan).

## How the owner works (follow these)

- **Work runs in local sessions only.** The Roblox Studio MCP is available, so changes can be
  tested in Studio directly. Edit files in `src/` (Rojo is the source of truth); don't edit
  synced scripts inside Studio.
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
  the doc). All 15 generated icons, plus `fireball` (Flare, Flares5), `trash_bin` (Clean, BarnacleClean) and `wood_planks` (Track_Board), are uploaded and live in `Icons.Images`. The raw Canva exports
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

- **UI round 3 (2026-11-15, owner's reference screenshots):**
  - `docs/UI_STYLE_GUIDE.md` (also in the Obsidian vault as "UI Style Guide") is now the UI
    contract: Throw Power for buttons and layout, Animal Index for windows, Food Shop for shops.
  - **Windows and modals:**
    - They never close on a click outside, only through the X, gamepad B or their own buttons.
    - They pop in from 0.85 and pop out (`Kit.PopOut`) instead of vanishing. This covers
      UIController windows, OfferController modals and RelicViewer.
    - The title band has diagonal stripes (`Kit.Stripes`, a CanvasGroup), and the body has a
      lighter top.
  - **Relic cards** (`UI/RelicCard`): bright rarity-coloured slabs with a dark outline, the
    name on top and the rarity and subtitle at the bottom. Models turn slowly (each card starts
    at a random angle). `RelicView` spinners run at 30 Hz and skip views that are hidden or
    scrolled out of view.
  - **Dock stands:**
    - Prompt reach is 6 studs (`STAND_REACH`; it was 12).
    - The always-on Info label is gone. The server sets `Relic*` attributes on the stand, and
      `StandHoverController` shows a hover card: on mouse-over, or near the stand on
      touch/gamepad. The card pops in with an overshoot, a wobble and a shine.
    - Placing a relic pops it out of the pedestal: a spring, a spin, a shockwave ring and
      sparkles (FXController `popDisplay`).
  - **Suits:**
    - There are 12 tiers (`Config/Upgrades.Suits`, each with Zone, Tier, Air, Swim, Desc).
    - The zone gate uses `Upgrades.SuitZone(data.Suit)`, not the raw index.
    - Data v3 migrates old suit indices (1, 3, 5, 7, 9, 12).
    - `data.SuitLook` lets you wear any owned suit (`RequestEquipSuit`).
    - New art flags: `crest`, `jets`, `spikes`, `tankColor`, and lamps on domes.
  - **Suit Shop:**
    - `SuitShopController` window: Food Shop cards with your own avatar in each suit.
    - A market stall on every dock (`WorldService.buildSuitStall`, a keeper visual) opens it.
    - The Upgrades suit card and the Diver window now link to the shop instead of buying
      directly.
  - **Verified in a Studio play test:**
    - the hover card
    - the place pop
    - the stall prompt
    - buying through the UI (perks apply: air 60s to 63s)
    - an outside click doesn't close the window
    - the X pop-out
    - Codex cards turning
    - no client errors

    Not checked: phone sizes, the late-tier suit art (crest, jets, spikes), and the hover card
    with the mouse (it was checked through the proximity path).
  - Screenshot tip: the Studio MCP capture doesn't draw AlwaysOnTop billboards, and its mouse
    y is in GUI space (screen y minus the 58 px top bar).

- **UI round 3b (game buttons):**
  - Figma file "Abyss Salvage - Game Buttons" (https://www.figma.com/design/zFdUG7hvixMW2FDAeloS0b)
    holds the `HudTile` and `ActionButton` component sets.
  - Code: `Kit.HudTile` (the HUD rail, with title-case labels and a gold "Shop") and
    `Kit.ActionButton` (the Suit Shop buttons). Specs are in `docs/UI_STYLE_GUIDE.md` section 8.
  - Converted everywhere on the owner's go-ahead:
    - the HUD actions are tiles
    - every `Kit.Button`, `Kit.GameButton` and `Kit.PricePlate` is restyled in place (see the
      style guide, section 8)
  - Currencies and the bag count are `Kit.Readout`: a big icon next to an outlined gradient
    number, with no capsule. Figma has a `Readout` component.
  - Tabs (Animal Index style), pills, the oxygen bar and the event cards were converted too. The
    HUD has no glass capsules left.
  - Not yet checked on phone sizes: the taller tab text and the bigger HUD readouts.
  - Studio tip: Rojo sometimes misses one of several quick edits. Before a play test, grep the
    synced script for the new line.

- **World and economy round (2026-11-15):**
  - **Sea:** the water is now an 8-stud slab of Terrain water (real waves, glints and
    reflections). The old flat `WaterSurface` part is gone. New `WaterController`: ripple rings
    round dock pillars, buoys that bob (tag `Bob`), surface sparkles and faint light shafts
    underwater. Note: EditableMesh waves would need "Allow Mesh / Image APIs" in Game Settings
    > Security; we don't use it.
  - **Relics:** nodes no longer spawn inside props (`WorldService.clearOfProps`, using the prop
    spots that `placeProp` records). Every node has a soft light pillar and a diamond marker
    (AlwaysOnTop, 110 studs) so it can be found through coral.
  - **Reef art:** new Reef props (brain coral with ridges, branching coral with glowing tips,
    sea fans, tube sponges, table coral, anemone, plus a sea-grass foot) and Kelp props (tall
    strands with leaves). Fish are multi-part models (body, stripe, forked tail, dorsal fin,
    eye) moved with one `BulkMoveTo`.
  - **Dock (keeper visuals):** the name sign is on a raised entrance arch. `buildDiveStation`
    adds rope rails, lamp posts, a tank rack, a compressor, a diver-down flag, a life ring, a
    moored dinghy, buoys and crates. The Suit Shop stall has bulbs and lights, and its floor pad
    (tag `SuitShopDisc`) opens the shop when you step on it.
  - **Ghost Thief removed** (the raid tutorial in RaidService).
  - **Suit Shop:** cards show the suit on a plain grey mannequin, and a small TRY ON button
    shows it on your own avatar. The cards show the coins and luck perks in gold.
  - **Economy:** 16 suits (new: Snorkeler, Tidecaller, Salvage Master, Anglerlight) with the
    new `Income` and `Luck` perks (`Formulas.SuitIncome` / `SuitLuck`), steeper suit and
    upgrade prices, rebirth at Pressure Mk II (index 10) plus 100M. Data v4 remaps old suit
    indices. The full scheme is in `docs/ECONOMY.md`, including planned relic material
    modifiers (Gold, Emerald, Diamond).
  - **Checked in a Studio play test:** the water, the dock arch and dressing, the stall pad
    opening the shop, the shop cards, the reef props and relic placement, and no errors after
    the fish fix. **Not checked:**
    - the stall glow after toning it down
    - the fainter light shafts
    - swimming at the surface with Terrain water (watch for buoyancy jitter near y = 0)
    - the node markers (the capture doesn't draw AlwaysOnTop billboards)
    - the new suit art
    - Lune unit tests (Lune isn't installed on this machine; tests were updated for the new
      costs)
  - **Next (owner's list):** sharks that guard relic clusters and attack, diver weapons
    (harpoon / knife) with real models, relic material modifiers, more Wrecks/Abyss/Trench
    props.

- **Round 2 (2026-11-15, same day):**
  - **Fixes:**
    - Double water: underwater, `WaterController` makes the Terrain water invisible and shows
      a flat local `SurfaceFromBelow` ceiling instead.
    - Roblox's default Swimming and Splash sounds are muted.
    - The starter guide is off (`TutorialController.ENABLED = false`).
    - Spire caps are flat stepped plateaus with rim rocks, not giant sand balls.
  - **Air:** the surface no longer refills your tank. Use the tank rack on your dock (prompt
    `AirRefillPrompt`, `DiveService.RefillAtRack`) or the new **Auto Refill** pass (49 R$,
    first in the Shop's pass list, offered once when you surface low). **Its pass `id` is 0:
    create the pass in Creator Hub and paste the ID into `Config/Passes.luau`.**
  - **Relic materials** (`Config/Materials`): Gold x3, Emerald x6, Diamond x12, Rainbow x30
    (luck boosts the odds). They stack with mutations and size. Size tiers: Tiny, Big, HUGE,
    TITANIC. Materials show on cards, the reveal, the stand hover card, the stand look
    (material first in the look list) and announcements.
  - **Zone guardians** (`Config/Monsters`, `GuardianService`, `GuardianController`,
    `shared/MonsterArt`):
    - One monster per zone: Reef Shark, Kelp Barracuda, Wreck Shark (glowing eyes, scars),
      Abyss Angler (glowing lure) and Magma Serpent (a segmented body that follows a trail).
    - Each guards a lair of red-marked relic nodes that roll with x1.5 to x2.5 luck.
    - Behaviour: patrol, chase (leashed to the lair), telegraphed wind-up, lunge and bite,
      cooldown. Flares scare them off.
    - The server moves one invisible root per monster; clients draw and animate the body.
  - **Blender:** `tools/blender/world_builds.py` and `run_world.py` build the four fish
    monsters, five corals, kelp and the air rack. Outputs: `models/monsters/*.glb`,
    `models/world/*.glb`, the bundles `monsters_bundle_1.glb` and `world_bundle_1.glb`, and
    the previews (`models/world/previews/sheet.png`). **Upload the two bundles and paste their
    IDs into `Config/WorldMeshes.Bundles`.** Until then the code-built versions show. The
    serpent stays code-built.
  - **Checked in Studio:**
    - Guardians spawn (21 lairs, 77 guarded nodes), and a full chase, wind-up, lunge and bite
      took HP 100 to 74 with the toast.
    - The tank rack refill and the Auto Refill offer, and no refill at the surface.
    - No double water at 20 m. Surface swimming is smooth (PlatformStand), and the default
      sounds are muted.
    - The new suit art in the world (Snorkeler, Salvage Master, Anglerlight, Leviathan, Coral
      Emperor).
    - Node markers: every node the client sees has one.
    - The unit-test expectations, run inside Studio (Lune is still not installed;
      `aftman install` needs the owner).
  - **Blender models are in the place:** the owner imported both bundles with Import 3D, and
    the 11 models now live in `ReplicatedStorage.WorldMeshes`, saved with the place, like
    RelicMeshes. Studio drops the glTF colours, so `WorldMeshes.Paint` colours every clone by
    role. MonsterArt turns imported monsters 180 degrees (they come in facing +Z).
    - Checked in play: 180 Blender corals, 88 kelp, the rack on all 16 docks, and the four
      fish monsters facing forward with the right colours.
    - Node lights are dimmer now: three or four lights at a lair blew the guardian out to
      white.
  - **Round 3 fixes:**
    - Floating corals, kelp and tank rack: the imported models' pivots sat at their slot in
      the bundle (up to 36 units off). `meshProp` now re-centres the pivot on the geometry,
      and the stored templates were fixed too.
    - Refill works again: the rack is back on its prompt.
    - Light shafts are off (`SHAFTS = 0`); they flickered.
    - Double water from above: the Terrain slab is 16 studs thick with WaterTransparency
      0.25, so its bottom face no longer shows through.
    - The 5-zone bar is gone. A big zone banner (icon, name, depth range) pops in on entering
      a zone (`HUDController.zoneBanner`).
    - Roll reel before salvage reveals (`RevealController.rollReel`): 26 tiles from the zone's
      real odds. Undiscovered relics are grey silhouettes that keep their rarity label. Tap
      to skip.
    - All checked in Studio play.
  - **Round 4:**
    - **Double water fixed properly.** Roblox draws a water slab's bottom face even at
      WaterTransparency 1. The Terrain water is now filled by each client
      (`WaterController.fillWater`): it is cleared while the camera is underwater (a flat
      ceiling part stands in) and refilled on surfacing. Each swap costs about 8 ms. The place
      has no other terrain (`CountCells` = 0); if you ever add some, change the `Terrain:Clear()`
      there.
    - **Chest opening** (`UI/RelicOpening`) replaces the tile reel, designed with the
      roblox-vfx skill's method:
      - A blocky chest drops in front of the camera, and the world dims.
      - Rarity tease: one step per tier (COMMON... RARE!!), seam colour, hop, pulse ring,
        rising shake and light leaks.
      - Release: suck-in and a dark beat, a 2-frame white flash, an FOV punch, the lid blasts
        off, rays, a shockwave ring, sparks and a fireball puff. Confetti for Epic+, a tinted
        whiteout and letterbox for Legendary+.
      - The relic rises out, then the reveal card plays. Tap to skip.
      - It uses stock textures only. The skill's generated texture library and upload route
        are not set up: no `LOCAL.md`, and they need an Open Cloud key.
  - **Round 5: A/B chest openings** (owner wants to compare two approaches):
    - Both share the chest, timeline, rarity words and relic rise in `UI/RelicOpening`
      (`opts.style`).
    - **A = "lihfolk":** LihFolk's ready-made ability VFX, vendored to
      `UI/Vendor/LihFolkVFX_Abilities.luau`:
      - `Buff` on each tease step
      - `Teleport` for the suck-in and burst
      - `LevelUp` for Epic+
      - its `CameraShake`
      - Its texture pack isn't on this PC, so it uses its built-in looks (warnings in the
        output are expected). Tested in Studio.
    - **B = "custom" (the default in real salvages):** our layers with 8 textures generated by the
      roblox-vfx skill and uploaded through the Studio MCP (`TEX` ids): streak sparks, stars,
      a flare flash, a shockwave flipbook, a tinted explosion flipbook, a charge-in flipbook,
      a ring pulse and a comic burst behind the rarity words. **Not seen in Studio yet:** the
      auto-mode check kept timing out on stop and play.
    - Dev panel, Relics tab, top section "Opening test": A/B x Common/Epic/Mythic.
    - **Round 5b (owner feedback: "switching back to my character is uncomfortable"):**
      - **Camera:** the opening no longer takes the camera. The chest stands in front of the
        diver on the camera side, faces the camera and follows them smoothly.
      - **Blur and HUD:** the world behind the chest is blurred (DepthOfField focused on the
        chest each frame) and the HUD is hidden during the show.
      - **Shake:** added on top of the player's camera (BindToRenderStep at Camera+1). FOV
        punch on the custom camera.
      - **Version B:** 6 more of our textures uploaded: focus lines, a spinning magic circle
        (glowing SurfaceGui) under the chest for Rare+, glitter round the rising relic, embers
        after the burst, a lens streak on the flash, and flipbook landing dust.
      - Verified in Studio: B tease and burst, A burst, the HUD, blur and camera restored, no
        errors.
      - Studio MCP quirk: an `execute_luau` that overlaps the intro fly-over makes the tool
        "restore" CameraType Scriptable. That's the tool, not the game.
    - roblox-vfx setup is in the skill's `LOCAL.md` (memory limits on this PC; how to build per
      family; how to upload).
    - **Round 6 (2026-11-16): summon-style opening** (reference: `docs/reference/chest_opening`):
      - **On the camera:** the chest is placed relative to the camera every frame
        (`stageTarget`: 7.5 studs out, centred at eye level, top tilted 16 degrees towards you).
        The camera is not changed (only the FOV punch and push-in). The diver and their name
        tag are hidden while they stand between the camera and the chest or just behind it.
      - **Reveal in the world:** after the burst the chest shrinks away. The relic pops out where
        it was (Back-eased scale, a fast spin that settles, a bob), inside a rarity bubble flash
        (a ForceField shell and a Neon core). Big sparkle stars pop at the screen edges.
      - **Hold:** a god-ray backdrop (rays plus a flare glow card) turns slowly behind the relic,
        and the FOV pushes in (up to 7 degrees). The magic circle stays on as the pad (B). Text:
        the name on top (outlined Fredoka, a line with diamond ends), the rarity word in its
        colour, chips (material, mutations, +Coins/s on display), and "(Click anywhere to
        continue)". **Nothing auto-closes:** a click, tap, gamepad A or Enter ends it (with a
        0.35 s grace). A tap during the tease still skips to the release.
      - The presentation is in the shared base, so A (lihfolk) and B (custom) both get it.
      - `RevealController` no longer shows the old full-screen card after a salvage opening; the
        next queued reveal plays after the click. Other sources still use the card.
      - In the opening only, the relic is built without its PointLight, and Neon parts larger
        than 1.6 studs become SmoothPlastic: at this size and distance they bloomed into a
        white blob (the Secret Nautilus).
      - **Checked in Studio play:** B Mythic and A Rare on the dock, B Common then Secret queued
        underwater, B Secret on the dock. The hold stayed up over a minute until a real click,
        then the cleanup was complete (blur, grade, HUD, FOV 70, folder, diver). No console
        errors. **Not checked:** phone sizes (long names use TextScaled, capped at 56 px), a
        wall right behind the camera, and gamepad A.
    - **Round 7 (2026-11-16): B kept, A removed; neon HUD buttons:**
      - The owner picked B. The LihFolk version A is gone: `opts.style`, the vendored
        `UI/Vendor/LihFolkVFX_Abilities.luau` and the A buttons. The Dev panel "Opening test"
        now has one button per rarity (Common, Rare, Epic, Legendary, Mythic, Secret).
      - New HUD buttons from the owner's reference clip (`docs/reference/hud_buttons`: the clip,
        14 frames at 3 fps, and a crop sheet). The design is the Figma component set `NeonTile`
        and the frame "HUD Rail — Neon (preview)" in "Abyss Salvage - Game Buttons". The code
        is `Kit.HudTile` (see `docs/UI_STYLE_GUIDE.md` section 8). The rail and the action
        buttons use it, with key letters (M, B, U; Q, G, R).
      - The Quests red dot is now the tile's badge ("!"). The flare count moved from the label
        to the badge.
      - Checked in Studio play: the rail and the actions render, the badges show, the opening
        still works, and no console errors. **Not checked:** hover in a real mouse session,
        phone sizes (key letters are hidden on touch-only devices), and the Up/Down tiles
        underwater.
    - **Round 8 (2026-11-16): glow fix, and clean Shop, Upgrades and Settings windows**
      (reference: `docs/reference/shop_upgrades`; Studio screenshots of the result in its
      `after/` folder):
      - **Icon glow fixed.** The HUD tiles had two see-through squares behind them and three
        hard discs behind the icon, which read as a second border and a bullseye. Glows are now
        many thin layers (`Kit.GlowLayers`); `Kit.Glow` uses the same method, so shop cards,
        offers, relic cards and the reveal are fixed too.
      - **New window look for every window** (`UIController.RegisterWindow`): a black panel
        with a glow in the window's colour, a slanted colour band over the top-left corner, a
        red X over the top-right corner, and a blurred world behind. The inside of the other
        windows (Bag, Codex, Quests and so on) is unchanged.
      - **Shop:** flat tabs, a dark well, gradient cards (`Kit.ShopCard`). Passes, Boosts,
        Crates and Pass+ use wide cards; Coins, Pearls and Event use small ones. The VIP banner
        became a VIP button in the title band. Same remotes and purchases as before.
      - **Upgrades:** gradient cards per track, the price along the bottom (green when you can
        pay), an "Upgrade!" tag, centred section names, and your coins in the title band.
      - **Settings:** a plain charcoal panel, rows with a title and a grey line, sliders for
        the two volumes (sent once, on release) and a green pill switch. The Diver window gets
        the same rows and switch.
      - The spec is section 9 of `docs/UI_STYLE_GUIDE.md`.
      - Figma: the frames "Shop — new (Passes)", "Shop — new (Coins)", "Upgrades — new" and
        "Settings — new" plus their components were created in "Abyss Salvage - Game Buttons",
        then the Figma MCP hit the Starter plan's tool-call limit, so they were never
        screenshotted or checked. The code is the source of truth.
      - **Checked in Studio play:** the Shop's Passes, Coins, Crates and Event tabs; an upgrade
        bought with dev coins (Oxygen Tank to Lv 2); a switch flipped and
        a slider dragged in Settings, both kept after closing and reopening; the Quests, Dev
        and Diver windows in the new chrome (the Diver rows and switches too); no console
        errors. **Not checked:** phone sizes, the Boosts, Pearls and Pass+ tabs, an owned pass
        card, a real Robux purchase prompt, and gamepad. StyLua and Selene are not installed on
        this PC, so the new code is not formatted or linted.
  - **Not checked:**
    - the Kelp to Trench guardians up close
    - the material look on stands
    - the Auto Refill purchase itself (no pass ID)
    - phone layout

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
