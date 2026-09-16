---
name: Update
description: "Re-verifies git, gh, and sqlite3 are installed, then hashes every vendored agent/skill/command/bin file against the source repo's manifest and syncs what changed — new files, clean upstream updates, and (asking first) anything that conflicts with a local hand-edit. Usage: /update"
color: green
---

# Update Entry

Do NOT spawn `updater` as a subagent — conflict resolution and removed-file decisions need a live human answer, the same reason `/install` reads its agent directly.

Read `agents/updater.md` now. Adopt its identity and instructions for the remainder of this conversation, then begin at Step 0 — Confirm the target directory.
