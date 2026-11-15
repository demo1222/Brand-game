# Blocky modelling kit for Abyss Salvage relics (docs/ART_PASS_PLAN.md).
# Run inside Blender: exec(open(path).read(), ns). Everything is built from boxes, so the
# models match the chosen "blocky" style. Every helper returns the verts it made, so callers
# can move a group with xf().
import bpy, bmesh, math, random, os, json
from mathutils import Vector, Matrix, Euler

REPO = r"C:\Users\Zarylbek\Documents\GitHub\Brand game"
NAVY = "#14213D"


def lin(h):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c)


def Rm(rx=0.0, ry=0.0, rz=0.0):
    return Euler((math.radians(rx), math.radians(ry), math.radians(rz))).to_matrix().to_4x4()


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation(Vector((x, y, z)))


class Parts:
    """Role name -> bmesh, created on first use."""
    def __init__(self):
        self.bms = {}

    def __getitem__(self, role):
        if role not in self.bms:
            self.bms[role] = bmesh.new()
        return self.bms[role]


def xf(bm, verts, M):
    if verts:
        bmesh.ops.transform(bm, matrix=M, verts=list(verts))
    return verts


def box(bm, c, s, rot=None):
    M = T(*c) @ (rot if rot is not None else Matrix.Identity(4)) @ Matrix.Diagonal((max(s[0], 1e-3), max(s[1], 1e-3), max(s[2], 1e-3), 1))
    return bmesh.ops.create_cube(bm, size=1.0, matrix=M)["verts"]


def tube(bm, pts, radii, flat=1.0):
    """Square-section tube through pts. radii per point; 0 makes a point. flat squashes one side."""
    sides = 4; twist = math.pi / 4
    pts = [Vector(p) for p in pts]; n = len(pts); out = []
    tans = [(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized() for i in range(n)]
    t0 = tans[0]; a = Vector((0, 0, 1)) if abs(t0.z) < 0.9 else Vector((1, 0, 0))
    nrm = (a - t0 * a.dot(t0)).normalized(); rings = []
    for i in range(n):
        t = tans[i]; nn = nrm - t * nrm.dot(t)
        if nn.length < 1e-6:
            a = Vector((1, 0, 0)); nn = a - t * a.dot(t)
        nrm = nn.normalized(); b = t.cross(nrm); r = radii[i]
        if r <= 1e-5:
            v = bm.verts.new(pts[i]); rings.append([v]); out.append(v)
        else:
            ring = [bm.verts.new(pts[i] + r * (math.cos(2 * math.pi * k / sides + twist) * nrm + flat * math.sin(2 * math.pi * k / sides + twist) * b)) for k in range(sides)]
            rings.append(ring); out += ring

    def F(vs):
        try:
            bm.faces.new(vs)
        except ValueError:
            pass
    for A, B in zip(rings, rings[1:]):
        if len(A) == 1 and len(B) == 1:
            continue
        if len(A) == 1:
            for k in range(sides): F((A[0], B[k], B[(k + 1) % sides]))
        elif len(B) == 1:
            for k in range(sides): F((A[k], A[(k + 1) % sides], B[0]))
        else:
            for k in range(sides): F((A[k], A[(k + 1) % sides], B[(k + 1) % sides], B[k]))
    if len(rings[0]) > 1: F(list(reversed(rings[0])))
    if len(rings[-1]) > 1: F(rings[-1])
    return out


def spike(bm, a, b, r):
    return tube(bm, [a, b], [r, 0.0])


def star(bm, c, ro, ri, depth, rot=None, points=5):
    """Faceted star in the XZ plane facing -Y (a bipyramid)."""
    c = Vector(c); M = (rot if rot is not None else Matrix.Identity(4)).to_3x3(); ring = []
    for k in range(points * 2):
        ang = math.pi / 2 + k * math.pi / points; r = ro if k % 2 == 0 else ri
        ring.append(bm.verts.new(c + M @ Vector((r * math.cos(ang), 0, r * math.sin(ang)))))
    f = bm.verts.new(c + M @ Vector((0, -depth, 0))); bk = bm.verts.new(c + M @ Vector((0, depth, 0)))
    m = len(ring)
    for k in range(m):
        bm.faces.new((ring[k], ring[(k + 1) % m], f)); bm.faces.new((ring[(k + 1) % m], ring[k], bk))
    return ring + [f, bk]


def _map(axis, u, v, h):
    if axis == 'Z': return (u, v, h)
    if axis == 'Y': return (u, h, v)
    return (h, u, v)  # X


def disc(bm, r, thick, cell=0.1, axis='Y', at=0.0, squash=(1.0, 1.0), rin=0.0, rows=None):
    """One pixel-disc layer: rows of boxes. axis = disc normal. squash scales (u, v)."""
    out = []
    n = max(1, int(round(2 * r / cell))); step = 2 * r / n
    for j in range(n):
        v = -r + step * (j + 0.5)
        if rows and not rows(v / r):
            continue
        w = r * math.sqrt(max(1 - (v / r) ** 2, 0.0)); w = max(round(w / cell) * cell, cell * 0.5)
        if rin > 0 and abs(v) < rin:
            wi = round(math.sqrt(rin * rin - v * v) / cell) * cell
            if w - wi >= cell * 0.5:
                for sgn in (-1, 1):
                    uc = sgn * (w + wi) / 2
                    out += box(bm, _map(axis, uc * squash[0], v * squash[1], at), _map(axis, (w - wi) * squash[0], step * squash[1], thick))
            continue
        out += box(bm, _map(axis, 0, v * squash[1], at), _map(axis, 2 * w * squash[0], step * squash[1], thick))
    return out


def _interp(profile, h):
    for (h0, r0), (h1, r1) in zip(profile, profile[1:]):
        if h0 <= h <= h1:
            t = 0 if h1 == h0 else (h - h0) / (h1 - h0)
            return r0 + (r1 - r0) * t
    return 0.0


def lathe(bm, profile, cell=0.1, axis='Z', squash=(1.0, 1.0), hollow=0.0, M=None):
    """Stack of pixel discs along axis; profile = [(h, r), ...] sorted by h."""
    out = []; h0 = profile[0][0]; h1 = profile[-1][0]
    n = max(1, int(round((h1 - h0) / cell))); step = (h1 - h0) / n
    for i in range(n):
        h = h0 + step * (i + 0.5); r = _interp(profile, h)
        if r >= cell * 0.35:
            out += disc(bm, r, step, cell, axis, h, squash, rin=r * hollow if hollow else 0.0)
    if M is not None:
        xf(bm, out, M)
    return out


def sq_frame(bm, half, t, depth, M):
    """Square ring in the XZ plane (a halo), transformed by M."""
    out = []
    for (dx, dz, sx, sz) in [(0, half, 2 * half + t, t), (0, -half, 2 * half + t, t), (half, 0, t, 2 * half), (-half, 0, t, 2 * half)]:
        out += box(bm, (dx, 0, dz), (sx, depth, sz))
    return xf(bm, out, M)


def sparkle(bm, c, s):
    out = box(bm, c, (s, s * 0.12, s * 0.18)) + box(bm, c, (s * 0.18, s * 0.12, s))
    out += box(bm, c, (s * 0.3, s * 0.12, s * 0.3), Rm(0, 45, 0))
    return out


def cubes(bm, rng, n, center, rmin, rmax, zmin, zmax, smin, smax):
    out = []
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi); r = rng.uniform(rmin, rmax); z = rng.uniform(zmin, zmax); s = rng.uniform(smin, smax)
        out += box(bm, (center[0] + r * math.cos(a), center[1] + r * math.sin(a), center[2] + z), (s, s, s), Rm(rng.uniform(0, 90), rng.uniform(0, 90), rng.uniform(0, 90)))
    return out


def mound(bm, w, d, steps=3, h=0.16, z0=0.0, shrink=0.75):
    out = []
    for i in range(steps):
        k = shrink ** i
        out += box(bm, (0, 0, z0 + h / 2 + i * h), (w * k, d * k, h))
    return out


# ----------------------------------------------------------------------------------------
# Objects, materials, scene, render, export
# ----------------------------------------------------------------------------------------
NEON_PREFIX = ("Glow", "Aura_", "Spin_")


def is_neon(role):
    return role == "Glow" or role.startswith("Aura_") or role.startswith("Spin_")


def make_mat(name, hexc, role):
    m = bpy.data.materials.new(name)
    try: m.use_nodes = True
    except Exception: pass
    b = m.node_tree.nodes.get("Principled BSDF"); c = lin(hexc)
    b.inputs["Base Color"].default_value = (*c, 1); b.inputs["Roughness"].default_value = 0.65
    b.inputs["Metallic"].default_value = 0.0
    if is_neon(role):
        b.inputs["Emission Color"].default_value = (*c, 1)
        b.inputs["Emission Strength"].default_value = 1.6 if role == "Glow" else 1.8
    if role == "Glass":
        b.inputs["Alpha"].default_value = 0.35
        try: m.surface_render_method = 'BLENDED'
        except Exception: pass
    return m


def finish(rid, parts, colors, coll):
    root = bpy.data.objects.new(rid, None); coll.objects.link(root); tris = 0
    for role, bm in parts.bms.items():
        if len(bm.verts) == 0:
            bm.free(); continue
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        tris += sum(len(f.verts) - 2 for f in bm.faces)
        me = bpy.data.meshes.new(f"{rid}_{role}"); bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(f"{rid}_{role}", me); coll.objects.link(ob); ob.parent = root
        me.materials.append(make_mat(f"{rid}_{role}", colors.get(role, "#FF00FF"), role))
    return root, tris


def scene(name="Relics_Blocky"):
    sc = bpy.data.scenes.get(name) or bpy.data.scenes.new(name)
    try: bpy.context.window.scene = sc
    except Exception: pass
    if not sc.world:
        w = bpy.data.worlds.get("StyleTest_World") or bpy.data.worlds.new("Relics_World")
        try: w.use_nodes = True
        except Exception: pass
        bg = w.node_tree.nodes.get("Background"); bg.inputs["Color"].default_value = (*lin(NAVY), 1)
        sc.world = w
    if not sc.camera:
        coll = sc.collection
        for nm, rot, e, col in [("Key", (50, -25, -35), 3.2, (1, .96, .9)), ("Rim", (-60, 0, 160), 2.5, (.6, .8, 1)), ("Fill", (70, 0, 40), .6, (.7, .75, 1))]:
            l = bpy.data.lights.new(f"RB_{nm}", 'SUN'); l.energy = e; l.color = col; l.angle = math.radians(8)
            o = bpy.data.objects.new(f"RB_{nm}", l); coll.objects.link(o); o.rotation_euler = tuple(math.radians(a) for a in rot)
        cd = bpy.data.cameras.new("RB_Cam"); cd.lens = 50
        cam = bpy.data.objects.new("RB_Cam", cd); coll.objects.link(cam); sc.camera = cam
    r = sc.render; r.engine = 'BLENDER_EEVEE'; r.resolution_x = 512; r.resolution_y = 512
    sc.view_settings.view_transform = 'Standard'
    try: sc.eevee.taa_render_samples = 48
    except Exception: pass
    # Bloom through the compositor. The Render Layers node must point at THIS scene.
    try:
        gname = f"{name}_Bloom"
        ng = bpy.data.node_groups.get(gname) or bpy.data.node_groups.new(gname, 'CompositorNodeTree')
        for nd in list(ng.nodes): ng.nodes.remove(nd)
        if not ng.interface.items_tree:
            ng.interface.new_socket("Image", in_out='OUTPUT', socket_type='NodeSocketColor')
        rl = ng.nodes.new("CompositorNodeRLayers"); rl.scene = sc
        gl = ng.nodes.new("CompositorNodeGlare"); out = ng.nodes.new("NodeGroupOutput")
        names = [i.name for i in gl.inputs]
        if "Type" in names:
            try: gl.inputs["Type"].default_value = 'Bloom'
            except Exception: pass
        for nm, val in (("Threshold", 0.85), ("Strength", 0.7), ("Size", 0.6)):
            if nm in names:
                try: gl.inputs[nm].default_value = val
                except Exception: pass
        ng.links.new(rl.outputs["Image"], gl.inputs["Image"]); ng.links.new(gl.outputs["Image"], out.inputs[0])
        sc.compositing_node_group = ng
    except Exception:
        pass
    return sc


def tree(o):
    return [o] + list(o.children_recursive)


def render_preview(sc, root, path, others=()):
    for o in others:
        for x in tree(o): x.hide_render = True
    for x in tree(root): x.hide_render = False
    bpy.context.view_layer.update()
    pts = []
    for o in tree(root):
        if o.type == 'MESH': pts += [o.matrix_world @ Vector(v) for v in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    ctr = (lo + hi) / 2; size = (hi - lo).length
    cam = sc.camera; cam.data.lens = 50
    d = Vector((0.35, -1, 0.42)).normalized()
    cam.location = ctr + d * (size * 0.5 / math.tan(math.atan(18 / 50)) * 1.05)
    cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True, scene=sc.name)


def export_glb(sc, roots, path):
    vl = bpy.context.view_layer
    saved = {r.name: (r.location.copy(), r.rotation_euler.copy()) for r in roots}
    for o in sc.objects: o.select_set(False)
    for r in roots:
        r.location = (0, 0, 0); r.rotation_euler = (0, 0, 0)
        for x in tree(r): x.select_set(True)
    vl.objects.active = roots[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
    for r in roots:
        r.location, r.rotation_euler = saved[r.name]
    for o in sc.objects: o.select_set(False)
