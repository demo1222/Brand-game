# Prompt: redesign the Settings and Shop windows from a reference video

Copy everything below the line into the other model, and attach the reference video(s).

---

You are working on **Abyss Salvage**, a Roblox game (Luau, Rojo). The repo is at
`C:\Users\Zarylbek\Documents\GitHub\Brand game`. I'm attaching a screen recording from another
Roblox game. I want my **Settings** window and my **Shop** window to look and feel like the ones
in the video. Copy the style, the layout ideas and the motion, not the other game's art, names
or logos.

## Read first

1. `CLAUDE.md`: code lives only in `src/`, Rojo syncs it into Studio, and you never edit synced
   scripts in Studio.
2. `docs/HANDOFF.md`: how I work, what I like and dislike, and the tools on this PC.
3. `docs/UI_STYLE_GUIDE.md`: the UI contract. Section 8 is the button kit. Windows **never
   close on a click outside**; they close only through the X, gamepad B or their own buttons,
   and they pop in and pop out.

## Step 1: study the video

- Extract frames at 3 fps: `python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())"`
  gives an ffmpeg binary. Save the clip and frames in `docs/reference/<name>/`, as
  `docs/reference/hud_buttons/` does.
- Write down, per window:
  - the panel: its colour, corner radius, border, shadow, and the title bar
  - the close button
  - section headers, and the rows: height, padding, a title plus a small grey line under it
  - the controls: toggles (on and off colours, the knob), sliders (track, fill, knob), and
    buttons
  - shop cards: the layout, the price buttons, tags, tabs and the currency display
  - the motion: open, close, toggle flip, slider drag, hover and press
- What I already saw in my first clip (Settings): a dark charcoal panel over a blurred game,
  the bold white title "Settings" top left, and a square red X button with a white cross.
  Centred section headers (Trading, Pets, Sound). Rounded darker rows with a white bold title
  and a small grey description. Green pill toggles with a white knob (grey and red when off).
  Sliders with a white round knob on a dark track. A thin scroll bar on the right.

## Step 2: design in Figma first

- Use the Figma MCP. My file is "Abyss Salvage - Game Buttons":
  https://www.figma.com/design/zFdUG7hvixMW2FDAeloS0b. Load the `figma-use` skill (via
  `get_figma_skill`) and call `create_session` before `use_figma`.
- Add a page or frames: "Settings — new" and "Shop — new". Build the reusable pieces as
  components: Window chrome, Section header, Setting row, Toggle (On/Off), Slider, Shop card,
  Price button and Tab.
- Reuse what's there: `NeonTile` (my HUD buttons), `ActionButton` (price buttons) and
  `Readout` (currencies). Font: Fredoka One.
- Show me a screenshot of the frames, and wait for my OK before you code.
- If Figma's limit runs out, skip Figma and build it carefully in code instead.

## Step 3: build it in Luau

- Settings: `src/client/Controllers/MenuController.luau`, `settingRow` (around line 2538),
  `renderSettings` (around line 2599), and the window registration
  `UI.RegisterWindow("Settings", ...)` (around line 2998). The Diver window also uses
  `settingRow` with `reserve = 112`; keep that working.
- Shop: `src/client/Controllers/ShopController.luau` (`build`, `render`, `OpenTab`). The Suit Shop
  (`SuitShopController.luau`) is a separate window; leave it unless I ask.
- Window chrome is in `src/client/Controllers/UIController.luau` (`RegisterWindow`). Building
  blocks are in `src/client/UI/Kit.luau`: `Kit.HudTile`, `Kit.ActionButton`, `Kit.Readout`,
  `Kit.Tabs`, `Kit.Pill`, `Kit.Pop` and `Kit.PopOut`.
- Put new reusable pieces in `Kit` (for example `Kit.Toggle`, `Kit.Slider`, `Kit.SettingRow`,
  `Kit.ShopCard`) so other windows can use them.
- Keep every setting and purchase working exactly as now: the same remotes, the same state
  keys, and the same `MarketplaceService` calls. This is a visual change only.
- Rules:
  - no emoji or special glyphs (they render as boxes); draw shapes with Frames or use `UI/Icon`
    and `Icons.Get`
  - mobile-first: touch targets at least 44 px, and it must fit on phones (about 800x360) and
    desktop
  - a window that refreshes every second must not rebuild unless something visible changed
    (use a signature, as `renderUpgrades` does)

## Step 4: check it in Roblox Studio

- Use the Roblox Studio MCP. Stop play, grep the synced script for a new line
  (`script_grep`) to be sure Rojo picked it up, then start play and wait about 14 s for the
  intro fly-over.
- Open each window and take a `screen_capture`. Click with `user_mouse_input`; scripts can't
  send clicks. Flip a toggle, drag a slider, buy something with the dev panel's coins, and
  check the console (`get_console_output`) for errors.
- Compare with the video frames side by side, and fix what's off.

## Done means

- Settings and Shop look like the video's style in Studio, at desktop and phone size.
- Every setting and purchase still works. There are no console errors.
- The Figma file has the matching frames and components.
- A short "Round 8" note in `docs/NEXT_SESSION.md` and an update to `docs/HANDOFF.md`.
- **Don't commit and don't upload assets to my Roblox account without asking me first.**
