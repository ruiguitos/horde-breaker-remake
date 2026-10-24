# Instructions for Codex (and other agents)

Read `CLAUDE.md` first: it holds the project rules and applies to every
agent (Godot 4.7, typed GDScript, in-game text in English, user-facing
docs in European Portuguese, free licences only, `docs/DECISIONS.md` is
never edited by agents).

Practical notes for this machine (Windows):
- Godot: `C:/Users/Rui/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`.
  Exit codes 5/139 when Godot quits are a known Windows quirk, not a failure.
- Tests: `<godot> --headless --path . --script res://tests/<test>.gd`;
  a test passes when its output has no `TEST FAIL` and no `SCRIPT ERROR`.
- After adding a `class_name`, run `<godot> --headless --path . --import`.
  Only two addon libraries are tracked today; if the import removes them,
  restore them right after:
  `git checkout -- addons/terrain_3d/bin/libterrain.windows.debug.x86_64.dll addons/terrain_3d/bin/libterrain.windows.release.x86_64.dll`
  (The Orchestrator and TerraBrush libraries no longer exist; the old restore
  command in this file referred to them and failed.)
- Never use `git stash`. Never commit `game/world/handmade/world_test_handmade*`
  (the user's own files). Commit the `.uid` files Godot creates.
- Commit and push to `master` only when the user asks; Conventional Commits
  in English; `git pull --rebase origin master` before pushing.

Current task list: `TODO.md`. Handoffs and dated reports live in `docs/history/`
and are records, not lists.
