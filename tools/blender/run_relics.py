# Build, preview and export blocky relics in Blender.
# In Blender: ns = {"IDS": ["R038", ...]}; exec(open(".../run_relics.py").read(), ns)
# Results land in ns["RESULT"]. Set ns["SHEET"] = "name" to also render a contact sheet.
import os
KIT = os.path.join(os.path.dirname(__file__) if "__file__" in dir() else r"C:\Users\Zarylbek\Documents\GitHub\Brand game\tools\blender", "blocky_kit.py")
BASE = r"C:\Users\Zarylbek\Documents\GitHub\Brand game\tools\blender"
exec(open(os.path.join(BASE, "blocky_kit.py")).read(), globals())
exec(open(os.path.join(BASE, "relic_builds.py")).read(), globals())

IDS = globals().get("IDS") or list(BUILDS.keys())
SHEET = globals().get("SHEET")
sc = scene("Relics_Blocky"); coll = sc.collection
prev_dir = os.path.join(REPO, "models", "relics", "previews")
os.makedirs(prev_dir, exist_ok=True)
result = {}
built = []
for rid in IDS:
    old = bpy.data.objects.get(rid)
    if old is not None:
        for o in reversed(tree(old)): bpy.data.objects.remove(o, do_unlink=True)
    for me in [m for m in bpy.data.meshes if m.users == 0 and m.name.startswith(rid + "_")]:
        bpy.data.meshes.remove(me)
    for mt in [m for m in bpy.data.materials if m.users == 0 and m.name.startswith(rid + "_")]:
        bpy.data.materials.remove(mt)
    is_cache = rid.startswith("CACHE_")
    fn = (CACHE_BUILDS if is_cache else BUILDS)[rid]
    colors = (CACHE_COLORS if is_cache else COLORS)[rid]
    P = Parts(); fn(P, random.Random(sum(ord(ch) * (i + 1) for i, ch in enumerate(rid))))
    root, tris = finish(rid, P, colors, coll)
    built.append(root); result[rid] = tris

others = [o for o in sc.objects if o.parent is None and o.type == 'EMPTY' and o not in built]
for r in built:
    render_preview(sc, r, os.path.join(prev_dir, f"{r.name}.png"), others=others + [b for b in built if b is not r])
    sub = "caches" if r.name.startswith("CACHE_") else "relics"
    export_glb(sc, [r], os.path.join(REPO, "models", sub, f"{r.name}.glb"))

if SHEET:
    roots = [o for o in sc.objects if o.parent is None and o.type == 'EMPTY']
    roots.sort(key=lambda o: o.name)
    cols = 7
    for i, r in enumerate(roots):
        r.location = ((i % cols) * 2.8, 0, -(i // cols) * 2.8); r.rotation_euler = (0, 0, math.radians(20))
        for x in tree(r): x.hide_render = False
    rows = (len(roots) + cols - 1) // cols
    cam = sc.camera; cam.data.type = 'ORTHO'; cam.data.ortho_scale = max(cols, rows * 1.6) * 2.8 * 1.02
    cx = (cols - 1) * 2.8 / 2; cz = -(rows - 1) * 2.8 / 2
    cam.location = (cx, -20, cz + 4); cam.rotation_euler = (Vector((cx, 0, cz)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.resolution_x = 2100; sc.render.resolution_y = int(2100 * rows * 1.0 / cols * 1.15) + 60
    sc.render.filepath = os.path.join(prev_dir, f"{SHEET}.png")
    bpy.ops.render.render(write_still=True, scene=sc.name)
    cam.data.type = 'PERSP'; sc.render.resolution_x = 512; sc.render.resolution_y = 512

with open(os.path.join(REPO, "models", "relics", "colors.json"), "w") as f:
    json.dump({"relics": COLORS, "caches": CACHE_COLORS}, f, indent=1)
RESULT = result
