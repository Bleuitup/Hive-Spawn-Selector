# CLAUDE.md

Guidance for AI assistants and contributors working in this repository.

## What this is

**Hive Spawn Selection** is a server-side mod for the game **Natural Selection 2**. Before a
round, the **alien commander** picks the team's starting hive from a UI; the **marines** are then
placed at a random *legal* partner location for that hive. It also freezes players and locks
commander logout during the start-of-round countdown.

The underlying approach is adapted from the **NSL** plugin by **Dragon (xToken)** —
<https://github.com/xToken/NSL>. Files that borrow from it credit it in their header. `README.md`
is the user/server-admin facing doc; this file is for development.

This is a **standalone NS2 mod**, not a Shine extension — an earlier `shine-extension` branch
converted it into one (with an integration against Shine-Epsilon's CustomSpawns plugin so the
alien commander could only pick spawns CustomSpawns already permitted per-map), but that approach
was reverted: it made the mod harder to debug than the standalone form, which was already working
correctly. Don't re-attempt that conversion without being asked again.

## Layout

Mod files live at the repo root (standard NS2 layout). Load order is declared in
`lua/entry/HiveSpawnSelection.entry` (`Client` / `Server` / `Predict` bootstraps + `Priority`).

- `lua/HiveSpawnSelection/HiveSpawnSelection_Utility.lua` — vendored `Class_ReplaceMethod`; loaded first.
- `lua/HiveSpawnSelection/HiveSpawnSelection_Shared.lua` — network message, a shared `TechPoint` getter,
  `GameInfo` synced fields (`spawnSelectionEnabled`, `spawnSelected`), and the countdown freeze.
  Loaded by client, server **and** predict.
- `lua/HiveSpawnSelection/HiveSpawnSelection_Server.lua` — all server logic (pick handler, marine selection,
  the spawn-apply mechanism, logout lock, `sv_spawnselect` admin toggle).
- `lua/HiveSpawnSelection/HiveSpawnSelection_Client.lua` — attaches the UI to `AlienCommander`.
- `lua/HiveSpawnSelection/GUIHiveSpawnSelectionMenu.lua` — the "SELECT STARTING LOCATION" panel.
- `lua/HiveSpawnSelection/HiveSpawnSelection_Predict.lua` — loads shared defs into the prediction VM.

Naming: the mod's name is **Hive Spawn Selection** and file/class/network-message identifiers
follow that. `sv_spawnselect` (the console command) and the internal `GameInfo` field names
(`spawnSelectionEnabled`, `spawnSelected`, local vars like `kEnabled`) are deliberately left as
generic descriptive names rather than renamed to match — that's an intentional, already-decided
scope boundary, not an oversight.

## NS2 specifics worth knowing before changing things

- **Spawn placement is applied via `Server.teamSpawnOverride`**, NOT by hooking
  `NS2Gamerules:ChooseTechPoint`. `ResetGame` checks, in order: `Server.teamSpawnOverride` →
  `Server.spawnSelectionOverrides` (fixed per-map pairs from `spawn_selection_override` map
  entities, common on competitive servers) → `ChooseTechPoint`. Because comp maps populate the
  middle one, a `ChooseTechPoint` hook gets silently bypassed. We set
  `Server.teamSpawnOverride = {{ marineSpawn=<lowercase>, alienSpawn=<lowercase> }}` (names must be
  lowercase to match) and clear it on random/disable/round-end.
- **The marine spawn must be a *legal* partner** of the alien pick, or `ResetGame` rejects the
  override and falls back to a random map pair. We pick the marine name randomly (`math.random`,
  not the engine's `techPointRandomizer` which kept returning the first entry) from the partners
  the map pairs with the alien hive in `Server.spawnSelectionOverrides`.
- **Pre-round states:** WarmUp → PreGame (free roam) → Countdown (engine teleports players to
  spawns + drops initial structures and freezes input) → Started. Do not key custom freezes off
  `Player:GetCountdownActive` — that flag also drives the countdown zoom camera / "Game is starting"
  text, and starts it early. Freeze via `Player:GetCanControl`→false plus a no-op
  `Player:UpdateViewAngles`, gated on `GameInfo:GetState() == kGameState.Countdown`.
- **Adding networkVars to a vanilla entity** is fine: `Class_Reload("Class", {newVars})` *merges*
  (doesn't replace). Movement/freeze overrides that affect prediction must be loaded in the
  **Predict** VM too, or the local player rubber-bands.
- `Class_ReplaceMethod(class, name, fn)` returns the original for chaining and also replaces it on
  already-derived classes. Vanilla `TechPoint:GetTeamNumberAllowed()` is server-only — the shared
  getter in `HiveSpawnSelection_Shared.lua` exists so client UI can call it.

## Deliberate behaviors — do not "fix" these

Each of these looks like an oversight in review and is not. Confirmed by the maintainer:

- **A selection survives `sv_reset`.** Only `EndGame` clears the cached pick, so an admin reset
  restarts the round on the same spawns. That is what a scrim reset should do.
- **`sv_spawnselect false` does not persist across a map change.** `kEnabled` is a module local
  and the Lua VM is rebuilt per map, so the mod returns to enabled. The supported way to disable
  it permanently is to remove the mod from the server.
- **There is no debug logging in the shipped build.** The diagnostics were removed in `d2acfcb`
  once the feature was verified. If a remote problem needs diagnosing, add them back behind a
  `kDebug` flag (off by default) and keep the flag once it's fixed.
- **Never run alongside NSL.** Its `customspawns` feature writes the same
  `Server.teamSpawnOverride`, so the two mods fight over the spawn. This is documented for
  admins in `README.md`; do not try to make them interoperate.

## Conventions

- Match the surrounding file's indentation: the server/shared/client/utility files use **tabs**;
  `GUIHiveSpawnSelectionMenu.lua` uses 4-space indent (kept from its NSL origin).
- Gate new round-affecting behavior on the synced enable flag (`GameInfo:GetSpawnSelectionEnabled()`
  / the server-side `kEnabled`) so `sv_spawnselect false` reverts cleanly to vanilla.
- Keep `README.md` user-facing; put developer notes here.
