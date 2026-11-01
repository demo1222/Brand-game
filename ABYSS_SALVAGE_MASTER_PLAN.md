# ABYSS SALVAGE — Master Game Design & Implementation Plan

> **A co-op deep-sea salvage game for Roblox, with relic collecting, a base that earns while you're offline, base raids, and a full set of game passes and paid items.**
>
> Version 1.0 · Prepared November 1, 2026 · Status: Pre-production
>
> **About the numbers in this document.** Market figures are snapshots from public trackers taken in October 2026, and the trackers disagree with each other. Check current data on Rolimons, RoTrends or the official Roblox charts before you commit budget. DevEx rates and Roblox policies change, so confirm them on the official Creator Hub before launch. Every economy number below is a **starting value to tune during playtests**, not a final answer.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Market Analysis](#2-market-analysis)
3. [Niche Selection & Positioning](#3-niche-selection--positioning)
4. [Design Pillars](#4-design-pillars)
5. [Core Gameplay Loop](#5-core-gameplay-loop)
6. [World Design — Depth Zones](#6-world-design--depth-zones)
7. [Loot System — Relics, Rarity & Mutations](#7-loot-system--relics-rarity--mutations)
8. [The Dock — Base & Idle Income](#8-the-dock--base--idle-income)
9. [Raid System (Steal Mechanic)](#9-raid-system-steal-mechanic)
10. [Threats — Predator AI & Hazards](#10-threats--predator-ai--hazards)
11. [Progression & Upgrades](#11-progression--upgrades)
12. [Rebirth System — "Resurface"](#12-rebirth-system--resurface)
13. [Economy Design & Formulas](#13-economy-design--formulas)
14. [Social Systems](#14-social-systems)
15. [Monetization — Full System](#15-monetization--full-system)
16. [Policy & Compliance](#16-policy--compliance)
17. [First-Time User Experience (FTUE)](#17-first-time-user-experience-ftue)
18. [UI / UX Specification](#18-ui--ux-specification)
19. [Art Direction & Audio](#19-art-direction--audio)
20. [Technical Architecture](#20-technical-architecture)
21. [Data Model & Persistence](#21-data-model--persistence)
22. [Monetization Code Implementation](#22-monetization-code-implementation)
23. [Security & Anti-Exploit](#23-security--anti-exploit)
24. [Performance Budget](#24-performance-budget)
25. [Analytics & KPIs](#25-analytics--kpis)
26. [Live Operations Plan](#26-live-operations-plan)
27. [Marketing & User Acquisition](#27-marketing--user-acquisition)
28. [Team, Budget & Tooling](#28-team-budget--tooling)
29. [Production Roadmap (Week by Week)](#29-production-roadmap-week-by-week)
30. [QA & Test Plan](#30-qa--test-plan)
31. [Risk Register](#31-risk-register)
32. [Launch Checklist](#32-launch-checklist)
33. [Appendices](#33-appendices)

---

## 1. Executive Summary

| Item | Detail |
|---|---|
| **Working title** | Abyss Salvage (other options: *Deep Grab*, *Steal a Relic*, *Trench Raiders*) |
| **Genre** | Collect-and-steal simulator with co-op survival-horror tension |
| **Platform** | Roblox (mobile first, also PC, console and tablet) |
| **Target audience** | Core: ages 9–16. Secondary: 17–24 (an 18+ verified audience earns the higher DevEx rate) |
| **Session length target** | 18–25 minutes |
| **Core fantasy** | "I dove into the deadliest trench, grabbed a Mythic relic, escaped the Leviathan, and now everyone in the server wants to steal it." |
| **Business model** | Free to play. Game passes, developer products, a Robux subscription, private servers, Premium Payouts |
| **Time to soft launch** | About 8 weeks |
| **Time to full launch** | About 12 weeks |
| **Success bar (Month 3)** | 5,000+ peak concurrent players, D1 ≥ 30%, 2–4% of players paying, ≥ 1.5 Robux per daily active user (ARPDAU) |

**One-paragraph pitch.** Players dive from their dock into a large ocean split into five depth zones. Each dive is a race against oxygen while hunting for relics: ancient artifacts, strange creatures and sunken treasure. Every relic rolls a rarity and can roll a random mutation. Back at the dock, relics go on display stands and earn Coins every second, including while you're offline. Other players can swim over and steal them, so every rare find is both a prize and a target. Deeper zones have better loot and a hunting predator, which produces screaming, clip-worthy escapes. Coins buy better suits, tanks, sonar and dock space, which let you go deeper. Resurfacing (rebirth) gives a permanent multiplier and starts the climb again.

---

## 2. Market Analysis

### 2.1 Top Roblox games, snapshot (October 2026)

| Rank (approx.) | Game | Genre | Peak / concurrent signal | Launch |
|---|---|---|---|---|
| 1 | Steal An Egg | Collect, defend base, steal | 1M+ concurrent; 30-day peak above 14M (Rolimons via Adellion, Oct 1) | Jul 25, 2026 |
| 2 | Murder Mystery 2 | Social deduction | About 1.5–1.9M at peak snapshot | 2014 |
| 3 | Brookhaven RP | Social roleplay | About 400–500k | 2020 |
| 4 | Adopt Me! | Pet collecting and roleplay | Hundreds of thousands | 2017 |
| 5 | Steal a Brainrot | Steal, collect, idle | Still trending in 2026 | May 2025 |
| 6 | Grow a Garden / GaG 2 | Idle farming with mutations | Biggest new game of the cycle | 2025 / Jun 2026 |
| 7 | 99 Nights in the Forest | Co-op survival horror | Now a lasting hit | 2025 |
| 8 | Fish It / Hooked! | Fishing collection | Hooked! grew about 9,000% in Q1 2026 | 2025–26 |

### 2.2 Pattern analysis: what the winners share

| Pattern | Seen in | How Abyss Salvage uses it |
|---|---|---|
| **Collecting with rarity tiers** | Grow a Garden, Fish It, Adopt Me | Relics with 7 rarity tiers and 12+ mutations |
| **Mutations and variants** | Grow a Garden | Gilded, Bioluminescent, Cursed, Ancient… with multipliers that stack |
| **Base that earns while you're away** | Steal a Brainrot, Steal An Egg | Dock display stands earn Coins per second, with capped offline earnings |
| **Stealing from other players** | Steal a Brainrot, Steal An Egg | Swim to a dock and grab a relic; owners can chase you |
| **Co-op threat** | 99 Nights in the Forest | A Leviathan hunts deep divers; teaming up helps you survive |
| **Moments that make good clips** | All of them | Mythic pulls, last-second escapes, steals, jump scares |
| **Frequent content updates** | Grow a Garden (weekly) | New mutation or event every week, new zone every 4–6 weeks |
| **Effects that hit the whole server** | Grow a Garden weather, admin abuse events | Server Luck Boosts, "Blood Tide" events |

### 2.3 What's crowded vs. what's open

- **Crowded:** generic "Steal a [noun]" copies, casual fishing, tycoons, obbies.
- **Open:** collecting that *has real danger*. Current steal games have almost no tension while you gather. Horror games have shallow collecting. **Nobody combines danger, collecting and stealing well.**
- **Underwater theme:** there are few big underwater games. The setting naturally gives you limited sight, scary depth, glowing creatures and pressure as a reason for zones to exist.

### 2.4 Platform economics (confirm before launch)

- **Game passes:** creator keeps 70% of the Robux.
- **Developer products:** 70%.
- **Robux subscriptions:** auto-renew, priced in local currency.
- **Private servers:** creator share as Roblox sets it.
- **Premium Payouts:** paid out based on how long Premium members spend in your game.
- **18+ DevEx boost:** about 42% more DevEx on qualifying spend from age-verified US players aged 18+ (starting June 8, 2026). Covers game passes, subscriptions, select in-game items and private servers. Requires a "novel" game and R15 avatars. Avatar and Marketplace items don't qualify. → **Build the game in R15 from day one.**
- **Base DevEx rate:** reported around $0.0035–0.0038 per Robux. Check the official Roblox page.

---

## 3. Niche Selection & Positioning

### 3.1 Why "Abyss Salvage" wins

1. **Combines three proven hits.** Collecting (Fish It), stealing (Steal An Egg) and co-op danger (99 Nights). Each part is proven; the combination is new.
2. **The theme justifies the systems.** Oxygen limits how long a dive lasts. Depth explains the zones. Darkness explains why sonar is worth upgrading. Pressure explains suit tiers.
3. **Built for clips.** Glowing Mythic relics in pitch-black water are striking to look at.
4. **Lots of room to grow.** New zones, new predators, a sub/vehicle system, guilds, seasons.
5. **Works on mobile.** Swimming is forgiving; there's no precise platforming.

### 3.2 Positioning statement

> For Roblox players who love collecting rare things and showing them off, **Abyss Salvage** is the collecting game where every rare find is a risk: you have to survive the deep to get it, and defend your dock to keep it. Other steal games are just walking and grabbing; here every dive is a heart-pounding escape.

### 3.3 Competitive differentiation

| Feature | Steal a Brainrot | Fish It | 99 Nights | **Abyss Salvage** |
|---|---|---|---|---|
| Rarity collecting | ✅ | ✅ | ⚠️ | ✅ |
| Mutations | ⚠️ | ⚠️ | ❌ | ✅ |
| Stealing from players | ✅ | ❌ | ❌ | ✅ |
| Danger while collecting | ❌ | ❌ | ✅ | ✅ |
| Co-op | ⚠️ | ⚠️ | ✅ | ✅ |
| Offline earnings | ✅ | ❌ | ❌ | ✅ |

---

## 4. Design Pillars

1. **"Risk Makes It Rare."** Every valuable thing has to be *earned through danger*. A Mythic found in safe water feels cheap; one carried out of the Trench feels legendary.
2. **"Show It Off."** Rare items should be *visible* to everyone: glowing stands, server-wide announcements, a display on your back while you swim.
3. **"Always One More Dive."** A dive loop of 2–4 minutes, with upgrades that are always close.
4. **"Fair Pressure."** Raids create tension, but never wipe anyone out. Pay to save time, never to win.
5. **"Something New Every Week."** Live ops are part of the game's identity, not an afterthought.

---

## 5. Core Gameplay Loop

### 5.1 Micro loop (30–60 seconds)
```
Spot glow on sonar → Swim to it → Hold-to-salvage (1–4s) → Rarity reveal → Bag it
```

### 5.2 Core loop (2–4 minutes = 1 dive)
```
┌─────────────────────────────────────────────────────────┐
│  DOCK  →  DIVE  →  SALVAGE  →  ESCAPE  →  DISPLAY        │
│   ↑                                          │           │
│   └──── UPGRADE ←── EARN COINS ←─────────────┘           │
│                       ↑                                   │
│                RAID / DEFEND (anytime)                    │
└─────────────────────────────────────────────────────────┘
```

1. **Dock.** Hub: shop, display stands, upgrades.
2. **Dive.** Jump off the dock and descend. Your oxygen bar starts draining.
3. **Salvage.** Find relics. The bag holds 3–12 items depending on upgrades.
4. **Escape.** Get back to the surface before oxygen runs out or the predator catches you.
   - **If you die:** you lose the bag (or keep 1 item if you own Vault Lock / Insurance). You can buy a revive.
5. **Display.** Put relics on stands. Each relic earns `baseValue × mutationMultiplier × rebirthMultiplier` Coins per second.
6. **Upgrade.** Spend Coins to dive deeper and longer and find better loot.

### 5.3 Meta loop (days to weeks)
- Fill your **Codex** (a collection book: every relic × every mutation).
- **Resurface** (rebirth) for permanent multipliers.
- Climb the leaderboards (Deepest Dive, Total Value, Most Steals, Codex %).
- Take part in weekly events and get limited-time relics.
- Advance the season pass track.

### 5.4 Session flow target (20 minutes)
| Minute | Activity | Emotional beat |
|---|---|---|
| 0–1 | Join and collect offline earnings | Reward ("I earned 12k while I was gone!") |
| 1–3 | Buy an upgrade | Progress |
| 3–12 | 3–4 dives | Tension, discovery, relief |
| 12–14 | A raid or getting raided | Social spike |
| 14–18 | Deeper dive with the new upgrade | Mastery |
| 18–20 | Event, leaderboard check, logout hook ("Mythic egg hatches in 2h") | Reason to come back |

---

## 6. World Design — Depth Zones

The ocean is one continuous map with depth bands. Light, colour, fog density and music change as you go deeper.

| # | Zone | Depth (studs) | Suit needed | Oxygen drain | Threats | Loot tier focus | Visual mood |
|---|---|---|---|---|---|---|---|
| 1 | **Sunlit Reef** | 0–150 | Basic | 1×/s | None | Common–Uncommon | Bright turquoise, coral, sunbeams |
| 2 | **Kelp Twilight** | 150–400 | Neoprene | 1.25× | Eels (knockback) | Uncommon–Rare | Green-blue haze, swaying kelp |
| 3 | **Midnight Wrecks** | 400–800 | Pressure Mk I | 1.5× | Anglerfish lures, jellyfish | Rare–Epic | Dark navy, shipwrecks, glowing lures |
| 4 | **The Abyss** | 800–1,400 | Pressure Mk II | 2× | **Leviathan** patrols | Epic–Legendary | Near-black, glowing life |
| 5 | **The Trench** | 1,400–2,200 | Abyssal Rig | 3× | Leviathan aggro, pressure cracks | Legendary–Mythic | Pitch black, red vents, ancient ruins |
| 6* | **The Sunken Throne** (Update 1) | 2,200+ | Titan Suit | 4× | Boss: *The Drowned King* | Mythic–Secret | Gold and obsidian city |

**Zone access rule.** Without the required suit you can still enter, but you take pressure damage, about 5% of HP per second. This lets good players take risky "speed dives".

**Points of interest per zone:** 3–5 hand-built landmarks (a wreck, a cave, a statue) that guarantee higher spawn weights. Players learn the map and share routes, which creates community content.

**Air pockets.** Rare oxygen refill bubbles in zones 3–5, placed to create "do I risk it?" route choices.

**Server layout.** 12–16 players per server. Docks are arranged in a ring around a central "Harbor" plaza. The dive zone is underneath everything and shared.

---

## 7. Loot System — Relics, Rarity & Mutations

### 7.1 Rarity tiers

| Tier | Colour | Base drop weight* | Base Coins/sec | Reveal effect |
|---|---|---|---|---|
| Common | Grey | 60% | 1–5 | None |
| Uncommon | Green | 25% | 8–20 | Small sparkle |
| Rare | Blue | 10% | 40–90 | Beam + chime |
| Epic | Purple | 4% | 200–500 | Screen-edge glow |
| Legendary | Gold | 0.9% | 1.5k–4k | Slow-mo + local announcement |
| Mythic | Red / rainbow | 0.095% | 20k–60k | **Server-wide announcement** + fanfare |
| Secret | Black / prismatic | 0.005% | 250k+ | Server and global cross-server announcement |

*Weights shift by zone. Deeper zones move the curve toward rarer tiers (see 7.3). Every displayed odd **must** match the actual roll table.

### 7.2 Relic catalogue (launch: 60 relics; target 150 by Month 3)

Example entries:

| ID | Name | Zone | Rarity | Base C/s | Notes |
|---|---|---|---|---|---|
| R001 | Rusty Anchor | 1 | Common | 2 | Tutorial item |
| R002 | Glass Bottle Message | 1 | Common | 3 | Contains lore |
| R010 | Pearl Clam | 1 | Uncommon | 12 | |
| R021 | Pirate Doubloon | 2 | Rare | 55 | |
| R034 | Captain's Compass | 3 | Epic | 320 | Points to a nearby rare |
| R041 | Lantern of the Deep | 4 | Legendary | 2,800 | Lights the area while displayed |
| R052 | Leviathan Tooth | 4–5 | Mythic | 35,000 | Only drops after escaping the Leviathan |
| R058 | Crown of the Drowned King | 5 | Mythic | 55,000 | |
| R060 | ??? (Heart of the Trench) | 5 | Secret | 300,000 | Silhouette in Codex |

### 7.3 Zone rarity modifiers

| Zone | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
|---|---|---|---|---|---|---|---|
| 1 Reef | 75% | 20% | 4.5% | 0.5% | 0% | 0% | 0% |
| 2 Kelp | 55% | 30% | 12% | 2.7% | 0.3% | 0% | 0% |
| 3 Wrecks | 35% | 33% | 22% | 8.5% | 1.4% | 0.1% | 0% |
| 4 Abyss | 15% | 30% | 30% | 18% | 6.5% | 0.49% | 0.01% |
| 5 Trench | 0% | 20% | 35% | 28% | 14.5% | 2.45% | 0.05% |

**Pity system.** Every dive in zone 4+ without a Legendary or better adds +0.1% to Legendary weight, capped at +5%. The counter resets when you get one. This is stored per player and keeps unlucky players from quitting.

### 7.4 Mutations

Each relic rolls a mutation independently after the rarity roll. Multipliers apply to Coins/sec and sell value. Two mutations can stack (rare).

| Mutation | Chance | Multiplier | Visual |
|---|---|---|---|
| None | 85% | 1× | — |
| **Wet** (event) | event only | 1.5× | Dripping particles |
| **Gilded** | 6% | 2× | Gold material |
| **Barnacled** | 4% | 1.5× | Barnacle texture; can be "cleaned" for a reroll |
| **Bioluminescent** | 2.5% | 3× | Pulsing cyan glow |
| **Frozen** | 1% | 4× | Ice shell |
| **Cursed** | 0.8% | 6× | Purple smoke; *attracts the predator while carried* |
| **Ancient** | 0.5% | 8× | Runic engravings |
| **Prismatic** | 0.15% | 15× | Rainbow shimmer |
| **Void** | 0.05% | 30× | Black hole distortion |
| **Kraken-touched** (event) | event only | 10× | Tentacle aura |
| **Double mutation** | 1% of mutated | Product of both | Both effects |

Weather and tide events (Section 26) temporarily raise specific mutation chances, which creates "log in NOW" moments.

### 7.5 Size and weight variance
Every relic rolls a **size from 0.8× to 1.5×** (normal distribution). That multiplies value and is shown as "Huge!" above 1.35×. It adds variety at no content cost and creates "I got a HUGE Gilded Doubloon" moments.

### 7.6 Codex (collection book)
- Grid of all relics × mutations, with silhouettes for undiscovered entries.
- Milestone rewards at 10%, 25%, 50%, 75% and 100% per zone (gems, cosmetics, titles).
- Completing a whole zone gives a +5% permanent luck bonus in that zone.

---

## 8. The Dock — Base & Idle Income

### 8.1 Layout
- Each player is assigned one dock plot in the server ring when they join (saved layout, loaded into the plot).
- **Display stands:** start with 6 slots. Upgrade to 30; game pass adds +4.
- **Vault slots:** 0 by default, 2 with the Vault Lock pass, more through upgrades. These can't be stolen.
- **Dock decor:** cosmetic flags, lights, statues (cosmetic store and Codex rewards).
- **Coin collector pad:** step on it to collect stored Coins (touch to collect, as in Steal a Brainrot), or buy auto-collect.

### 8.2 Income math
```
CoinsPerSecond(stand) = BaseCPS(relic) × SizeMult × MutationMult × RebirthMult × PassMult × EventMult
DockCPS = Σ CoinsPerSecond(stands)
```

### 8.3 Offline earnings
- Earn **25% of DockCPS** while offline, capped at **4 hours** by default.
- Upgrades raise this to 50% and 12 hours. VIP adds +2 hours.
- On login: a big "Welcome back! You earned 48,210 Coins" popup with a **"2× with Pass+"** or "Watch for 2×" button. Use rewarded video ads if Roblox ad formats allow them.

### 8.4 Dock defense
- **Laser Gate** (Coins upgrade): blocks your dock for 60 seconds after you activate it, with a 5-minute cooldown.
- **Alarm bell:** notifies you when someone enters your dock (always on).
- **Guard Crab** (upgrade): slows intruders by 30%.
- **Dock Lock on join:** 90 seconds of protection after you join, so new arrivals aren't instantly raided.

---

## 9. Raid System (Steal Mechanic)

### 9.1 Flow
1. A raider enters another player's dock area.
2. The owner gets an alert with an arrow pointing at the intruder.
3. The raider holds interact on a stand for **2.5 seconds**. A progress ring shows, and the relic is visibly lifted.
4. The raider now **carries the relic on their back** and moves 20% slower. A visible beam marks them as a target.
5. The raider must get the relic back to **their own dock** to claim it.
6. **Steal-back window:** the owner (or anyone, for a bounty) can touch or hit the carrier to knock the relic loose. It goes back to its owner's stand.
7. If the raider succeeds, the relic moves to their stand. The previous owner gets a "You were robbed by X — Revenge?" button that teleports them near the thief's dock for 60 seconds.

### 9.2 Fairness guardrails
| Rule | Value |
|---|---|
| Power band | You can only raid docks between 0.33× and 3× your Total Dock Value |
| Steal cooldown per raider | 45 seconds |
| Victim protection | After being robbed, 3 minutes of immunity |
| Max relics stolen from one player per hour | 3 |
| Can't steal | Vault-slot items, items placed in the last 30s, Secret-tier items (optional design call) |
| New player shield | First 30 minutes of total playtime: can't be raided |
| Steal in a private server | Off unless the owner turns it on |

### 9.3 Why raids matter
- They push players to **invite friends** (defense partners).
- They create rivalry and revenge, which makes long sessions.
- They create **demand for monetized safety** (Vault Lock, Laser Gate refills) without making safety mandatory.

---

## 10. Threats — Predator AI & Hazards

### 10.1 The Leviathan (main predator)
- **Spawns:** patrols zones 4–5. One Leviathan per server, plus one more per 6 players in zone 4+.
- **States:** `Patrol → Investigate (heard noise/sonar ping) → Hunt → Lunge → Cooldown`.
- **Perception:**
  - Sight cone of 60 studs (shrinks if the player is in kelp or caves).
  - "Noise" meter rises with boosting, sonar pings and carrying Cursed relics.
- **Attack:** a telegraphed lunge with a 1-second wind-up (roar and screen shake). Dodge it by turning sharply or breaking line of sight. A hit deals 70% HP; two hits kill.
- **Co-op:** a teammate can throw a **flare** (cheap consumable) to distract it for 6 seconds.
- **Mechanics:** server-side movement with PathfindingService, simplified to swim waypoints in 3D. Use `AlignPosition`/`AlignOrientation` for smooth movement. Network ownership stays on the server.

### 10.2 Secondary hazards
| Hazard | Zone | Effect |
|---|---|---|
| Electric Eels | 2+ | Knockback and a 10% oxygen hit |
| Jellyfish swarms | 3+ | Slow and damage over time |
| Anglerfish lures | 3+ | Fake glowing "relics" that bite |
| Pressure cracks | 5 | Sudden geysers |
| Whirlpools | event | Pull players into a bonus cave |

### 10.3 Death rules
- Lose your current bag (unless you have Insurance or Vault Lock: keep the 1 most valuable relic).
- Respawn at your dock.
- Offer: **Revive in place (35 R$)**, shown immediately on a 10-second timer. This is one of the biggest consumable earners.
- **Bag drop:** your lost bag stays where you died for 90 seconds, and **other players can loot it.** This creates emergent stories.

---

## 11. Progression & Upgrades

### 11.1 Upgrade tracks (bought with Coins)

| Track | Levels | Effect per level | Cost curve |
|---|---|---|---|
| **Suit** | 6 tiers | Unlocks a zone without pressure damage | Fixed big milestones |
| **Oxygen Tank** | 25 | +6s dive time | `50 × 1.45^L` |
| **Fins (speed)** | 20 | +4% swim speed | `40 × 1.42^L` |
| **Bag size** | 10 | +1 slot (3 → 13) | `200 × 1.8^L` |
| **Sonar** | 15 | +range, +rare-detect, highlights mutations at L10 | `150 × 1.5^L` |
| **Salvage speed** | 10 | −8% hold time | `100 × 1.5^L` |
| **Display slots** | 24 | +1 stand | `500 × 1.35^L` |
| **Offline earnings** | 10 | +2.5% rate, +48 min cap | `1000 × 1.6^L` |
| **Dock defense** | 5 each | Gate, Crab, Alarm range | `2000 × 2^L` |

### 11.2 Suit tiers

| Suit | Cost (Coins) | Unlocks | Visual |
|---|---|---|---|
| Basic Wetsuit | Free | Reef | Yellow |
| Neoprene | 2,500 | Kelp | Blue |
| Pressure Mk I | 60,000 | Wrecks | Brass helmet |
| Pressure Mk II | 1.2M | Abyss | Steel, lamp |
| Abyssal Rig | 25M | Trench | Black, glowing visor |
| Titan Suit (U1) | 600M | Throne | Gold armour |

### 11.3 Player level (XP)
- XP from salvaging, escaping, Codex discoveries and raids.
- Level-ups give small gem payouts and unlock **titles** (shown over your head) and **emotes**.
- Level gates: Raiding unlocks at Level 5 (protects brand-new players).

---

## 12. Rebirth System — "Resurface"

- **Requirement:** own the Pressure Mk II suit and have 5M lifetime Coins (rises with each rebirth: `5M × 3^n`).
- **Resets:** Coins, upgrades (except Suit cosmetics), bag and sonar.
- **Keeps:** relics on stands (**design choice: keep them**, to protect the player's emotional attachment), Codex, gems, passes, cosmetics, level.
- **Gains:**
  - +50% permanent Coin multiplier per rebirth (additive: 1.5×, 2×, 2.5×…).
  - +2% luck per rebirth (capped at +30%).
  - An exclusive helmet trim colour per rebirth tier (shows off).
  - Rebirth tokens → a talent tree (e.g. "Start with Neoprene", "+1 bag slot", "Leviathan hears you 10% less").
- A rebirth leaderboard drives long-term players.

---

## 13. Economy Design & Formulas

### 13.1 Currencies
| Currency | Source | Sink | Paid? |
|---|---|---|---|
| **Coins** (soft) | Dock income, selling relics | Upgrades, decor | Buyable via dev products |
| **Pearls** (premium) | Codex, levels, events, Pass+ daily, Robux | Crates, cosmetics, skips, revives (alternative to Robux) | Yes |
| **Event Tokens** (seasonal) | Event-only activities | Event shop | No (keeps events fair) |
| **Rebirth Tokens** | Resurfacing | Talent tree | No |

### 13.2 Selling relics
- Sell price = `CPS × 60` (one minute of income), so displaying usually beats selling, but selling clears bag space and funds early upgrades.
- A "Sell all Commons" button in the bag UI.

### 13.3 Time-to-progress targets (free player, no passes)

| Milestone | Target playtime |
|---|---|
| First upgrade | 2 minutes |
| Kelp suit | 12 minutes |
| Wrecks suit | 1.5 hours |
| Abyss suit | 6 hours |
| First Resurface | 10–12 hours |
| Trench suit | 25 hours |
| First Mythic (expected) | 8–15 hours |

**Paying players (VIP + Oxygen + Drone)** should reach the same milestones about **35–45% faster**. That's noticeably faster, but not enough to make free players feel left out.

### 13.4 Inflation control
- Exponential upgrade costs (×1.35–1.8 per level).
- Coins have a single main use: progress. Cosmetics sold for Pearls keep the premium currency valuable.
- Big-number formatting (K, M, B, T, Qa) up to 1e30 for long-term play.
- A server-side economy log (Coins earned per hour per player percentile) to spot runaway inflation.

### 13.5 Example balance spreadsheet formulas
```
UpgradeCost(L)        = Base × Growth^L
DiveValue(zone)       ≈ Σ_r P(r|zone) × AvgCPS(r) × E[mutMult] × E[size] × BagSize
E[mutMult]            ≈ 0.85·1 + 0.06·2 + 0.04·1.5 + 0.025·3 + 0.01·4 + 0.008·6 + 0.005·8 + 0.0015·15 + 0.0005·30 ≈ 1.27
TimeToAfford(cost)    = cost / (DockCPS + DiveValue/DiveDuration)
```
Keep the balance model in a Google Sheet that exports to `ReplicatedStorage/Shared/Config/*.lua` through a small script (see 20.6).

---

## 14. Social Systems

| System | Description | Why |
|---|---|---|
| **Dive Party** | Up to 4 players; shared sonar pings, flares, +10% luck per member | Co-op retention and invites |
| **Friend boost** | +10% Coins per friend in the server (max +40%) | Viral sharing |
| **Trading** | Unlocks at Level 15. Two-sided trade window, both confirm, 5s countdown, server-side checks. Trade history log | Long-term economy and community |
| **Server announcements** | Mythic and Secret finds, big steals, boss kills | Envy and aspiration |
| **Global announcements** | Secret finds across servers via MessagingService | Hype |
| **Leaderboards** | Global (OrderedDataStore): Deepest, Total Value, Rebirths, Steals, Codex%. Server board on the plaza | Competition |
| **Crews (Update 2)** | Guilds of up to 20, crew dock, weekly crew goals | Long-term retention |
| **Group rewards** | Join the Roblox group → +5% Coins and an exclusive flag | Community growth |
| **Invite rewards** | Invite a friend who plays 10 minutes → a Pearl reward for both | Viral growth |
| **Like / favourite prompt** | After the first Legendary (positive moment) | Algorithm signals |

---

## 15. Monetization — Full System

### 15.1 Monetization philosophy
1. **Sell time, convenience, safety, status and luck. Never exclusive power over other players.**
2. **Place offers at the moments of strongest feeling:** right after death (revive), after being robbed (Vault Lock), at a near-miss Mythic (Luck), at the oxygen-empty screen (bigger tank).
3. **Make the first purchase easy** with cheap items under 100 R$.
4. **Show buyers off.** VIP tags and auras make other players aspire to buy.
5. **Make it worth paying every month** (Pass+ subscription).

### 15.2 Game passes (one-time, permanent)

| # | Pass | Price (R$) | Effect | Placement / trigger | Expected rank |
|---|---|---|---|---|---|
| 1 | **VIP Diver** | 249 | 1.5× Coins, `[VIP]` gold tag, VIP lounge dock, +2h offline cap, daily VIP chest | Shop front page, plaza VIP door you can see but not enter | #1 earner |
| 2 | **2× Oxygen** | 199 | Twice the base tank | "Out of air" screen | #2 |
| 3 | **Auto-Salvage Drone** | 399 | A drone pet that collects Common and Uncommon items within 20 studs | After 10 dives | #3 |
| 4 | **Lucky Sonar** | 349 | +25% luck (multiplies rare weights) | After a near miss; shop | #4 |
| 5 | **Vault Lock** | 299 | 2 slots that can't be stolen, plus keep 1 relic on death | "You were robbed" screen | #5 |
| 6 | **+4 Display Slots** | 149 | +4 stands | When stands are full | High conversion |
| 7 | **Big Bag** | 179 | +4 bag slots | When the bag is full | |
| 8 | **Instant Resurface** | 99 | Teleport to the dock once per dive | First death in zone 3+ | Best first purchase |
| 9 | **Speed Fins** | 149 | +30% swim speed | Shop | |
| 10 | **Auto-Collect Coins** | 129 | No need to step on the collector | After 5 collections | |
| 11 | **Mutation Scanner** | 249 | Sonar shows mutation type before you salvage | Shop | |
| 12 | **Pet Slot +1** (U1) | 199 | Equip an extra companion | Companion update | |
| 13 | **Radio** | 99 | Play approved audio at your dock | Shop | Classic |
| 14 | **Starter Pack** | 99 (shown once, 48h timer) | 10k Coins, 100 Pearls, Neoprene suit, Rare relic | First session at minute 8 | Converts 3–6% |

**Price psychology:** prices end in 9; one "decoy" high price (the 399 Drone) makes 249 VIP look reasonable; bundles show the % saved.

**Bundle passes:**
- **Deep Diver Bundle:** VIP + 2× Oxygen + Big Bag for 499 R$ (normally 627, save 20%).
- **Collector Bundle:** Lucky Sonar + Mutation Scanner + Vault Lock for 699 R$ (normally 897).

*(Bundles are made as separate game passes; the grant logic checks for the bundle ID **or** the individual ID.)*

### 15.3 Developer products (consumables)

| Product | Price (R$) | Effect | Trigger |
|---|---|---|---|
| Oxygen Refill | 25 | Full tank instantly | Oxygen under 15% (one tap) |
| Revive in Place | 35 | Respawn where you died, keep your bag | Death screen, 10s timer |
| Flare ×5 | 19 | Leviathan distraction | Leviathan nearby |
| Laser Gate Recharge | 29 | Reset gate cooldown | When raided |
| Server Luck Boost (15 min) | 199 | 2× rare odds for **everyone in the server**; buyer's name announced | Plaza totem |
| Personal Luck Potion (10 min) | 49 | 2× luck | Before a deep dive |
| Mutation Potion (10 min) | 79 | 3× mutation chance | Event weekends |
| Coins pack S / M / L / XL / XXL | 49 / 149 / 399 / 999 / 1,999 | Scaled to the current Dock CPS (e.g. 20 min / 1.5h / 5h / 15h / 36h of income) | Shop |
| Pearls 100 / 550 / 1,200 / 2,600 / 7,000 | 49 / 249 / 499 / 999 / 2,499 | Premium currency (more bonus at higher tiers) | Shop |
| Skip Pity (instant Legendary roll) | 149 | Rolls the Legendary table | After 20+ dry dives |
| Barnacle Clean (mutation reroll) | 39 | Reroll mutation on a Barnacled relic | Inventory |
| **Mystery Crates** (Pearls or Robux) | 99 / 299 (×3) | Random cosmetic or relic, **odds shown** | Shop, behind the PolicyService check |
| Rename Dock | 25 | Custom dock sign (filtered) | Dock |

**Scaling Coin packs to player progress** is essential. A fixed 10k Coins pack is worthless to late-game players. Always price them as "X hours of your income".

### 15.4 Subscription — "Abyss Pass+"

| Item | Detail |
|---|---|
| Price | About $4.99/month (Roblox subscription, local currency pricing) |
| Daily | 60 Pearls/day on login (about 1,800/month, worth more than the price in Pearl terms) |
| Permanent while active | +10% Coins, +10% luck, 1 free revive/day, offline cap +4h, 2× offline-earnings claim |
| Cosmetic | Exclusive monthly suit skin (kept forever after the month), animated Pass+ badge |
| Quality of life | Auto-sell Commons, extra Codex hint per day |
| Retention hook | "Streak" visual: suit trim colour upgrades at 3, 6 and 12 months |

### 15.5 Season Pass — "Tide Pass" (Pearls or Robux)
- 6-week seasons, 50 tiers.
- **Free track:** Coins, Pearls, small cosmetics.
- **Premium track (about 499 R$ or 800 Pearls):** exclusive relics (displayable, earn Coins), suits, a dock theme, an emote, and a tier-50 Mythic.
- XP comes from daily and weekly quests ("Escape the Leviathan 3 times", "Steal 2 relics", "Find 1 Bioluminescent").
- **Tier skip:** 49 R$ per tier.

### 15.6 Private servers
- **"Private Trench"** at 100 R$/month. Steals off by default; owner controls (event trigger once per day).
- This counts toward the 18+ DevEx boost for adult buyers.

### 15.7 Premium Payouts optimization
- A Premium-only perk: +10% Coins and a Premium chest every 24h (Roblox allows Premium benefits). This boosts how long Premium members play.

### 15.8 Ads and sponsorship (optional)
- Use Roblox's in-experience ad formats where available (billboards in the plaza) for extra revenue.
- Rewarded video (if available/compliant): 2× offline earnings, 1 free revive/day.

### 15.9 Revenue model (illustrative)

Assumptions (Month 3, steady state):
- Peak concurrent: 5,000 → about 60,000 daily active users (DAU).
- ARPDAU: 2.0 Robux.
- Daily gross: 120,000 R$ → about 84,000 R$ net after the 30% fee on passes and products.
- Monthly net: about 2.5M R$ → at about $0.0035/R$ DevEx ≈ **$8,800/month**. This doesn't include Premium Payouts or the 18+ boost.

| Scenario | Peak CCU | DAU | ARPDAU (R$) | Monthly DevEx (approx.) |
|---|---|---|---|---|
| Soft | 1,000 | 12k | 1.5 | ~$1,300 |
| Target | 5,000 | 60k | 2.0 | ~$8,800 |
| Hit | 50,000 | 600k | 2.5 | ~$110,000 |
| Viral | 500,000 | 6M | 2.5 | ~$1.1M |

### 15.10 Monetization placement map
```
JOIN ──► Offline earnings popup [2× w/ Pass+]
  │
  ├─► Dock: full stands? ──► [+4 Slots pass]
  │
  ├─► Dive: oxygen <15% ──► [Refill 25R$]   oxygen 0 ──► [2× Oxygen pass]
  │          Leviathan near ──► [Flares]
  │          died ──► [Revive 35R$] ──► 2nd death zone3+ ──► [Instant Resurface pass]
  │          bag full ──► [Big Bag pass]
  │
  ├─► Robbed ──► [Vault Lock pass] [Gate recharge]
  │
  ├─► Near-miss Mythic ("So close!") ──► [Lucky Sonar] [Luck potion]
  │
  ├─► Minute 8 ──► [Starter Pack 99R$, 48h timer]
  │
  └─► Plaza: VIP door, Server Luck Totem, Tide Pass board
```
**Rule:** at most one *unprompted* popup per 10 minutes. Contextual offers (death or empty oxygen) are always fine, because the player can just dismiss them.

---

## 16. Policy & Compliance

| Area | Requirement | Implementation |
|---|---|---|
| **Paid random items** | Odds must be shown before purchase. Restricted in some regions | Show the odds table in the crate UI. Check `PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted` and hide or disable crates for those players. Offer direct-purchase alternatives |
| **Experience Guidelines / Maturity** | Complete the Maturity & Compliance questionnaire | Horror elements: mild fear (creature jump scares). Probably **"Mild"** content label. No blood or gore |
| **Text filtering** | All user text (dock names, trade notes) | `TextService:FilterStringAsync` + `GetNonChatStringForBroadcastAsync` |
| **Chat / social** | Respect `PolicyService` and chat permissions | Use TextChatService defaults |
| **Data privacy** | No personal data collection | Don't store anything but the UserId |
| **Misleading monetization** | No fake timers, no fake prices, no "free Robux" | Starter pack timer is real (stored server-side) |
| **18+ DevEx eligibility** | Game must be "novel" and R15 | R15 rig, original IP |
| **Trading** | Must not enable real-money trading | Trades only in-game items; nothing cashable |
| **Gambling optics** | Avoid "spin to win Robux" | Crates give cosmetics and relics, never Robux |
| **Ads policy** | Respect age-based ad restrictions | Use the official ad APIs only |
| **Copyright** | Original assets only | No borrowed IP, music or meme characters without licences |

---

## 17. First-Time User Experience (FTUE)

**Goal:** a "fun moment" within 60 seconds, the first Rare by minute 3, the first upgrade by minute 2, and understanding raids by minute 10.

| Step | Time | Event | Guidance |
|---|---|---|---|
| 1 | 0:00 | Spawn on your own dock; camera flyover of the ocean with a Leviathan silhouette (hook) | Text: "Your dock. Your treasures. The deep awaits." |
| 2 | 0:10 | Arrow to the dive ramp → jump | Big glowing arrow |
| 3 | 0:20 | Guaranteed Rusty Anchor nearby (Common) | "Hold [E] / tap to salvage" |
| 4 | 0:40 | Guaranteed **Rare** Pirate Doubloon (scripted) with a full reveal effect | The dopamine moment |
| 5 | 1:00 | Oxygen warning → swim up | Tutorial oxygen drains slowly |
| 6 | 1:20 | Place relics on stands → Coins start ticking | "Your relics earn Coins forever!" |
| 7 | 1:45 | Collect Coins → buy Fins L1 | Upgrade unlocked |
| 8 | 3:00 | Second dive, more freedom; free 5-minute Luck potion | |
| 9 | 5:00 | See a server announcement: "PlayerX found a MYTHIC Leviathan Tooth!" | Aspiration |
| 10 | 8:00 | Starter Pack offer | |
| 11 | 10:00 | Raid tutorial: a ghost NPC steals your Common → chase and recover it | Teaches raids safely |
| 12 | 12:00 | Kelp suit goal shown | Next objective |
| 13 | End | "Come back in 4h to collect your offline Coins!" plus a daily-reward calendar preview | Reason to return |

**Daily login calendar:** a 7-day streak (Coins → Pearls → Luck potion → Rare relic → … → Day 7 Epic relic). It resets if you miss a day (or keep it with Pass+).

---

## 18. UI / UX Specification

### 18.1 HUD (mobile first)
```
┌────────────────────────────────────────────────┐
│ [Coins 12.4K +320/s] [Pearls 85]   [⚙] [🛒]    │
│                                                 │
│  Depth: 612m ▼   Zone: Midnight Wrecks          │
│                                                 │
│                                                 │
│ [O₂ ████████░░ 72%]                 [Bag 4/6]  │
│ [Sonar ◎]                [Boost ⇧] [Salvage ✋] │
└────────────────────────────────────────────────┘
```
- Oxygen bar: turns red and pulses under 25%, with a heartbeat sound.
- Depth meter with zone colour bands.
- Buttons at least 48×48 dp for touch.

### 18.2 Screens
1. **Shop** (tabs: Passes, Boosts, Coins, Pearls, Crates, Tide Pass, Cosmetics). The VIP banner is always at the top.
2. **Inventory / Bag** (sort by value or rarity, Sell, Display, Lock as favourite).
3. **Dock Manager** (drag relics onto stands, view CPS).
4. **Upgrades** (track list with a cost and a "MAX" indicator).
5. **Codex** (zone tabs, completion %).
6. **Leaderboards**.
7. **Trading window**.
8. **Settings** (graphics quality, music volume, horror intensity "Lower jump scares" toggle, which is good for retention and parents).
9. **Daily rewards / Quests**.
10. **Rebirth screen** (preview gains).

### 18.3 UX rules
- Every purchase prompt is preceded by an in-game preview of the benefit (e.g. "Double your dive time: 90s → 180s").
- Rarity reveals are skippable after the first 10.
- Number pop-ups (+1,240) on collection feel satisfying.
- Colour-blind safe rarity indicators (icons plus colours).
- Localize at launch: English, Spanish, Portuguese (BR), Indonesian, Filipino, German, French, Russian, Turkish, Thai, Vietnamese. Use Roblox auto-translation plus manual fixes for UI strings.

---

## 19. Art Direction & Audio

### 19.1 Visual style
- **Stylized low-poly, exaggerated silhouettes**, readable on low-end phones.
- Light changes with depth: Reef (bright, saturated) → Trench (near-black with emissive accents).
- **Emissive materials for rare items** stand out in dark zones, which is good for thumbnails and clips.
- Use the `Atmosphere`, `ColorCorrection`, `Bloom` and `DepthOfField` effects, tweened by depth on the client.
- Underwater: a "caustics" texture scrolling on the floor, bubble particles, Terrain Water with custom fog.

### 19.2 Asset list (MVP)
| Category | Count |
|---|---|
| Relic models | 60 (low-poly, 200–1,500 tris each) |
| Mutation VFX | 10 particle and material presets |
| Suits | 6 (as R15 accessory and layered-clothing packs) |
| Creatures | Leviathan (rigged and animated), Eel, Jellyfish, Anglerfish, 20 ambient fish (boids) |
| Environment kits | Reef, Kelp, Wreck, Abyss, Trench (modular) |
| Dock kit | Platform, 30 stands, decor set |
| UI | Icon set (rarity, currencies, buttons), 9-slice frames |

### 19.3 Audio
- **Music:** adaptive layers, from calm reef melody to deep drones to a hunt percussion layer when the Leviathan aggros.
- **SFX:** salvage clicks, a rarity-specific reveal fanfare (each tier sounds different), oxygen alarm, Leviathan roar (directional), steal alarm bell.
- Use only Roblox-licensed audio or commissioned original tracks.

### 19.4 Thumbnail and icon
- **Icon:** a diver's helmet reflecting a glowing red Mythic relic, with the Leviathan eye behind it.
- **Thumbnails (A/B test 4):**
  1. A huge Leviathan mouth chasing a diver holding a glowing relic.
  2. A dock full of glowing relics with a thief sneaking.
  3. A Mythic reveal: "0.05%!" text.
  4. Before/after: Basic suit → Titan suit.

---

## 20. Technical Architecture

### 20.1 Stack
- **Language:** Luau (strict mode, `--!strict`).
- **Tooling:** Rojo (file sync), Wally (packages), Selene (linting), StyLua (formatting), Git and GitHub, TestEZ or Jest-Lua for tests, Lune for CI scripts.
- **Packages:** ProfileStore (data), Promise, Signal, Janitor or Trove (cleanup), optionally ReplicaService or your own replication layer, Fusion or React-lua for UI.
- **Framework:** a lightweight service/controller pattern (Knit-style, without the dependency) for simplicity.

### 20.2 Project structure (Rojo)
```
abyss-salvage/
├─ default.project.json
├─ wally.toml
├─ selene.toml / stylua.toml
├─ src/
│  ├─ server/
│  │  ├─ init.server.luau                 -- boot: loads services in order
│  │  ├─ Services/
│  │  │  ├─ DataService.luau              -- ProfileStore, session lock, schema migration
│  │  │  ├─ MonetizationService.luau      -- passes, products, ProcessReceipt, subscriptions
│  │  │  ├─ PolicyService.luau            -- PolicyService wrapper, region gating
│  │  │  ├─ CurrencyService.luau          -- add/spend Coins/Pearls (single source of truth)
│  │  │  ├─ DiveService.luau              -- oxygen, depth, zone detection, death
│  │  │  ├─ LootService.luau              -- spawn nodes, rolls, pity
│  │  │  ├─ InventoryService.luau         -- bag, relic instances, UUIDs
│  │  │  ├─ DockService.luau              -- plots, stands, CPS, offline earnings
│  │  │  ├─ RaidService.luau              -- steal validation, carry state, cooldowns
│  │  │  ├─ PredatorService.luau          -- Leviathan AI state machines
│  │  │  ├─ UpgradeService.luau
│  │  │  ├─ RebirthService.luau
│  │  │  ├─ TradeService.luau
│  │  │  ├─ QuestService.luau             -- daily/weekly/season quests
│  │  │  ├─ EventService.luau             -- timed events, weather, admin abuse
│  │  │  ├─ LeaderboardService.luau       -- OrderedDataStore
│  │  │  ├─ AnnouncementService.luau      -- server + MessagingService global
│  │  │  ├─ AnalyticsService.luau         -- AnalyticsService funnels/economy events
│  │  │  └─ AdminService.luau             -- whitelisted commands, live config
│  │  └─ Util/
│  ├─ client/
│  │  ├─ init.client.luau
│  │  ├─ Controllers/
│  │  │  ├─ SwimController.luau           -- underwater movement feel
│  │  │  ├─ CameraController.luau
│  │  │  ├─ LightingController.luau       -- depth-based atmosphere
│  │  │  ├─ SonarController.luau
│  │  │  ├─ SalvageController.luau        -- input → request
│  │  │  ├─ HUDController.luau
│  │  │  ├─ ShopController.luau
│  │  │  ├─ RevealController.luau         -- rarity reveal VFX
│  │  │  ├─ AudioController.luau          -- adaptive music
│  │  │  └─ OfferController.luau          -- contextual monetization prompts
│  │  └─ UI/ (Fusion components)
│  └─ shared/
│     ├─ Config/
│     │  ├─ Relics.luau
│     │  ├─ Rarities.luau
│     │  ├─ Mutations.luau
│     │  ├─ Zones.luau
│     │  ├─ Upgrades.luau
│     │  ├─ Passes.luau
│     │  ├─ Products.luau
│     │  └─ Events.luau
│     ├─ Types.luau
│     ├─ Net.luau                         -- remote definitions
│     ├─ NumberFormat.luau
│     └─ WeightedRandom.luau
├─ assets/ (rbxm models)
└─ tests/
```

### 20.3 Server boot order
```
PolicyService → DataService → CurrencyService → MonetizationService → InventoryService
→ DockService → UpgradeService → LootService → DiveService → PredatorService
→ RaidService → TradeService → QuestService → EventService → Leaderboard/Announcement/Analytics
```

### 20.4 Networking
- Define all remotes in `shared/Net.luau`. Name them by intent: `RequestSalvage(nodeId)`, `RequestPlaceRelic(relicId, standIndex)`, `RequestSteal(ownerUserId, standIndex)`, `RequestUpgrade(trackId)`.
- **The client never sends values**, only intent and IDs.
- Server → client: state snapshots and diffs (`InventoryChanged`, `CurrencyChanged`, `DockChanged`) through a replication module.
- Use `UnreliableRemoteEvent` for high-frequency cosmetic updates (sonar pings, predator position hints).

### 20.5 Loot rolling (server)
```lua
--!strict
-- shared/WeightedRandom.luau
local WeightedRandom = {}

function WeightedRandom.pick<T>(entries: {{item: T, weight: number}}, rng: Random): T
	local total = 0
	for _, e in entries do total += e.weight end
	local roll = rng:NextNumber() * total
	for _, e in entries do
		roll -= e.weight
		if roll <= 0 then return e.item end
	end
	return entries[#entries].item
end

return WeightedRandom
```

```lua
--!strict
-- server/Services/LootService.luau (excerpt)
local LootService = {}
local rng = Random.new()

function LootService.RollRelic(player: Player, zoneId: string): RelicInstance
	local profile = DataService.Get(player)
	local luck = MonetizationService.GetLuckMultiplier(player)   -- passes, potions, server boost, rebirth
		* EventService.GetLuckMultiplier()
	local pityBonus = profile.Data.Pity[zoneId] or 0

	local rarityTable = Zones[zoneId].RarityWeights
	local adjusted = {}
	for _, entry in rarityTable do
		local w = entry.weight
		if Rarities[entry.item].Tier >= Rarities.Epic.Tier then
			w *= luck
		end
		if entry.item == "Legendary" then w += pityBonus end
		table.insert(adjusted, {item = entry.item, weight = w})
	end

	local rarity = WeightedRandom.pick(adjusted, rng)
	local relicId = WeightedRandom.pick(Relics.ByZoneAndRarity[zoneId][rarity], rng)
	local mutation = LootService.RollMutation(player, rng)
	local size = math.clamp(1 + rng:NextNumber(-1, 1) * 0.175, 0.8, 1.5) -- tune with normal approx

	-- pity update
	if Rarities[rarity].Tier >= Rarities.Legendary.Tier then
		profile.Data.Pity[zoneId] = 0
	elseif Zones[zoneId].Index >= 4 then
		profile.Data.Pity[zoneId] = math.min(pityBonus + 0.1, 5)
	end

	return InventoryService.CreateRelic(relicId, rarity, mutation, size)
end

return LootService
```

### 20.6 Config pipeline
- The balance sheet (Google Sheets) is exported to CSV, and a Lune script generates `Config/*.luau`.
- **Live config** (event multipliers, prices shown in UI, feature flags) lives in a DataStore key `LiveConfig`, read when the server starts and refreshed through MessagingService, so you can tune without shipping a new version. Roblox's built-in Configs feature also works if it's available.

### 20.7 Underwater movement
- Roblox characters don't swim well in custom setups. Use **Terrain Water** for the native swim state **or** a custom controller:
  - Set Humanoid state to `Swimming` while inside the water region, with custom `VectorForce` buoyancy.
  - Camera-relative 3D movement (move in the direction you're looking). Mobile: joystick plus an up/down button pair.
  - A boost button (drains oxygen 2× while held).
- Prototype both in week 1 and pick based on mobile feel.

---

## 21. Data Model & Persistence

### 21.1 Profile schema (ProfileStore)
```lua
export type RelicInstance = {
	uid: string,          -- HttpService:GenerateGUID(false)
	id: string,           -- "R041"
	rarity: string,
	mutations: {string},
	size: number,
	foundAt: number,      -- os.time()
	foundBy: number,      -- original finder UserId (provenance for trades)
	locked: boolean,      -- favorite lock
}

export type ProfileData = {
	Version: number,                 -- schema version for migrations
	Coins: number,
	Pearls: number,
	LifetimeCoins: number,
	Level: number, XP: number,
	Rebirths: number, RebirthTokens: number, Talents: {[string]: number},
	Upgrades: {[string]: number},    -- trackId -> level
	Suit: string,
	Bag: {RelicInstance},
	Storage: {RelicInstance},        -- overflow inventory
	Stands: {[number]: string?},     -- standIndex -> relic uid
	VaultStands: {[number]: string?},
	Codex: {[string]: {[string]: boolean}}, -- relicId -> mutation -> found
	Pity: {[string]: number},
	LastLogout: number,
	LoginStreak: number, LastLoginDay: number,
	Quests: {Daily: {}, Weekly: {}, SeasonXP: number, SeasonId: string, PremiumTrack: boolean, ClaimedTiers: {number}},
	PurchaseHistory: {[string]: boolean}, -- receipt PurchaseId -> true (idempotency)
	ProductCounts: {[string]: number},    -- analytics
	ActiveBoosts: {[string]: number},     -- boostId -> expiry os.time()
	StarterPackShownAt: number?,
	Settings: {Music: number, SFX: number, LowScare: boolean},
	Stats: {Dives: number, Deaths: number, Steals: number, TimesRobbed: number, DeepestDepth: number, MythicsFound: number},
	Flags: {TutorialDone: boolean, RaidTutorialDone: boolean},
}
```

### 21.2 Persistence rules
- **ProfileStore** with session locking (stops item duplication across servers).
- Autosave every 60–120s and on `PlayerRemoving` and `BindToClose`.
- **Trimming `PurchaseHistory`:** keep the last 500 receipt IDs. Roblox retries unhandled receipts, so keeping recent ones is enough in practice. Don't remove an ID until its grant is saved.
- **Migrations:** a `Migrations` table keyed by version, run on load.
- Leaderboards: separate OrderedDataStores, updated every 5 minutes per player, not on every change.
- **Backups:** profile version history (DataStore versioning) plus an admin rollback tool.

### 21.3 DataStore budget
- Profile reads and writes go through ProfileStore (well within limits).
- OrderedDataStore writes: about 1 per player per 5 minutes × 5 boards. Stay inside the per-server request limits; batch writes.
- MessagingService: global announcements are rate-limited (max 1 per 10s per server; drop extras).

---

## 22. Monetization Code Implementation

### 22.1 Config
```lua
--!strict
-- shared/Config/Passes.luau
return {
	VIP            = { id = 0, price = 249, name = "VIP Diver" },
	DoubleOxygen   = { id = 0, price = 199, name = "2x Oxygen" },
	Drone          = { id = 0, price = 399, name = "Auto-Salvage Drone" },
	LuckySonar     = { id = 0, price = 349, name = "Lucky Sonar" },
	VaultLock      = { id = 0, price = 299, name = "Vault Lock" },
	ExtraSlots     = { id = 0, price = 149, name = "+4 Display Slots" },
	BigBag         = { id = 0, price = 179, name = "Big Bag" },
	InstantSurface = { id = 0, price =  99, name = "Instant Resurface" },
	SpeedFins      = { id = 0, price = 149, name = "Speed Fins" },
	AutoCollect    = { id = 0, price = 129, name = "Auto-Collect" },
	MutationScan   = { id = 0, price = 249, name = "Mutation Scanner" },
	-- Bundles grant multiple keys:
	DeepDiverBundle = { id = 0, price = 499, grants = {"VIP", "DoubleOxygen", "BigBag"} },
	CollectorBundle = { id = 0, price = 699, grants = {"LuckySonar", "MutationScan", "VaultLock"} },
}
-- Replace id = 0 with real Game Pass IDs from Creator Hub.
```

```lua
--!strict
-- shared/Config/Products.luau
return {
	OxygenRefill   = { id = 0, price = 25 },
	Revive         = { id = 0, price = 35 },
	Flares5        = { id = 0, price = 19 },
	GateRecharge   = { id = 0, price = 29 },
	ServerLuck     = { id = 0, price = 199 },
	LuckPotion     = { id = 0, price = 49 },
	MutationPotion = { id = 0, price = 79 },
	CoinsS = { id = 0, price = 49,   incomeMinutes = 20 },
	CoinsM = { id = 0, price = 149,  incomeMinutes = 90 },
	CoinsL = { id = 0, price = 399,  incomeMinutes = 300 },
	CoinsXL= { id = 0, price = 999,  incomeMinutes = 900 },
	CoinsXXL={ id = 0, price = 1999, incomeMinutes = 2160 },
	Pearls100  = { id = 0, price = 49,   pearls = 100 },
	Pearls550  = { id = 0, price = 249,  pearls = 550 },
	Pearls1200 = { id = 0, price = 499,  pearls = 1200 },
	Pearls2600 = { id = 0, price = 999,  pearls = 2600 },
	Pearls7000 = { id = 0, price = 2499, pearls = 7000 },
	StarterPack= { id = 0, price = 99 },
	SkipPity   = { id = 0, price = 149 },
	BarnacleClean = { id = 0, price = 39 },
	CrateSingle= { id = 0, price = 99,  paidRandom = true },
	CrateTriple= { id = 0, price = 299, paidRandom = true },
	RenameDock = { id = 0, price = 25 },
}
```

### 22.2 MonetizationService (core)
```lua
--!strict
-- server/Services/MonetizationService.luau
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Passes = require(Shared.Config.Passes)
local Products = require(Shared.Config.Products)

local MonetizationService = {}
local ownedCache: {[Player]: {[string]: boolean}} = {}
local passIdToKey: {[number]: string} = {}
local productIdToKey: {[number]: string} = {}

for key, p in Passes do passIdToKey[p.id] = key end
for key, p in Products do productIdToKey[p.id] = key end

local function grantPassKey(player: Player, key: string)
	local cache = ownedCache[player]
	if not cache then return end
	local def = Passes[key]
	if def.grants then
		for _, sub in def.grants do cache[sub] = true end
	end
	cache[key] = true
	-- notify client & apply live effects (e.g. bag size, oxygen)
	Net.PassesChanged:FireClient(player, cache)
	MonetizationService.PassGranted:Fire(player, key)
end

function MonetizationService.Owns(player: Player, key: string): boolean
	local cache = ownedCache[player]
	return cache ~= nil and cache[key] == true
end

local function loadOwnership(player: Player)
	ownedCache[player] = {}
	for key, def in Passes do
		if def.id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, def.id)
			if ok and owns then grantPassKey(player, key) end
		end
	end
end

Players.PlayerAdded:Connect(loadOwnership)
Players.PlayerRemoving:Connect(function(p) ownedCache[p] = nil end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passIdToKey[passId] then
		grantPassKey(player, passIdToKey[passId])
		AnalyticsService.LogPurchase(player, "pass", passIdToKey[passId])
	end
end)

-- Product handlers: return true on success
local handlers: {[string]: (Player, any) -> boolean} = {
	OxygenRefill = function(player) return DiveService.RefillOxygen(player) end,
	Revive = function(player) return DiveService.ReviveInPlace(player) end,
	ServerLuck = function(player)
		EventService.StartServerBoost("Luck", 2, 15 * 60, player)
		AnnouncementService.Server(`{player.DisplayName} activated a SERVER LUCK BOOST! 2x luck for 15 minutes!`)
		return true
	end,
	-- Coins packs scale with income
	CoinsS = function(player) return CurrencyService.GrantIncomeMinutes(player, Products.CoinsS.incomeMinutes) end,
	-- ... etc
}

local function processReceipt(receiptInfo): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local profile = DataService.Get(player)
	if not profile then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local purchaseId = receiptInfo.PurchaseId
	if profile.Data.PurchaseHistory[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already handled (idempotent)
	end

	local key = productIdToKey[receiptInfo.ProductId]
	local handler = key and handlers[key]
	if not handler then
		warn("Unknown product", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, result = pcall(handler, player, receiptInfo)
	if not ok or result ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	profile.Data.PurchaseHistory[purchaseId] = true
	profile.Data.ProductCounts[key] = (profile.Data.ProductCounts[key] or 0) + 1

	-- Make sure the grant is saved before acknowledging
	local saved = DataService.SaveNow(player) -- wraps profile save; yields
	if not saved then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	AnalyticsService.LogPurchase(player, "product", key, receiptInfo.CurrencySpent)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

function MonetizationService.GetLuckMultiplier(player: Player): number
	local m = 1
	if MonetizationService.Owns(player, "LuckySonar") then m *= 1.25 end
	if MonetizationService.HasActiveSubscription(player) then m *= 1.10 end
	if BoostService.Active(player, "LuckPotion") then m *= 2 end
	m *= 1 + math.min(DataService.Get(player).Data.Rebirths * 0.02, 0.30)
	return m
end

return MonetizationService
```

> **Important ProcessReceipt rules:** (1) Only one script may set `ProcessReceipt`. (2) Return `NotProcessedYet` whenever anything fails; Roblox retries later. (3) Never grant twice: check the PurchaseId. (4) Only return `PurchaseGranted` after the grant is saved. With ProfileStore's session lock you can also accept that the next autosave persists it; pick one approach and document it.

### 22.3 Subscription check
```lua
-- Check Roblox subscription status (API: MarketplaceService:GetUserSubscriptionStatusAsync)
function MonetizationService.RefreshSubscription(player: Player)
	local ok, status = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(player, SUBSCRIPTION_ID)
	end)
	subCache[player] = ok and status and status.IsSubscribed or false
end
-- Also listen to Players.UserSubscriptionStatusChanged to refresh live.
```
*(Check the exact API names against the current Creator Docs at build time.)*

### 22.4 Paid random item gating
```lua
local PolicyService = game:GetService("PolicyService")
function PolicyWrapper.CanBuyRandomItems(player: Player): boolean
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if not ok then return false end -- fail closed
	return not info.ArePaidRandomItemsRestricted
end
```
The crate UI is shown only if this returns true, **and the server checks again** in the receipt handler. If the check fails, refuse the purchase (`NotProcessedYet` is wrong here; prevent the prompt in the first place). The client must never be able to prompt a restricted product: the server owns `PromptProductPurchase` for crates.

### 22.5 Contextual offer controller (client)
```lua
-- OfferController: decides when to show non-intrusive offers
local COOLDOWN = 10 * 60
local lastUnprompted = 0

Net.OxygenLow.OnClientEvent:Connect(function(pct)
	if pct < 0.15 and not Passes.Owns("DoubleOxygen") then
		HUD.ShowQuickBuy("OxygenRefill") -- small button, not a modal
	end
end)

Net.PlayerDied.OnClientEvent:Connect(function(info)
	DeathScreen.Show({ reviveProductKey = "Revive", timer = 10, bagValue = info.bagValue })
end)

Net.Robbed.OnClientEvent:Connect(function(info)
	if not Passes.Owns("VaultLock") then
		RobbedScreen.Show({ upsell = "VaultLock", thief = info.thiefName })
	end
end)

function OfferController.TryUnprompted(offerKey)
	if os.clock() - lastUnprompted < COOLDOWN then return end
	lastUnprompted = os.clock()
	OfferModal.Show(offerKey)
end
```

---

## 23. Security & Anti-Exploit

| Threat | Mitigation |
|---|---|
| Teleport or speed hacks to reach loot | The server checks the distance from the character to the loot node (≤ 12 studs) and the time since the last salvage. Track the speed of the character's HumanoidRootPart; flag anything over 1.5× the expected max |
| Fake remote calls (spamming salvage or steal) | Per-player rate limiter (token bucket) on every remote; reject and log |
| Remote argument tampering | Type-check every argument (`typeof`), clamp, and look up by ID only |
| Dupes via trade or rejoin | ProfileStore session lock; trades are atomic (both profiles updated in one server step, with relic UIDs moved, never copied); a trade log |
| Dupes via death and bag drops | The bag drop owns the relic UIDs; once picked up they move. Server-only |
| Auto-farm scripts | Loot node positions randomized; occasional "is this a fish?" mini-interaction for AFK loops (optional); diminishing returns on identical routes |
| Steal exploits | Server checks the raider's position inside the victim's dock region, the hold time (server timer), power band and cooldowns |
| Client-side currency display tampering | Visual only; all currency on the server |
| Admin abuse | Admin commands limited to a server-side UserId whitelist, logged to an audit DataStore |
| Ban system | Ban DataStore + Roblox Ban API (`Players:BanAsync`) for confirmed exploiters |

**Rule of thumb:** treat the client as a keyboard and a monitor. It only *asks*; the server *decides*.

---

## 24. Performance Budget

| Metric | Target (low-end mobile) |
|---|---|
| Client FPS | ≥ 30 stable, 60 on mid-range |
| Client memory | < 1.2 GB |
| Server heartbeat | ≥ 55 Hz with 16 players |
| Network receive | < 50 KB/s per client average |
| Parts in view | Use StreamingEnabled; streaming radius tuned per zone |
| Instances | Relic models are instanced from templates; stands use LOD (impostors past 150 studs) |

**Techniques:**
- **StreamingEnabled** on, with `ModelStreamingMode` set per model (docks: Persistent for the owner, Atomic for others).
- Ambient fish: client-side boids (no server replication).
- Predator: the server simulates a simple position and the client interpolates a smooth animated model.
- Lighting tweens on the client only.
- Particle budgets per rarity effect; disable on the low graphics setting.
- Use the Script Profiler and MicroProfiler before every release.

---

## 25. Analytics & KPIs

### 25.1 Funnel events (AnalyticsService custom events and funnels)
```
FTUE funnel: Join → FirstDive → FirstSalvage → FirstRare → FirstDisplay → FirstUpgrade → SecondDive → KelpSuit → RaidTutorial → Session10min
Monetization funnel: ShopOpened → OfferShown(key) → PromptShown(key) → PurchaseCompleted(key)
Economy: CoinsSource(type, amount), CoinsSink(type, amount), PearlsSource/Sink
Progression: ZoneUnlocked(n), Rebirth(n), CodexMilestone(%)
Social: PartyFormed, FriendJoined, TradeCompleted, RaidSuccess/Fail, Robbed
Retention signals: LeviathanEscape, Death(cause, zone), Rage-quit (leave within 30s of death)
```

### 25.2 KPI targets

| KPI | Soft launch gate | Healthy | Breakout |
|---|---|---|---|
| D1 retention | ≥ 25% | ≥ 30% | ≥ 40% |
| D7 retention | ≥ 7% | ≥ 10% | ≥ 15% |
| D30 retention | ≥ 2% | ≥ 4% | ≥ 6% |
| Average session | ≥ 14 min | ≥ 18 min | ≥ 25 min |
| Sessions per DAU | ≥ 1.5 | ≥ 2 | ≥ 3 |
| Payer conversion | ≥ 1.5% | 2–4% | ≥ 5% |
| ARPDAU (R$) | ≥ 1.0 | ≥ 1.5–3 | ≥ 4 |
| Thumbnail click-through | ≥ 5% | ≥ 8% | ≥ 12% |
| Like ratio | ≥ 80% | ≥ 88% | ≥ 92% |
| Avg revenue per paying user / month (R$) | — | 400+ | 800+ |

### 25.3 Dashboards
- Daily: DAU, CCU peak, revenue by SKU, conversion by SKU placement, D1 by cohort.
- Weekly: economy inflation (median Coins/hour by percentile), zone distribution, death causes (balance the Leviathan), raid success rate (aim for 35–50%).
- Use the Roblox Creator Dashboard (Analytics, Monetization, Retention, Engagement) plus custom events.

### 25.4 A/B tests (in order)
1. Thumbnail and icon (Roblox thumbnail personalization / A/B tooling).
2. Starter pack price: 99 vs 149 R$.
3. VIP price: 199 vs 249 vs 299.
4. Revive price: 25 vs 35 vs 49.
5. Offline cap: 4h vs 6h (retention vs. Pass+ conversion).
6. Raid protection length.

Implement this as a deterministic bucket: `hash(UserId) % 100` assigns the variant, and every analytics event carries the variant tag.

---

## 26. Live Operations Plan

### 26.1 Weekly cadence
| Day | Activity |
|---|---|
| Mon | Patch review, data analysis, plan the weekend event |
| Tue–Wed | Build the weekly content |
| Thu | Update teaser on socials and Discord |
| **Fri 4 PM ET** | **Weekly update ships** (new relics, mutation, or feature) |
| Sat | **Admin Abuse Hour** (devs join, trigger global events). Huge CCU spikes |
| Sun | **Mutation Weekend** ends; hotfixes |

### 26.2 Recurring events
| Event | Frequency | Effect |
|---|---|---|
| **Blood Tide** | Every 2h, 5 min | Leviathan ×2, Mythic odds ×3 (risk and reward) |
| **Bioluminescent Bloom** | Random, 10 min | Bioluminescent mutation ×10 |
| **Golden Current** | Hourly, 3 min | Gilded ×5 |
| **Storm Surge** | Weekends | Surface waves, Wet mutation, bonus relic spawns |
| **Kraken Raid** (U2) | Weekly boss | Server co-op boss, exclusive Kraken-touched mutation |
| **Treasure Fleet** | Daily | A sunken fleet spawns in the Wrecks with guaranteed Epic+ chests |

Event timers use `os.time()`-based schedules so every server is in sync (everyone sees the same Blood Tide), which supports "log in now" posts on social media.

### 26.3 Content roadmap (post-launch)
| Update | Week | Headline | Monetization hook |
|---|---|---|---|
| U0 Launch | 12 | Five zones, Leviathan, raids | Core passes |
| U0.1 | 13 | Balance and QoL from launch data | — |
| U0.2 | 14 | 15 new relics, Frozen Tide event | Mutation potion |
| **U1** | 16 | **The Sunken Throne** zone + Drowned King boss + Titan Suit | Titan suit skin bundle |
| U1.1 | 17 | Companions (pets that give perks), hatched from Abyss Eggs | Companion slot pass, egg crates |
| U1.2 | 18 | Trading 2.0 + trade plaza | — |
| **U2** | 20 | **Crews** (guilds) + Crew docks + Kraken weekly boss | Crew banner cosmetics |
| U2.1 | 22 | Submarines (vehicles) | Sub skins, Turbo Sub pass |
| **U3** | 24 | Halloween / Winter seasonal event (depending on date): "Ghost Fleet" | Seasonal Tide Pass |
| U4 | 28 | New ocean biome: "Frozen Sea" (parallel progression) | New zone suits |
| Ongoing | — | New Tide Pass every 6 weeks | Premium track |

### 26.4 Seasonal calendar (from launch)
- **Late Jan:** Lunar New Year "Dragon Pearl" event.
- **Feb:** Valentine's "Heart of the Sea" relics.
- **Apr:** Easter "Egg Hunt in the Abyss".
- **Jun–Aug:** Summer "Beach Bash" (Roblox's biggest season; plan the largest update here).
- **Oct:** Halloween "Ghost Fleet".
- **Dec:** Winter "Frozen Abyss" + advent calendar.

---

## 27. Marketing & User Acquisition

### 27.1 Pre-launch (weeks 6–12)
- **Roblox group:** create it, with group-only playtest perks.
- **Discord server:** channels for announcements, codes, trading, bug reports and clips.
- **TikTok, YouTube Shorts and Reels:** 3–5 clips a week from playtests: Leviathan chases, Mythic reveals, steals. Hook in the first second.
- **Teaser game page:** "Coming soon" with a notify button (Roblox experience events/notifications).
- **Codes system:** redeemable codes (Discord and YouTube) for Coins, Pearls and potions. Codes are great for creator promotion and search ("Abyss Salvage codes").

### 27.2 Launch
- **Sponsored Experiences / Roblox Ads:** start at 10–20k R$/day during the soft launch to test; scale if D1 ≥ 30% and the thumbnail click-through rate ≥ 8%.
- **Creator partnerships:** pay mid-tier Roblox YouTubers and TikTokers (50k–500k subscribers). Give them exclusive codes and early access. Budget $500–$5,000 for the launch week.
- **Launch on a Friday afternoon (US)** to catch weekend traffic.
- **Admin Abuse event** in the first weekend, announced in advance.

### 27.3 Algorithm optimization (Roblox discovery)
- What Roblox's discovery rewards: **engagement (session time), retention, monetization, and how often players come back and invite friends.**
- The friend boost and invite rewards add to social signals.
- Prompt favouriting at positive moments.
- Use Roblox experience notifications (opt-in) for "your offline Coins are full" and event reminders.
- Title and description keywords: "steal", "relic", "ocean", "deep sea", "dive", "treasure", plus the current trending word if it's relevant.
- Update the game icon and thumbnails with every major update.

### 27.4 Community management
- Bug-report form in Discord, triaged weekly.
- Trading channel with scam warnings.
- Content creator program: a "Creator" tag in-game for partners.
- Respond to the top player feedback publicly every week.

---

## 28. Team, Budget & Tooling

### 28.1 Minimum team

| Role | Count | Notes |
|---|---|---|
| Lead / gameplay programmer | 1 | Systems, data, monetization |
| Second programmer (UI / client) | 1 | Fusion UI, controllers, VFX scripting |
| 3D artist | 1–2 | Relics, environments, creatures (or a contractor) |
| Animator | 0.5 | Leviathan, diver animations |
| UI / UX designer | 0.5 | |
| Game designer / economy | 0.5 | Can be the lead |
| Community / marketing | 0.5 | Discord, TikTok, creator outreach |
| QA testers | Volunteer group | Discord playtesters |

**Solo route:** use the Creator Store carefully (licences!), buy kits, outsource relic models (about $15–40 each on freelance marketplaces), and focus your own time on systems.

### 28.2 Budget estimate (to launch)

| Item | Lean | Standard |
|---|---|---|
| 3D assets (60 relics, environment kits, creatures) | $1,500 | $8,000 |
| Animation | $300 | $1,500 |
| UI art | $200 | $1,500 |
| Music and SFX | $0 (licensed library) | $1,000 |
| Thumbnails and icon | $100 | $600 |
| Ads (Robux, about 3 weeks) | 150k R$ (~$1,500 buy-in) | 600k R$ |
| Creator partnerships | $500 | $5,000 |
| **Total (excluding salaries)** | **~$4,000** | **~$25,000** |

### 28.3 Tooling
- Roblox Studio + Rojo + VS Code (Luau LSP).
- GitHub (protected main branch, PR reviews), GitHub Actions running Selene, StyLua checks and unit tests through Lune or run-in-roblox.
- Project management: Notion or Linear board (backlog → sprint → QA → done).
- Balance: Google Sheets.
- Analytics: the Creator Dashboard plus your own data exports.

---

## 29. Production Roadmap (Week by Week)

### Phase 0 — Pre-production (Week 0)
- [ ] Finalize the game name; search Roblox for duplicates.
- [ ] Create the Roblox group, experience shell and Discord server.
- [ ] Set up the repo (Rojo, Wally, linting, CI).
- [ ] Balance sheet v0.

### Phase 1 — Prototype (Weeks 1–2) → *Is it fun?*
- [ ] Week 1: Swimming (Terrain Water vs. custom, decide by day 3), oxygen, depth detection, 1 zone graybox.
- [ ] Week 1: Loot nodes, salvage interaction, server roll, bag.
- [ ] Week 2: Dock plot assignment, stands, CPS ticking, collector pad.
- [ ] Week 2: Basic Leviathan (patrol and chase) in a graybox deep zone.
- [ ] Week 2: **Playtest with 10–20 people.** Questions: does the dive loop feel tense? Do people want "one more dive"?
- **Gate:** at least 60% of testers say they'd keep playing. Otherwise change the loop (e.g. less oxygen pressure, more loot).

### Phase 2 — Vertical slice and MVP (Weeks 3–6)
- [ ] Week 3: DataService (ProfileStore), CurrencyService, InventoryService (UIDs), saving and loading.
- [ ] Week 3: Upgrade system (all tracks), suits and zone gating.
- [ ] Week 4: All 5 zones blocked out → first art pass on zones 1–3.
- [ ] Week 4: Rarity reveal VFX, mutations, size, Codex v1.
- [ ] Week 5: Raid system (steal, carry, steal-back, protections).
- [ ] Week 5: Leviathan full AI (perception, lunge, flares), eels and jellyfish.
- [ ] Week 5: MonetizationService + 6 core passes + 6 core products (VIP, Oxygen, Drone, Vault, Slots, Instant Resurface; Refill, Revive, Flares, Coins S/M/L).
- [ ] Week 6: FTUE tutorial, daily login rewards, offline earnings.
- [ ] Week 6: HUD and all core screens (Fusion), mobile controls.
- [ ] Week 6: Analytics events and funnels.
- [ ] Week 6: Anti-exploit pass, rate limiters.

### Phase 3 — Soft launch (Weeks 7–8)
- [ ] Week 7: Zone 4–5 art, 60 relics, audio pass, adaptive music.
- [ ] Week 7: Leaderboards, server announcements, friend boost.
- [ ] Week 7: Policy checks, maturity questionnaire, localization v1.
- [ ] Week 8: **Soft launch** (public; modest sponsored budget). Collect D1, session length, conversion and click-through rate.
- [ ] Week 8: Fix the top 10 bugs; first balance pass.

### Phase 4 — Polish and monetization depth (Weeks 9–10)
- [ ] All remaining passes, bundles, Starter Pack, Pearls, luck potions, Server Luck Boost.
- [ ] Abyss Pass+ subscription.
- [ ] Tide Pass (season 1) + quests.
- [ ] Resurface (rebirth) + talent tree.
- [ ] Crates (policy-gated) with the odds UI.
- [ ] Events system (Blood Tide, Golden Current, Bloom).
- [ ] Performance pass on low-end Android.
- [ ] Thumbnail A/B test round 1.

### Phase 5 — Full launch (Weeks 11–12)
- [ ] Trading v1 (Level 15+).
- [ ] Codes system.
- [ ] Launch trailer (30s, vertical and horizontal).
- [ ] Creator outreach: 10–20 creators with codes.
- [ ] Load test (fill servers with bots/alt testers; MicroProfiler).
- [ ] **Launch, Friday 4 PM ET.** Admin Abuse Saturday.
- [ ] War room for 72 hours: monitor errors, economy and receipts.

### Phase 6 — Live ops (Week 13+)
- Weekly updates (see Section 26).
- Monthly retrospective on KPIs and decisions on what to build next.

---

## 30. QA & Test Plan

### 30.1 Automated tests
- Unit: WeightedRandom distribution (100k rolls should match the configured weights within ±0.5%), upgrade cost formulas, number formatting, migrations.
- Integration (in Studio): ProcessReceipt idempotency (simulate a duplicate PurchaseId), trade atomicity, steal validation.

### 30.2 Manual test matrix
| Area | Cases |
|---|---|
| Devices | Low-end Android, iPhone, iPad, PC, Xbox controller |
| Purchases | Every pass and product in Studio test mode; buying while dead; buying then leaving immediately; bundle plus an individual pass owned |
| Data | Rejoin quickly (session lock), server shutdown (`BindToClose`), new player vs. migrated profile |
| Raids | Steal at the power-band edges, steal-back, cooldowns, vault immunity, new-player shield |
| Edge cases | Full bag + revive, offline earnings at the cap, rebirth with items on stands, trade during a raid |
| Policy | Crate hidden for a restricted-policy account (test with alt accounts/regions where possible) |

### 30.3 Economy simulation
- A Lune script simulates 1,000 virtual players over 30 days with different play patterns (casual 20 min/day, core 2h/day, whale with all passes) and plots time to milestones. Check against Section 13.3.

---

## 31. Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | The steal-game trend fades before launch | Medium | High | The core is collecting plus danger; raids can be turned down. Pitch the game as "deep-sea adventure" |
| 2 | Swimming feels bad on mobile | Medium | High | Prototype in week 1; consider "walking on the seabed" plus jetpack-style vertical movement as a fallback |
| 3 | Leviathan too scary for young players or parents | Low–Medium | Medium | "Low scare" setting, cartoon art style, Mild content label |
| 4 | Exploiters duplicate relics | Medium | High | Session locks, atomic trades, audit logs, ban API |
| 5 | Copycats clone the game after it takes off | High | Medium | Ship faster, build community, own the IP and brand, weekly content |
| 6 | Raids frustrate new players → churn | Medium | High | New-player shield, power bands, vault slots, steal-back |
| 7 | Pay-to-win perception | Medium | Medium | Passes save time, not exclusive power; public "fair play" FAQ |
| 8 | Paid random items policy changes | Medium | Medium | Crates are optional revenue; direct-buy alternatives |
| 9 | Low thumbnail click-through | Medium | High | Professional thumbnails, continuous A/B testing |
| 10 | Scope creep | High | Medium | Strict MVP; everything else goes into the post-launch updates |
| 11 | DevEx or platform fee changes | Low | Medium | Spread revenue across passes, subscription and Premium Payouts |
| 12 | Server performance with 16 players + predator AI | Medium | Medium | Server AI kept simple, client does visuals, StreamingEnabled |

---

## 32. Launch Checklist

**Game**
- [ ] All zones playable, no blockers
- [ ] FTUE completion ≥ 80% in soft launch
- [ ] No known dupe or exploit bugs
- [ ] Mobile controls verified on 3+ devices
- [ ] Low graphics setting tested

**Monetization**
- [ ] All Game Pass and Developer Product IDs in config (no `id = 0`)
- [ ] Each pass grants correctly on purchase **and** on rejoin
- [ ] Bundles grant their sub-perks
- [ ] ProcessReceipt idempotency verified
- [ ] Subscription perks turn on and off with status
- [ ] Crate odds displayed; PolicyService gating verified
- [ ] Starter Pack timer is real and server-side
- [ ] Prices match the images shown in the shop

**Compliance**
- [ ] Maturity & Compliance questionnaire submitted
- [ ] All user text filtered
- [ ] All assets owned or licensed
- [ ] R15 avatars (18+ DevEx eligibility)

**Platform**
- [ ] Icon + 4 thumbnails + trailer uploaded
- [ ] Description with keywords; social links (Discord, group)
- [ ] Experience notifications set up
- [ ] Private servers enabled and priced
- [ ] Premium benefits on
- [ ] Localization reviewed

**Ops**
- [ ] Analytics funnels firing
- [ ] Admin tools and LiveConfig working
- [ ] Ban system tested
- [ ] Data rollback procedure documented
- [ ] Discord moderation team ready
- [ ] Launch-weekend event scheduled
- [ ] Creator codes distributed

---

## 33. Appendices

### Appendix A — Relic master list template (CSV columns)
```
id,name,zone,rarity,baseCPS,modelAsset,iconAsset,lore,special,eventOnly,releaseUpdate
R001,Rusty Anchor,1,Common,2,rbxassetid://...,rbxassetid://...,"An anchor from a forgotten fishing boat.",,false,U0
```

### Appendix B — Number formatting
```lua
local SUFFIXES = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
local function format(n: number): string
	if n < 1000 then return tostring(math.floor(n)) end
	local i = math.floor(math.log10(n) / 3)
	i = math.min(i, #SUFFIXES - 1)
	local v = n / 10 ^ (i * 3)
	return string.format(v < 10 and "%.2f%s" or v < 100 and "%.1f%s" or "%.0f%s", v, SUFFIXES[i + 1])
end
```

### Appendix C — Rate limiter
```lua
local RateLimiter = {}
RateLimiter.__index = RateLimiter
function RateLimiter.new(maxTokens: number, refillPerSec: number)
	return setmetatable({max = maxTokens, rate = refillPerSec, buckets = {}}, RateLimiter)
end
function RateLimiter:Check(player: Player): boolean
	local now = os.clock()
	local b = self.buckets[player] or {tokens = self.max, t = now}
	b.tokens = math.min(self.max, b.tokens + (now - b.t) * self.rate)
	b.t = now
	self.buckets[player] = b
	if b.tokens >= 1 then b.tokens -= 1 return true end
	return false
end
return RateLimiter
```

### Appendix D — Offline earnings
```lua
function DockService.ComputeOffline(profile, dockCPS: number, player: Player): number
	local now = os.time()
	local elapsed = math.max(0, now - (profile.Data.LastLogout or now))
	local capHours = 4 + UpgradeService.OfflineCapBonus(profile)
		+ (MonetizationService.Owns(player, "VIP") and 2 or 0)
		+ (MonetizationService.HasActiveSubscription(player) and 4 or 0)
	local rate = 0.25 + UpgradeService.OfflineRateBonus(profile)
	local seconds = math.min(elapsed, capHours * 3600)
	return math.floor(dockCPS * rate * seconds)
end
```

### Appendix E — Steal validation (server)
```lua
function RaidService.RequestSteal(raider: Player, ownerId: number, standIndex: number)
	if not limiter:Check(raider) then return end
	if typeof(ownerId) ~= "number" or typeof(standIndex) ~= "number" then return end
	local owner = Players:GetPlayerByUserId(ownerId)
	if not owner or owner == raider then return end

	local rp, op = DataService.Get(raider), DataService.Get(owner)
	if not (rp and op) then return end
	if rp.Data.Level < 5 then return end
	if RaidService.IsShielded(owner) then return end                 -- new player / recently robbed / join lock
	if not RaidService.InPowerBand(raider, owner) then return end
	if RaidService.OnCooldown(raider) then return end
	if not DockService.IsInsideDock(raider, owner) then return end   -- position check
	local uid = op.Data.Stands[standIndex]
	if not uid then return end
	local relic = InventoryService.Find(op, uid)
	if not relic or relic.rarity == "Secret" then return end
	if DockService.PlacedRecently(owner, standIndex, 30) then return end

	RaidService.BeginHold(raider, owner, standIndex, 2.5)           -- server timer; cancels if raider leaves the area
end
```

### Appendix F — Glossary
| Term | Meaning |
|---|---|
| CCU | Concurrent users (players online at the same time) |
| DAU | Daily active users |
| ARPDAU | Average revenue per daily active user |
| ARPPU | Average revenue per paying user |
| CTR | Click-through rate (thumbnail impressions → plays) |
| CPS | Coins per second |
| FTUE | First-time user experience |
| DevEx | Developer Exchange (Robux → USD) |
| Pity | A mechanic that raises your odds after bad luck |
| LiveConfig | Remote config you can change without publishing |

### Appendix G — Sources (market research, Oct 2026)
- Statroblox — Top 100 by live players: https://statroblox.com/leaderboards/playing
- Dor.gg — Popular Roblox games ranking: https://clip.dor.gg/en/blog/roblox-popular-games-ranking
- Adellion — Best Roblox simulator games Oct 2026: https://adellion.com/roblox-simulator-games
- Sportskeeda — Best Roblox games Oct 2026: https://www.sportskeeda.com/roblox-news/best-roblox-games-to-play-right-now
- Robipedia — Live player counts: https://robipedia.com/topic/popular
- LevelUpPlay — Most played: https://levelupplay.my/charts/top-playing
- Wikipedia — Steal a Brainrot: https://en.wikipedia.org/wiki/Steal_a_Brainrot
- Driffle — New & trending Roblox games: https://driffle.com/blog/top-10-new-and-trending-roblox-games/
- Rowatcher — Week in numbers: https://rowatcher.com/news/roblox-week-in-numbers-2026-w39
- ForgeGUI — Roblox game ideas (Jun 2026): https://forgegui.com/blog/10-roblox-game-ideas-blowing-up-june-2026
- Tubefilter — Roblox 42% DevEx hike for 18+: https://www.tubefilter.com/2026/05/01/roblox-hikes-developer-earnings-by-42-but-only-if-they-make-games-aimed-at-adults/amp/
- Roblox Creator Docs — Monetization: https://create.roblox.com/docs/get-started/monetization
- Rowatcher — Monetization strategies 2026: https://rowatcher.com/news/roblox-monetization-strategies-that-actually-work-in-2026
- Rowatcher — DevEx math 2026: https://rowatcher.com/news/devex-math-in-2026-what-you-actually-take-home-per-1-000-players

---

*End of document. Next step: approve the niche and MVP scope, then start the Phase 0 setup and the Week 1 swimming prototype.*
