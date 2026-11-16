# Abyss Salvage: notes for Claude

## Before starting

Read `docs/NEXT_SESSION.md` first: how the owner works, current state, and what's next.
For any UI work, follow `docs/UI_STYLE_GUIDE.md` (the owner's reference look: buttons, windows,
shop cards, motion, and "never close on a backdrop click").

## Workflow: hybrid (code in files, visuals in Studio)

- **Code** (logic, UI, physics, systems) is written only in `src/`. Rojo syncs it into Studio.
  Never edit synced scripts inside Studio; the next sync overwrites them.
- **Visuals** (layout, props, lighting, placement, tuning) may be iterated in Studio through the
  Roblox Studio MCP, with screenshots.
- **Keep in history only the most important visual pieces:** the dock layout, the diving board,
  the sea, and anything the owner calls a keeper. Export each one to a rebuild script in `src/`,
  and record it in the commit. Skip small tweaks; they stay in Studio and are not versioned.
- Keep screenshot use lean: check only what changed, not the whole scene every time.
