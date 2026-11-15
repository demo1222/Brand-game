# Blender prompts: relics, caches, Megalodon

How to use: give the modelling AI the **shared brief** once, then one item prompt at a time.
Each item prompt names its ID, colours, parts and budget. The plan behind these is in
`docs/ART_PASS_PLAN.md`.

Start with the three pilots (R021, R049, the Sunlit Reef cache), check them in Studio, then
batch the rest.

---

## Shared brief (paste first, every session)

```text
You are modelling game assets in Blender for "Abyss Salvage", a Roblox game about diving for
sunken relics. Work through Blender's Python API.

STYLE: BLOCKY
- Build everything from boxes and wedges, like Roblox bricks. Round things become square
  sections: a shaft is a square column, a ball is a cube, a curve is a chain of short
  straight blocks. No smooth surfaces, no bevels, flat shading.
- A bold, readable silhouette first; detail second. Slightly exaggerated proportions: thick
  rims, oversized gems, big heads and handles.
- It must read instantly as a 64 px thumbnail on a dark navy card. No detail smaller than about
  3% of the object's length.
- Avoid very dark colours on large parts: they vanish on the dark card.

AURA: THE RARER, THE LOUDER
- Rarity shows through glow and aura, and every Legendary and above has its own aura theme
  (given in the item prompt), so no two look alike.
- Rare: one small Glow part. Epic: bigger Glow parts. Legendary: Glow plus one Aura_ part
  (a blocky halo, ring or crown of shards). Mythic: several Aura_ parts that float around
  the object. Secret: the aura is dark, with one bright colour.
- Model Aura_ parts as blocky shards, cubes or rings, each a separate object with its origin
  at its pivot. Particles and lights are added in game code, not in Blender.
- Keep glow colours saturated, not white: emission strength about 1.5 in the preview.
- Underwater wear where it fits: a few barnacles, a coral sprig, a chipped edge. Never so much
  that it hides the shape.
- No realistic gore, no real logos, no real writing systems (use invented glyphs), and no
  copies of characters or items from other games or films.

SCALE AND ORIENTATION
- Longest side exactly 2.0 m. Origin at the centre of the bounding box. Apply all transforms.
- The front faces Blender -Y (what you see in Front view). Design for a 3/4 view from the
  front, slightly above.

OBJECTS AND COLOUR
- Split the model into separate mesh objects by colour role. Use only these names (skip any
  that are not needed): Main, Accent, Trim, Glow, Gem, Glass, plus Aura_<what> and
  Spin_<what> parts. Salvage caches also use Lid, and the Megalodon also uses Eyes. If a role needs two separate pieces, join them into one
  object.
- Main is the body. The game recolours it for mutations, so it must be the largest piece.
- Glow is everything that emits light. The game makes it Neon.
- One material per object, named the same as the object, with the plain base colour given in
  the item prompt. No textures and no UV work: the game colours the parts in code.
- Moving parts are separate objects named Spin_<what> (for example Spin_Ring), with their
  origin at the pivot they turn around. Say in your reply which axis they should turn on.
- Parent everything to an empty named after the item ID.

GEOMETRY
- Stay inside the triangle budget for the rarity (all objects together): Rare 800,
  Epic 1,500, Legendary 3,000, Mythic and Secret 5,000. Blocky models need far fewer
  triangles than the budgets in older prompts; use these numbers.
- Triangulate on export, no n-gons, no loose vertices, no interior faces, normals pointing out.

OUTPUT
- Export glTF binary (.glb), +Y up, selected objects only, modifiers applied, to the path the
  item prompt gives.
- Render a 512x512 preview: 3/4 front-high camera, background #14213D, a soft key light from
  the top left and a cool rim light from behind. Glow objects use an emission shader in the
  preview only. Save it next to the model in a "previews" folder as <ID>.png.
- Reply with: triangle count per object, the Spin axes, and anything you had to simplify.
```

---

## Pilots

Built and exported in the blocky style on 2026-11-15 (previews in
`models/relics/previews/`). Treat the files as the reference for every other model: each
object is named `<ID>_<Role>` (for example `R021_Main`). The Doubloon added Gem for the dark
eye holes, and the cache added LidInner, a warm inner face on the lid, so the open shell
doesn't render as a dead grey.

### R021 Pirate Doubloon (Rare, Kelp Twilight)

```text
ID R021 "Pirate Doubloon". Lore: "Stamped with a skull and a wave." This is the first rare
item every new player finds, so it has to feel like real treasure.
SHAPE: one thick, chunky gold coin standing on its edge, tilted back about 15 degrees. The
rim is a raised, rope-twisted ring. The face shows a raised skull in profile above a curling
wave. Two small chips are bitten out of the edge, and a tiny barnacle cluster sits on the rim.
The back shows a simple compass rose.
OBJECTS: Main = coin body (#FFC440). Accent = skull and wave relief (#E8A21C). Trim = barnacles
(#D9D2BF).
BUDGET: 2,000 triangles. FILE: models/relics/R021_pirate_doubloon.glb
```

### R049 Starfall Trident (Mythic, The Abyss)

```text
ID R049 "Starfall Trident". Lore: "Stars fell into the sea, once. One of them was forged."
This is the game's flagship Mythic.
SHAPE: a tall trident, standing upright. Three prongs of pale star-metal. The middle prong is
longest; the outer two curve outwards like wave crests and each has a barbed tip. Where the
prongs meet sits a five-pointed star gem, glowing. The shaft is dark sea-wood with spiralling
gold bands, and pink coral has grown over its lower third. A small crescent counterweight is at
the base. Three small star-shaped shards orbit the head.
OBJECTS: Main = prongs and head (#F2E6B8). Accent = shaft (#2B2440). Trim = gold bands and
counterweight (#FFC440). Gem = coral (#FF7A8A). Glow = star gem and the channels running
down each prong (#7FE8FF). Spin_Shards = the three orbiting shards (#BFF6FF), pivot on the
shaft axis at the height of the star gem, turning around the vertical axis.
AURA: the three orbiting star shards, a square halo ring behind the head, and a thin light pillar rising from the star gem (#7FE8FF).
FILE: models/relics/R049_starfall_trident.glb
```

### Sunlit Reef cache (the uncollected form, zone 1)

```text
ID CACHE_REEF "Sunlit Reef salvage cache". This sits on the sea floor where a relic is
buried. It must look like treasure without hinting at which relic is inside.
SHAPE: a giant clam half-buried in a low mound of sand, lips parted a hand's width. Gold
glints inside the gap. Two small starfish and a sprig of coral sit on the sand. The top half of
the shell is a separate object so the game can open it.
SIZE: unlike the relics, this is 3.4 m wide. The origin sits at the base, centred.
OBJECTS: Main = sand mound (#D8C59A). Accent = lower shell (#E9B9A6). Lid = top shell (#E9B9A6),
origin on the hinge at the back. Trim = starfish and coral (#FF8A5C). Glow = the gold glint
inside (#FFD45A).
BUDGET: 3,000 triangles. FILE: models/caches/reef_cache.glb
```

---

## Rare (keep the name, new mesh)

### R011 Scuba Mask '78

```text
ID R011 "Scuba Mask '78". Lore: "Signed by a famous diver."
SHAPE: a retro oval dive mask with a single wide glass pane and a chunky chrome rim. A thick
rubber skirt, and a strap with a square buckle on each side, curled behind the mask. A small
brass plate on the strap carries a scribbled signature shape (a squiggle, not letters).
OBJECTS: Main = rubber skirt and strap (#F2B33D). Accent = chrome rim and buckles (#C9CED6).
Glass = pane (#AEE3FF). Trim = brass plate (#C8963E).
FILE: models/relics/R011_scuba_mask_78.glb
```

### R012 Mermaid Comb

```text
ID R012 "Mermaid Comb". Lore: "Carved from a single whale tooth."
SHAPE: a wide comb with nine thick teeth. The back is a fan, carved in relief with a curling
mermaid tail. A small pearl is set where the tail fin splits.
OBJECTS: Main = comb (#EDE2C8). Accent = tail relief (#CBB892). Gem = pearl (#F7F0FF).
FILE: models/relics/R012_mermaid_comb.glb
```

### R020 Silver Spoon Set

```text
ID R020 "Silver Spoon Set". Lore: "From the captain's table."
SHAPE: three ornate spoons fanned out and tied at the handles with a faded red ribbon bow.
Each handle ends in a small anchor crest. One spoon bowl has a tiny dent.
OBJECTS: Main = spoons (#D3D8E0). Accent = ribbon (#B8343F). Trim = anchor crests (#F0C860).
FILE: models/relics/R020_silver_spoon_set.glb
```

### R022 Jade Turtle

```text
ID R022 "Jade Turtle". Lore: "Said to bring long life."
SHAPE: a carved jade turtle figurine, head raised and looking up. The shell has raised
hexagon plates outlined with thin gold inlay. It sits on a small round base carved like a
lotus.
OBJECTS: Main = turtle (#3FAE7A). Trim = gold inlay (#FFC440). Accent = base (#2E6B55).
FILE: models/relics/R022_jade_turtle.glb
```

### R030 Brass Spyglass

```text
ID R030 "Brass Spyglass". Lore: "Shows a ship that isn't there."
SHAPE: an extended spyglass in three telescoping brass sections, with a leather grip wrapped
around the widest section. A lens cap hangs from a short chain. The front lens glows faintly.
Lay it diagonally on a small coil of rope.
OBJECTS: Main = brass tubes (#D2A04A). Accent = leather and rope (#6B4428). Trim = chain and
cap (#8A8F99). Glow = lens (#9FD8FF).
FILE: models/relics/R030_brass_spyglass.glb
```

### R031 Ghost Lantern

```text
ID R031 "Ghost Lantern". Lore: "The flame is cold."
SHAPE: a ship's hurricane lantern with a verdigris frame, a glass chimney and a ring handle.
Inside, a cold flame shaped like a small wisp with two hollow eye spots.
OBJECTS: Main = frame (#4F8F7E). Glass = chimney (#CFEFFF). Glow = flame (#7DFFD4).
Trim = handle and base (#2F3A3F).
FILE: models/relics/R031_ghost_lantern.glb
```

### R032 Treasure Chest

```text
ID R032 "Treasure Chest". Lore: "Finally, a classic."
SHAPE: a classic domed sea chest, lid open about 30 degrees. Iron bands with rivets, a big
lock plate on the front. Gold coins and a string of pearls spill over the front edge. The game
also shows this chest in Gilded, Prismatic and Void versions by recolouring Main, so Main must
be the wooden body only.
OBJECTS: Main = wood body and lid (#8A5A34). Accent = iron bands and lock (#3A3D45).
Trim = coins (#FFC440). Gem = pearls (#F7F0FF).
FILE: models/relics/R032_treasure_chest.glb
```

### R042 Abyssal Pearl

```text
ID R042 "Abyssal Pearl". Lore: "Black as the water around it."
SHAPE: a large black pearl, a third of the object's height, resting in a dark open clam.
A thin glowing purple line runs around the inside lip of the shell.
OBJECTS: Gem = pearl (#1B1726). Main = clam (#3B3550). Glow = lip line (#B57BFF).
FILE: models/relics/R042_abyssal_pearl.glb
```

### R043 Gulper Skull

```text
ID R043 "Gulper Skull". Lore: "Mostly mouth."
SHAPE: the skull of a deep-sea gulper eel. A tiny cranium with big round eye sockets and an
enormous hinged jaw, opened wide, with rows of thin needle teeth. Bleached bone.
OBJECTS: Main = skull and jaw (#E6DCC4). Accent = teeth (#FFFFFF). Glow = a faint glint deep
in each eye socket (#7FE8FF).
FILE: models/relics/R043_gulper_skull.glb
```

### R054 Ancient Ruin Tablet

```text
ID R054 "Ancient Ruin Tablet". Lore: "A language no one speaks."
SHAPE: an upright stone tablet with a rounded top, one corner broken off. Carved rows of
invented glyphs (spirals, waves, eye shapes) glow from inside. A few barnacles cling to the
broken edge.
OBJECTS: Main = stone (#7C8590). Glow = glyphs (#63E6FF). Trim = barnacles (#D9D2BF).
FILE: models/relics/R054_ancient_ruin_tablet.glb
```

### R055 Pressure Diamond

```text
ID R055 "Pressure Diamond". Lore: "Forged by the whole ocean's weight."
SHAPE: a large brilliant-cut diamond wedged at an angle into a chunk of dark basalt. A soft
light glows from the diamond's core.
OBJECTS: Gem = diamond (#DDF4FF). Main = basalt (#2E2B30). Glow = inner core (#FFFFFF), a
small shape inside the diamond.
FILE: models/relics/R055_pressure_diamond.glb
```

---

## Epic (new identity)

### R013 Conch of Calling (was Reef Idol)

```text
ID R013 "Conch of Calling". Lore: "Blow it, and every fish in the reef turns to look."
SHAPE: a big spiral conch horn lying on its side, mouth facing the viewer. The outside is
cream with orange bands; the flared lip is glossy coral pink. A gold mouthpiece caps the
pointed end, held by a gold band set with three turquoise gems. Two small fish-shaped gold
charms hang from the band on short chains.
OBJECTS: Main = shell (#F3E2C4). Accent = lip and inner mouth (#FF8FA0). Trim = gold
mouthpiece, band, charms (#FFC440). Gem = turquoise (#36D6C3).
FILE: models/relics/R013_conch_of_calling.glb
```

### R023 Siren's Mirror

```text
ID R023 "Siren's Mirror". Lore: "Don't look too long."
SHAPE: an ornate hand mirror. The oval frame is made of twisting kelp strands and small
shells. The handle is a siren's tail curling down to a fin. The glass is dark, with a faint
glowing outline of a face looking out.
OBJECTS: Main = frame and handle (#3F9E8C). Trim = shells (#F2D7C0). Glass = mirror
(#1C2B3A). Glow = face outline (#9AF7FF).
FILE: models/relics/R023_sirens_mirror.glb
```

### R024 Sceptre of the Kelp Monarch (was Kelp Monarch Statue)

```text
ID R024 "Sceptre of the Kelp Monarch". Lore: "The forest's forgotten ruler."
SHAPE: an upright sceptre. The staff is wrapped in spiralling kelp ribbons. At the top, a
carved green-stone hand grips a glowing seed pod. Gold bands sit under the hand and at the
base.
OBJECTS: Main = staff and hand (#3E7F5A). Accent = kelp ribbons (#7BC25B). Trim = gold
bands (#FFC440). Glow = seed pod (#C9FF6B).
FILE: models/relics/R024_kelp_monarch_sceptre.glb
```

### R033 Medal of the Lost Fleet (was Admiral's Medal)

```text
ID R033 "Medal of the Lost Fleet". Lore: "Awarded to a crew that never came home."
SHAPE: a large eight-pointed star medal hanging from a short, tattered ribbon. In the centre,
an enamel disc shows a small sailing ship in relief. A faint ghostly light seeps from the
enamel.
OBJECTS: Main = star (#E4B54A). Accent = ribbon (#2E4D9A). Gem = enamel disc (#4E7BD9).
Glow = ghost light around the ship (#A8F0FF).
FILE: models/relics/R033_medal_of_the_lost_fleet.glb
```

### R034 Compass of Lost Things (was Captain's Compass)

```text
ID R034 "Compass of Lost Things". Lore: "It doesn't point north. It points to treasure."
(In game it points to a nearby rare.)
SHAPE: an open brass pocket compass, lid raised at 100 degrees, with a wave engraving on the
inside of the lid. Inside, the needle floats above the dial: a glowing arrow shaped like a
small fish. Make the needle a separate spinning object.
OBJECTS: Main = case and lid (#C8963E). Accent = dial face (#F2E6C8). Spin_Needle = needle
(#FF6B5C), pivot at the dial centre, turning around the dial's axis. Glow = a ring under the
needle (#FFD45A).
FILE: models/relics/R034_compass_of_lost_things.glb
```

### R035 Kraken's Ink Chart (was Kraken Ink Map)

```text
ID R035 "Kraken's Ink Chart". Lore: "Drawn in something darker than ink."
SHAPE: a half-unrolled parchment map. A purple tentacle curls around one end and holds the
roll open. The map shows a large X and a swirl of islands as raised, inked shapes. A small
pool of glowing purple ink spills from one corner.
OBJECTS: Main = parchment (#E9D7A8). Accent = tentacle (#7B3FA0). Trim = inked shapes
(#2A1E3A). Glow = ink pool and the X (#C27BFF).
FILE: models/relics/R035_kraken_ink_chart.glb
```

### R044 Bottled Starjelly (was Bioluminescent Orb)

```text
ID R044 "Bottled Starjelly". Lore: "Pulses like a heartbeat."
SHAPE: a round glass jar with a cork, tied with rope at the neck. Inside, a glowing jellyfish
with a domed bell and curling tentacles floats in the middle. The jellyfish is its own object
so the game can pulse it.
OBJECTS: Glass = jar (#BFE9FF). Main = cork and rope (#A07A4E). Glow = jellyfish
(#7FFFE0).
FILE: models/relics/R044_bottled_starjelly.glb
```

### R045 Totem of the Deep Ones

```text
ID R045 "Totem of the Deep Ones". Lore: "Who carved this, down here?"
SHAPE: a stacked totem of three fish-frog faces, each wider at the mouth, carved from
green-black stone. Big round eyes glow. The top face wears a crown of three tall fin-spikes.
A few barnacles cling to the base.
OBJECTS: Main = stone (#2F4A44). Accent = carved mouths and fins (#4E7A6A). Glow = eyes
(#7DFFC0). Trim = barnacles (#D9D2BF).
FILE: models/relics/R045_totem_of_the_deep_ones.glb
```

### R046 Inkshroud Cloak (was Vampire Squid Cloak)

```text
ID R046 "Inkshroud Cloak". Lore: "Soft, dark and unsettling."
SHAPE: a hooded cloak standing as if worn by an invisible figure. The hem is cut into eight
webbed points like a vampire squid's arms, each tipped with a small soft spike. Inside the
empty hood, two glowing blue eye spots.
OBJECTS: Main = cloak (#6E1F33). Accent = inner lining (#2A0F18). Trim = spikes (#E9C7CF).
Glow = eye spots (#62C8FF).
FILE: models/relics/R046_inkshroud_cloak.glb
```

### R056 Hydra Fang Dagger (was Trench Hydra Fang)

```text
ID R056 "Hydra Fang Dagger". Lore: "There were three of them."
SHAPE: a dagger whose blade is a single curved, ivory fang. The crossguard is three small
serpent heads facing outwards. The grip is wrapped in dark leather, ending in a round
pommel with a red gem.
OBJECTS: Main = fang blade (#EEE4CC). Accent = serpent heads (#3F6F4A). Trim = grip
(#3A2A22). Gem = pommel (#E0303F). Glow = a thin line along the fang's edge (#9DFF7A).
FILE: models/relics/R056_hydra_fang_dagger.glb
```

### R057 Idol of the Furnace Below (was Red Vent Idol)

```text
ID R057 "Idol of the Furnace Below". Lore: "Glows the colour of the vents."
SHAPE: a squat, seated basalt idol with a big head, hands resting on a round belly. The mouth
is open, with fire inside. Cracks across the body glow orange like lava.
OBJECTS: Main = basalt (#3A2F2E). Glow = mouth fire and cracks (#FF7A2A). Accent = carved
brow and hands (#5A4440).
FILE: models/relics/R057_idol_of_the_furnace_below.glb
```

---

## Legendary (new identity)

### R025 Harp of the Tidesong (was Golden Kelp Harp)

```text
ID R025 "Harp of the Tidesong". Lore: "Plays itself in the current."
SHAPE: a golden harp whose curved frame is a breaking wave, the crest curling over the top.
Kelp wraps the front pillar. Pearl finials sit at the tips. Seven glowing strings.
OBJECTS: Main = gold frame (#FFC440). Accent = kelp (#4FA35E). Gem = pearls (#F7F0FF).
Glow = strings (#8FF3FF).
AURA: a ring of blocky music-note shards circling the harp slowly (#8FF3FF).
FILE: models/relics/R025_harp_of_the_tidesong.glb
```

### R036 Figurehead of the Weeping Queen (was Wreck Figurehead)

```text
ID R036 "Figurehead of the Weeping Queen". Lore: "She guided a thousand voyages."
SHAPE: a carved wooden ship's figurehead: the bust of a crowned queen, arms crossed over her
chest, leaning forward as if into the wind, with long carved hair flowing back. Her paint is
cracked. Glowing pearl tears run down her cheeks. Barnacles on the base.
Stylised, dignified, not realistic.
OBJECTS: Main = wood (#9C6B42). Accent = painted dress (#2F5E8E). Trim = gold crown
(#FFC440). Glow = tears (#BFF6FF). Gem = barnacles (#D9D2BF).
AURA: a halo of blocky sea-foam crests behind her head (#BFF6FF), with pearl cubes drifting down.
FILE: models/relics/R036_figurehead_weeping_queen.glb
```

### R037 Blackwater Cutlass (was Cursed Cutlass)

```text
ID R037 "Blackwater Cutlass". Lore: "It hums near the Leviathan."
SHAPE: a curved cutlass, standing point-down into a small mound of black silt. A black steel
blade with glowing green runes (invented shapes) along it. A basket guard shaped like a
grinning skull. A tattered red tassel hangs from the pommel.
OBJECTS: Main = blade (#2A2E36). Accent = guard (#B8BEC8). Trim = tassel (#B8343F). Glow =
runes (#7DFF8A). Gem = silt mound (#1A1A20).
AURA: green rune cubes rising off the blade like sparks, and a ring of green shards around the silt (#7DFF8A).
FILE: models/relics/R037_blackwater_cutlass.glb
```

### R041 Lantern of the Deep

```text
ID R041 "Lantern of the Deep". Lore: "Lights the area while displayed." (It gives light.)
SHAPE: a large ornate iron lantern hanging from a hooked chain. The cage is shaped like the
open jaws of an anglerfish, with teeth as the bars. Inside the jaws, a bright glowing orb.
A thin lure stalk curls over the top.
OBJECTS: Main = iron cage (#3A3D45). Accent = teeth (#EDE4D0). Glow = orb and lure tip
(#FFE27A). Trim = chain and hook (#6B6F78).
AURA: long thin wedge rays fanning out from the orb like a sunburst (#FFE27A).
FILE: models/relics/R041_lantern_of_the_deep.glb
```

### R047 Mask of the Faceless Tide (was Obsidian Mask)

```text
ID R047 "Mask of the Faceless Tide". Lore: "Warm to the touch."
SHAPE: a smooth obsidian mask with no nose or mouth, only two narrow eye slits that glow like
cracks. A gold crest of three fins rises from the forehead. Thin gold lines trace the
cheekbones.
OBJECTS: Main = obsidian (#17141F). Trim = gold crest and lines (#FFC440). Glow = eye slits
(#FF5A3C).
AURA: a crown of flickering flame blocks above the crest (#FF5A3C).
FILE: models/relics/R047_mask_of_the_faceless_tide.glb
```

### R048 Leviathan Scale Shield (was Leviathan Scale)

```text
ID R048 "Leviathan Scale Shield". Lore: "Each scale is the size of a shield. This one is."
SHAPE: a single huge iridescent scale, teardrop-shaped and slightly curved, made into a
shield. A bone rim, leather straps across the back, and three small scale-ridges along the
front. Stands upright, tilted back.
OBJECTS: Main = scale (#2BA6A0). Accent = bone rim (#E6DCC4). Trim = straps (#5A3A26).
Glow = a thin line along each ridge (#7FFFE8).
AURA: three hexagonal plates orbiting the shield like a barrier (#7FFFE8).
FILE: models/relics/R048_leviathan_scale_shield.glb
```

### R059 Gauntlet of the Abyssal Titan (was Titan's Gauntlet)

```text
ID R059 "Gauntlet of the Abyssal Titan". Lore: "Built for a hand twice your size."
SHAPE: an oversized armoured gauntlet, the fist clenched and raised. Thick overlapping
plates, knuckle spikes, a flared cuff. A glowing red core is set in the back of the hand, with
glowing seams running from it to each knuckle. Barnacles on the cuff.
OBJECTS: Main = plates (#5B6270). Accent = joints and cuff (#3A3F4A). Glow = core and seams
(#FF4A3A). Trim = barnacles (#D9D2BF).
AURA: cracked rock chunks with glowing seams orbiting the fist (#FF4A3A).
FILE: models/relics/R059_gauntlet_of_the_abyssal_titan.glb
```

---

## Mythic (new identity)

### R038 Bell of the Last Voyage (was Sunken Galleon Bell)

```text
ID R038 "Bell of the Last Voyage". Lore: "Its toll was heard on the surface."
SHAPE: a huge bronze ship's bell with a green patina, hanging from a short broken beam.
A small ghost ship is engraved around the waist. Spectral blue light leaks from the open mouth.
A loose loop of ghostly rope drifts around it as a spinning part.
OBJECTS: Main = bell (#B07A3E). Accent = patina patches (#4FA38A). Trim = beam (#5A3E28).
Glow = light inside the mouth (#8FE0FF). Spin_Rope = ghost rope loop (#BFF2FF), pivot at
the bell's centre, turning around the vertical axis.
AURA: stacked square sound-wave rings spreading below the bell's mouth, plus the ghost rope (#8FE0FF).
FILE: models/relics/R038_bell_of_the_last_voyage.glb
```

### R050 Eye of the Sleeper (was Abyss Eye)

```text
ID R050 "Eye of the Sleeper". Lore: "It blinks."
SHAPE: a giant eye set into a rough stone socket. Four short tentacles curl out from behind
the stone. The iris is violet with a slit pupil. The upper eyelid is half closed and is a
separate object so the game can make it blink.
OBJECTS: Main = stone socket (#3A3548). Accent = tentacles (#5E3A7A). Gem = eyeball white
(#EDE6F2). Glow = iris (#C36BFF). Spin_Lid = eyelid (#4A3A5C), pivot at the eye's centre,
turning around the horizontal (X) axis.
AURA: a fan of violet tentacle shards rising behind the socket, and a square iris ring hovering in front (#C36BFF).
FILE: models/relics/R050_eye_of_the_sleeper.glb
```

### R052 Leviathan's Fang (was Leviathan Tooth)

```text
ID R052 "Leviathan's Fang". Lore: "Only the brave pry these loose." (It drops from the
Leviathan.)
SHAPE: a huge curved fang, taller than a diver, with cracked enamel and a dark root. A
broken harpoon is still lodged in its side, with a frayed rope. Faint glowing veins run up
from the root. No blood.
OBJECTS: Main = enamel (#EFE7D2). Accent = root (#4A3A34). Trim = harpoon and rope
(#7A7F88). Glow = veins (#FF6A4A).
AURA: three floating claw-mark slashes around the fang and drifting ember cubes (#FF6A4A).
FILE: models/relics/R052_leviathans_fang.glb
```

### R058 Crown of the Drowned King

```text
ID R058 "Crown of the Drowned King". Lore: "He'll want it back."
SHAPE: a tall, heavy crown with seven points of corroded gold. Coral grows over two points,
and seaweed drapes over one side. Pearls line the band. A large sea-green gem sits in front.
A ring of water droplets floats around the crown as a spinning part.
OBJECTS: Main = gold (#D9A93A). Accent = corrosion (#5E8F6A). Trim = coral and seaweed
(#FF7A8A). Gem = pearls (#F7F0FF). Glow = front gem (#4DFFB8). Spin_Droplets = droplet ring
(#AEE9FF), pivot at the crown's centre, turning around the vertical axis.
AURA: the droplet ring plus small gem shards floating above the crown (#4DFFB8).
FILE: models/relics/R058_crown_of_the_drowned_king.glb
```

(R049 Starfall Trident is in the pilots.)

---

## Secret (new identity)

### R051 Whispering Nautilus (was Whisper Shell)

```text
ID R051 "Whispering Nautilus". Lore: "Hold it to your ear. Don't."
SHAPE: a large nautilus shell, matte black outside with pale pearl stripes. The opening
glows from deep inside the spiral. Small invented glyphs float in a slow spiral out of the
opening as a spinning part.
OBJECTS: Main = shell (#121016). Accent = pearl stripes (#E8E2F0). Glow = inner glow
(#B98CFF). Spin_Glyphs = floating glyphs (#D9C2FF), pivot at the shell opening, turning
around the shell's spiral axis.
AURA: a spiral of black cubes with violet edges winding out of the shell, carrying the glyphs (#B98CFF on #121016).
FILE: models/relics/R051_whispering_nautilus.glb
```

### R060 Heart of the Trench

```text
ID R060 "Heart of the Trench". Lore: "???" (It shows as a black silhouette until found, so
the outline must be unmistakable.)
SHAPE: a stylised stone heart (a strong rounded silhouette, not anatomical, nothing gory)
made of basalt. Lava veins glow across it. Two short vent chimneys rise from the top like
arteries, with a wisp of glowing smoke. Small rocks orbit it slowly as a spinning part.
OBJECTS: Main = basalt (#2A2224). Glow = veins and smoke (#FF4A2A). Accent = chimneys
(#4A3A36). Spin_Rocks = orbiting rocks (#3A3034), pivot at the heart's centre, turning
around the vertical axis.
AURA: the orbiting rocks plus dark-red pulse rings expanding from the heart, and black smoke cubes (#FF4A2A on #1A1214).
FILE: models/relics/R060_heart_of_the_trench.glb
```

---

## Salvage caches (the other four zones)

All four follow the Sunlit Reef cache rules: 3.4 m wide, origin at the base, a separate Lid
(or the part that breaks open) with its origin at the hinge, a Glow part for the inner light,
and nothing that hints at rarity. Budget 3,000 each.

### Kelp Twilight cache

```text
ID CACHE_KELP. A barnacled lobster trap lying on a mossy rock, wrapped in two kelp strands.
Something gold shines between the slats. The trap's top hatch is the Lid.
OBJECTS: Main = rock (#4A5A4C). Accent = trap (#7A5A3A). Trim = kelp (#4FA35E). Lid = hatch
(#7A5A3A). Glow = inner shine (#FFD45A). FILE: models/caches/kelp_cache.glb
```

### Midnight Wrecks cache

```text
ID CACHE_WRECKS. The corner of an old sea chest sticking out of grey silt at an angle, with
a broken plank lying across it and an iron ring on its side. Light leaks from under the lid.
OBJECTS: Main = silt (#5A5E66). Accent = chest (#5E4430). Trim = iron (#3A3D45). Lid = chest
lid (#5E4430). Glow = light under the lid (#FFD45A). FILE: models/caches/wrecks_cache.glb
```

### The Abyss cache

```text
ID CACHE_ABYSS. A cracked round rock geode, half buried in dark sand. The cracks glow
blue-violet. The top third splits off as the Lid.
OBJECTS: Main = sand (#1E2030). Accent = geode shell (#3A3548). Lid = top piece (#3A3548).
Glow = cracks and interior crystals (#8A7BFF). FILE: models/caches/abyss_cache.glb
```

### The Trench cache

```text
ID CACHE_TRENCH. A lumpy basalt vent nodule on cracked rock, with orange-glowing cracks and
a small chimney on top. The front slab breaks away as the Lid.
OBJECTS: Main = rock (#2A2224). Accent = nodule (#3A2F2E). Lid = front slab (#3A2F2E).
Glow = cracks (#FF7A2A). FILE: models/caches/trench_cache.glb
```

---

## Megalodon (rigged)

```text
ID MEGALODON. A giant prehistoric shark: the mid-water monster that harasses divers while
they dig. Menacing but readable, in the same chunky stylised low-poly as the relics, not
realistic. If models/fishes/megalodon.glb exists, start from its shape and improve it;
otherwise model from scratch.
SHAPE: a massive torpedo body, a blunt wide head, a huge jaw that can open 50 degrees, three
rows of oversized triangular teeth, small black eyes with a white glint, a tall dorsal fin
with a notch bitten out of it, battle scars on the flank (raised ridges, no blood), a
crescent tail. A slate-blue back over a cream belly, with a hard colour split along the side.
SIZE: 12 m long, nose pointing Blender -Y, origin at the centre of mass.
OBJECTS (separate meshes): Main = body (#5A6672). Accent = belly (#E8DEC4). Trim = teeth
(#F7F4EA). Gem = mouth interior (#5C2228). Eyes = eyes (#0A0A0B), each with a small white
glint joined into the same object.
RIG: an armature named MegalodonRig with bones Root, Spine1, Spine2, Spine3, Tail1, Tail2,
TailFin, Head, Jaw, PecFin_L, PecFin_R, Dorsal. Skin Main, Accent, Trim, Gem and Eyes to it with
smooth weights along the spine. The Jaw bone opens the lower jaw and lower teeth.
No animations needed; the game drives the bones in code.
BUDGET: 12,000 triangles total. FILE: models/fishes/megalodon_rigged.glb (include the
armature and skin weights).
Also render the preview with the jaw open 30 degrees, from the front-side.
```
