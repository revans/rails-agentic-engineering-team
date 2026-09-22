---
name: Rails Update
description: "Re-verifies git, gh, and sqlite3 are installed, then hashes every vendored agent/skill/command/bin file against the source repo's manifest and syncs what changed — new files, clean upstream updates, and (asking first) anything that conflicts with a local hand-edit. Named rails-update, not update — rails-qa-team has its own update command, and vendoring both into the same project would otherwise overwrite one with the other. Usage: /rails-update"
color: green
---

# Rails Update Entry

Do NOT spawn `rails-updater` as a subagent — conflict resolution and removed-file decisions need a live human answer, the same reason `/rails-install` reads its agent directly.

Read `agents/rails-updater.md` now. Adopt its identity and instructions for the remainder of this conversation, then begin at Step 0 — Confirm the target directory.
