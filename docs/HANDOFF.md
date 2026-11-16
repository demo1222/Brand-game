# Hand-off: everything from the 2026-11-15/16 sessions

Read this before starting a new session on Abyss Salvage. It holds what was built, how the tools
are set up, what the owner likes and dislikes, what is still open, and the next task in full.
More detail per round is in `docs/NEXT_SESSION.md` (the "World and economy round" through
"Round 8" entries) and `docs/ECONOMY.md`. Last updated after Round 8 (2026-11-16).

## 1. How the owner works

- **They judge by screenshots from Roblox Studio.** Show the result in Studio, not just code.
- **They want chunky, colourful game UI** (see `docs/UI_STYLE_GUIDE.md`). Never website-like.
- **They talk in short simple sentences.** Caveman mode was on for the last part of the session.
- **Ask before:**
  - uploading assets to their Roblox account
  - committing
  - anything they did not ask for
- **Things they disliked:**
  - the camera being taken over and then switching back to the character ("really uncomfortable")
  - flickering light shafts
  - double water
  - floating props
  - the ghost thief
  - the zone bar
  - the starter guide (switched off for now)
  - small differences between suits
  - cheap upgrades
- **Things they liked:**
  - the Terrain water and waves
  - the dock as a dive station
  - the blocky Blender models
  - the chest opening with the rarity tease
  - the background blur
  - the comic pops behind the rarity words
  - the magic circle
  - the A/B comparison idea, and then **version B** of the opening ("b is awesome", A removed)
  - the neon HUD buttons of another game's reference clip (asked for the same look; done in
    Round 7)
  - the "very clean" shop, inventory and settings windows of the same game (asked for the
    same look; done in Round 8)
- **Things they disliked (Round 8):** the first icon glow ("looks very strange": hard discs
  and squares), and the old Shop and Upgrades design ("looks very bad")

## 2. Project rules (from `CLAUDE.md`)

- **Code only in `src/`.** Rojo syncs it into Studio. Never edit synced scripts in Studio.
- **Visuals can be tuned in Studio through the Studio MCP.** Keeper visuals (dock, diving board,
  sea) live as rebuild code in `src/`.
- **No emoji, no special glyphs** (▼ ▲ and similar render as boxes). Draw shapes with Frames, or
  use `UI/Icon` or `Kit`.
- **Nothing is committed yet.** All the work below is uncommitted on branch `relic-art-pass`.

## 3. What was built (by area)

| Area | Where | Notes |
|---|---|---|
| Sea | `WorldService.buildOcean`, `client/Controllers/WaterController.luau` | Terrain water slab (16 studs, WaterTransparency 0.25) filled **on each client**. It is cleared while the camera is underwater (a flat ceiling part stands in) and refilled on surfacing: Roblox draws a water slab's bottom face even at transparency 1, which was the "double water". Each swap is about 8 ms. Also: ripples round dock posts, bobbing buoys (tag `Bob`), sun glints, and the default swim and splash sounds muted. Light shafts are off (`SHAFTS = 0`). The place has no other terrain; `Terrain:Clear()` assumes that. |
| Reef props | `WorldService` `PROPS`, `meshProp`, `placeProp`, `clearOfProps` | Blender models from `ReplicatedStorage.WorldMeshes` (saved in the place) when present, else code-built. `meshProp` re-centres imported pivots (the bundle's slot offsets made props float). Relics never spawn inside props. Spire tops are stepped plateaus. |
| Relic nodes | `LootService.markNode` | A light pillar plus a diamond marker that shows through coral (110 studs). Guarded nodes are red. Node lights are dimmed. |
| Dock | `WorldService.buildDiveStation`, `buildSuitStall` | Entrance arch with the name sign up high, rope rails, lamps, the tank rack (`AirRefillPrompt`), compressor, flag, life ring, dinghy, buoys and crates. The Suit Shop stall has bulbs and a floor pad (tag `SuitShopDisc`) that opens the shop. |
| Air | `DiveService.RefillAtRack`, `Config/Passes.AutoRefill` | The surface no longer refills the tank: use the rack, or the Auto Refill pass (49 R$; **its `id` is still 0**). |
| Suits and economy | `Config/Upgrades.luau`, `Formulas.SuitIncome/SuitLuck`, `docs/ECONOMY.md` | 16 suits with Income and Luck perks, steeper costs, rebirth at Pressure Mk II plus 100M. Data v4 remaps old suit indices. |
| Suit Shop | `SuitShopController` | A plain grey mannequin, a TRY ON button, and coins and luck perks in gold. |
| Relic materials | `Config/Materials.luau` | Gold x3, Emerald x6, Diamond x12, Rainbow x30, plus size tiers. Shown on cards, the reveal, the stand hover card, the stand model and announcements. |
| Zone guardians | `Config/Monsters`, `GuardianService`, `GuardianController`, `shared/MonsterArt` | One per zone: Reef Shark, Kelp Barracuda, Wreck Shark, Abyss Angler, Magma Serpent. Each guards a lair of red luck-boosted nodes and runs patrol, chase, wind-up, lunge, bite. Flares scare them. Four use Blender models; the serpent is code-built. |
| Blender pipeline | `tools/blender/world_builds.py`, `run_world.py`, `Config/WorldMeshes.luau` | Builds the monsters, corals, kelp and rack into `models/monsters`, `models/world` and their bundles. The owner imported them with Import 3D; the models live in `ReplicatedStorage.WorldMeshes` (save the place!). `WorldMeshes.Paint` colours by role, since the importer drops colours. |
| HUD | `HUDController.zoneBanner` | The 5-zone bar is removed. A big zone banner (icon, name, depth range) pops in when you enter a zone. |
| Starter guide | `TutorialController.ENABLED = false` | Off at the owner's request. |
| Chest opening | `client/UI/RelicOpening.luau` | Round 6: summon style on the player's own camera, in-world reveal, hold until a click. Round 7: only our own effects (B) are left. See section 5. |
| HUD buttons | `Kit.HudTile`, `HUDController` (`RAIL_COLORS`, `RAIL_KEYS`) | Round 7: neon tiles (dark tinted tile, glowing border in its colour, key letter, red badge via `Kit.HudTileBadge`). Figma `NeonTile`. Round 8: the glow is many thin layers (`Kit.GlowLayers`), not discs and squares. |
| Windows | `UIController.RegisterWindow`, `Kit.SlantBand`, `Kit.NeonCard`, `Kit.ShopCard`, `Kit.FlatTabs`, `Kit.SettingRow`, `Kit.Toggle`, `Kit.Slider` | Round 8: the clean look for every window (black panel, colour glow, slanted band, blurred world). Shop, Upgrades and Settings are rebuilt inside too. Spec: `docs/UI_STYLE_GUIDE.md` section 9. |

## 4. Tools and how they are set up

- **Roblox Studio MCP:**
  - `execute_luau`, `screen_capture`, `start_stop_play`, `upload_image` (uploads as the owner's
    Studio login, no API key).
  - The intro fly-over runs about 10 s after Play: wait for it before testing, or the MCP tool
    may "restore" CameraType Scriptable.
  - Restart play to load client changes. Grep the synced script in the Edit datamodel to confirm
    Rojo picked a change up.
  - The auto-mode safety check sometimes times out on `start_stop_play`. Retry once, then move on.
- **Blender MCP:** connected. `tools/blender/blocky_kit.py` is the shared kit (boxes, square
  tubes, pixel lathes, preview, glb export). Monsters face +Y in Blender, which becomes Roblox -Z
  after the glTF export plus the Studio import; `MonsterArt` turns imported templates 180
  degrees.
- **roblox-vfx skill:** `.claude/skills/roblox-vfx/`. Read its `LOCAL.md`.
  - Base textures, magic circles, painted textures and all its meshes are built. The 2,570-texture
    library is only partly built.
  - Build per family, with few workers:
    `OPENBLAS_NUM_THREADS=1 python build_library.py --procs 4 --limit 3 --families <names>` in
    `sim/tex/lib` (it ran out of memory with many workers before).
  - Built families:
    - sprites: ring, starburst, flare, streak, star, comic_burst, speed_lines, sigil, anamorphic,
      bokeh
    - flipbooks: sparks, explosion, shockwave, charge_in, magic_poof, sigil_spin, twinkle,
      embers_rise, smoke_puff_fb, dust_ground
  - Upload: run `python sim/serve.py 8765`, then the Studio MCP `upload_image` with
    `http://127.0.0.1:8765/textures/lib/<path>`. **Ask the owner first.**
  - The 14 ids uploaded so far are in `TEX` in `RelicOpening.luau`.
  - Node.js is not installed (needed only for the skill's `studio_kit.js`).
- **LihFolk plugin:** skills `lihfolk:lihfolk` (a knowledge vault) and `lihfolk:lihfolk-vfx`
  (ready-made VFX). Its ability module was vendored for opening version A; **A and the vendored
  module were removed in Round 7** (the owner chose B). A PostToolUse hook runs a LihFolk Luau
  check on every edit; it flags things like `FindFirstChild(...)` chains.
- **Figma MCP:** file "Abyss Salvage - Game Buttons" (https://www.figma.com/design/zFdUG7hvixMW2FDAeloS0b),
  one page "Buttons": `HudTile` (old grey), `NeonTile` (8 colour variants, the current look),
  `ActionButton`, `Readout`, icon components, and the frame "HUD Rail — Neon (preview)". Load
  the `figma-use` skill (`get_figma_skill skill://figma/figma-use/SKILL.md`) and `create_session`
  before `use_figma`. Fredoka One is available there. The file is on the Starter plan, whose
  MCP tool-call limit is small: Round 8 ran out after about seven calls. Round 8 added
  `WinIcon/*`, `Win/Tab`, `Win/Close`, `Shop/CardSmall`, `Shop/CardWide`, `Upgrade/Card`,
  `Settings/Row`, `Settings/Toggle On/Off` and four "— new" window frames (not yet looked at).
- **Clicks in play tests:** scripts can't send input (`VirtualInputManager` needs a higher
  capability). Use the Studio MCP `user_mouse_input` (Client) for a real click. To fire a reveal
  from the server use `ReplicatedStorage.Remotes.RevealRelic:FireClient(player, relic, "Salvage")`;
  requiring `Shared.Net` from the MCP server context fails ("Net used before Net.Setup()").
- **Python:** 3.14, with numpy, scipy, Pillow and imageio-ffmpeg installed. For an ffmpeg binary:
  `python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())"`.
- **Lune:** not installed. `aftman install` needs the owner to trust the tools. Unit tests were
  run inside Studio instead; `tests/run.luau` is updated.

## 5. Done in the last session (Rounds 6 and 7) and what's next

### Round 6: the summon-style opening (done, checked in Studio)

- Reference: `docs/reference/chest_opening` (sheet, clip, frames).
- `RelicOpening.Play(relic, { onDone, play })`. The chest is placed on the camera every frame
  (`stageTarget`: 7.5 studs out, eye level, top tilted 16 degrees towards you). No CameraType
  change; only an FOV punch at the burst and a slow push-in (up to 7 degrees) during the hold.
- The diver and their name tag are hidden while they would show round the chest
  (`diverInTheWay`, `hideDiver`).
- After the burst the chest shrinks away and the relic pops out where it was, inside a rarity
  bubble flash (ForceField shell plus Neon core), with big sparkle stars at the screen edges.
- Hold: god rays and a flare glow card behind the relic, and the magic circle as the pad.
  - The text: the name on top, a line with diamond ends, the rarity word in its colour, chips
    (material, mutations, +Coins/s on display), and "(Click anywhere to continue)".
  - Nothing auto-closes. A click, tap, gamepad A or Enter ends it, after a 0.35 s grace.
- `RevealController` skips the old full-screen card after a salvage opening; queued reveals play
  one after another, each after a click.
- Inside the opening only: the relic is built without its PointLight, and Neon parts larger than
  1.6 studs become SmoothPlastic, because they bloomed into a white blob (the Secret Nautilus).

### Round 7 (done, checked in Studio)

- The owner liked B. Version A (LihFolk) is removed. The Dev panel "Opening test" has one button
  per rarity.
- Neon HUD buttons from the owner's reference clip (`docs/reference/hud_buttons`: the clip, 14
  frames at 3 fps in `frames/` and `crops/`, and `buttons_sheet.png`).
  - Designed in Figma first (`NeonTile`, plus the rail preview), then built in `Kit.HudTile`.
    The spec is in `docs/UI_STYLE_GUIDE.md` section 8.
  - What the reference does: a dark square tile, a thick glowing border in the icon's colour
    (some borders are gradients), a big icon, a white outlined label over its bottom, a key
    letter at the top right, a red number badge at the top left, and a tilted "New!" tag.

### Round 7b (done, checked in Studio)

- "Icons a little off from center": the PNGs are centred to within 1%, but their art fills the
  image differently (the 147-pack about 59%, the generated icons 70-94%). So icons showed at
  different sizes and sat high. `Icons.ArtBox` (measured with Pillow from
  `docs/images/icons/**`) now lets `Kit.HudTile` size every icon to the same visible art
  (66% of the tile) and centre the art.
- "Icons from the reference have a small glow": a soft round glow in the tile's colour
  (three stacked discs) sits behind each icon and brightens on hover. The flare texture was
  tried first but was too faint at HUD size.
- The owner wants Settings and Shop like the reference too. The prompt is
  `docs/prompts/settings_and_shop_redesign.md`; done in Round 8.

### Round 8 (done, checked in Studio)

- Reference: `docs/reference/shop_upgrades` (the clip, 64 frames at 3 fps, contact sheets,
  crops, and `after/` with Studio screenshots of the result).
- **Icon glow:** "our icons have a glowing effect but it looks very strange". The cause: two
  see-through squares behind each tile and three hard discs behind the icon. Now a smooth
  halo and a soft light (`Kit.GlowLayers`). `Kit.Glow` got the same fix, which also cleans up
  shop cards, offers and relic cards.
- **Windows:** new chrome for all of them; Shop, Upgrades and Settings rebuilt inside. See
  the "Round 8" entry in `docs/NEXT_SESSION.md` and section 9 of the style guide.
- **Choices the owner has not confirmed yet:**
  - The big VIP banner in the Shop became a VIP button in the title band.
  - Every window got the new chrome, but the inside of Bag, Codex, Quests, Rebirth,
    Leaderboards, Players, Trade, Diver and the Suit Shop still has the older navy cards.
- **Figma:** the mock frames and components exist in the file but were never looked at; the
  MCP hit the Starter plan's tool-call limit straight after creating them.

### Start of the next session (read this first)

The owner stopped Round 8 here to switch models: the session used too much of their usage
limit. **Work lean:** no Figma, few screenshots, small edits, and ask before a big task.

1. **Ask the owner what they think of Round 8.** They have seen the screenshots in
   `docs/reference/shop_upgrades/after/` but have not said yet whether they like the new Shop,
   Upgrades and Settings, the VIP button in the title band, or the glow.
2. **Do not start the other windows yet.** The owner said "dont do it yet" to restyling the
   inside of Bag, Codex, Quests and the rest. The brief for that task, for when they say go, is
   `docs/prompts/other_windows_clean_look.md`.
3. Nothing is committed. Ask before committing.

Things that save time in Studio (learned in Round 8):

- **Click by path, not by pixel:** `user_mouse_input` with `instance_path`.
  - HUD buttons: `LocalPlayer.PlayerGui.AbyssHUD.Rail.Frame.<Shop|Bag|Upgrades|Codex|Quests|Rebirth|Leaderboards|Players|Settings>`
  - A window's X: `LocalPlayer.PlayerGui.AbyssWindows.<Window>.GameButton.Face`
  - A Shop tab: `LocalPlayer.PlayerGui.AbyssWindows.Shop.Body.ScrollingFrame.Tabs.<Passes|Boosts|Coins|Pearls|Crates|Pass+|Event>`
  - An upgrade card: `...AbyssWindows.Upgrades.Body.Well.ScrollingFrame.Frame.<TrackId>.Card`
  - Dev coins: `...AbyssHUD.DevButton.Face`, then the Money tab, then
    `...AbyssWindows.Dev.Body.Currency.Frame.TextButton` (+1M Coins).
- **Wait for the intro** with two `wait` actions (9 s and 7 s) at the start of the same
  `user_mouse_input` call that does the first click.
- **A click by x and y uses GUI space:** the screenshot's y minus 58.
- **`script_grep` takes a Luau pattern:** escape `(` and `)` with `%`, or search plain words.
- **The Starter Pack offer** can pop up the first time the Shop opens. Click "No thanks".
- **To replace a long function,** write the new text to a scratch file and splice it in with a
  short Python script. The source files use CRLF line endings.
- **Check a window's state without a screenshot:** read labels with `execute_luau` on the
  Client (for example the `%` readouts in Settings).

### Ideas for the next task (ask the owner which)

- Bring the clean card look to the inside of the other windows (Bag, Codex, Quests, Rebirth,
  Leaderboards, Players, Trade, Diver, Suit Shop) and the offer pop-ups.
- Bring the neon look to the rest of the HUD: the currency readouts, the oxygen bar, the bag
  count, and the event cards (top right).
- Phone check of the new windows, the HUD and the opening.
- The open items in section 6.

## 6. Still open (not the next task)

- **Owner:**
  - **Save the place in Studio:** `ReplicatedStorage.WorldMeshes` holds the Blender models and
    their fixed pivots.
  - Create the Auto Refill game pass and paste its id into `Config/Passes.luau`.
  - Optionally run `aftman install` (trust: yes) for local Lune tests.
- **Not checked yet:**
  - the Kelp-to-Trench guardians up close
  - the material look on stands
  - the Auto Refill purchase
  - phone layouts (the new neon HUD and the opening's hold text too)
  - hover on the neon tiles with a real mouse, and the Up/Down tiles underwater
- **Ideas the owner raised for later:**
  - weapons for the diver (harpoon or knife) to fight the guardians
  - more Blender props for the Wrecks, Abyss and Trench zones
- **Known quirks:**
  - The client sees fewer relic nodes than the server holds, which suggests StreamingEnabled is
    on; check it.
  - The "Buy · 49 R$" text on offer pop-ups looks muddy (an existing style).
