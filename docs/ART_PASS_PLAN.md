# Art pass: relic models, salvage caches, Megalodon

This is the plan for replacing the weakest 3D art with real Blender meshes. The prompts for the
modelling AI are in `docs/relic_model_prompts.md`.

## What's wrong today

- Every relic is built from Roblox primitives in `shared/RelicArt.luau`. That works for simple
  objects (anchor, bottle, barrel) but falls apart for anything special: idols, masks, cloaks,
  orbs, eyes and hearts read as blobs. The higher the rarity, the worse the gap, because a
  Mythic should feel like a prize and today it looks like a Common.
- The "uncollected" relic in the world is the same sand mound on every node: a sphere, a
  gold foil slab and a neon ball (`LootService.decorateNode`). It doesn't look like treasure,
  and it doesn't change between zones.
- The Megalodon exists twice, as a part-built model (`server/Util/MegalodonBuilder.luau`, about
  650 parts) and as `models/fishes/megalodon.glb`, but it has no gameplay role yet.

## Decisions

1. **Common and Uncommon stay procedural** (23 relics). They are everyday junk and the
   primitive look suits them. Fix single ugly ones later if needed.
2. **Rare keeps its names** (12 relics: spyglass, chest, doubloon and so on). These are real-world
   treasures and the names already work. They get proper meshes.
3. **Epic, Legendary, Mythic and Secret get new identities** (25 relics): mythic names, stronger
   silhouettes, glow and moving parts. This is where the Trident lives.
4. **IDs and rarities don't change.** Saves store relic IDs, and drop rates and income are
   tuned per rarity. Only the name, lore line and model change, so no player loses anything.
   Specials stay on their IDs (R034 points to rares, R041 gives light, R052 is the Leviathan
   drop, R060 shows as a silhouette).
5. **No borrowed names.** "Eye of Cthulhu" is a boss from another game, so the eye relic is
   "Eye of the Sleeper". Lovecraft's own mythos (Deep Ones) is public domain and fine.
6. **Colour stays in code.** Blender models are split into objects by colour role (Main,
   Accent, Trim, Glow, Gem, Glass). `RelicArt` colours them from its palette, so mutations
   (Gilded, Prismatic, Void) keep working on the Main object and no textures need uploading.

## Style: blocky (chosen 2026-11-15)

The owner picked the blocky style from a four-way test on the Starfall Trident
(`models/relics/style_test/trident_styles.png`): everything is built from boxes and wedges, like
Roblox bricks, with flat shading. Rarity is carried by glow and aura instead of surface detail.

## Rarity visual language: the rarer, the louder

Each tier adds aura on top of the tier below. From Legendary up, every relic has its own aura
theme (written in its prompt), so no two rare relics look alike.

| Tier | Mesh (Blender) | Runtime aura (game code) | Triangles |
|---|---|---|---|
| Rare | one small Glow part | soft light, a few sparkles | up to 800 |
| Epic | bigger Glow parts | light, steady sparkles, slow bob | up to 1,500 |
| Legendary | Glow plus one Aura_ part (halo, ring or crown of shards) | coloured light, themed particles, the Aura_ part spins | up to 3,000 |
| Mythic | several Aura_ parts floating around it | strong light, a light pillar, dense themed particles, pulse | up to 5,000 |
| Secret | a dark aura with one bright colour | dark particles, a slow heartbeat pulse | up to 5,000 |

Particles, lights and beams are added in code by rarity (the reveal, the Bag view, dock
stands), so they cost no mesh budget and can be tuned without re-exporting.

## New names for the higher tiers

| ID | Rarity | Zone | Old name | New name |
|---|---|---|---|---|
| R013 | Epic | Reef | Reef Idol | Conch of Calling |
| R023 | Epic | Kelp | Siren's Mirror | Siren's Mirror (kept) |
| R024 | Epic | Kelp | Kelp Monarch Statue | Sceptre of the Kelp Monarch |
| R025 | Legendary | Kelp | Golden Kelp Harp | Harp of the Tidesong |
| R033 | Epic | Wrecks | Admiral's Medal | Medal of the Lost Fleet |
| R034 | Epic | Wrecks | Captain's Compass | Compass of Lost Things |
| R035 | Epic | Wrecks | Kraken Ink Map | Kraken's Ink Chart |
| R036 | Legendary | Wrecks | Wreck Figurehead | Figurehead of the Weeping Queen |
| R037 | Legendary | Wrecks | Cursed Cutlass | Blackwater Cutlass |
| R038 | Mythic | Wrecks | Sunken Galleon Bell | Bell of the Last Voyage |
| R041 | Legendary | Abyss | Lantern of the Deep | Lantern of the Deep (kept) |
| R044 | Epic | Abyss | Bioluminescent Orb | Bottled Starjelly |
| R045 | Epic | Abyss | Deep One Totem | Totem of the Deep Ones |
| R046 | Epic | Abyss | Vampire Squid Cloak | Inkshroud Cloak |
| R047 | Legendary | Abyss | Obsidian Mask | Mask of the Faceless Tide |
| R048 | Legendary | Abyss | Leviathan Scale | Leviathan Scale Shield |
| R049 | Mythic | Abyss | Starlight Coral | Starfall Trident |
| R050 | Mythic | Abyss | Abyss Eye | Eye of the Sleeper |
| R051 | Secret | Abyss | Whisper Shell | Whispering Nautilus |
| R052 | Mythic | Trench | Leviathan Tooth | Leviathan's Fang |
| R056 | Epic | Trench | Trench Hydra Fang | Hydra Fang Dagger |
| R057 | Epic | Trench | Red Vent Idol | Idol of the Furnace Below |
| R058 | Mythic | Trench | Crown of the Drowned King | Crown of the Drowned King (kept) |
| R059 | Legendary | Trench | Titan's Gauntlet | Gauntlet of the Abyssal Titan |
| R060 | Secret | Trench | Heart of the Trench | Heart of the Trench (kept) |

The Trident took the Starlight Coral slot: it keeps the "stars fell into the sea" lore, now
as star-metal prongs with coral grown over the shaft.

## The uncollected form: salvage caches

Replace the sand mound with one cache model **per zone**, not per rarity: the look must not
give away the server roll (sonar reveals rarity, as now). Each cache has a `Lid` object, so a
dig animation can crack it open before the relic pops out.

| Zone | Cache |
|---|---|
| Sunlit Reef | a giant clam half-buried in sand, lips parted, gold glinting inside |
| Kelp Twilight | a barnacled lobster trap wrapped in kelp, something shining in it |
| Midnight Wrecks | the corner of a sea chest sticking out of silt, a broken plank across it |
| The Abyss | a cracked rock geode whose cracks glow in the zone colour |
| The Trench | a basalt vent nodule, cracks glowing orange, small smoke vent on top |

## Megalodon: the monster that gets in the way

The Leviathan owns the deep (800 m and below) and kills. The Megalodon should cover the middle
water (Kelp Twilight and Midnight Wrecks, 150–800 m) and be a **nuisance, not a killer**: its
job is to break up digging.

- **Patrol:** circles the densest cluster of salvage caches in its zone. A dorsal fin shadow
  and a low music sting tell you it's close. Sonar shows it as a red blip.
- **Interferes with digging:** holding to dig makes noise. If it sees or hears you mid-dig,
  it charges. A hit knocks you back, cancels the dig and costs a chunk of oxygen (not health),
  so the threat is losing time, not dying.
- **Steals caches:** if nobody is digging it, it can swallow a cache, which respawns elsewhere
  in the zone. Players learn to dig fast near it.
- **Counterplay:** hide in kelp or inside a wreck (it loses sight), throw a flare (it chases
  the light, as the Leviathan does), or bait it with a fish from the shop.
- **Tuning start point:** patrol 16 studs/s, charge 40 studs/s, sight 50 studs, hear 100
  studs, knockback 60 studs/s, oxygen cost 15% of max, cooldown 6 s.

The `PredatorService` Leviathan loop (patrol, investigate, hunt, lunge, cooldown, flare) is
the right base; the Megalodon is a second predator kind with different numbers and a
knockback instead of damage.

**Model:** a rigged, skinned mesh beats 650 anchored parts for both looks and performance.
The prompt asks for a rig (spine, jaw, tail, pectoral fins) that `MegalodonAnimator` can drive
with Bone transforms. The existing `megalodon.glb` can be the starting point if its shape is
good.

## Order of work

1. **Approve names and concepts.** Edit the table above or the prompts before any modelling.
2. **Pilot three models** to lock the style before the batch:
   - R021 Pirate Doubloon: the first rare every player gets (FTUE)
   - R049 Starfall Trident: the flagship Mythic
   - the Sunlit Reef cache: the first thing a new player digs

   Import them into Studio and check them in the Bag grid, the reveal card, on a dock stand
   and in the world.
3. **Mesh hook in code** (only `RelicArt.Build` changes, as the file header says):
   - if `ReplicatedStorage.RelicMeshes[def.Id]` exists, clone it
   - colour each part from the palette by its name (Main, Accent, Trim, Glow, Gem, Glass)
   - spin any `Spin_*` part
   - otherwise fall back to the current procedural recipe

   New names and lore go into `Config/Relics.luau`, with IDs kept.
4. **Batch by tier:** Mythic and Secret (7), then Legendary (7), Epic (11), Rare (12). The
   rarest first, because players chase those and screenshot them.
5. **Salvage caches** in `LootService.decorateNode`, one model per zone.
6. **Megalodon:** rigged model, then the predator kind in `PredatorService`.
7. **Icons:** render the new meshes to icon PNGs from the same camera, so the Bag, Codex and
   HUD icons match the models.

## Status (2026-11-15)

- Pilots built in Blender, uploaded as Model assets and inserted into
  `ReplicatedStorage.RelicMeshes` (R021 `138551824910166`, R049 `117722556428460`,
  CACHE_REEF `86216966481980`). IDs and colours are in `shared/Config/RelicMeshes.luau`.
- `RelicArt.Build` uses a template when one exists and falls back to the recipe otherwise.
  Meshes are turned 180° on build, because Blender fronts face -Z and RelicView looks from +Z.
- Zone 1 dig sites use the clam (`LootService.decorateWithCache`). Checked in a play test: all 45
  spawn, sitting on the floor. The colours were made more saturated after the test, because
  pastels vanished in the reef fog.
- Checked in Studio: the world display, the Bag-style ViewportFrame cards (220 px and 96 px),
  and the Gilded mutation.
- **All 37 Rare-and-up relics and all 5 dig sites are now blocky meshes** (built with
  `tools/blender/run_relics.py`). 35 relics and 4 caches shipped as two bundle assets
  (`Bundles` in `RelicMeshes.luau`). Checked in Studio: all 37 in ViewportFrame cards, the real
  Bag window, and dig sites in every zone (195/195 in a play test). New names and lore are live in
  `Config/Relics.luau`.
- Dev panel (`DevService`, `DevController`, Studio admins only): checked opening it and running
  Give all relics, +1B coins and Max upgrades in a play test.
- Weakest models to revisit: R037 Blackwater Cutlass, R043 Gulper Skull.
- **Auras are live** (`shared/RelicAura.luau`):
  - World relics get a rarity light and sparkles. Legendary and up add rising motes. Mythic and
    Secret add a light pillar (a Beam), and Secret uses dark smoke.
  - `RelicArt.BuildFromMesh` decorates the model and tags it `RelicAura`. On each client,
    `RelicAuraController` animates tagged relics within 160 studs.
  - Cards (`RelicView`) animate the same parts and add a pulsing rarity glow for Epic and up.
  - Motion: Spin_ parts turn, orbit clouds circle the relic, rings and halos breathe, other Aura_
    parts bob, and Spin_Lid (Eye of the Sleeper) blinks.
  - Checked in a play test: every aura type moves, the pillars show, and the Bag cards glow under
    the model.
  - Watch out: `PrimaryPart` can replicate after the model, so the controller waits for it instead
    of dropping the model.
  In ViewportFrames, Neon has no bloom, so the Trident's halo reads as plain white-cyan. A
  rarity glow behind the card would carry it.

## Where files go

- `models/relics/<ID>_<snake_name>.glb`: one per relic
- `models/relics/previews/<ID>.png`: 512 px preview renders for review
- `models/caches/<zone>_cache.glb`
- `models/fishes/megalodon_rigged.glb`

Uploaded mesh IDs or packaged models live in Studio under `ReplicatedStorage.RelicMeshes`. Per
CLAUDE.md, the keepers also get a rebuild path in `src/` (the mesh hook plus an ID table).
