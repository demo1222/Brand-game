# Next session: Round 9b (written 2026-11-16, owner's usage limit was at 4%)

Read `CLAUDE.md`, then `docs/HANDOFF.md` ("Start of the next session" and the Studio shortcuts),
then this file. Work lean: no Figma, one Studio screenshot per change, ask before committing or
uploading assets. Nothing is committed yet (branch `relic-art-pass`).

## Done in Round 9 (this session, all checked in Studio, owner said OK)

The brief `docs/prompts/other_windows_clean_look.md` was followed window by window, all in
`src/client/Controllers/MenuController.luau`:

- **Inventory** (was "Bag & Dock"; window id is still `Bag`, the HUD tile still says Bag):
  - Two tabs: Inventory (the dive bag, lost on death) and Storage. The Dock tab is merged into
    Storage: stand and vault relics come first with a green tick (`equippedTick`).
  - Full-width grid in a `Kit.Well`, no side panel.
  - Tapping a card opens a small pop-up beside it (`relicPopup`, shared with the Codex): name,
    rarity, coins/s, sell price, a gold View button (opens `RelicViewer`), and coloured action
    buttons (Display, Vault, Lock, Sell, Take, Clean).
  - Top right: Equip Best (blue, Storage only), Sort (green), Sell Commons (red).
  - **Equip Best** (`equipBest`): puts the highest coins/s relics from stands and storage on the
    stands. Client only, through the existing `RequestPlaceRelic` (a place on a taken stand
    swaps it back to storage), one call every 0.35 s for the dock rate limit (8, 3/s).
- **Codex:** flat zone tabs, a dark progress row, a full-width grid in a well, and the same
  pop-up (undiscovered: "???", where to search, a grey "Find it to view").
- **Quests & Tide Pass:** reward tiles are `Kit.NeonCard`s (Claim! / tick / lock), quest rows
  are dark rows (gold neon card when claimable), centred section titles, gold and blue buttons.
  It now rebuilds only when its data changes (`questSig`, JSON of the shown state).
- **Resurface:** neon Now/After cards, a dark requirements row, an `ActionButton` Resurface
  (grey with a lock until ready), word chips for You Keep / Resets, and talent neon cards.

Not done from the brief: Leaderboards, Players, Trade, Diver, Suit Shop, `OfferController`
pop-ups. No Round 9 note in `docs/NEXT_SESSION.md` or `docs/HANDOFF.md` yet: add one.

## What the owner wants next (in their words, then what it means)

> "i wanna remove rebirth system, leaderboard button and move settings on the side and make it
> small setting button instead. Right now i wanna increase modal ui and inspection a little bit"

Do these one at a time, with one screenshot each, and wait for an OK in between.

1. **Make the windows ("modal UI") a little bigger.** See `UIController.RegisterWindow`
   (`opts.MaxSize` and the default size). Check that it still fits a phone (about 800x360).
2. **Make the inspection a little bigger.** Most likely the relic pop-up (`relicPopup`, width
   `W = 236`, text sizes) and maybe the full-screen `RelicViewer` (stage is 0.62 of the screen).
   Ask which one if unsure.
3. **Remove the rebirth (Resurface) system.** Ask first how far to go:
   - just hide the HUD tile and the window, or
   - also remove `RebirthService`, `Net.RequestRebirth` / `RequestTalent`, the talents, and
     the rebirth parts of `Formulas` / `Economy` / `DataService` (saved data keeps `Rebirths`,
     `RebirthTokens`, `Talents`: leave the fields so old saves still load), plus the
     `AbyssSalvage_LB_Rebirths` leaderboard, the Suit Shop and Upgrades text that mentions
     rebirth, and `tests/run.luau`.
   The suit economy (`docs/ECONOMY.md`) ends at "rebirth at Pressure Mk II plus 100M": ask what
   the end goal becomes.
4. **Remove the Leaderboards HUD button** (`HUDController` rail: `RAIL_KEYS`, `RAIL_COLORS`).
   Ask whether the window and `LeaderboardService` stay (for example, reachable elsewhere).
5. **Settings becomes a small button on the side** instead of a rail tile. A small
   round or square neon button (`Kit.HudTile` look, smaller), placed at the screen edge away from
   the rail. Keep the key letter if the tile had one.

After removing tiles, the rail has fewer buttons: check that it still lines up.
