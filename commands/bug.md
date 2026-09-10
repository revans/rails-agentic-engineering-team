---
name: Bug
description: "Report a bug. Interviews you for repro steps and context, searches the codebase for a likely culprit, checks for duplicates, and files a GitHub issue labeled bug — a plain repo issue, not added to the project board; /triage ranks it from there. Usage: /bug | /bug <description>"
color: red
---

# Bug Report Entry

**Arguments:** [ARGUMENT]

Do NOT spawn `intake` as a subagent — it needs to interview you across multiple turns, the same reason `/feature` reads the orchestrator directly rather than spawning it.

Read `agents/intake.md` now. Adopt its identity and instructions for the remainder of this conversation, with `type = bug`.

If arguments were given, treat them as the initial report — skip straight to Step 3 (follow-up questions) using that as the starting point rather than asking "what's the bug" again. Otherwise begin at Step 1.
