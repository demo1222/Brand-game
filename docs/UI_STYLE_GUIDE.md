# UI style guide: how Abyss Salvage UI should look

The owner's references (Nov 2026) are a big-studio Roblox look: chunky, bright and outlined, with
everything pressable. Three screenshots define it:

- **Throw Power widget**: the model for buttons and layout. A compact dark panel. A header row
  with an icon, a title and coloured values, and a red X. A dark slider well. A footer row with
  info on the left and one bright action button on the right.
- **Animal Index**: the model for windows. A gradient title band with diagonal stripes, a white
  outlined title and a red X. Icon tabs, a dark content well, and cards filled with their rarity
  colour.
- **Food Shop**: the model for shops. A horizontal row of tall cards: big name, rarity line, the
  3D item, a tier plate and a price button. The equipped card glows green.

Kit v4 (`src/client/UI/Kit.luau`) implements most of this. When in doubt, copy what this page
says, not what an older screen does.

## 1. Rules

1. **Outline everything.** Every panel, card, button, bar and title has a near-black outline
   (`T.Outline`):
   - windows: 4 px
   - cards and buttons: 2 px
   - text: 2 to 3 px stroke

   No thin coloured hairlines.
2. **Colour fills, not colour borders.** A rare card is a blue slab, not a dark card with a blue
   border. Use rarity, zone and category colours as the fill, lighter at the top and darker at
   the bottom.
3. **White text with a black stroke on any colour.** Use Fredoka (`T.Title`) for names, numbers
   and buttons, and Gotham Bold only for small body copy. Body text is at least 13 px; never use
   grey text smaller than that.
4. **Buttons are blocks.** A bright face, a lighter top, a darker lip (4 to 6 px) and a 2 px
   outline. Pressing it pushes the face down onto the lip. Use `Kit.GameButton`, `Kit.GameCard`
   or `Kit.Button`, never a flat `TextButton`.
5. **Icons are big and pop out.** Tab and bar icons overlap the edge of their pill, like the
   Animal Index book and the Throw Power arm. No emoji: they render as boxes.
6. **Content sits in a well.** Inside a window, lists and grids sit in a darker, rounded,
   outlined well (`T.PanelDark`), not straight on the window body.
7. **One primary action per row**, bottom-right, in the action colour. Info goes bottom-left:
   a label in white, and the value in its colour ("Lands in: **SAVANNA**").
8. **Nothing just sits there.** 3D items turn slowly, claimable things pulse, and shiny tiers
   shine.

## 2. Button colours

| Colour | Meaning | Example |
|---|---|---|
| Green `T.Good` | Go, buy (affordable), max, claim | MAX, CLAIM!, BUY |
| Orange or gold `T.Gold` | A price | $700Qi, 2.5K |
| Blue `T.Accent` | Equip, view, info | EQUIP, View |
| Red `T.Bad` | Close, danger | X, Leave |
| Dark slate | Already done or equipped | EQUIPPED, OWNED |
| Grey | Locked or can't afford | LOCKED |

## 3. Window anatomy (`UIController.RegisterWindow`)

Since 2026-11-16 every window uses the clean look of section 9 (reference clip:
`docs/reference/shop_upgrades`).

```
 /--------------------------------------------\          [ X ]   red X over the top-right corner
/  TITLE          (slanted colour band)   [..] /-----------+
+--+                                          /            |    black panel, 4 px black outline,
   |  [tab][tab][tab]                                      |    a soft glow in the window's colour
   |  +--------------------------------------------------+ |
   |  |  well: grid of gradient cards                    | |
   |  +--------------------------------------------------+ |
   +-------------------------------------------------------+
```

- **Opening:** the window pops in (scale 0.85 to 1, Back ease, 0.22 s), the backdrop fades in
  and the world behind it blurs.
- **Closing:** the window shrinks (1 to 0.88) and fades out in 0.15 s, then hides.
- **Closing happens only through** the X, Escape or gamepad B, or the window's own action. Never
  close a window or modal on a backdrop click: a click that misses a button must do nothing.

## 4. Shop card (Food Shop pattern)

A tall card, about 220 x 300, filled with its tier colour. From top to bottom:

1. the name, big and outlined
2. the tier or rarity word
3. the 3D item (turning)
4. the tier plate (`Tier 7`), dark and translucent
5. the action button: a price (green when affordable, grey when not), EQUIP, or EQUIPPED (dark)

The equipped card gets a green 3 px rim. Cards scroll horizontally, and the selected card is
centred.

## 5. Compact widget (Throw Power pattern)

Use this for small pop-ups and HUD panels:

- **Body:** a charcoal panel, corner radius 16, a 3 px black outline and a faint lighter inner
  rim.
- **Header:** a 40 px icon, an outlined title, then the values in colour (current in blue, max
  in grey), and the red X on the right.
- **Middle:** the control, such as a slider in a dark well, with colour ticks and a big round
  knob.
- **Footer:** info on the left and one bright action button on the right.

## 6. Motion

| What | How |
|---|---|
| Open | Pop: scale 0.85 to 1, `Back`, 0.22 s |
| Close | Scale to 0.88 and fade out, 0.15 s |
| Hover | Scale 1.04 |
| Press | Scale 0.95, and the face drops onto its lip |
| World hover card | Pop from 0 with a slight overshoot, a shine sweep, and pop out on leave |
| 3D in cards | Slow turntable, each card starting at a different angle |
| Claimable | Pulse (`Kit.Pulse`) |
| Legendary and up | Shine sweep (`Kit.Shine`) |

## 7. Don'ts

- Thin borders, flat web cards, tiny grey text.
- Closing on a click outside.
- Popping things in and out with no animation.
- Text without an outline on a coloured fill.
- More than one bright button per row.

## 8. Button components (Figma: "Abyss Salvage - Game Buttons")

The source of truth for both is the Figma file
https://www.figma.com/design/zFdUG7hvixMW2FDAeloS0b. It holds the `HudTile` and `ActionButton`
component sets, the icon components and a "Game UI" colour collection. In code:

- **`Kit.HudTile(icon, label, { Size, Color, Highlight, Key, Badge, Tag, ... })`**: the HUD
  rail and action button, **neon style** (2026-11-16; reference clip and frames in
  `docs/reference/hud_buttons`; Figma component set `NeonTile`, which replaces the grey
  `HudTile`).
  - **Tile:** a dark rounded square tinted by its colour (the colour at 72% to 90% black, top to
    bottom), corner 20%, and a 2 px near-black ring outside.
  - **Border:** a thick neon stroke (`size/15`, at least 3 px) in the colour, light at the top
    and darker at the bottom. Its light spills outwards as a soft halo (seven thin rounded
    layers, one pixel apart) and a little inwards (four one-pixel lines).
  - **Colours:** saturated, one per button (HUD `RAIL_COLORS`): Shop gold, Bag green, Upgrade
    orange, Codex purple, Quests blue, Rebirth cyan, Top pink, Friends lime, Settings steel.
  - **Icon:** in the upper part of the tile (centre at 42%). Every image icon's visible art
    fills 66% of the tile, and the art itself is centred, not the image: `Icons.ArtBox` holds
    each image's art box, measured from the PNGs (regenerate it after new uploads). Drawn
    vector icons are drawn at 62%.
  - **Icon glow:** a soft light in the tile's colour behind the icon (ten thin discs that add
    up to a smooth falloff, see section 9). It brightens on hover. The first version used
    three big discs and two see-through squares, which looked like a bullseye and a second
    border.
  - **Label:** Fredoka One at 30% of the tile, white, with a heavy dark outline. It sits on the
    tile's lower edge.
  - **Extras:**
    - `Key`: a big outlined letter off the top-right corner, shown to keyboard players only.
    - `Badge`: a red circle at the top left; set it with `Kit.HudTileBadge(button, value)`
      (Quests "!", the flare count).
    - `Tag`: a tilted red outlined word such as "New!".
  - **Highlight:** a white light band turns slowly round the border. Use it on one tile only
    (Shop).
  - **Motion:** hover grows it to 1.06 and brightens the glow, a press squashes it to 0.88,
    and release bounces it back (Back ease).
- **`Kit.ActionButton(text, color, onClick, { Size, Icon, TextSize, ... })`**: the price and
  action button (reference: the green Robux price buttons).
  - **Look:** a gradient face (lighter top), a 3 px outline, a white shine strip, and a darker
    6 px lip it presses onto. An optional icon sits before an outlined Fredoka value.
  - **Colours:** `Green` (buy, go), `Blue` (equip, info), `Red` (close, danger), `Gold` (price
    highlight), `Grey` (locked or can't afford), `Dark` (equipped or done). Any `Color3` also
    works.

- **`Kit.Readout(icon, palette, { TextSize, IconSize, ... })`**: currency and stat readouts
  (reference: the icon and coloured number rows).
  - **Layout:** a big glossy icon, then a Fredoka number painted with a light-to-dark gradient
    and a heavy outline. No panel or capsule behind it.
  - **Palettes** (`Kit.ReadoutColors`): Coins gold, Pearls sky blue, Tokens purple, Money lime,
    Good green (income), White, Bad red.
  - **Recolouring:** `Kit.ReadoutPaint(label, palette)` recolours any label; the bag count uses
    it to turn gold when there's loot and red when the bag is full.
- **`Kit.OutlineText(control)`**: the heavy white outlined text on any TextLabel or
  TextButton. It mirrors the text into a child label that has its own outline.
- **`Kit.ButtonFill(color)`**: maps the soft theme colours to the saturated button palette
  (`T.Good` to real green, `T.Bad` to red, `T.Gold` to orange-gold, `T.Accent` to blue).

Where these are used:

| Element | Built from |
|---|---|
| HUD rail, and the Boost, Sonar, Flare, Home and Up/Down actions | `Kit.HudTile` |
| Coins, income, Pearls and the bag count on the HUD | `Kit.Readout` |
| Every `Kit.Button`, `Kit.GameButton` and `Kit.PricePlate` | Restyled in place: saturated fill, glossy gradient, darker lip, shine strip, 3 px outline, Fredoka text with a heavy outline |
| Suit Shop buttons | `Kit.ActionButton` |

| Tab strips (`Kit.Tabs`) | Animal Index tabs: a dark outlined tray. The selected tab is a glossy slab in its colour with a shine strip and white outlined text, and it pops when picked. The others are dark slate (`#2C3242`) with dimmer outlined text and the icon in the tab's colour. |
| Pills (`Kit.Pill`) | Fredoka, white outlined text, a glossy fill and a 2 px outline |
| Oxygen bar | A big tank icon, then a chunky outlined track with a glossy fill and the seconds in outlined text on top. The outline flashes red when air is critical. |
| Event cards (top right) | A glossy slab in the event colour, the ticket icon popping out on the left, an outlined title and line, and a dark timer pill with a clock |

The HUD has no glass capsules left: the `glass()` helper is gone.

## 9. Clean windows (2026-11-16, reference `docs/reference/shop_upgrades`)

The owner's second reference clip (an inventory, a shop and a settings window) replaced the
navy windows with striped title bands. Where this section and an older one disagree, this one
wins for windows. `after/` in the reference folder holds Studio screenshots of the result.

What the reference does:

- **Panel:** near-black, with a thick black outline and a soft glow in one bright colour round
  it. The world behind is blurred.
- **Title band:** a colour sweep (left to right) that hangs over the top-left corner, with a
  slanted right end. White outlined title on it. A red X sits over the top-right corner.
- **Tabs:** small flat coloured slabs with white outlined text. No tray, no icons.
- **Cards:** a rounded tile that is dark at the top and its colour at the bottom, with a thin
  bright border. The name on top, a big icon, the price along the bottom in big outlined text.
  No separate price button: the whole card is the button. Red words such as "+29% More!" sit
  over the top edge.
- **Owned:** the card is dimmed and a big green word covers it.
- **Settings:** a plain charcoal panel (no band), centred section names, dark rounded rows
  with a bold title and a small grey line, green pill switches and sliders with a white knob.

In code:

| Piece | Built from |
|---|---|
| Window | `UIController.RegisterWindow(name, title, build, refresh, opts)`. `opts.Plain` = the charcoal Settings panel, `opts.MaxSize`, `opts.Header(holder)` = things at the right end of the band (the Shop's VIP button, the Upgrades coin count). The band's three colours come from the window's colour (`Kit.BandColors`). |
| Title band | `Kit.SlantBand` |
| Tabs | `Kit.FlatTabs` (the picked tab is bright with a white edge; the others are dark versions of their own colour) |
| Well | `Kit.Well` |
| Card | `Kit.NeonCard(color, props, onClick)`; `Sideways = true` for wide hero cards |
| Shop card | `Kit.ShopCard({ Name, Sub, Desc, Icon, Price, Color, Tag, Owned, Wide, OnClick })`. Small = name, icon, price (Coins, Pearls, Event). `Wide` = icon left, name and description, price (Passes, Boosts, Crates, Pass+). |
| Tag over a card | `Kit.CardTag` |
| Icon that fills its holder | `Kit.IconFill` (sizes each uploaded image by `Icons.ArtBox`) |
| Outlined text | `Kit.Text(text, size, props)` |
| Section name | `Kit.SectionTitle` |
| Settings row | `Kit.SettingRow`, `Kit.Toggle`, `Kit.Slider` |
| Soft glow | `Kit.Glow` and `Kit.GlowLayers` (see below) |

Rules that come with it:

- **A glow is many thin layers, never three big ones.** `Kit.GlowLayers(n, peak, power)` gives
  the opacity of each layer so the stack fades smoothly. Three or four big discs read as a
  bullseye, and two see-through squares read as a second border (the old HUD tile glow).
- **Never rotate anything inside a ScrollingFrame.** A rotated object ignores the frame's
  clipping and draws over the title when it scrolls out. Tags and "Owned!" are straight.
- **Leave room for tags.** A grid of cards needs about 18 px of top padding and 16 px between
  rows, because tags sit over a card's top edge.
- **Price colours:** white for Robux, green (`Kit.Clean.Go`) for a coin price you can pay, grey
  (`Kit.Clean.Off`) for one you can't, gold for MAX.
