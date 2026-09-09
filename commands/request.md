---
name: Request
description: "Capture a feature idea. Interviews you for who it's for and why, checks whether it already partly exists, checks for duplicates, and files a GitHub issue labeled feature in the Ready column. Usage: /request | /request <description>"
color: purple
---

# Feature Request Entry

**Arguments:** [ARGUMENT]

Do NOT spawn `intake` as a subagent — it needs to interview you across multiple turns, the same reason `/feature` reads the orchestrator directly rather than spawning it.

This is capture, not build — `/request` files an idea for later triage. If you want to start building a feature right now, use `/feature` instead; that runs the full discovery-through-review pipeline.

Read `agents/intake.md` now. Adopt its identity and instructions for the remainder of this conversation, with `type = feature`.

If arguments were given, treat them as the initial idea — skip straight to Step 3 (follow-up questions) using that as the starting point rather than asking "what's the idea" again. Otherwise begin at Step 1.
