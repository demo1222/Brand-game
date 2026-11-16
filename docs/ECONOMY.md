# Economy scheme: how money works in Abyss Salvage

All numbers live in `src/shared/Config/Upgrades.luau` (suits, upgrade tracks),
`src/shared/Config/Economy.luau` (rebirth, selling) and `src/shared/Config/Relics.luau` (relic CPS).
They are starting values: tune them from playtests, but keep the shape below.

## 1. The loop

```
dive -> salvage relics -> bag -> dock
                                  |-- display on a stand -> coins per second (CPS), forever
                                  |-- sell -> CPS x 60 coins, once
coins -> suits (deeper zone + big perks) and upgrades (air, fins, bag, stands...)
deeper zone -> rarer relics -> more CPS -> the next suit
```

## 2. Income

**Coins per second** = (sum of the CPS of every displayed relic) x the coin multiplier.

- **Relic CPS** = `BaseCPS x size x mutation multiplier`
  - BaseCPS by rarity: Common 1-5, Uncommon 8-22, Rare 40-90, Epic 220-500,
    Legendary 1.6K-4K, Mythic 22K-55K, Secret 250K+.
  - Size is 0.8 to 1.5 (HUGE above 1.35).
  - Mutations multiply: Gilded x2, Bioluminescent x3, Frozen x4, Cursed x6, Ancient x8,
    Prismatic x15, Void x30.
- **Coin multiplier** = rebirth (+0.5 per rebirth) x **suit Income perk (new)** x VIP / passes x
  friends x events.
- **Selling** pays CPS x 60 at once, so a relic you sell is worth one minute of displaying it.

## 3. Sinks

| Sink | Why players buy it | Cost shape |
|---|---|---|
| **Suits** (16) | the next zone, plus big Income / Luck / Air / Swim jumps | a fixed price per suit, x3 to x4 per step |
| **Upgrades** (11 tracks) | air, speed, bag, stands, defense | `Base x Growth^level`, Growth 1.62 to 2.6 |
| Rebirth | x1.5, x2... coins forever, +luck | needs Pressure Mk II and 100M lifetime coins (x3 per rebirth) |

## 4. Suits: the spine of progression

Three suits per zone. The **first** suit of a zone unlocks it. The **next two** are the "get
stronger here" buys. Each one is a visible jump, mainly in **coins** (the Income perk), so buying
a suit always raises your +N/s on the spot.

| # | Suit | Zone | Cost | Coins | Luck | Air | Swim |
|---|---|---|---|---|---|---|---|
| 1 | Basic Wetsuit | Reef | free | x1 | - | - | - |
| 2 | Snorkeler | Reef | 1.5K | x1.05 | - | +10% | +5% |
| 3 | Reef Runner | Reef | 6K | x1.1 | +5% | +15% | +15% |
| 4 | **Neoprene** | **Kelp** | 25K | x1.25 | +10% | +30% | +20% |
| 5 | Kelp Stalker | Kelp | 100K | x1.4 | +15% | +40% | +30% |
| 6 | Tidecaller | Kelp | 400K | x1.6 | +25% | +55% | +35% |
| 7 | **Pressure Mk I** | **Wrecks** | 1.5M | x2 | +35% | +75% | +40% |
| 8 | Wreck Diver | Wrecks | 6M | x2.5 | +45% | +90% | +45% |
| 9 | Salvage Master | Wrecks | 20M | x3.2 | +60% | +110% | +50% |
| 10 | **Pressure Mk II** | **Abyss** | 60M | x4 | +75% | +130% | +55% |
| 11 | Lantern Rig | Abyss | 180M | x5 | +90% | +150% | +60% |
| 12 | Anglerlight | Abyss | 550M | x6.5 | +110% | +175% | +65% |
| 13 | **Abyssal Rig** | **Trench** | 2B | x8.5 | +130% | +200% | +70% |
| 14 | Leviathan Hide | Trench | 8B | x11 | +160% | +240% | +80% |
| 15 | Coral Emperor | Trench | 30B | x15 | +200% | +280% | +90% |
| 16 | Titan Suit | (next zone) | 120B | x21 | +250% | +350% | +100% |

Old saves keep their suit (DataService v4 maps the old 12-suit index into this list).

## 5. Pacing targets (what the costs were set from)

These are estimates for one player with typical luck. Measure them in playtests and move the
**cost** columns, not the shape.

| Phase | Typical income | Time on the zone's suits | Notes |
|---|---|---|---|
| Reef | 20 -> 100 /s | ~10 min | first suit in ~2 min; Neoprene at ~25K |
| Kelp | 400 -> 1.5K /s | ~25-35 min | Epics start to show up; selling Rares helps |
| Wrecks | 3K -> 15K /s | ~45-60 min | first Legendaries; display slots matter |
| Abyss | 60K -> 250K /s | ~1.5 h | Mythics; Rebirth unlocks (Mk II + 100M) |
| Trench | 1M -> 5M /s | 3 h+ | endgame; rebirth loops take over |

Rule of thumb: the **next suit costs 5 to 20 minutes of current income**, and a zone's opener
costs about 2.5x the suit before it. Upgrades fill the gaps between suits: a level should cost
1 to 5 minutes of income when it's "on time", so players always have something to buy.

## 6. Upgrade curves

| Track | Base | Growth | Max | Last level costs |
|---|---|---|---|---|
| Oxygen Tank | 100 | 1.65 | 25 | ~16M |
| Fins | 80 | 1.75 | 20 | ~3.3M |
| Bag Size | 500 | 2.3 | 10 | ~900K |
| Sonar | 300 | 1.8 | 15 | ~1.1M |
| Salvage Speed | 250 | 2.0 | 10 | ~128K |
| Display Slots | 750 | 1.62 | 24 | ~49M |
| Offline Earnings | 2.5K | 2.0 | 10 | ~1.3M |
| Laser Gate / Guard Crab / Alarm | 5K | 2.6 | 5 | ~228K |
| Diving Board | 600 | 1.9 | 10 | ~193K |

Display Slots is the main income upgrade, so it has the longest curve and stays relevant into
the Abyss.

## 7. Relic materials (built: `Config/Materials`)

A relic's value is BaseCPS x size x mutations x **material**. Materials add a visible "what is it
made of" layer on top, in the Pet Simulator style. Luck (suits, potions, passes, guarded lairs)
raises their odds at half strength. Rainbow rolls at 0.03% normally, not event-only:

| Modifier | Look | Multiplier | Base chance |
|---|---|---|---|
| Gold | gold foil, sparkle | x3 | 4% |
| Emerald | green glass, glow | x6 | 1% |
| Diamond | clear glass, rainbow glint | x12 | 0.25% |
| Rainbow / Void | animated | x30+ | event only |

- One material per relic. It stacks with mutations and size, and appears on the card, the
  stand hover card and the reveal.
- **Size** becomes visible tiers: Tiny (0.8), Normal, Big (1.2+), HUGE (1.35+), TITANIC (1.5,
  event only), with the 3D model scaled on the stand.
- The data already has `size` and `mutations`. Add a `material` field (nil = plain) in
  `LootRoll.Roll`, the multiplier in `Formulas.RelicCPS`, and the look in `RelicArt`.
