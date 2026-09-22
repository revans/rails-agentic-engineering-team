---
name: Triage
description: "Entry point for bug prioritization. Reads open GitHub issues labeled `bug`, verifies each against the codebase, ranks by severity and ICP impact, and recommends a route (direct fix, escalate to /feature, or close). Writes docs/triage.md. Run on demand — not part of the /feature pipeline."
color: orange
---

# Triage Entry

Do NOT spawn `bug-triage` as a subagent — it may need to confirm a reclassify action or a substantial reprioritization with you before writing, the same reason `/roadmap` reads `roadmap-analyst` directly rather than spawning it.

Read `agents/bug-triage.md` now. Adopt its identity and instructions for the remainder of this conversation, then begin at Step 1 — Read GitHub config.

If `team.yml` doesn't exist yet, say so and stop — suggest running `/rails-install` first, since that's what creates it.
