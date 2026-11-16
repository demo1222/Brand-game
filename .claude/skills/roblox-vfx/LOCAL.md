# roblox-vfx local settings (this machine)

- ROBLOX_VFX_LIB (a folder path; also settable as an environment variable of the same name): your VFX library folder. Value: C:/Users/Zarylbek/RobloxVFX/Library
- Studio bridge: Roblox's built-in Studio MCP (`execute_luau`, `screen_capture`, `upload_image`). Value: Roblox Studio MCP
- Sink port: the localhost port `recipe_server.py` listens on. Value: 48752
- Studio window: you need Studio maximised and in the foreground for screenshots (see trap 5). Nothing to fill in.
- Blender: Value: C:/Program Files/Blender Foundation/Blender 5.3/blender.exe (the Blender MCP is also connected)
- Lune folder: Value: C:/Users/Zarylbek/Documents/GitHub/Brand game (its aftman.toml lists Lune; run `aftman install` there once, answering yes to trust)
- VFX research folder: Value: C:/Users/Zarylbek/RobloxVFX/Research
- Open Cloud key: environment variable name only. Value: ROBLOX_OPEN_CLOUD_KEY (not set yet; textures can upload through the Studio MCP's upload_image instead)
- Node.js: needed by `sim/studio_kit.js`, `sim/snap.js` tooling and `phys_audit.js`. Value: not installed yet
- Texture library and meshes: base textures, magic circles, painted textures and all Blender meshes built
  (2026-11-15). The 2,570-texture library is only partly built: this PC runs out of memory with many workers
  (32 cores, ~2.4 GB free). Build with single-threaded BLAS and few workers, ideally per family:
  `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python build_library.py --procs 2 --limit 3 --families ring,star,...`
  Built so far: ring, starburst, flare, streak, star, sparks, explosion, shockwave, charge_in, magic_poof,
  comic_burst (3 per style). Prop skins (`make_prop_tex.py`) not run yet. Value: partial
- Uploads: through the Studio MCP `upload_image` from `python sim/serve.py 8765` (http://127.0.0.1:8765/textures/...),
  no API key needed. Uploaded 2026-11-16 (Abyss Salvage chest opening, version B): see TEX in
  src/client/UI/RelicOpening.luau for the 8 ids.
