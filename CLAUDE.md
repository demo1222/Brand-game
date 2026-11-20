# Abyss Salvage: notes for Claude

## Before starting

Read `docs/NEXT_SESSION.md` first: how the owner works, current state, and what's next.
For any UI work, follow `docs/UI_STYLE_GUIDE.md` (the owner's reference look: buttons, windows,
shop cards, motion, and "never close on a backdrop click").

## Workflow: hybrid (code in files, visuals in Studio)

- **Code** (logic, UI, physics, systems) is written only in `src/`. Rojo syncs it into Studio.
  Never edit synced scripts inside Studio; the next sync overwrites them.
- **The map lives in the place, not in code.** `Workspace.AbyssWorld` (attribute `Baked = true`)
  is saved in the Studio place and edited by hand there. At runtime `WorldService` adopts it and
  reads gameplay data back from the instances (`scan()`); it only builds from code when no baked
  map exists. Do not move map visuals back into rebuild scripts.
- What the code finds by name or marker, so keep these when editing the map: `Docks/DockN`
  (with `Platform`, `StandN`, `VaultN`, `CollectorPad`, `Sign`, `GateButton`, `LaserGate`,
  `DiveRamp`, `AirRefillPrompt`), `LootAnchor` attachments (where loot spawns; they move with
  their part), `Prop` models with a `Zone` attribute, `Landmark` parts, `AirPocket` parts, and
  the `Plaza` objects `LuckTotem`, `VipDoor`, `VipLounge`.
- To rebuild the map from code (wipes hand edits): in edit mode,
  `require(game.ServerScriptService.Server.Services.WorldService).Bake(require(game.ServerScriptService.Server.Services.RelicMeshService))`, then save the place.
- Visual tuning in Studio can go through the Roblox Studio MCP. Keep screenshot use lean: check
  only what changed, not the whole scene every time.
