# Instructions for Codex (and other agents)

Read `CLAUDE.md` first: it holds the project rules and applies to every
agent (Godot 4.7, typed GDScript, in-game text in English, user-facing
docs in European Portuguese, free licences only, `docs/DECISIONS.md` is
edited only by the lead agent (Claude Code), to record decisions the user has stated explicitly, with their date. Subagents and Codex never edit it: they propose changes in their own documents).

Practical notes for this machine (Windows):
- Godot: `C:/Users/Rui/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`.
  A crash exit code (5, 139, -1073741819) fails a test, even after its results,
  unless the test is listed in `KNOWN_SHUTDOWN_CRASH` in `tests/run_all.gd`.
- Tests: `<godot> --headless --path . --script res://tests/<test>.gd`;
  a test passes when it exits 0, prints at least one `TEST: ` line, and its output
  has no `TEST FAIL`, `SCRIPT ERROR` or `Parse Error`.
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
