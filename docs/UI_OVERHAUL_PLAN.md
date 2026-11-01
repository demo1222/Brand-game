# UI & Visual Overhaul Plan

Goal: make Abyss Salvage *look* like a collecting game. Relics are the star of the game, but
today they only exist as text rows in menus and as a single grey primitive on the dock. Every
screen is a vertical list of labels and flat buttons.

## Constraint: no uploaded art (yet)

Roblox images need uploaded asset IDs, and the repo has none. So the overhaul is built from
things that render with **zero assets**:

| Need | Asset-free technique |
|---|---|
| Item "photos" | Procedural low-poly relic models (`shared/RelicArt`) rendered live in `ViewportFrame`s (`client/UI/RelicView`) |
| Icons | Colour emoji inside gradient "badge" circles (`client/UI/Icons`, `Kit.IconBadge`) |
| Depth & polish | `UIGradient`, `UIStroke`, layered glow circles, animated shine sweeps, sunburst rays |
| Game feel | Press/hover scale on every button, pop-in windows, dimmed backdrop |

Every icon goes through `Icons.lua`'s `Images` table first. When real icon art is uploaded, put
the `rbxassetid://` there and the UI switches from emoji to the image with no other changes.

## Phase 1 — Foundation + item visuals (this change)

1. **`shared/RelicArt`**: one recognisable model per relic (anchor, bottle, bell, chest,
   helmet, skull, crown, harp, …). There are 51 archetypes with per-relic palettes, and
   mutations recolour and re-material the main body. Server and client share the module, so the
   **dock stands and the thief's carried relic show the same model as the menus**.
2. **`client/UI/RelicView`**: a ViewportFrame widget with an auto-framed camera, an optional
   slow orbit and silhouette mode (for undiscovered Codex entries). It caches one template model
   per relic and mutation.
3. **`Kit` v2**: gradient buttons with press animation, gradient panels, icon badges, pills,
   tabs, shine, glow and rarity-gradient cards. Existing screens pick up the new look
   automatically.
4. **Window chrome**: a dim backdrop (tap to close), a header with an icon badge and a display
   font, and a round close button.
5. **Inventory (Bag & Dock)**: a card grid with a 3D render, a rarity gradient, mutation dots,
   HUGE/lock badges and income, plus a **detail panel** with a big spinning model, lore, stats
   and actions. Tabs: Bag / Storage / Display. Sort: value / rarity.
6. **Codex**: a grid of 3D cards. Undiscovered relics show as black silhouettes. Zone tabs are
   coloured by zone, with a completion progress bar.
7. **Reveal**: a full-screen moment with rotating rarity rays, layered glow, a spinning model,
   mutation chips and a "tap to continue" hint.
8. **HUD**: currency pills with icon badges, labelled menu tiles, a styled depth meter, an
   O₂ bar with a gradient and icon, and round action buttons.
9. **Shop**: tile grid with big icon badges, a gradient VIP banner with shine, and styled tabs.
10. **Upgrades**: cards with icon badges and level progress bars, plus a 3D helmet preview
    in the suit's colour.
11. Fix the Lune test harness (it yielded inside a metamethod and crashed on Lune 0.8.9), and
    add RelicArt coverage tests.

## Phase 2 — World & feedback (done)

- **Loot nodes:** a sand mound with a glinting gold edge, a gem and sparkles replaces the neon
  ball. Every node looks the same, so the look leaks nothing about the server-side roll. After
  a sonar ping, the node's sparkles burst in the pinged rarity's colour.
- **Sonar:** an expanding pulse around the diver, and markers restyled as rounded rarity
  chips with a pointer.
- **Dock displays** (`FXController`, client-only): relics on stands bob and spin, and stands get
  a rarity-coloured glow ring. Legendary+ relics get sparkles and Mythic+ a light pillar.
  Animation is limited to 60 stands within 110 studs and runs at 30 Hz.
- **Coin feedback (§18.3):** a floating "+1.24K" with a caption, and coins that fly into the HUD
  coin badge. Used for collecting, selling, Sell Commons and the offline claim (`CoinBurst`
  remote).
- **Quests:** a 7-day login calendar of reward tiles, and quest cards with progress bars and
  reward pills.
- **Tide Pass:** a horizontal free/premium reward track that scrolls to your tier. Previews use
  `Formulas.TierReward`, now shared with the server.
- **Rebirth:** NOW → AFTER comparison cards, a requirements progress bar, keep/reset
  summary and a talent tree with level pips.
- **Leaderboards:** board tabs, a podium for the top 3 and ranked rows below.
- **Players:** avatar headshots (`rbxthumb://`, no upload needed).
- **Trade:** both offers side by side as relic cards with ready states, and a card grid
  picker for your storage.
- **Popups:** offers, confirms, death, robbed and offline popups have a dim backdrop, a hero
  icon badge and an accent glow.

## Phase 3 — Real art pass

- Replace emoji with an uploaded icon set (fill `Icons.Images`).
- Replace procedural relics with modelled meshes. Keep `RelicArt.Build` as the single entry
  point, so only that module changes.
- 9-slice frames, custom font (`Font.new` with an uploaded family), sounds for UI clicks.

## Verification

This was written without Roblox Studio. `lune run tests/run` checks that every relic has art and
every archetype exists, and `rojo build` checks the project. The first Studio session should check:
viewport framing per archetype, mobile layout at 1334×750 and 800×360, and frame time with the
Bag window open on a low-end device.
