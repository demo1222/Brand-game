# Implementation Status — Abyss Salvage

This file tracks how the code covers each section of [`ABYSS_SALVAGE_MASTER_PLAN.md`](../ABYSS_SALVAGE_MASTER_PLAN.md).

**Legend:** ✅ implemented in code · 🟡 implemented with a simplification (noted) · 📋 not code (business, art or ops task; checklist below)

> **Verification note.** This code was written without access to Roblox Studio or a Luau toolchain. The first Studio run should be treated as an integration pass. Expect small runtime fixes (property names, physics feel, UI layout). Run `selene src` and `lune run tests/run` first.

## Sections 1–4 · Summary, market, niche, pillars
📋 Design and business context. The pillars show up in code as: danger in deep zones, glowing displays and announcements, a 2–4 minute dive loop, raid guardrails, and the live events system.

## Section 5 · Core loop ✅
- Dock → dive → salvage → escape → display → upgrade. See `DiveService`, `LootService`, `InventoryService`, `DockService`, `UpgradeService`.
- **Escape:** relics are carried in the **Bag** during a dive. They move to **Storage** when you reach your own dock. If you die, you lose the Bag.

## Section 6 · Depth zones ✅
- `Config/Zones.luau` defines five zones with depth bands, oxygen drain, required suit, fog and rarity weights.
- Diving without the right suit causes pressure damage (5% HP per second).
- Air pockets in zones 3–5 (`WorldService`, `DiveService`). Three landmarks per zone.
- 16 docks in a ring around the Harbor plaza.
- 🟡 Landmarks are decoration only. They don't raise loot spawn weights yet.
- 🟡 Zone 6 (Sunken Throne) is Update 1. The Titan suit is in config and marked `ComingSoon`.

## Section 7 · Loot ✅
- Seven rarity tiers and 60 relics (`Config/Relics.luau`). The table from §7.3 is used exactly.
- Pity system: +0.1 per roll in zone 4+, capped at +5.
- 10 mutations, including event-only Wet and Kraken-touched, plus double mutations.
- Size rolls follow an approximately normal distribution from 0.8× to 1.5×, with a "HUGE" label.
- Codex with milestone rewards per zone, and +5% luck in a zone once its Codex is complete.
- **Rolls are server-only** (`shared/LootRoll.luau` + `LootService`). Each node is rolled once per player, when that player first pings it with sonar or salvages it. This keeps sonar previews and the Mutation Scanner honest, and re-pinging can't reroll.

## Section 8 · Dock ✅
- Plot assignment, 6 to 34 stands, 2 vault slots (Vault Lock), a collector pad and the Auto-Collect pass.
- Offline earnings (Appendix D) with a popup and a 2× claim for Pass+ subscribers.
- Laser Gate (Coins upgrade, recharge product), Guard Crab slow, an alarm with an upgradable range, and a 90-second Dock Lock on join.
- Dock rename (dev product + `TextService` filter).

## Section 9 · Raids ✅
- Server-timed 2.5-second hold. The thief carries the relic on their back (−20% speed, highlight, THIEF tag). Anyone who tags the carrier knocks it loose, and a bystander gets a bounty. Reaching your own dock claims the relic.
- Every guardrail from §9.2: power band, cooldown, victim immunity, 3 per hour, 30-second placement protection, Secret items protected, new-player shield, private servers off by default, level 5+.
- Revenge teleport. Raid tutorial with a ghost thief at about 10 minutes of playtime.
- Anti-dupe: the relic stays in the owner's profile until the claim, which happens in a single server step.

## Section 10 · Threats ✅ / 🟡
- Leviathan state machine: Patrol → Investigate → Hunt → WindUp (1 s) → Lunge → Cooldown.
- Sight cone, noise meter (boost, sonar, Cursed relics, Quiet Diver talent), hits for 70% HP, flares distract it for 6 s.
- One Leviathan, plus one per 6 deep divers, doubled during Blood Tide.
- Eels (oxygen hit and knockback) and jellyfish (damage over time and slow).
- Death: bag lost, Vault Lock keeps one relic, revive in place (35 R$ or a Pass+ daily free revive), and a 90-second lootable bag drop.
- 🟡 The Leviathan moves straight through obstacles. It uses direct steering, not PathfindingService. Anglerfish lures, pressure-crack geysers and whirlpools are not built yet.

## Section 11 · Progression ✅
All 10 upgrade tracks, 6 suits, player level and XP. Raiding unlocks at level 5 and trading at level 15.

## Section 12 · Resurface ✅
Requirements and multipliers follow the plan, plus a talent tree with 4 talents. **Design call:** Display Slots are *kept* through a rebirth so the relics on stands stay in place, matching the plan's "keep relics on stands".

## Section 13 · Economy ✅
- Coins, Pearls and Rebirth Tokens. Selling pays 60 × CPS, with a Sell all Commons button.
- Big-number formatting. Analytics economy events.
- `tools/economy_sim.luau` implements §30.3. Run it and compare against §13.3 before you tune.
- 🟡 Event Tokens and the event shop are not built yet.

## Section 14 · Social ✅
- Dive Party (up to 4 players, shared sonar, +10% luck per member).
- Friend boost (+10% each, up to +40%), group perk (set `Economy.Social.GroupId`), invite rewards via `GetJoinData().ReferredByPlayerId`.
- Trading with a two-sided window, 5-second countdown, atomic swap and trade log.
- Server, nearby and global (MessagingService) announcements. Five global leaderboards plus plaza boards.
- 📋 Crews are Update 2.

## Section 15 · Monetization ✅
- 12 passes and 2 bundles. Bundles grant every included key.
- 26 developer products, including income-scaled Coin packs.
- Idempotent `ProcessReceipt` that saves before acknowledging.
- Abyss Pass+ subscription check and perks, Premium perks, VIP / Pass+ / Premium daily chests.
- Starter Pack: shown at 8 minutes, with a server-side 48-hour timer.
- Tide Pass: 50 tiers, free and premium tracks, tier skips.
- Contextual offers follow the §15.10 map, with at most one unprompted offer per 10 minutes.
- 📋 Real Game Pass, Product and Subscription IDs. Private server price. In-experience ads.

## Section 16 · Policy ✅
- Crates are gated by `PolicyService` and fail closed. The server owns the prompt, and exact odds are shown in the Shop.
- Dock names are filtered with `TextService`. Only UserIds are stored. Low-scare setting.
- 📋 Maturity questionnaire, R15 setting, asset licences.

## Section 17 · FTUE ✅ / 🟡
- Scripted first rolls: a Rusty Anchor, then a Rare Doubloon.
- Objective hints with a guiding beam (`TutorialController`), Starter Pack at minute 8, raid tutorial, 7-day login calendar.
- 🟡 There is no opening camera flyover.

## Section 18 · UI ✅
- HUD from §18.1, built mobile-first with buttons of at least 48 px.
- Screens: Shop, Bag & Dock Manager, Upgrades, Codex, Quests & Tide Pass, Resurface, Leaderboards, Players, Trade, Settings, plus the reveal card, death, robbed and offline popups.
- Rarity is shown with icons as well as colours, so it works for colour-blind players.
- **Visual overhaul, Phase 1** ([`UI_OVERHAUL_PLAN.md`](UI_OVERHAUL_PLAN.md)): every relic has a live 3D render (`RelicView`) on collectible cards (`RelicCard`). The Bag & Dock screen is a card grid with a detail panel, and the Codex is a 3D grid with silhouettes for undiscovered relics. The reveal is full-screen with rays and a spinning model. The HUD has currency pills, menu tiles and a responsive scale, the Shop is a tile grid, and Upgrades has progress bars and a 3D suit helmet. Window chrome adds a backdrop and header badges.
- Icons are emoji in gradient badges (`client/UI/Icons.luau`). Put uploaded `rbxassetid://` ids in `Icons.Images` and they replace the emoji with no code changes.
- **Visual overhaul, Phase 2:** buried "glint" loot nodes, a sonar pulse with rarity-tinted node sparkles, animated dock displays with rarity rings, auras and pillars, and coin pop-ups that fly into the HUD. Also restyled: Quests, a horizontal Tide Pass track, a Rebirth before/after view, a Leaderboards podium, Players with avatars, Trade with relic cards, and popup modals.
- 📋 Localization and final UI art. The UI is built in code with plain Instances, not Fusion, so it has no dependencies.

## Section 19 · Art and audio 🟡
- Depth-based lighting (fog, colour correction, bloom, atmosphere).
- Procedural low-poly relic models (`shared/RelicArt`): 60 recognisable models across 51 archetypes, with mutation materials and lights. The dock stands, the thief's carried relic and every UI render share them. `tools/relic_art_check` builds all of them with Lune's Roblox API in CI. Preview: [`docs/images/relic_art_preview.png`](images/relic_art_preview.png).
- Adaptive music system: `AudioController` holds empty asset IDs. Fill them with licensed audio.
- 📋 Final modelled art, animation, music, icon and thumbnails. To swap in a real mesh, change `RelicArt.Build` only.

## Section 20 · Architecture ✅
- Service/controller pattern with Init/Start. Remotes named by intent, and the client never sends values.
- `UnreliableRemoteEvent` for dive status and predator hints.
- LiveConfig through a DataStore plus MessagingService.
- 🟡 Swimming uses a custom controller (LinearVelocity + AlignOrientation while PlatformStood), not Terrain Water. Prototype feel on mobile in week 1, as the plan says.

## Section 21 · Data ✅
- Session-locked DataStore profiles with lock refresh, stale-lock steal and kick on lost lock.
- Autosave every 90 s, plus saves on leave and in `BindToClose`.
- Schema migrations, purchase history trimmed to 500 entries.
- 🟡 Uses a hand-written session lock instead of the ProfileStore package, so it has no dependencies. ProfileStore can replace `DataService` without changing the other services.

## Section 22 · Monetization code ✅
See `MonetizationService.luau`. The handlers cover every product in `Config/Products.luau`.

## Section 23 · Security ✅
- Token-bucket limiter on every remote. Every argument is type-checked.
- Server-timed holds for salvage and steal. Distance checks.
- Movement speed flagging, with a kick after repeated flags.
- Admin whitelist with an audit DataStore. Ban API command.

## Section 24 · Performance 🟡
- Server AI runs at 20 Hz. Hazards and sonar markers are cheap. Lighting is client-only.
- 📋 Turn on StreamingEnabled and profile on a low-end Android device. The world currently relies on server-placed nodes being visible to clients.

## Section 25 · Analytics ✅
- FTUE onboarding funnel, economy events, custom events (purchases, deaths, raids, codex, rebirths).
- Deterministic A/B buckets via `AnalyticsService.Bucket`.

## Section 26 · Live ops ✅ / 📋
- Blood Tide, Golden Current, Bio Bloom (deterministic random), Storm Surge (weekends) and Treasure Fleet all run on `os.time()` schedules, so every server agrees.
- Purchasable server luck. Admin Abuse commands.
- 📋 Weekly content cadence, seasonal events, the U1–U4 roadmap.

## Sections 27–29, 31–32 · Marketing, team, roadmap, risks, launch 📋
These are non-code. See the checklist below.

## Section 30 · QA ✅ / 📋
- `tests/run.luau`: WeightedRandom within ±0.5% over 100k rolls, number formatting, config integrity, loot distribution, formulas.
- 📋 Studio integration tests (receipt idempotency, trade atomicity) and the device matrix.

---

## Remaining non-code checklist (before soft launch)

- [ ] Set the avatar type to R15. Turn on API services. Publish the place.
- [ ] Create the Game Passes, Developer Products and Abyss Pass+ subscription. Put their IDs into `Config/Passes.luau`, `Config/Products.luau` and `Economy.SubscriptionId` (§32: no `id = 0`).
- [ ] Create the Roblox group and set `Economy.Social.GroupId`. Add moderator UserIds to `Economy.AdminUserIds`.
- [ ] Commission or buy final art: 60 relics, suits, creatures, zone kits, UI icons. Licence audio and fill `AudioController.SOUND_IDS`.
- [ ] Prototype swim feel on mobile and tune `Upgrades.Base` and `Config/Zones`.
- [ ] Run `tools/economy_sim`, compare against §13.3, then tune.
- [ ] Submit the Maturity & Compliance questionnaire. Review localization.
- [ ] Make the icon, 4 thumbnails and a trailer. Set up the Discord. Prepare creator codes in `Economy.Codes` or LiveConfig.
- [ ] Load test with 16 players. Turn on StreamingEnabled and profile.
