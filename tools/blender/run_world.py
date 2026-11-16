# Build, preview and export the world models (zone guardians and reef props) in Blender.
# In Blender: ns = {}; exec(open(".../run_world.py").read(), ns). Optional ns["IDS"] = [...].
# Writes models/monsters/<ID>.glb, models/world/<ID>.glb, a bundle per folder
# (monsters_bundle_1.glb, world_bundle_1.glb: upload these, like the relic bundles) and
# previews in each folder's previews/ (plus a contact sheet).
import os
BASE = r"C:\Users\Zarylbek\Documents\GitHub\Brand game\tools\blender"
exec(open(os.path.join(BASE, "blocky_kit.py")).read(), globals())
exec(open(os.path.join(BASE, "world_builds.py")).read(), globals())

ALL = list(MONSTER_BUILDS.keys()) + list(PROP_BUILDS.keys())
IDS = globals().get("IDS") or ALL
sc = scene("World_Blocky"); coll = sc.collection
result = {}
built = {"monsters": [], "world": []}
for rid in IDS:
    old = bpy.data.objects.get(rid)
    if old is not None:
        for o in reversed(tree(old)): bpy.data.objects.remove(o, do_unlink=True)
    for me in [m for m in bpy.data.meshes if m.users == 0 and m.name.startswith(rid + "_")]:
        bpy.data.meshes.remove(me)
    for mt in [m for m in bpy.data.materials if m.users == 0 and m.name.startswith(rid + "_")]:
        bpy.data.materials.remove(mt)
    is_monster = rid in MONSTER_BUILDS
    fn = (MONSTER_BUILDS if is_monster else PROP_BUILDS)[rid]
    colors = (MONSTER_COLORS if is_monster else PROP_COLORS)[rid]
    P = Parts(); fn(P, random.Random(sum(ord(ch) * (i + 1) for i, ch in enumerate(rid))))
    root, tris = finish(rid, P, colors, coll)
    built["monsters" if is_monster else "world"].append(root); result[rid] = tris

every = [r for group in built.values() for r in group]
others = [o for o in sc.objects if o.parent is None and o.type == 'EMPTY' and o not in every]
for sub, roots in built.items():
    d = os.path.join(REPO, "models", sub); pd = os.path.join(d, "previews")
    os.makedirs(pd, exist_ok=True)
    for r in roots:
        render_preview(sc, r, os.path.join(pd, f"{r.name}.png"), others=others + [b for b in every if b is not r])
        export_glb(sc, [r], os.path.join(d, f"{r.name}.glb"))
    if roots and set(r.name for r in roots) == set(k for k in ALL if (k in MONSTER_BUILDS) == (sub == "monsters")):
        # all of this folder's models in one file, spread out so they don't overlap
        for i, r in enumerate(roots):
            r.location = (i * 6.0, 0, 0)
        export_bundle = os.path.join(d, f"{sub}_bundle_1.glb")
        for o in sc.objects: o.select_set(False)
        for r in roots:
            for x in tree(r): x.select_set(True)
        bpy.context.view_layer.objects.active = roots[0]
        bpy.ops.export_scene.gltf(filepath=export_bundle, export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
        for r in roots:
            r.location = (0, 0, 0)

# contact sheet of everything built
for x in sc.objects: x.hide_render = True
for i, r in enumerate(every):
    r.location = ((i % 4) * 6.0, 0, -(i // 4) * 5.0); r.rotation_euler = (0, 0, math.radians(-35))
    for x in tree(r): x.hide_render = False
for l in [o for o in sc.objects if o.type == 'LIGHT']: l.hide_render = False
rows = (len(every) + 3) // 4
cam = sc.camera; cam.hide_render = False; cam.data.type = 'ORTHO'; cam.data.ortho_scale = 4 * 6.0 * 1.05
cx = 1.5 * 6.0; cz = -(rows - 1) * 5.0 / 2
cam.location = (cx + 6, -24, cz + 9); cam.rotation_euler = (Vector((cx, 0, cz)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.render.resolution_x = 1600; sc.render.resolution_y = int(1600 * rows * 5.0 / 24.0) + 120
sc.render.filepath = os.path.join(REPO, "models", "world", "previews", "sheet.png")
bpy.ops.render.render(write_still=True, scene=sc.name)
cam.data.type = 'PERSP'; sc.render.resolution_x = 512; sc.render.resolution_y = 512
for r in every: r.location = (0, 0, 0); r.rotation_euler = (0, 0, 0)
RESULT = result
