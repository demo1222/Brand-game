# Blocky relic builds for Abyss Salvage. Needs blocky_kit.py in the same namespace.
# Each build(P, rng) fills Parts P (role -> bmesh). Z is up, the front faces -Y, and the
# longest side is about 2 m. Colours mirror docs/relic_model_prompts.md.

BUILDS = {}
COLORS = {}


def relic(rid, colors):
    def deco(fn):
        BUILDS[rid] = fn; COLORS[rid] = colors
        return fn
    return deco


# ======================================== RARE ==========================================
@relic("R011", {"Main": "#F2B33D", "Accent": "#C9CED6", "Glass": "#AEE3FF", "Trim": "#C8963E", "Glow": "#FFFFFF"})
def b_R011(P, rng):  # Scuba Mask '78
    disc(P["Accent"], 0.62, 0.16, 0.1, 'Y', -0.05, (1.35, 1.0), rin=0.5)          # chrome rim
    disc(P["Glass"], 0.52, 0.05, 0.1, 'Y', -0.06, (1.35, 1.0))                     # pane
    disc(P["Main"], 0.66, 0.22, 0.1, 'Y', 0.12, (1.35, 1.0), rin=0.46)             # rubber skirt
    box(P["Main"], (0, 0.12, -0.42), (0.36, 0.22, 0.2))                            # nose pocket
    tube(P["Main"], [(-0.92, 0.15, 0), (-0.95, 0.55, 0.05), (-0.5, 0.95, 0.1), (0.5, 0.95, 0.1), (0.95, 0.55, 0.05), (0.92, 0.15, 0)], [0.09] * 6, flat=0.45)
    for sx in (-1, 1):
        box(P["Accent"], (sx * 0.93, 0.18, 0), (0.12, 0.2, 0.26))                  # buckles
    box(P["Trim"], (0, 0.97, 0.1), (0.3, 0.06, 0.16))                              # signature plate
    sparkle(P["Glow"], (0.45, -0.1, 0.32), 0.22)


@relic("R012", {"Main": "#EDE2C8", "Accent": "#CBB892", "Gem": "#F7F0FF", "Glow": "#FFFFFF"})
def b_R012(P, rng):  # Mermaid Comb
    disc(P["Main"], 0.8, 0.14, 0.1, 'Y', 0, (1.0, 0.75), rows=lambda t: t > 0.05)  # fan back (upper half)
    xf(P["Main"], box(P["Main"], (0, 0, 0.0), (1.6, 0.16, 0.14)), T())
    for i in range(9):
        x = -0.72 + i * 0.18
        tube(P["Main"], [(x, 0, -0.05), (x, 0, -0.75)], [0.055, 0.03])
    tube(P["Accent"], [(-0.4, -0.09, 0.12), (-0.2, -0.09, 0.3), (0.05, -0.09, 0.32), (0.22, -0.09, 0.42)], [0.06, 0.06, 0.05, 0.04])
    spike(P["Accent"], (0.22, -0.09, 0.42), (0.42, -0.09, 0.58), 0.06)
    spike(P["Accent"], (0.22, -0.09, 0.42), (0.38, -0.09, 0.3), 0.06)
    box(P["Gem"], (0.24, -0.12, 0.43), (0.12, 0.12, 0.12), Rm(0, 45, 0))
    sparkle(P["Glow"], (-0.5, -0.1, 0.45), 0.2)


@relic("R020", {"Main": "#D3D8E0", "Accent": "#B8343F", "Trim": "#F0C860", "Glow": "#FFFFFF"})
def b_R020(P, rng):  # Silver Spoon Set
    for ang in (-24, 0, 24):
        M = T(0, 0.04 * (ang / 24), -0.1) @ Rm(0, ang, 0)
        v = box(P["Main"], (0, 0, -0.35), (0.1, 0.06, 1.1))
        xf(P["Main"], v, M)
        bowl = disc(P["Main"], 0.24, 0.09, 0.06, 'Y', 0, (1.0, 1.35)); xf(P["Main"], bowl, M @ T(0, 0, 0.5))
        crest = box(P["Trim"], (0, -0.04, -0.86), (0.08, 0.05, 0.22)) + box(P["Trim"], (0, -0.04, -0.8), (0.2, 0.05, 0.05)) + box(P["Trim"], (0, -0.04, -0.96), (0.2, 0.05, 0.05))
        xf(P["Trim"], crest, M)
    box(P["Accent"], (0, -0.08, -0.42), (0.16, 0.1, 0.14))
    for sx in (-1, 1):
        box(P["Accent"], (sx * 0.17, -0.08, -0.36), (0.24, 0.08, 0.13), Rm(0, -sx * 30, 0))
        box(P["Accent"], (sx * 0.1, -0.08, -0.6), (0.08, 0.08, 0.3), Rm(0, sx * 15, 0))
    sparkle(P["Glow"], (0.0, -0.12, 0.62), 0.2)


@relic("R022", {"Main": "#3FAE7A", "Trim": "#FFC440", "Accent": "#2E6B55", "Glow": "#B6FF9A"})
def b_R022(P, rng):  # Jade Turtle
    disc(P["Accent"], 0.9, 0.14, 0.12, 'Z', -0.55)                                    # lotus base
    for k in range(8):
        a = k * 45; box(P["Accent"], (0.95 * math.cos(math.radians(a)), 0.95 * math.sin(math.radians(a)), -0.5), (0.3, 0.16, 0.14), Rm(0, 0, a))
    lathe(P["Main"], [(0, 0.72), (0.18, 0.7), (0.4, 0.58), (0.6, 0.38), (0.72, 0.0)], 0.1, 'Z', (1.0, 1.2), M=T(0, 0.05, -0.42))
    for (x, y) in [(-0.6, -0.62), (0.6, -0.62), (-0.6, 0.62), (0.6, 0.62)]:
        box(P["Main"], (x, y, -0.4), (0.3, 0.3, 0.2))
    tube(P["Main"], [(0, -0.8, -0.25), (0, -1.0, 0.0)], [0.13, 0.13])
    box(P["Main"], (0, -1.08, 0.12), (0.38, 0.38, 0.32))
    for g in [box(P["Trim"], (0, 0.05, 0.07), (0.05, 1.5, 0.04)), box(P["Trim"], (0, 0.05, 0.07), (1.2, 0.05, 0.04))]:
        pass
    disc(P["Trim"], 0.62, 0.05, 0.1, 'Z', -0.05, (1.0, 1.2), rin=0.55, rows=None)
    for sx in (-1, 1):
        box(P["Glow"], (sx * 0.11, -1.28, 0.18), (0.08, 0.04, 0.08))


@relic("R030", {"Main": "#D2A04A", "Accent": "#6B4428", "Trim": "#8A8F99", "Glow": "#9FD8FF"})
def b_R030(P, rng):  # Brass Spyglass
    a, b, c, d = (-0.95, 0, -0.25), (-0.3, 0, 0.0), (0.3, 0, 0.22), (0.9, 0, 0.42)
    tube(P["Main"], [a, b], [0.17, 0.17]); tube(P["Main"], [b, c], [0.135, 0.135]); tube(P["Main"], [c, d], [0.1, 0.1])
    for p, r in [(b, 0.19), (c, 0.155), (d, 0.12), (a, 0.2)]:
        q = Vector(p); tube(P["Trim"], [q - Vector((0.03, 0, 0.012)), q + Vector((0.03, 0, 0.012))], [r, r])
    tube(P["Accent"], [(-0.8, 0, -0.2), (-0.45, 0, -0.06)], [0.185, 0.185])
    box(P["Glow"], (-0.99, 0, -0.27), (0.04, 0.28, 0.28), Rm(0, -20, 0))
    for i in range(4):
        box(P["Trim"], (0.9 + 0.02 * i, -0.08, 0.3 - 0.1 * i), (0.04, 0.04, 0.06))
    box(P["Trim"], (0.95, -0.08, -0.12), (0.16, 0.16, 0.08))
    disc(P["Accent"], 0.62, 0.12, 0.12, 'Z', -0.6, rin=0.4)


@relic("R031", {"Main": "#4F8F7E", "Glass": "#CFEFFF", "Glow": "#7DFFD4", "Trim": "#2F3A3F", "Gem": "#103A30"})
def b_R031(P, rng):  # Ghost Lantern
    box(P["Trim"], (0, 0, -0.85), (0.9, 0.9, 0.18))
    for i, s in enumerate((0.85, 0.65, 0.42)):
        box(P["Trim"], (0, 0, 0.55 + i * 0.12), (s, s, 0.12))
    sq_frame(P["Main"], 0.18, 0.06, 0.06, T(0, 0, 0.98))
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(P["Main"], (sx * 0.36, sy * 0.36, -0.15), (0.09, 0.09, 1.3))
    box(P["Main"], (0, 0, 0.47), (0.82, 0.82, 0.08)); box(P["Main"], (0, 0, -0.72), (0.82, 0.82, 0.08))
    box(P["Glass"], (0, 0, -0.13), (0.64, 0.64, 1.1))
    for i, s in enumerate((0.34, 0.28, 0.2, 0.12)):
        box(P["Glow"], (0, 0, -0.45 + i * 0.16), (s, s, 0.16), Rm(0, 0, i * 12))
    for sx in (-1, 1):
        box(P["Gem"], (sx * 0.07, -0.15, -0.22), (0.06, 0.04, 0.07))


@relic("R032", {"Main": "#8A5A34", "Accent": "#3A3D45", "Trim": "#FFC440", "Gem": "#F7F0FF", "Glow": "#FFD45A"})
def b_R032(P, rng):  # Treasure Chest
    box(P["Main"], (0, 0, -0.38), (1.7, 1.0, 0.8))
    lid = disc(P["Main"], 0.5, 1.7, 0.1, 'X', 0, rows=lambda t: t > 0)
    xf(P["Main"], lid, T(0, 0.5, 0.02) @ Rm(-35, 0, 0) @ T(0, -0.5, 0) @ Matrix.Diagonal((1, 1, 0.7, 1)))
    for x in (-0.55, 0.55):
        box(P["Accent"], (x, 0, -0.38), (0.12, 1.04, 0.84))
    box(P["Accent"], (0, -0.52, -0.15), (0.26, 0.06, 0.3)); box(P["Trim"], (0, -0.56, -0.17), (0.08, 0.04, 0.1))
    box(P["Glow"], (0, 0, 0.03), (1.5, 0.85, 0.06))
    for i in range(14):
        box(P["Trim"], (rng.uniform(-0.7, 0.7), rng.uniform(-0.45, 0.35), 0.08 + rng.uniform(0, 0.12)), (0.16, 0.16, 0.05), Rm(rng.uniform(-20, 20), rng.uniform(-20, 20), rng.uniform(0, 90)))
    for i in range(5):
        box(P["Trim"], (-0.3 + i * 0.12, -0.55 - i * 0.03, 0.0 - i * 0.12), (0.15, 0.15, 0.05), Rm(30, 0, i * 20))
    for i in range(7):
        box(P["Gem"], (0.2 + i * 0.07, -0.53, 0.02 - abs(i - 3) * 0.05), (0.07, 0.07, 0.07))


@relic("R042", {"Main": "#6A6088", "Gem": "#3A2E55", "Glow": "#B57BFF", "Accent": "#7A6E98", "Trim": "#E8DDFF"})
def b_R042(P, rng):  # Abyssal Pearl
    lathe(P["Main"], [(-0.5, 0.25), (-0.4, 0.6), (-0.25, 0.85), (-0.15, 0.95)], 0.1, 'Z', (1.0, 0.85))
    disc(P["Glow"], 0.96, 0.05, 0.1, 'Z', -0.12, (1.0, 0.85), rin=0.86)
    lid = disc(P["Accent"], 0.95, 0.12, 0.1, 'Z', 0, (1.0, 0.85))
    for k in range(-3, 4):
        lid += box(P["Accent"], (k * 0.24, -0.05, 0.08), (0.08, 1.4 - abs(k) * 0.2, 0.06))
    xf(P["Accent"], lid, T(0, 0.8, -0.12) @ Rm(-62, 0, 0) @ T(0, -0.8, 0))
    lathe(P["Gem"], [(-0.42, 0.0), (-0.3, 0.3), (-0.05, 0.42), (0.2, 0.3), (0.32, 0.0)], 0.09, 'Z', M=T(0, -0.05, 0.0))
    box(P["Trim"], (-0.15, -0.42, 0.12), (0.1, 0.04, 0.1)); box(P["Trim"], (-0.08, -0.43, 0.2), (0.05, 0.03, 0.05))


@relic("R043", {"Main": "#E6DCC4", "Accent": "#FFFFFF", "Glow": "#7FE8FF", "Gem": "#3A3226"})
def b_R043(P, rng):  # Gulper Skull
    box(P["Main"], (0, 0.55, 0.35), (0.72, 0.62, 0.58))
    box(P["Main"], (0, 0.15, 0.42), (0.6, 0.4, 0.22))
    for sx in (-1, 1):
        box(P["Gem"], (sx * 0.36, 0.45, 0.42), (0.04, 0.26, 0.26))
        box(P["Glow"], (sx * 0.37, 0.45, 0.42), (0.03, 0.1, 0.1))
        tube(P["Main"], [(sx * 0.24, 0.2, 0.3), (sx * 0.42, -0.4, 0.3), (sx * 0.38, -0.95, 0.25)], [0.11, 0.1, 0.08])
        tube(P["Main"], [(sx * 0.22, 0.25, 0.08), (sx * 0.5, -0.3, -0.35), (sx * 0.45, -0.85, -0.62)], [0.11, 0.1, 0.08])
        for i in range(6):
            f = i / 5.0
            top = Vector((sx * (0.38 - 0.02 * i), 0.0 - 0.9 * f, 0.22 - 0.04 * f))
            spike(P["Accent"], top, top + Vector((0, 0, -0.28)), 0.04)
            bot = Vector((sx * (0.46 - 0.01 * i), 0.0 - 0.8 * f, -0.2 - 0.38 * f))
            spike(P["Accent"], bot, bot + Vector((0, 0, 0.26)), 0.04)
    tube(P["Main"], [(-0.4, -0.95, 0.25), (0.4, -0.95, 0.25)], [0.08, 0.08])
    tube(P["Main"], [(-0.47, -0.85, -0.62), (0.47, -0.85, -0.62)], [0.08, 0.08])


@relic("R054", {"Main": "#7C8590", "Glow": "#63E6FF", "Trim": "#D9D2BF"})
def b_R054(P, rng):  # Ancient Ruin Tablet
    c = 0.12
    for j in range(16):
        z = -0.9 + c * (j + 0.5)
        w = 0.62 if z < 0.4 else 0.62 * math.sqrt(max(1 - ((z - 0.4) / 0.55) ** 2, 0))
        right = w if z < 0.3 else min(w, 0.62 - (z - 0.3) * 1.4)
        if right <= -w + c * 0.5:
            continue
        box(P["Main"], ((right - w) / 2, 0, z), (right + w, 0.26, c))
    glyphs = [[(0, 0), (1, 0), (1, 1)], [(0, 0), (0, 1), (1, 1), (1, 0)], [(0, 0), (1, 1)], [(0, 1), (1, 0), (1, 1)]]
    for row in range(4):
        for col in range(3):
            g = glyphs[(row + col) % 4]; ox = -0.38 + col * 0.3; oz = 0.18 - row * 0.28
            for (gx, gz) in g:
                box(P["Glow"], (ox + gx * 0.08, -0.14, oz + gz * 0.08), (0.08, 0.04, 0.08))
    for i in range(5):
        box(P["Trim"], (0.35 + i * 0.05, -0.05, 0.55 - i * 0.06), (0.08, 0.1, 0.08), Rm(0, rng.uniform(0, 45), 0))


@relic("R055", {"Gem": "#DDF4FF", "Main": "#2E2B30", "Glow": "#FFFFFF"})
def b_R055(P, rng):  # Pressure Diamond
    for i in range(9):
        box(P["Main"], (rng.uniform(-0.6, 0.6), rng.uniform(-0.4, 0.4), rng.uniform(-0.85, -0.45)), (rng.uniform(0.35, 0.6), rng.uniform(0.35, 0.6), rng.uniform(0.3, 0.5)), Rm(rng.uniform(-15, 15), rng.uniform(-15, 15), rng.uniform(0, 90)))
    M = T(0, 0, 0.0) @ Rm(0, 18, 0)
    lathe(P["Gem"], [(-0.65, 0.0), (0.1, 0.6), (0.25, 0.6), (0.45, 0.38)], 0.1, 'Z', M=M)
    xf(P["Glow"], box(P["Glow"], (0, 0, 0.47), (0.5, 0.5, 0.04)), M)


# ======================================== EPIC ==========================================
@relic("R013", {"Main": "#F3E2C4", "Accent": "#FF8FA0", "Trim": "#FFC440", "Gem": "#36D6C3", "Glow": "#FFB3C1"})
def b_R013(P, rng):  # Conch of Calling
    lathe(P["Main"], [(-1.0, 0.0), (-0.6, 0.22), (0.0, 0.45), (0.45, 0.52), (0.7, 0.35)], 0.1, 'X')
    for i in range(6):
        x = -0.6 + i * 0.22; spike(P["Main"], (x, 0, 0.3 + x * 0.1), (x, 0, 0.62 + x * 0.1), 0.06)
    for x in (-0.3, 0.1):
        tube(P["Accent"], [(x, 0, 0), (x + 0.04, 0, 0)], [0.48, 0.48])
    disc(P["Accent"], 0.6, 0.12, 0.1, 'X', 0.72, (1.0, 1.15))
    disc(P["Glow"], 0.36, 0.06, 0.1, 'X', 0.79, (1.0, 1.15))
    tube(P["Trim"], [(-1.1, 0, 0), (-0.85, 0, 0)], [0.07, 0.11])
    tube(P["Trim"], [(-0.72, 0, 0), (-0.64, 0, 0)], [0.21, 0.21])
    for k in (-1, 0, 1):
        box(P["Gem"], (-0.68, -0.22, k * 0.12), (0.1, 0.06, 0.1), Rm(0, 45, 0))
    for sx in (-0.75, -0.6):
        for i in range(3):
            box(P["Trim"], (sx, -0.2, -0.24 - i * 0.08), (0.04, 0.04, 0.05))
        box(P["Trim"], (sx, -0.2, -0.52), (0.08, 0.06, 0.12)); spike(P["Trim"], (sx, -0.2, -0.58), (sx, -0.2, -0.7), 0.05)


@relic("R023", {"Main": "#3F9E8C", "Trim": "#F2D7C0", "Glass": "#1C2B3A", "Glow": "#9AF7FF"})
def b_R023(P, rng):  # Siren's Mirror
    disc(P["Main"], 0.55, 0.14, 0.09, 'Y', 0, (1.0, 1.25), rin=0.44)
    disc(P["Glass"], 0.46, 0.05, 0.09, 'Y', 0.02, (1.0, 1.25))
    for k in range(8):
        a = math.radians(k * 45 + 10); box(P["Trim"], (0.58 * math.cos(a), -0.06, 0.72 * math.sin(a)), (0.13, 0.1, 0.13), Rm(0, 45, 0))
    tube(P["Main"], [(0, 0, -0.66), (0.08, 0, -0.85), (-0.05, 0, -1.05), (0.04, 0, -1.25)], [0.09, 0.08, 0.07, 0.06])
    spike(P["Main"], (0.04, 0, -1.25), (0.25, 0, -1.38), 0.07); spike(P["Main"], (0.04, 0, -1.25), (-0.18, 0, -1.4), 0.07)
    disc(P["Glow"], 0.3, 0.03, 0.06, 'Y', -0.02, (1.0, 1.3), rin=0.25)
    for sx in (-1, 1):
        box(P["Glow"], (sx * 0.11, -0.03, 0.1), (0.07, 0.03, 0.05))
    box(P["Glow"], (0, -0.03, -0.14), (0.14, 0.03, 0.04))
    for v in P["Main"].verts: v.co.z += 0.25
    for v in P["Glass"].verts: v.co.z += 0.25
    for v in P["Glow"].verts: v.co.z += 0.25
    for v in P["Trim"].verts: v.co.z += 0.25


@relic("R024", {"Main": "#3E7F5A", "Accent": "#7BC25B", "Trim": "#FFC440", "Glow": "#C9FF6B"})
def b_R024(P, rng):  # Sceptre of the Kelp Monarch
    tube(P["Main"], [(0, 0, -1.0), (0, 0, 0.45)], [0.065, 0.065])
    hel = [(0.075 * math.cos(f * 10 * math.pi), 0.075 * math.sin(f * 10 * math.pi), -0.9 + f * 1.3) for f in [i / 50 for i in range(51)]]
    tube(P["Accent"], hel, [0.025] * len(hel))
    for i in range(6):
        z = -0.8 + i * 0.24; a = i * 70
        box(P["Accent"], (0.13 * math.cos(math.radians(a)), 0.13 * math.sin(math.radians(a)), z), (0.16, 0.05, 0.06), Rm(0, -30, a))
    for z in (-0.98, -0.05, 0.42):
        tube(P["Trim"], [(0, 0, z - 0.04), (0, 0, z + 0.04)], [0.1, 0.1])
    box(P["Main"], (0, 0, 0.55), (0.3, 0.26, 0.18))
    for k in range(4):
        a = k * 90 + 45; ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        tube(P["Main"], [(0.12 * ca, 0.12 * sa, 0.6), (0.2 * ca, 0.2 * sa, 0.78), (0.1 * ca, 0.1 * sa, 0.92)], [0.05, 0.045, 0.035])
    lathe(P["Glow"], [(0.6, 0.0), (0.68, 0.14), (0.78, 0.17), (0.9, 0.12), (0.98, 0.0)], 0.06)


@relic("R033", {"Main": "#E4B54A", "Accent": "#2E4D9A", "Gem": "#4E7BD9", "Glow": "#A8F0FF"})
def b_R033(P, rng):  # Medal of the Lost Fleet
    star(P["Main"], (0, 0, -0.2), 0.75, 0.42, 0.12, points=8)
    disc(P["Gem"], 0.36, 0.14, 0.08, 'Y', -0.02, rin=0.0)
    xf(P["Gem"], [v for v in P["Gem"].verts], T(0, 0, -0.2))
    box(P["Glow"], (0, -0.12, -0.3), (0.38, 0.05, 0.08)); box(P["Glow"], (0, -0.12, -0.24), (0.3, 0.05, 0.05))
    box(P["Glow"], (0.02, -0.12, -0.08), (0.03, 0.05, 0.3)); box(P["Glow"], (-0.06, -0.12, -0.1), (0.12, 0.04, 0.16))
    xf(P["Glow"], disc(P["Glow"], 0.4, 0.03, 0.08, 'Y', -0.08, rin=0.34), T(0, 0, -0.2))
    box(P["Main"], (0, 0, 0.62), (0.18, 0.1, 0.18))
    for sx in (-1, 1):
        box(P["Accent"], (sx * 0.14, 0.02, 0.95), (0.24, 0.06, 0.62), Rm(0, sx * 12, 0))
        box(P["Accent"], (sx * 0.2, 0.02, 1.25), (0.1, 0.06, 0.12), Rm(0, sx * 35, 0))


@relic("R034", {"Main": "#C8963E", "Accent": "#F2E6C8", "Trim": "#8A5A20", "Spin_Needle": "#FF6B5C", "Glow": "#FFD45A"})
def b_R034(P, rng):  # Compass of Lost Things
    lathe(P["Main"], [(-0.2, 0.75), (0.0, 0.78), (0.08, 0.7)], 0.08)
    disc(P["Accent"], 0.62, 0.03, 0.08, 'Z', 0.09)
    for k in range(8):
        a = math.radians(k * 45); box(P["Trim"], (0.52 * math.cos(a), 0.52 * math.sin(a), 0.11), (0.1 if k % 2 == 0 else 0.05, 0.04, 0.02), Rm(0, 0, k * 45))
    # lid: built flat at the origin, then swung up on a hinge at the back edge
    lidM = disc(P["Main"], 0.75, 0.1, 0.08, 'Z', 0)
    lidT = disc(P["Trim"], 0.4, 0.02, 0.08, 'Z', -0.06)
    for i in range(5):
        lidT += box(P["Trim"], (-0.3 + i * 0.15, 0.0, -0.07), (0.12, 0.05, 0.02)) + box(P["Trim"], (-0.24 + i * 0.15, 0.06, -0.07), (0.06, 0.05, 0.02))
    hinge = T(0, 0.78, 0.13) @ Rm(-100, 0, 0) @ T(0, -0.78, 0)
    xf(P["Main"], lidM, hinge); xf(P["Trim"], lidT, hinge)
    n = P["Spin_Needle"]
    box(n, (0, -0.18, 0.28), (0.1, 0.36, 0.05), Rm(0, 0, 0)); spike(n, (0, -0.36, 0.28), (0, -0.56, 0.28), 0.07)
    box(n, (0, 0.2, 0.28), (0.08, 0.3, 0.05)); box(n, (0, 0.38, 0.28), (0.22, 0.08, 0.05))
    disc(P["Glow"], 0.3, 0.03, 0.06, 'Z', 0.14, rin=0.22)


@relic("R035", {"Main": "#E9D7A8", "Accent": "#7B3FA0", "Trim": "#2A1E3A", "Glow": "#C27BFF"})
def b_R035(P, rng):  # Kraken's Ink Chart
    M = Rm(-55, 0, 0)
    xf(P["Main"], box(P["Main"], (0.1, 0, 0), (1.5, 0.04, 1.1)), M)
    xf(P["Main"], tube(P["Main"], [(-0.7, 0, -0.55), (-0.7, 0, 0.55)], [0.13, 0.13]), M)
    for (x, z, s) in [(0.2, 0.25, 0.22), (0.45, -0.1, 0.16), (-0.2, -0.25, 0.2), (0.0, 0.0, 0.08)]:
        xf(P["Trim"], box(P["Trim"], (x, -0.03, z), (s, 0.03, s * 0.7)), M)
    for sgn in (1, -1):
        xf(P["Glow"], box(P["Glow"], (0.45, -0.04, 0.3), (0.3, 0.03, 0.06), Rm(0, sgn * 45, 0)), M)
    xf(P["Glow"], box(P["Glow"], (0.75, -0.04, -0.5), (0.3, 0.03, 0.22)), M)
    hel = []
    for i in range(30):
        f = i / 29; a = f * 3.2 * math.pi; z = -0.55 + f * 0.9
        hel.append((-0.7 + 0.19 * math.cos(a), 0.19 * math.sin(a), z))
    hel += [(-0.45, -0.25, 0.5), (-0.3, -0.35, 0.65), (-0.38, -0.42, 0.78)]
    xf(P["Accent"], tube(P["Accent"], hel, [0.1 - 0.06 * (i / len(hel)) for i in range(len(hel))]), M)
    xf(P["Glow"], disc(P["Glow"], 0.22, 0.03, 0.07, 'Y', 0, (1.3, 1.0)), M @ T(0.55, -0.04, -0.38))


@relic("R044", {"Glass": "#BFE9FF", "Main": "#A07A4E", "Glow": "#7FFFE0"})
def b_R044(P, rng):  # Bottled Starjelly
    # glass is a few big boxes, not a voxel stack: stacked transparent faces turn opaque
    box(P["Glass"], (0, 0, -0.3), (1.15, 1.15, 1.3)); box(P["Glass"], (0, 0, 0.42), (0.8, 0.8, 0.14))
    box(P["Glass"], (0, 0, 0.6), (0.5, 0.5, 0.22))
    lathe(P["Main"], [(0.68, 0.24), (0.9, 0.26)], 0.08)
    tube(P["Main"], [(0, 0, 0.5), (0, 0, 0.58)], [0.33, 0.33])
    lathe(P["Glow"], [(-0.05, 0.3), (0.1, 0.28), (0.22, 0.18), (0.28, 0.0)], 0.07)
    for k in range(6):
        a = math.radians(k * 60); x, y = 0.18 * math.cos(a), 0.18 * math.sin(a)
        tube(P["Glow"], [(x, y, -0.05), (x * 1.2, y * 1.2, -0.35), (x * 0.8, y * 0.8, -0.6)], [0.03, 0.025, 0.0])


@relic("R045", {"Main": "#2F4A44", "Accent": "#4E7A6A", "Glow": "#7DFFC0", "Trim": "#D9D2BF"})
def b_R045(P, rng):  # Totem of the Deep Ones
    for i in range(3):
        z = -0.75 + i * 0.52; w = 0.82 - i * 0.06
        box(P["Main"], (0, 0, z), (w, 0.7, 0.5))
        box(P["Accent"], (0, -0.38, z - 0.12), (w + 0.12, 0.12, 0.14))
        box(P["Accent"], (0, -0.36, z + 0.17), (w * 0.9, 0.08, 0.06))
        for sx in (-1, 1):
            box(P["Glow"], (sx * 0.22, -0.37, z + 0.05), (0.16, 0.06, 0.14))
            box(P["Accent"], (sx * (w / 2 + 0.06), 0, z), (0.1, 0.4, 0.3))
    for x, h in ((-0.25, 0.35), (0, 0.5), (0.25, 0.35)):
        spike(P["Accent"], (x, 0, 0.55), (x * 1.3, 0, 0.55 + h), 0.09)
    for i in range(6):
        box(P["Trim"], (rng.uniform(-0.45, 0.45), -0.36, rng.uniform(-1.0, -0.85)), (0.08, 0.08, 0.08), Rm(0, 0, rng.uniform(0, 45)))


@relic("R046", {"Main": "#6E1F33", "Accent": "#2A0F18", "Trim": "#E9C7CF", "Glow": "#62C8FF"})
def b_R046(P, rng):  # Inkshroud Cloak
    lathe(P["Main"], [(-0.85, 0.72), (-0.3, 0.55), (0.3, 0.4), (0.45, 0.3)], 0.1)
    lathe(P["Main"], [(0.4, 0.33), (0.65, 0.36), (0.85, 0.28), (1.0, 0.1)], 0.08, M=T(0, 0.05, 0))
    box(P["Accent"], (0, -0.28, 0.65), (0.4, 0.12, 0.38))
    box(P["Accent"], (0, -0.5, -0.3), (0.12, 0.2, 1.0), Rm(-8, 0, 0))
    for sx in (-1, 1):
        box(P["Glow"], (sx * 0.08, -0.35, 0.68), (0.07, 0.04, 0.07))
    for k in range(8):
        a = math.radians(k * 45 + 22.5); ca, sa = math.cos(a), math.sin(a)
        tube(P["Main"], [(0.68 * ca, 0.68 * sa, -0.8), (0.95 * ca, 0.95 * sa, -0.95)], [0.12, 0.05])
        box(P["Trim"], (1.0 * ca, 1.0 * sa, -0.97), (0.07, 0.07, 0.07))


@relic("R056", {"Main": "#EEE4CC", "Accent": "#3F6F4A", "Trim": "#3A2A22", "Gem": "#E0303F", "Glow": "#9DFF7A"})
def b_R056(P, rng):  # Hydra Fang Dagger
    tube(P["Main"], [(0, 0, -0.1), (0.04, 0, 0.35), (0.14, 0, 0.75), (0.3, 0, 1.0)], [0.12, 0.1, 0.06, 0.0], flat=0.55)
    tube(P["Glow"], [(-0.1, -0.04, 0.0), (-0.07, -0.04, 0.35), (0.04, -0.04, 0.72), (0.2, -0.03, 0.92)], [0.02, 0.02, 0.016, 0.0])
    for d in [(-1, 0), (1, 0), (0, -1)]:
        dx, dy = d
        tube(P["Accent"], [(0, 0, -0.15), (dx * 0.3, dy * 0.3, -0.1), (dx * 0.42, dy * 0.42, 0.02)], [0.06, 0.05, 0.05])
        box(P["Accent"], (dx * 0.47, dy * 0.47, 0.05), (0.14, 0.14, 0.12))
        spike(P["Accent"], (dx * 0.52, dy * 0.52, 0.05), (dx * 0.66, dy * 0.66, 0.03), 0.06)
        box(P["Glow"], (dx * 0.5 + (0.07 if dy else 0), dy * 0.5 - (0.07 if dx else 0), 0.1), (0.04, 0.04, 0.04))
    tube(P["Trim"], [(0, 0, -0.2), (0, 0, -0.8)], [0.07, 0.07])
    for z in (-0.3, -0.45, -0.6, -0.75):
        tube(P["Trim"], [(0, 0, z - 0.02), (0, 0, z + 0.02)], [0.085, 0.085])
    box(P["Gem"], (0, 0, -0.9), (0.18, 0.18, 0.18), Rm(45, 0, 45))


@relic("R057", {"Main": "#3A2F2E", "Glow": "#FF7A2A", "Accent": "#5A4440"})
def b_R057(P, rng):  # Idol of the Furnace Below
    lathe(P["Main"], [(-0.85, 0.55), (-0.4, 0.66), (0.0, 0.6), (0.15, 0.42)], 0.1)
    box(P["Main"], (0, 0, 0.5), (0.85, 0.75, 0.7))
    box(P["Accent"], (0, -0.4, 0.68), (0.9, 0.12, 0.12))
    box(P["Glow"], (0, -0.38, 0.35), (0.4, 0.06, 0.2))
    for sx in (-1, 1):
        box(P["Glow"], (sx * 0.2, -0.39, 0.56), (0.12, 0.04, 0.08))
        tube(P["Main"], [(sx * 0.5, -0.05, 0.05), (sx * 0.55, -0.4, -0.25), (sx * 0.2, -0.58, -0.32)], [0.13, 0.12, 0.1])
        box(P["Accent"], (sx * 0.15, -0.62, -0.32), (0.2, 0.14, 0.18))
        box(P["Main"], (sx * 0.3, -0.5, -0.82), (0.3, 0.5, 0.2))
    for (x, z, rz) in [(-0.25, -0.1, 30), (-0.1, -0.25, -40), (0.2, -0.05, 60), (0.3, -0.35, -20), (0.0, -0.6, 10)]:
        box(P["Glow"], (x, -0.6, z), (0.2, 0.04, 0.04), Rm(0, rz, 0))


# ===================================== LEGENDARY ========================================
@relic("R025", {"Main": "#FFC440", "Accent": "#4FA35E", "Gem": "#F7F0FF", "Glow": "#8FF3FF", "Aura_Notes": "#8FF3FF"})
def b_R025(P, rng):  # Harp of the Tidesong
    tube(P["Main"], [(-0.55, 0, -0.9), (-0.55, 0, 0.75)], [0.08, 0.07])
    tube(P["Main"], [(-0.55, 0, 0.75), (-0.2, 0, 0.92), (0.2, 0, 0.8), (0.5, 0, 0.6), (0.62, 0, 0.78), (0.5, 0, 0.95), (0.36, 0, 0.88)], [0.07, 0.07, 0.07, 0.06, 0.05, 0.04, 0.0])
    tube(P["Main"], [(-0.55, 0, -0.9), (0.52, 0, 0.55)], [0.11, 0.08])
    box(P["Main"], (-0.5, 0, -0.95), (0.4, 0.3, 0.14))
    hel = [(-0.55 + 0.1 * math.cos(f * 8 * math.pi), 0.1 * math.sin(f * 8 * math.pi), -0.8 + f * 1.45) for f in [i / 40 for i in range(41)]]
    tube(P["Accent"], hel, [0.025] * len(hel))
    for i in range(7):
        x = -0.4 + i * 0.13; ztop = 0.88 - 0.25 * ((x + 0.4) / 0.9) ** 2 - 0.05; zbot = -0.9 + (x + 0.55) * (1.45 / 1.07) + 0.08
        box(P["Glow"], (x, 0, (ztop + zbot) / 2), (0.025, 0.025, max(ztop - zbot, 0.05)))
    for p in [(-0.55, 0, 0.8), (0.36, 0, 0.88)]:
        box(P["Gem"], p, (0.12, 0.12, 0.12), Rm(45, 0, 45))
    for k in range(6):
        a = math.radians(k * 60); x, y = 1.0 * math.cos(a), 1.0 * math.sin(a); z = 0.1 + 0.15 * math.sin(k)
        box(P["Aura_Notes"], (x, y, z), (0.12, 0.1, 0.1)); box(P["Aura_Notes"], (x + 0.05, y, z + 0.14), (0.03, 0.03, 0.26))
        box(P["Aura_Notes"], (x + 0.1, y, z + 0.25), (0.1, 0.03, 0.04), Rm(0, -30, 0))


@relic("R036", {"Main": "#9C6B42", "Accent": "#2F5E8E", "Trim": "#FFC440", "Glow": "#BFF6FF", "Gem": "#D9D2BF", "Eyes": "#2A1A10", "Aura_Foam": "#BFF6FF", "Aura_Pearls": "#F7F0FF"})
def b_R036(P, rng):  # Figurehead of the Weeping Queen
    box(P["Main"], (0, 0.35, -0.85), (0.55, 1.1, 0.3), Rm(12, 0, 0))
    lathe(P["Accent"], [(-0.7, 0.32), (-0.2, 0.36), (0.15, 0.3), (0.3, 0.18)], 0.08, squash=(1.0, 0.8), M=T(0, -0.1, 0) @ Rm(-15, 0, 0))
    for sx in (-1, 1):
        box(P["Main"], (0, -0.38, -0.05 + sx * 0.06), (0.62, 0.14, 0.13), Rm(0, sx * 18, 0))
    box(P["Main"], (0, -0.12, 0.42), (0.12, 0.12, 0.14))
    box(P["Main"], (0, -0.18, 0.66), (0.38, 0.36, 0.42))
    for i in range(6):
        box(P["Main"], (rng.uniform(-0.2, 0.2), 0.1 + i * 0.1, 0.62 - i * 0.12), (0.34, 0.16, 0.12))
    for sx in (-1, 1):
        box(P["Eyes"], (sx * 0.09, -0.37, 0.7), (0.07, 0.03, 0.04))
        box(P["Glow"], (sx * 0.1, -0.37, 0.58), (0.04, 0.03, 0.1)); box(P["Glow"], (sx * 0.11, -0.37, 0.48), (0.05, 0.05, 0.05))
    for k in range(5):
        x = -0.16 + k * 0.08; box(P["Trim"], (x, -0.18, 0.9 + (0.06 if k % 2 == 0 else 0)), (0.06, 0.34, 0.12 + (0.1 if k % 2 == 0 else 0)))
    box(P["Trim"], (0, -0.18, 0.88), (0.42, 0.38, 0.06))
    for i in range(7):
        box(P["Gem"], (rng.uniform(-0.25, 0.25), rng.uniform(0, 0.8), -0.98), (0.08, 0.08, 0.08), Rm(0, 0, rng.uniform(0, 45)))
    for k in range(9):
        a = math.radians(-80 + k * 20); r = 0.55
        box(P["Aura_Foam"], (r * math.sin(a), 0.15, 0.66 + r * math.cos(a)), (0.13, 0.06, 0.13), Rm(0, k * 20 - 80, 0))
    cubes(P["Aura_Pearls"], rng, 7, (0, -0.2, 0.0), 0.5, 0.75, -0.5, 0.4, 0.05, 0.08)


@relic("R037", {"Main": "#56606E", "Accent": "#B8BEC8", "Trim": "#B8343F", "Glow": "#7DFF8A", "Gem": "#24242C", "Aura_Runes": "#7DFF8A"})
def b_R037(P, rng):  # Blackwater Cutlass
    mound(P["Gem"], 0.9, 0.7, steps=3, h=0.1, z0=-1.0)
    for i in range(10):  # a broad curved blade built from stepped slabs
        f = i / 9; z = -0.78 + f * 1.22; x = 0.14 * (1 - f) ** 2 - 0.02; w = 0.1 + 0.14 * min(f * 3, 1)
        box(P["Main"], (x + w * 0.25, 0, z), (w, 0.05, 0.14))
    for z in (-0.45, -0.2, 0.05, 0.3):
        box(P["Glow"], (0.05, -0.04, z), (0.07, 0.03, 0.09), Rm(0, 20, 0))
    box(P["Accent"], (-0.05, 0, 0.62), (0.34, 0.3, 0.3))
    for sx in (-1, 1):
        box(P["Gem"], (-0.05 + sx * 0.08, -0.16, 0.66), (0.08, 0.03, 0.08))
    box(P["Accent"], (-0.05, -0.05, 0.47), (0.5, 0.12, 0.06))
    tube(P["Main"], [(-0.05, 0, 0.77), (-0.06, 0, 1.0)], [0.05, 0.05])
    box(P["Accent"], (-0.06, 0, 1.04), (0.1, 0.1, 0.08))
    for i in range(4):
        box(P["Trim"], (-0.08 + i * 0.03, -0.04, 0.98 - i * 0.07), (0.05, 0.05, 0.09))
    cubes(P["Aura_Runes"], rng, 8, (0, 0, 0.4), 0.15, 0.4, -0.2, 0.7, 0.04, 0.07)
    for k in range(8):
        a = math.radians(k * 45); box(P["Aura_Runes"], (0.62 * math.cos(a), 0.5 * math.sin(a), -0.82), (0.12, 0.04, 0.04), Rm(0, 0, k * 45 + 90))


@relic("R041", {"Main": "#3A3D45", "Accent": "#EDE4D0", "Glow": "#FFE27A", "Trim": "#6B6F78", "Aura_Rays": "#FFE27A"})
def b_R041(P, rng):  # Lantern of the Deep
    lathe(P["Main"], [(0.25, 0.55), (0.45, 0.48), (0.62, 0.28), (0.7, 0.0)], 0.08)
    lathe(P["Main"], [(-0.7, 0.0), (-0.6, 0.35), (-0.4, 0.55), (-0.3, 0.55)], 0.08)
    for k in range(10):
        a = math.radians(k * 36); ca, sa = math.cos(a), math.sin(a)
        spike(P["Accent"], (0.5 * ca, 0.5 * sa, 0.27), (0.48 * ca, 0.48 * sa, -0.02), 0.045)
        spike(P["Accent"], (0.5 * ca, 0.5 * sa, -0.32), (0.48 * ca, 0.48 * sa, -0.06), 0.04)
    lathe(P["Glow"], [(-0.28, 0.0), (-0.2, 0.22), (0.0, 0.3), (0.2, 0.22), (0.28, 0.0)], 0.07)
    tube(P["Trim"], [(0, 0, 0.7), (0, 0.05, 0.92), (0, -0.25, 1.0), (0, -0.4, 0.82)], [0.04, 0.035, 0.03, 0.03])
    box(P["Glow"], (0, -0.42, 0.76), (0.12, 0.12, 0.12), Rm(45, 0, 45))
    for i in range(3):
        box(P["Trim"], (0.1, 0.0, 0.78 + i * 0.07), (0.05, 0.03, 0.08), Rm(0, 0, 90 * (i % 2)))
    for k in range(12):
        a = k * 30
        if 60 < a < 120: continue
        M = Rm(0, a, 0)
        xf(P["Aura_Rays"], box(P["Aura_Rays"], (0, -0.62, 0.95), (0.06, 0.02, 0.5)), M)


@relic("R047", {"Main": "#2C2638", "Trim": "#FFC440", "Glow": "#FF5A3C", "Aura_Flames": "#FF5A3C"})
def b_R047(P, rng):  # Mask of the Faceless Tide
    disc(P["Main"], 0.55, 0.14, 0.08, 'Y', 0, (1.0, 1.35))
    disc(P["Main"], 0.4, 0.12, 0.08, 'Y', -0.1, (1.0, 1.35))
    for sx in (-1, 1):
        box(P["Glow"], (sx * 0.2, -0.17, 0.12), (0.22, 0.03, 0.04), Rm(0, sx * 8, 0))
        box(P["Trim"], (sx * 0.3, -0.12, -0.2), (0.04, 0.03, 0.34), Rm(0, -sx * 18, 0))
    for x, h in ((-0.18, 0.32), (0, 0.48), (0.18, 0.32)):
        spike(P["Trim"], (x, -0.02, 0.62), (x * 1.4, 0, 0.62 + h), 0.07)
    for cx, s in ((-0.2, 0.7), (0, 1.0), (0.2, 0.7)):
        for i in range(4):
            w = (0.16 - i * 0.035) * s
            box(P["Aura_Flames"], (cx + rng.uniform(-0.02, 0.02), -0.02, 0.95 + s * 0.35 + i * 0.12 * s), (w, w, w), Rm(0, 0, 45))


@relic("R048", {"Main": "#2BA6A0", "Accent": "#E6DCC4", "Trim": "#5A3A26", "Glow": "#7FFFE8", "Aura_Plates": "#7FFFE8"})
def b_R048(P, rng):  # Leviathan Scale Shield
    c = 0.1
    for j in range(18):
        z = -0.85 + c * (j + 0.5); t = (z + 0.85) / 1.8
        w = 0.62 * math.sqrt(max(1 - ((t - 0.35) / 0.35) ** 2, 0)) if t < 0.35 else 0.62 * (1 - (t - 0.35) / 0.65) ** 0.8
        if w < 0.04: continue
        y = 0.12 * (z / 0.9) ** 2
        box(P["Main"], (0, y, z), (2 * w, 0.12, c))
        box(P["Accent"], (-w, y, z), (0.1, 0.16, c)); box(P["Accent"], (w, y, z), (0.1, 0.16, c))
    for x in (-0.22, 0, 0.22):
        box(P["Main"], (x, -0.08, -0.05), (0.07, 0.06, 1.0 - abs(x) * 1.5))
        box(P["Glow"], (x, -0.12, -0.05), (0.025, 0.03, 0.9 - abs(x) * 1.5))
    for z in (-0.3, 0.2):
        box(P["Trim"], (0, 0.12, z), (0.8, 0.05, 0.1))
    for k in range(3):
        a = math.radians(k * 120 + 30); x, y = 1.0 * math.cos(a), 1.0 * math.sin(a)
        v = disc(P["Aura_Plates"], 0.18, 0.04, 0.06, 'Y', 0)
        xf(P["Aura_Plates"], v, T(x, y, 0.1 * k) @ Rm(0, 0, k * 120 + 30 + 90))


@relic("R059", {"Main": "#5B6270", "Accent": "#3A3F4A", "Glow": "#FF4A3A", "Trim": "#D9D2BF", "Aura_Rocks": "#FF4A3A"})
def b_R059(P, rng):  # Gauntlet of the Abyssal Titan
    lathe(P["Accent"], [(-1.0, 0.45), (-0.75, 0.38), (-0.45, 0.32), (-0.35, 0.34)], 0.08)
    for z in (-0.3, -0.15):
        box(P["Main"], (0, 0, z), (0.62, 0.55, 0.14))
    box(P["Main"], (0, 0, 0.12), (0.72, 0.6, 0.42))
    for i in range(4):
        x = -0.27 + i * 0.18
        box(P["Main"], (x, -0.12, 0.42), (0.16, 0.42, 0.18))
        box(P["Main"], (x, -0.36, 0.26), (0.15, 0.16, 0.3))
        spike(P["Main"], (x, -0.05, 0.5), (x, -0.05, 0.68), 0.05)
    box(P["Main"], (-0.42, -0.3, 0.12), (0.16, 0.3, 0.16), Rm(0, 0, -20))
    box(P["Glow"], (0, 0.31, 0.15), (0.2, 0.04, 0.2), Rm(0, 45, 0))
    for i in range(4):  # glowing seams on the knuckles, facing the viewer
        x = -0.27 + i * 0.18
        box(P["Glow"], (x, -0.45, 0.28), (0.03, 0.03, 0.22)); box(P["Glow"], (x, -0.34, 0.52), (0.1, 0.03, 0.03))
    box(P["Glow"], (0, -0.31, -0.02), (0.5, 0.03, 0.04))
    for i in range(8):
        a = rng.uniform(0, 2 * math.pi); box(P["Trim"], (0.42 * math.cos(a), 0.42 * math.sin(a), rng.uniform(-0.95, -0.7)), (0.08, 0.08, 0.08))
    cubes(P["Aura_Rocks"], rng, 6, (0, 0, 0.15), 0.7, 0.9, -0.3, 0.5, 0.1, 0.17)


# ======================================= MYTHIC =========================================
@relic("R038", {"Main": "#B07A3E", "Accent": "#4FA38A", "Trim": "#5A3E28", "Glow": "#8FE0FF", "Spin_Rope": "#BFF2FF", "Aura_Waves": "#8FE0FF"})
def b_R038(P, rng):  # Bell of the Last Voyage
    lathe(P["Main"], [(-0.55, 0.85), (-0.42, 0.72), (-0.1, 0.56), (0.25, 0.47), (0.55, 0.36), (0.72, 0.16)], 0.08, hollow=0.0)
    disc(P["Glow"], 0.74, 0.05, 0.08, 'Z', -0.58)
    for i in range(10):
        a = rng.uniform(0, 2 * math.pi); z = rng.uniform(-0.4, 0.5); r = 0.56 + (0.2 * (0.1 - z)) + 0.02
        box(P["Accent"], (r * math.cos(a), r * math.sin(a), z), (0.16, 0.16, 0.12), Rm(0, 0, math.degrees(a)))
    for i in range(5):
        x = -0.24 + i * 0.12; box(P["Accent"], (x, -0.62, -0.12 + (0.06 if i == 2 else 0)), (0.1, 0.04, 0.06 + (0.12 if i == 2 else 0)))
    box(P["Trim"], (0, 0, 0.82), (1.3, 0.22, 0.16)); box(P["Trim"], (0, 0, 0.72), (0.18, 0.18, 0.12))
    for k in range(24):
        f = k / 24; a = f * 2 * math.pi
        box(P["Spin_Rope"], (0.95 * math.cos(a), 0.95 * math.sin(a), 0.1 + 0.25 * math.sin(2 * a)), (0.07, 0.07, 0.07), Rm(0, 0, math.degrees(a)))
    for i, s in enumerate((0.55, 0.75, 0.95)):
        sq_frame(P["Aura_Waves"], s, 0.04, 0.04, T(0, 0, -0.78 - i * 0.16) @ Rm(90, 0, 0) @ Rm(0, 45, 0))


@relic("R050", {"Main": "#3A3548", "Accent": "#5E3A7A", "Gem": "#EDE6F2", "Glow": "#C36BFF", "Eyes": "#120A1A", "Spin_Lid": "#4A3A5C", "Aura_Fan": "#C36BFF", "Aura_Ring": "#E0B8FF"})
def b_R050(P, rng):  # Eye of the Sleeper
    for (x, z, s) in [(-0.6, 0, (0.3, 0.6, 1.2)), (0.6, 0, (0.3, 0.6, 1.2)), (0, 0.6, (1.5, 0.6, 0.3)), (0, -0.6, (1.5, 0.6, 0.3))]:
        box(P["Main"], (x, 0.05, z), s, Rm(0, rng.uniform(-6, 6), 0))
    for i in range(6):
        box(P["Main"], (rng.choice([-0.7, 0.7]) + rng.uniform(-0.1, 0.1), 0.1, rng.uniform(-0.7, 0.7)), (0.25, 0.4, 0.25), Rm(rng.uniform(0, 30), 0, rng.uniform(0, 45)))
    lathe(P["Gem"], [(-0.52, 0.0), (-0.42, 0.32), (-0.2, 0.48), (0.1, 0.5), (0.4, 0.3), (0.5, 0.0)], 0.08, 'Y')
    disc(P["Glow"], 0.27, 0.05, 0.06, 'Y', -0.52)
    box(P["Eyes"], (0, -0.56, 0), (0.08, 0.03, 0.34))
    lid = lathe(P["Spin_Lid"], [(-0.58, 0.0), (-0.46, 0.38), (-0.25, 0.55), (0.0, 0.58)], 0.08, 'Y')
    keep = [v for v in lid]
    for v in keep:
        if v.co.z < 0.08: v.co.z = 0.08 + (v.co.z - 0.08) * 0.05
    for (sx, sz) in [(-1, 1), (1, 1), (-1, -1), (1, -1)]:
        tube(P["Accent"], [(sx * 0.7, 0.3, sz * 0.6), (sx * 0.95, 0.35, sz * 0.85), (sx * 1.05, 0.2, sz * 0.55), (sx * 0.95, 0.1, sz * 0.4)], [0.1, 0.08, 0.06, 0.0])
    for k in range(7):
        a = math.radians(-60 + k * 20)
        spike(P["Aura_Fan"], (0.3 * math.sin(a), 0.45, 0.3 * math.cos(a)), (1.1 * math.sin(a), 0.5, 1.1 * math.cos(a) + 0.1), 0.06)
    sq_frame(P["Aura_Ring"], 0.42, 0.04, 0.04, T(0, -0.9, 0) @ Rm(0, 45, 0))


@relic("R052", {"Main": "#EFE7D2", "Accent": "#4A3A34", "Trim": "#7A7F88", "Glow": "#FF6A4A", "Aura_Slashes": "#FF6A4A", "Aura_Embers": "#FFB04A"})
def b_R052(P, rng):  # Leviathan's Fang
    tube(P["Accent"], [(0, 0, -1.0), (0, 0, -0.62)], [0.3, 0.36])
    for sx in (-1, 1):
        spike(P["Accent"], (sx * 0.15, 0, -0.85), (sx * 0.28, 0, -1.1), 0.12)
    tube(P["Main"], [(0, 0, -0.62), (0.05, 0, -0.1), (0.2, 0, 0.45), (0.45, 0, 0.85), (0.62, 0, 1.0)], [0.36, 0.32, 0.24, 0.12, 0.0])
    for (x, z, rz) in [(-0.05, -0.4, 20), (0.0, -0.1, -30), (0.12, 0.2, 25), (0.25, 0.5, -20)]:
        box(P["Glow"], (x, -0.3 + z * 0.05, z), (0.04, 0.04, 0.26), Rm(0, rz, 0))
    tube(P["Trim"], [(-0.9, -0.5, -0.25), (0.15, 0.1, 0.05)], [0.05, 0.05])
    spike(P["Trim"], (0.12, 0.08, 0.04), (0.4, 0.25, 0.12), 0.1)
    for i in range(6):
        box(P["Trim"], (-0.9 + i * 0.02, -0.5, -0.32 - i * 0.08), (0.05, 0.05, 0.07))
    for k in range(3):
        xf(P["Aura_Slashes"], box(P["Aura_Slashes"], (-0.75 + k * 0.16, -0.4, 0.35 - k * 0.05), (0.06, 0.04, 0.9)), Rm(0, 25, 0) @ T(0, 0, 0))
    cubes(P["Aura_Embers"], rng, 9, (0, 0, 0.0), 0.45, 0.8, -0.6, 0.9, 0.04, 0.07)


@relic("R058", {"Main": "#D9A93A", "Accent": "#5E8F6A", "Trim": "#FF7A8A", "Gem": "#F7F0FF", "Glow": "#4DFFB8", "Spin_Droplets": "#AEE9FF", "Aura_Shards": "#4DFFB8"})
def b_R058(P, rng):  # Crown of the Drowned King
    lathe(P["Main"], [(-0.5, 0.7), (-0.15, 0.72)], 0.07, hollow=0.82)
    for k in range(7):
        a = math.radians(k * (360 / 7) - 90); ca, sa = math.cos(a), math.sin(a); h = 0.55 if k % 2 == 0 else 0.38
        spike(P["Main"], (0.66 * ca, 0.66 * sa, -0.18), (0.72 * ca, 0.72 * sa, -0.18 + h), 0.13)
        box(P["Gem"], (0.74 * ca, 0.74 * sa, -0.33), (0.09, 0.09, 0.09))
    for i in range(8):
        a = rng.uniform(0, 2 * math.pi); box(P["Accent"], (0.71 * math.cos(a), 0.71 * math.sin(a), rng.uniform(-0.45, -0.2)), (0.14, 0.06, 0.12), Rm(0, 0, math.degrees(a) + 90))
    for a0 in (40, 200):
        a = math.radians(a0); ca, sa = math.cos(a), math.sin(a)
        tube(P["Trim"], [(0.72 * ca, 0.72 * sa, -0.1), (0.8 * ca, 0.8 * sa, 0.2), (0.7 * ca, 0.7 * sa, 0.42)], [0.05, 0.04, 0.03])
        tube(P["Trim"], [(0.8 * ca, 0.8 * sa, 0.15), (0.95 * ca, 0.95 * sa, 0.3)], [0.035, 0.025])
    tube(P["Trim"], [(-0.6, -0.4, -0.2), (-0.75, -0.5, -0.5), (-0.7, -0.45, -0.75)], [0.05, 0.05, 0.03])
    box(P["Glow"], (0, -0.75, -0.28), (0.26, 0.1, 0.26), Rm(0, 45, 0))
    for k in range(12):
        a = math.radians(k * 30)
        box(P["Spin_Droplets"], (1.05 * math.cos(a), 1.05 * math.sin(a), 0.0 + 0.08 * math.sin(3 * a)), (0.08, 0.08, 0.08), Rm(45, 0, 45))
    for k in range(5):
        a = math.radians(k * 72 + 20); box(P["Aura_Shards"], (0.35 * math.cos(a), 0.35 * math.sin(a), 0.65 + 0.12 * (k % 2)), (0.07, 0.07, 0.16), Rm(rng.uniform(-20, 20), rng.uniform(-20, 20), 0))


# ======================================= SECRET =========================================
@relic("R051", {"Main": "#121016", "Accent": "#E8E2F0", "Glow": "#B98CFF", "Spin_Glyphs": "#D9C2FF", "Aura_Void": "#3A1E5C"})
def b_R051(P, rng):  # Whispering Nautilus
    # coiled shell: a lens-shaped disc seen side-on, a pale spiral on its face, a glowing mouth
    lathe(P["Main"], [(-0.32, 0.45), (-0.2, 0.7), (0.0, 0.78), (0.2, 0.7), (0.32, 0.45)], 0.08, 'Y')
    pts = []
    for i in range(40):
        t = i / 39; a = t * 2.6 * math.pi; r = 0.06 + 0.62 * t ** 1.1
        pts.append((r * math.cos(a), -0.36 + 0.03 * t, r * math.sin(a)))
    tube(P["Accent"], pts, [0.03 + 0.05 * (i / 39) for i in range(40)], flat=0.4)
    for sgn in (1,):
        pass
    disc(P["Glow"], 0.32, 0.2, 0.07, 'X', 0.7, (1.4, 1.0))
    xf(P["Glow"], [v for v in P["Glow"].verts], T(0.05, 0, -0.25))
    lathe(P["Main"], [(0.62, 0.36), (0.8, 0.3)], 0.07, 'X', (1.4, 1.0), M=T(0.05, 0, -0.25))
    a_end = 0.0
    for k in range(9):
        f = k / 8; a = -0.3 - f * 1.2; r = 0.95 + 0.25 * f
        box(P["Spin_Glyphs"], (r * math.cos(a), -0.2 - 0.15 * f, r * math.sin(a)), (0.08, 0.03, 0.08), Rm(0, k * 30, 0))
    for k in range(12):
        f = k / 11; a = f * 2 * math.pi; r = 1.05
        box(P["Aura_Void"], (r * math.cos(a), 0.25, r * math.sin(a)), (0.09, 0.09, 0.09), Rm(30, k * 15, 0))


@relic("R060", {"Main": "#6A3A3C", "Glow": "#FF5A2A", "Accent": "#8A5A4C", "Spin_Rocks": "#5A4044", "Aura_Pulse": "#C0281A"})
def b_R060(P, rng):  # Heart of the Trench
    for sx in (-1, 1):
        lathe(P["Main"], [(-0.42, 0.0), (-0.3, 0.32), (0.0, 0.42), (0.3, 0.32), (0.42, 0.0)], 0.09, M=T(sx * 0.27, 0, 0.32))
    lathe(P["Main"], [(-0.9, 0.0), (-0.5, 0.35), (-0.1, 0.62), (0.25, 0.62)], 0.09, squash=(1.0, 0.75))
    for (x, z, rz) in [(-0.3, 0.35, 30), (0.25, 0.3, -35), (-0.1, -0.05, 60), (0.15, -0.3, -20), (-0.05, -0.55, 10), (0.3, 0.05, 80), (-0.4, 0.05, -50), (0.05, 0.2, 5)]:
        box(P["Glow"], (x, -0.5 + abs(x) * 0.2, z), (0.36, 0.06, 0.07), Rm(0, rz, 0))
    for sx in (-1, 1):
        tube(P["Accent"], [(sx * 0.08, 0.05, 0.6), (sx * 0.14, 0.05, 0.95)], [0.11, 0.09])
        for i in range(3):
            box(P["Glow"], (sx * (0.15 + 0.03 * i), 0.05, 1.03 + i * 0.1), (0.08 - i * 0.02,) * 3, Rm(0, 45, 0))
    cubes(P["Spin_Rocks"], rng, 7, (0, 0, 0.1), 0.85, 1.0, -0.3, 0.4, 0.09, 0.15)
    for i, s in enumerate((0.85, 1.0)):
        sq_frame(P["Aura_Pulse"], s, 0.035, 0.035, T(0, 0.15 + i * 0.1, 0.05) @ Rm(0, 45, 0))


# ======================================= CACHES =========================================
CACHE_BUILDS = {}
CACHE_COLORS = {}


def cache(cid, colors):
    def deco(fn):
        CACHE_BUILDS[cid] = fn; CACHE_COLORS[cid] = colors
        return fn
    return deco


@cache("CACHE_KELP", {"Main": "#4A5A4C", "Accent": "#8A5A34", "Trim": "#4FA35E", "Lid": "#9C6B42", "Glow": "#FFD45A"})
def c_kelp(P, rng):
    mound(P["Main"], 3.0, 2.6, steps=3, h=0.18)
    for x in (-0.7, -0.35, 0, 0.35, 0.7):
        box(P["Accent"], (x, 0, 0.95), (0.1, 1.2, 0.08))
        box(P["Accent"], (x, -0.6, 0.75), (0.1, 0.08, 0.5)); box(P["Accent"], (x, 0.6, 0.75), (0.1, 0.08, 0.5))
    for z in (0.55, 0.95):
        box(P["Accent"], (0, -0.6, z), (1.6, 0.08, 0.08)); box(P["Accent"], (0, 0.6, z), (1.6, 0.08, 0.08))
        box(P["Accent"], (-0.8, 0, z), (0.08, 1.28, 0.08)); box(P["Accent"], (0.8, 0, z), (0.08, 1.28, 0.08))
    for i in range(6):
        box(P["Glow"], (rng.uniform(-0.5, 0.5), rng.uniform(-0.35, 0.35), 0.62 + rng.uniform(0, 0.1)), (0.18, 0.18, 0.06), Rm(0, 0, rng.uniform(0, 45)))
    lid = box(P["Lid"], (0.3, 0, 0.0), (0.6, 0.8, 0.07))
    xf(P["Lid"], lid, T(0, 0, 1.0) @ Rm(0, -35, 0))
    for (x, y, h) in [(-1.1, -0.7, 1.8), (1.0, 0.8, 1.5), (1.2, -0.6, 1.1)]:
        pts = [(x + 0.12 * math.sin(i * 1.3), y, 0.5 + h * i / 6) for i in range(7)]
        tube(P["Trim"], pts, [0.07] * 6 + [0.0])


@cache("CACHE_WRECKS", {"Main": "#5A5E66", "Accent": "#6E4A30", "Trim": "#3A3D45", "Lid": "#7A5434", "Glow": "#FFD45A"})
def c_wrecks(P, rng):
    mound(P["Main"], 3.2, 2.8, steps=3, h=0.16)
    M = T(0, 0, 0.55) @ Rm(12, -18, 8)
    xf(P["Accent"], box(P["Accent"], (0, 0, 0), (1.3, 0.85, 0.6)), M)
    for x in (-0.45, 0.45):
        xf(P["Trim"], box(P["Trim"], (x, 0, 0), (0.1, 0.9, 0.64)), M)
    xf(P["Trim"], box(P["Trim"], (0, -0.45, 0.05), (0.2, 0.06, 0.2)), M)
    xf(P["Glow"], box(P["Glow"], (0, 0, 0.32), (1.1, 0.7, 0.05)), M)
    lid = box(P["Lid"], (0, -0.42, 0.06), (1.3, 0.85, 0.12))
    xf(P["Lid"], lid, M @ T(0, 0.42, 0.3) @ Rm(-22, 0, 0))
    box(P["Accent"], (0.2, -0.3, 0.75), (2.2, 0.22, 0.08), Rm(0, 18, 25))
    xf(P["Trim"], box(P["Trim"], (0.75, 0, 0), (0.06, 0.2, 0.2)), M)


@cache("CACHE_ABYSS", {"Main": "#1E2030", "Accent": "#3A3548", "Lid": "#4A4360", "Glow": "#8A7BFF"})
def c_abyss(P, rng):
    mound(P["Main"], 3.2, 2.8, steps=3, h=0.15)
    lathe(P["Accent"], [(0.3, 0.6), (0.6, 0.85), (0.95, 0.8)], 0.12, hollow=0.75)
    for i in range(7):
        a = rng.uniform(0, 2 * math.pi); r = rng.uniform(0, 0.45)
        spike(P["Glow"], (r * math.cos(a), r * math.sin(a), 0.4), (r * math.cos(a) * 1.3, r * math.sin(a) * 1.3, 0.85 + rng.uniform(0, 0.25)), 0.08)
    lid = lathe(P["Lid"], [(0.0, 0.8), (0.2, 0.7), (0.38, 0.4), (0.45, 0.0)], 0.12)
    xf(P["Lid"], lid, T(0, 0.75, 1.0) @ Rm(-40, 0, 0) @ T(0, -0.75, 0))
    for (x, z, rz) in [(-0.5, 0.6, 40), (0.45, 0.7, -30), (0.0, 0.5, 80)]:
        box(P["Glow"], (x, -0.86, z), (0.3, 0.04, 0.05), Rm(0, rz, 0))


@cache("CACHE_TRENCH", {"Main": "#2A2224", "Accent": "#3A2F2E", "Lid": "#4A3A36", "Glow": "#FF7A2A"})
def c_trench(P, rng):
    mound(P["Main"], 3.2, 2.8, steps=3, h=0.16)
    lathe(P["Accent"], [(0.3, 0.75), (0.7, 0.8), (1.05, 0.55), (1.2, 0.25)], 0.12, squash=(1.1, 0.9))
    tube(P["Accent"], [(0.1, 0.1, 1.15), (0.15, 0.1, 1.55)], [0.18, 0.13])
    box(P["Glow"], (0.15, 0.1, 1.6), (0.18, 0.18, 0.08))
    for (x, z, rz) in [(-0.4, 0.6, 30), (0.3, 0.8, -40), (0.0, 0.5, 70), (0.5, 0.45, 10)]:
        box(P["Glow"], (x, -0.73, z), (0.32, 0.04, 0.05), Rm(0, rz, 0))
    lid = box(P["Lid"], (0, -0.06, 0.25), (0.9, 0.12, 0.5))
    xf(P["Lid"], lid, T(0, -0.72, 0.4) @ Rm(25, 0, 0))
    box(P["Glow"], (0, -0.66, 0.68), (0.7, 0.04, 0.4))
