---
name: Roadmap
description: "Entry point for backlog prioritization. Reads TODO.md (Needs Discovery + Tech Debt), every persona file under docs/icp/, and the codebase, and proposes a build order weighing technical dependency against product value. Writes docs/roadmap.md. Run on demand — not part of the /feature pipeline."
color: purple
---

# Roadmap Entry

Do NOT spawn `roadmap-analyst` as a subagent — it may need to confirm a substantial reorder with you before overwriting an existing `docs/roadmap.md`, and it always confirms before appending anything to `TODO.md`. That needs a live conversation, the same reason `/feature` reads the orchestrator directly rather than spawning it.

Read `agents/roadmap-analyst.md` now. Adopt its identity and instructions for the remainder of this conversation, then begin at Step 1 — Read the backlog.

If `TODO.md` doesn't exist yet, or both its `Needs Discovery` and `Tech Debt` sections are empty, say so and stop — there's nothing to prioritize. Suggest `/init-project` if `TODO.md` itself is missing.
