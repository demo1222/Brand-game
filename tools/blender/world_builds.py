# Blocky builds for the world: zone guardians (Config/Monsters) and reef props.
# Used by run_world.py with blocky_kit.py already exec'd. Each build fills Parts() by role;
# the object names become "<ID>_<Role>" and the game recolours by role:
#   monsters: Body, Belly, Accent, Eye (or Glow when it glows), Teeth, Tail, Jaw
#             Parts whose role ends in Tail or Jaw animate in game (MonsterArt).
#   props:    Main (recoloured to the coral's hue), Tip / Glow (lighter / neon), Stem, Rock
# Monsters face +Y here: after the glTF Y-up export that is Roblox's -Z (forward).
# Units: monsters are ~4 long (the game scales them to Monsters.Length); props ~2 tall.

MONSTER_COLORS = {
    "ReefShark": {"Body": "#6E8CA5", "Belly": "#EBEEF0", "Accent": "#465A6E", "Eye": "#141418", "Teeth": "#FAF8EB", "Tail": "#6E8CA5", "TailFin": "#6E8CA5", "Jaw": "#EBEEF0", "JawTeeth": "#FAF8EB"},
    "Barracuda": {"Body": "#96AFA0", "Belly": "#DCE6D7", "Accent": "#3C6E46", "Glow": "#F0D23C", "Teeth": "#FAF8EB", "Tail": "#3C6E46", "TailFin": "#3C6E46", "Jaw": "#DCE6D7", "JawTeeth": "#FAF8EB"},
    "WreckShark": {"Body": "#3A4250", "Belly": "#BEBEB9", "Accent": "#962828", "Glow": "#FF3228", "Teeth": "#FAF8EB", "Tail": "#3A4250", "TailFin": "#3A4250", "Jaw": "#BEBEB9", "JawTeeth": "#FAF8EB"},
    "AbyssAngler": {"Body": "#221E2E", "Belly": "#3C3246", "Accent": "#2A2438", "Glow": "#50F0FF", "Teeth": "#F0EEE6", "Tail": "#221E2E", "TailFin": "#221E2E", "Jaw": "#3C3246", "JawTeeth": "#F0EEE6"},
}

PROP_COLORS = {
    "CORAL_Brain": {"Main": "#FF6E8C", "Tip": "#FFB4C4", "Rock": "#B4A88C"},
    "CORAL_Branch": {"Main": "#AA64FF", "Glow": "#E6C8FF", "Rock": "#B4A88C"},
    "CORAL_Fan": {"Main": "#FFA03C", "Tip": "#FFD29A", "Stem": "#8C5A2A", "Rock": "#B4A88C"},
    "CORAL_Tube": {"Main": "#FFD65A", "Tip": "#28142A", "Rock": "#B4A88C"},
    "CORAL_Table": {"Main": "#46D2C8", "Tip": "#A8F0EA", "Stem": "#2C8A84", "Rock": "#B4A88C"},
    "KELP": {"Main": "#3C8C3C", "Tip": "#96D250", "Stem": "#6E6028", "Glow": "#C8B43C", "Rock": "#3C5A3C"},
    "AIR_RACK": {"Main": "#FAC828", "Tip": "#F0F0F0", "Stem": "#464E5C", "Accent": "#28282E"},
}


def _teeth(bm, n, x0, x1, y, z, h, down=False):
    for i in range(n):
        x = x0 + (x1 - x0) * (i / max(1, n - 1))
        tip = (x, y, z - h if down else z + h)
        spike(bm, (x, y, z), tip, h * 0.35)


def build_shark(P, rng, scars=False, glow_eyes=False):
    body = [(-1.7, 0.12), (-1.2, 0.34), (-0.4, 0.58), (0.4, 0.62), (1.1, 0.52), (1.6, 0.34), (1.95, 0.1)]
    lathe(P["Body"], body, cell=0.11, axis='Y', squash=(0.85, 1.0))
    belly = [(-1.1, 0.2), (-0.3, 0.5), (0.6, 0.52), (1.4, 0.3), (1.8, 0.08)]
    xf(P["Belly"], lathe(P["Belly"], belly, cell=0.11, axis='Y', squash=(0.8, 0.75)), T(0, 0, -0.17))
    # dorsal fin: a back-swept slab, two steps tall
    box(P["Body"], (0, -0.05, 0.75), (0.1, 0.55, 0.35), Rm(-28, 0, 0))
    box(P["Body"], (0, -0.2, 1.05), (0.09, 0.38, 0.3), Rm(-35, 0, 0))
    # pectoral fins
    for sx in (-1, 1):
        box(P["Body"], (sx * 0.62, 0.45, -0.32), (0.75, 0.32, 0.07), Rm(0, sx * 25, sx * -10) @ Rm(0, 0, sx * -20))
        # gills
        for g in range(3):
            box(P["Accent"], (sx * 0.5, 0.95 - g * 0.12, 0.05), (0.04, 0.04, 0.32))
        if scars:
            for k in range(3):
                box(P["Accent"], (sx * 0.53, 0.2 - k * 0.25, 0.25 - k * 0.1), (0.04, 0.42, 0.05), Rm(30 + k * 12, 0, 0))
    # eyes
    eye_role = "Glow" if glow_eyes else "Eye"
    for sx in (-1, 1):
        box(P[eye_role], (sx * 0.33, 1.35, 0.14), (0.08, 0.14, 0.12))
    # upper teeth under the snout, and the jaw (opens in game) with its own teeth
    _teeth(P["Teeth"], 6, -0.22, 0.22, 1.62, -0.16, 0.12, down=True)
    box(P["Jaw"], (0, 1.35, -0.33), (0.5, 0.62, 0.12))
    _teeth(P["JawTeeth"], 6, -0.2, 0.2, 1.6, -0.27, 0.12)
    # tail: a stem and the two forked lobes
    tube(P["Tail"], [(0, -1.5, 0.02), (0, -2.05, 0.06)], [0.17, 0.12])
    # forked lobes rooted on the stem's end (upper long, lower short)
    box(P["TailFin"], (0, -2.12, 0.42), (0.08, 0.3, 0.85), Rm(-30, 0, 0))
    box(P["TailFin"], (0, -2.08, -0.22), (0.08, 0.24, 0.5), Rm(35, 0, 0))


def build_barracuda(P, rng):
    body = [(-1.9, 0.08), (-1.4, 0.2), (-0.4, 0.3), (0.8, 0.3), (1.6, 0.22), (2.1, 0.1)]
    lathe(P["Body"], body, cell=0.08, axis='Y', squash=(0.8, 1.0))
    xf(P["Belly"], lathe(P["Belly"], [(-1.2, 0.12), (0.2, 0.22), (1.5, 0.14)], cell=0.08, axis='Y', squash=(0.75, 0.6)), T(0, 0, -0.1))
    for sx in (-1, 1):
        box(P["Glow"], (sx * 0.2, 1.75, 0.08), (0.06, 0.1, 0.1))
        for k in range(6):
            box(P["Accent"], (sx * 0.23, 1.0 - k * 0.42, 0.06), (0.03, 0.12, 0.38))
        box(P["Body"], (sx * 0.3, 1.0, -0.2), (0.4, 0.2, 0.05), Rm(0, sx * 25, 0))
    box(P["Accent"], (0, 0.2, 0.36), (0.06, 0.4, 0.3), Rm(-30, 0, 0))
    box(P["Accent"], (0, -0.9, 0.32), (0.06, 0.3, 0.25), Rm(-30, 0, 0))
    # long underbite jaw with a row of needle teeth
    box(P["Jaw"], (0, 1.95, -0.16), (0.24, 0.85, 0.09))
    for i in range(7):
        spike(P["JawTeeth"], (0, 1.65 + i * 0.09, -0.11), (0, 1.65 + i * 0.09, 0.02), 0.035)
    tube(P["Tail"], [(0, -1.8, 0), (0, -2.2, 0)], [0.1, 0.07])
    box(P["TailFin"], (0, -2.3, 0.26), (0.06, 0.25, 0.6), Rm(-38, 0, 0))
    box(P["TailFin"], (0, -2.3, -0.26), (0.06, 0.25, 0.6), Rm(38, 0, 0))


def build_angler(P, rng):
    lathe(P["Body"], [(-1.2, 0.3), (-0.8, 0.9), (0, 1.25), (0.7, 1.15), (1.15, 0.75), (1.35, 0.2)], cell=0.13, axis='Y', squash=(1.0, 0.9))
    xf(P["Belly"], lathe(P["Belly"], [(-0.6, 0.5), (0.2, 0.95), (1.0, 0.6)], cell=0.13, axis='Y', squash=(0.95, 0.6)), T(0, 0, -0.45))
    # the mouth: a dark gap, a huge underbite jaw, needle teeth up and fangs down
    box(P["Accent"], (0, 1.3, -0.25), (1.6, 0.18, 0.45))
    box(P["Jaw"], (0, 1.15, -0.72), (1.75, 0.95, 0.3))
    for i in range(8):
        x = -0.75 + i * (1.5 / 7)
        spike(P["JawTeeth"], (x, 1.45, -0.58), (x, 1.5, -0.12), 0.06)
    for i in range(7):
        x = -0.65 + i * (1.3 / 6)
        spike(P["Teeth"], (x, 1.42, 0.08), (x, 1.47, -0.32), 0.06)
    for sx in (-1, 1):
        box(P["Glow"], (sx * 0.55, 1.05, 0.45), (0.16, 0.16, 0.16))
        box(P["Body"], (sx * 1.15, 0.1, -0.1), (0.45, 0.5, 0.08), Rm(0, sx * 30, 0))
        for k in range(4):
            box(P["Glow"], (sx * 1.13, -0.2 + k * 0.25, 0.4 - k * 0.15), (0.07, 0.07, 0.07))
    # the lure: a stalk arching up and forward to a glowing bulb
    tube(P["Accent"], [(0, 0.3, 1.0), (0, 0.6, 1.75), (0, 1.3, 2.05), (0, 1.9, 1.75)], [0.08, 0.07, 0.06, 0.05])
    box(P["Glow"], (0, 2.0, 1.6), (0.28, 0.28, 0.28))
    box(P["Glow"], (0, 2.0, 1.6), (0.2, 0.2, 0.36), Rm(0, 45, 0))
    box(P["Accent"], (0, -0.3, 1.15), (0.08, 0.7, 0.45), Rm(-25, 0, 0))
    tube(P["Tail"], [(0, -1.15, 0), (0, -1.6, 0.05)], [0.3, 0.2])
    box(P["TailFin"], (0, -1.9, 0.05), (0.07, 0.35, 1.2))


def build_brain(P, rng):
    lathe(P["Main"], [(0, 1.0), (0.3, 1.0), (0.55, 0.85), (0.8, 0.55), (0.95, 0.2)], cell=0.1, axis='Z')
    for i, z in enumerate((0.42, 0.62, 0.8)):
        r = (1.02, 0.83, 0.55)[i]
        out = disc(P["Tip"], r, 0.05, 0.1, 'Z', z)
    bud = lathe(P["Main"], [(0, 0.45), (0.25, 0.42), (0.42, 0.2)], cell=0.1, axis='Z')
    xf(P["Main"], bud, T(1.0, 0.3, 0))
    cubes(P["Rock"], rng, 5, (0, 0, 0), 1.0, 1.4, 0.0, 0.05, 0.12, 0.25)


def build_branch(P, rng):
    def br(p, d, length, thick, depth):
        q = (p[0] + d[0] * length, p[1] + d[1] * length, p[2] + d[2] * length)
        tube(P["Main"], [p, q], [thick, thick * 0.8])
        if depth == 0:
            box(P["Glow"], q, (thick * 2.4, thick * 2.4, thick * 2.4))
            return
        for k in range(2):
            a = rng.uniform(0, 2 * math.pi) + k * math.pi
            tilt = math.radians(rng.uniform(25, 40))
            nd = Vector(d) * math.cos(tilt) + Vector((math.cos(a), math.sin(a), 0)) * math.sin(tilt)
            nd.normalize()
            br(q, tuple(nd), length * rng.uniform(0.6, 0.8), thick * 0.72, depth - 1)
    for k in range(3):
        a = k * 2.1
        br((math.cos(a) * 0.25, math.sin(a) * 0.25, 0), (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.98), 0.9, 0.13, 2)
    cubes(P["Rock"], rng, 4, (0, 0, 0), 0.4, 0.8, 0.0, 0.05, 0.12, 0.22)


def build_fan(P, rng):
    box(P["Stem"], (0, 0, 0.25), (0.12, 0.12, 0.5))
    # three overlapping lattice fans: pixel discs with gaps every other row
    for i, (x, r) in enumerate(((0, 1.0), (-0.45, 0.75), (0.45, 0.75))):
        out = disc(P["Main" if i == 0 else "Tip"], r, 0.05, 0.12, 'Y', 0.02 * i, rows=lambda v: int((v + 1) * 6) % 3 != 2)
        xf(P["Main" if i == 0 else "Tip"], out, T(x, 0, 0.5 + r))
    cubes(P["Rock"], rng, 3, (0, 0, 0), 0.25, 0.5, 0.0, 0.05, 0.12, 0.2)


def build_tube(P, rng):
    for k in range(5):
        a = k * 1.25 + rng.uniform(-0.2, 0.2); r = 0.35 if k else 0
        h = rng.uniform(0.9, 2.0); w = rng.uniform(0.22, 0.32)
        out = lathe(P["Main"], [(0, w), (h * 0.8, w * 1.05), (h, w * 1.15)], cell=0.12, axis='Z', hollow=0.55)
        xf(P["Main"], out, T(math.cos(a) * r, math.sin(a) * r, 0))
        dark = disc(P["Tip"], w * 0.6, 0.04, 0.08, 'Z', h * 0.86)
        xf(P["Tip"], dark, T(math.cos(a) * r, math.sin(a) * r, 0))
    cubes(P["Rock"], rng, 4, (0, 0, 0), 0.4, 0.7, 0.0, 0.05, 0.1, 0.2)


def build_table(P, rng):
    lathe(P["Stem"], [(0, 0.22), (0.5, 0.16), (0.7, 0.2)], cell=0.08, axis='Z')
    disc(P["Main"], 1.1, 0.12, 0.1, 'Z', 0.76)
    disc(P["Tip"], 1.16, 0.05, 0.1, 'Z', 0.84, rin=0.95)
    disc(P["Main"], 0.6, 0.1, 0.1, 'Z', 0.88)
    cubes(P["Rock"], rng, 3, (0, 0, 0), 0.3, 0.5, 0.0, 0.05, 0.1, 0.2)


def build_kelp(P, rng):
    for s in range(3):
        a = s * 2.1; base = (math.cos(a) * 0.25, math.sin(a) * 0.25, 0)
        pts = []; x, y = base[0], base[1]
        for i in range(9):
            pts.append((x + math.sin(i * 0.7 + s) * 0.12, y + math.cos(i * 0.6 + s) * 0.08, i * 0.42))
        tube(P["Stem"], pts, [0.05] * len(pts))
        for i, p in enumerate(pts[1:], 1):
            side = 1 if i % 2 else -1
            role = "Tip" if i > 6 else "Main"
            box(P[role], (p[0] + side * 0.22, p[1], p[2] + 0.1), (0.4, 0.04, 0.42), Rm(0, side * -25, a * 57))
            if i % 3 == 0:
                box(P["Glow"], (p[0] - side * 0.08, p[1], p[2]), (0.1, 0.1, 0.1))
    cubes(P["Rock"], rng, 3, (0, 0, 0), 0.2, 0.5, 0.0, 0.05, 0.15, 0.3)


def build_rack(P, rng):
    box(P["Stem"], (0, 0, 0.05), (2.6, 0.6, 0.1))
    box(P["Stem"], (0, 0.22, 0.95), (2.6, 0.08, 0.08))
    for x in (-1.25, 1.25):
        box(P["Stem"], (x, 0.22, 0.5), (0.08, 0.08, 1.0))
    for i in range(5):
        x = -1.0 + i * 0.5
        role = "Main" if i % 2 == 0 else "Tip"
        out = lathe(P[role], [(0.1, 0.17), (0.95, 0.18), (1.05, 0.12), (1.12, 0.06)], cell=0.09, axis='Z')
        xf(P[role], out, T(x, 0, 0))
        box(P["Accent"], (x, 0, 1.2), (0.08, 0.08, 0.14))
        box(P["Accent"], (x + 0.06, 0, 1.24), (0.1, 0.05, 0.04))


MONSTER_BUILDS = {
    "ReefShark": lambda P, rng: build_shark(P, rng),
    "Barracuda": build_barracuda,
    "WreckShark": lambda P, rng: build_shark(P, rng, scars=True, glow_eyes=True),
    "AbyssAngler": build_angler,
}

PROP_BUILDS = {
    "CORAL_Brain": build_brain,
    "CORAL_Branch": build_branch,
    "CORAL_Fan": build_fan,
    "CORAL_Tube": build_tube,
    "CORAL_Table": build_table,
    "KELP": build_kelp,
    "AIR_RACK": build_rack,
}
