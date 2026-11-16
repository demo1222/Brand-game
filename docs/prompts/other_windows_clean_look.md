# Prompt: bring the clean look to the inside of the other windows

Copy everything below the line into the other model. Use it only when I say I want this task.

---

You are working on **Abyss Salvage**, a Roblox game (Luau, Rojo). The repo is at
`C:\Users\Zarylbek\Documents\GitHub\Brand game`. In Round 8 the Shop, Upgrades and Settings
windows were rebuilt in a clean style from my reference clip, and every window got the new
frame (black panel, colour glow, slanted title band). The **inside** of the other windows still
uses the older navy cards. I want them to match.

## Read first

1. `CLAUDE.md`: code lives only in `src/`, Rojo syncs it into Studio, never edit synced scripts
   in Studio.
2. `docs/HANDOFF.md`, especially "Start of the next session": how I work, the Studio shortcuts,
   and what is still unconfirmed.
3. `docs/UI_STYLE_GUIDE.md` **section 9**: the clean look and the Kit pieces to reuse.
4. Look at `docs/reference/shop_upgrades/after/` (the finished Shop, Upgrades and Settings) and
   `docs/reference/shop_upgrades/crops/` (the reference). Match those.

## Work lean

The last session used too much of my usage limit.

- **No Figma.** Its tool-call limit is used up.
- **One window at a time.** Show me one Studio screenshot of it and wait for my OK before the
  next window.
- Take a screenshot only of what changed. Check values with `execute_luau` when you can.
- Don't re-read files you already read. Don't re-extract the reference video.

## What to change

Order (ask me if I want a different one): **Bag & Dock, Codex, Quests & Tide Pass, Resurface,
Leaderboards, Players, Trade, Diver, Suit Shop**, then the pop-ups in `OfferController`.

For each window, in `src/client/Controllers/MenuController.luau` (Suit Shop is
`SuitShopController.luau`):

- Put lists and grids in a `Kit.Well` (see `wellScroll` in MenuController).
- Replace `Kit.GameCard` / `Kit.Card` slabs with `Kit.NeonCard` in the item's colour, or with
  dark rows in the `Kit.SettingRow` style for plain rows.
- Replace `Kit.Tabs` with `Kit.FlatTabs`.
- Replace left-aligned `Kit.Header` labels with `Kit.SectionTitle`.
- Prices and big numbers: `Kit.Text`, green when you can pay (`Kit.Clean.Go`), grey when not
  (`Kit.Clean.Off`), gold for done.
- Icons: `Kit.IconFill`, with a `Kit.Glow` behind big ones.
- Relic cards (`src/client/UI/RelicCard.luau`) already use rarity-coloured slabs. Ask me before
  changing them.

## Rules

- **Visual change only.** Keep every remote, state key and purchase exactly as it is.
- A window that refreshes every second must not rebuild unless something visible changed (use
  a signature, as `renderUpgrades` and `renderBag` do).
- Never rotate anything inside a ScrollingFrame: rotated objects ignore its clipping.
- No emoji or special glyphs. Touch targets at least 44 px. It must fit a phone (about
  800x360).
- A glow is many thin layers (`Kit.Glow`, `Kit.GlowLayers`), never a few big discs.
- A PostToolUse hook checks every edit. It flags `FindFirstChild(...)` results that are indexed
  straight away: store the result and check it.

## Check it in Roblox Studio

- Stop play, `script_grep` a new line to be sure Rojo synced it, start play, wait about 16 s for
  the intro.
- Open the window by its HUD button path (listed in `docs/HANDOFF.md`), take one screenshot,
  click through its buttons, and read `get_console_output` for errors.

## Done means

- The window matches the clean look in Studio, with no console errors, and I said OK.
- A short note under "Round 9" in `docs/NEXT_SESSION.md` and an update to `docs/HANDOFF.md`.
- **Don't commit and don't upload assets to my Roblox account without asking me first.**
