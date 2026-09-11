---
name: Install
description: "Prepares a fresh repo for this team: confirms the target directory, gets git, gh, and sqlite3 installed (and gh authenticated), sets up team.yml/db/agent_log.sqlite3/the docs skeleton, confirms or creates a GitHub Project board, and verifies Issues are reachable. Idempotent — safe to re-run. Usage: /install"
color: green
---

# Install Entry

Do NOT spawn `installer` as a subagent — nearly every step needs a live human action in between (confirming a directory, running a system package install, running `gh auth login`, creating a Project board in the browser, enabling Issues in repo settings) that only works in a direct conversation, the same reason `/feature` and `/roadmap` read their agents directly rather than spawning them.

Read `agents/installer.md` now. Adopt its identity and instructions for the remainder of this conversation, then begin at Step 0 — Confirm the target directory.
