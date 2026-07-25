---
project: rails-agentic-engineering-team
date: 2026-07-23
time: 11:40
working_directory: /home/rre/Work/mrgrampz-marketplace/rails-agentic-engineering-team
previous_session: null
---

# Session: Agentic Team Refactor

## Summary

This session reviewed the agentic engineering team against an external critique, then implemented the improvements that were agreed upon: extracting lifecycle logging boilerplate into the agent-log skill, removing writer-app residue from the design agent, adding feature-id linkage to discovery, adding a `check` command to the CLI, and producing a feature synthesis artifact from the orchestrator. Two strategic additions were also designed — a standalone QA team and a future design team — and how they fit into a broader "rayspec" architecture where a main agent dispatches parallel specialist teams.

## What We Did

**Reviewed an external critique with four findings:**
1. Logging boilerplate was heavy (~60-80 lines repeated across 9 agents)
2. No install/update story (no version file, no smoke test command)
3. Incomplete generalization (writer-app residue in design.md)
4. Identity-adoption hack in /feature (orchestrator adopted in-session; `$SEQ` arithmetic in prose)

**Agreed scope:** fix findings 1, 2, 4, 5, 6 from the resulting priority list. Explicitly skipped finding 3 (engineer constraints like "never use Devise" — Robert confirmed these are intentional opinions for his stack, not generalization failures).

**Implemented changes:**

- `skills/agent-log/SKILL.md` — added a "Lifecycle Protocol" section at the top that owns: run start/end pattern, gap-query-before-writing, struggle reflection command, skill_gap reflection command, and event logging guidance (drop file_read events; keep test_run, bash, file_write). This is now the single source of truth for the common lifecycle pattern.

- `agents/architect.md`, `agents/engineer.md`, `agents/discovery.md`, `agents/code-review.md`, `agents/security-review.md`, `agents/performance-review.md`, `agents/design.md`, `agents/orchestrator.md`, `agents/skill-builder.md` — each agent's Activity Logging section trimmed to agent-specific content only (start/end flags, decision criteria, decision ID format). The ~40 lines of duplicated boilerplate per agent replaced by one reference line to the skill. Net: ~250 lines removed across the codebase.

- `agents/engineer.md` — also removed the duplicate "Decision Logging Criteria" section (lines that were already merged into Activity Logging). Criteria consolidated into a single clean list.

- `agents/design.md` — removed writer-app residue: "You are designing a focused writing tool" replaced with "Read CLAUDE.md to understand this project's primary user and what they value." Removed `bp-app-layout`, `bp-sidebar`, `bp-main-content` class references from both the codebase scan section and the design spec format template. Replaced with generic "refer to the design-system skill for this project's layout classes."

- `agents/discovery.md` — added `--feature-id {NNN}` to the run start command. The orchestrator assigns the feature number before adopting the discovery identity, so it's available in context. Without this, discovery runs were not linked to feature IDs in the database, meaning the log-analyst's cross-agent correlation queries (which join on feature_id) excluded discovery entirely.

- `skills/writer-design-system/SKILL.md` — deleted. Its own body said "this directory can be safely deleted." Dead weight.

- `bin/agent-log` — added `check` subcommand that verifies ruby and sqlite3 are on PATH and reports the database location. Exits 0 if ready, 1 if missing. Added to help text. Also documented in the install instructions.

- `VERSION` — created at repo root with value `1.0.0`. First versioned release marker.

- `agents/orchestrator.md` — added Stage 7 (Feature Synthesis), sliding Outcome Recording to Stage 8. The synthesis produces `{FEATURE_DIR}/{NNN}-summary.md` after the final verdict is confirmed. The orchestrator reads: Key Scenarios from discovery brief, Acceptance Criteria from architect spec, What Was Built + Deviations + Engineer Uncertainty Flags from the final engineer report, and PASS WITH NOTES findings from review reports. Assembles into a canonical handoff document for downstream teams (QA team, rayspec coordinator, human review). Updated the pipeline complete communication example to surface the summary file path.

**Designed (not built):**

- Standalone QA team architecture: four parallel specialist agents (Functional/playwright-mcp, Copy/file-reader, Design Consistency/file-reader+screenshot, Accessibility/playwright+grep) synthesized by a QA Orchestrator. On-demand via `/qa`, not embedded in the engineering pipeline. Can scope to a feature or run broadly across the app.

- Design team direction: the current design agent would be extracted from the engineering pipeline. A separate design team would produce HTML/CSS mockups using the-point (shared CSS framework), which then feed into the engineering team as the implementation spec instead of the current written design spec. Mockups eliminate the lossy translation from prose description to visual layout that the current design spec format requires.

- Rayspec architecture context: both the QA team and design team fit into a broader pattern where a main coordinating agent (rayspec) dispatches work to parallel specialist teams. Engineering and QA can run in parallel (QA testing feature A while engineering builds feature B). The feature synthesis artifact is the inter-team handoff contract — a single file any team can consume without reading the full pipeline history.

## Why We Did It This Way

**Lifecycle boilerplate into the skill, not kept per-agent.** The skill file is exactly the right place for a shared contract. Agents already load the agent-log skill; making it the single source means a change to the lifecycle pattern (e.g., adding a new reflection type) requires one edit instead of nine. The per-agent sections keep only what differs: start/end flags, decision criteria, decision ID format.

**File_read events dropped, not just moved.** The log-analyst's SQL queries don't touch the events table for pattern detection — only decisions, findings, and reflections drive the learning pipeline. Events are only queryable per-run for debugging. file_read events specifically are one Bash call per file read, generate noise in the context window, and reveal nothing the decisions and reflections don't already capture. test_run and file_write events kept because they have actual debugging value (duration data, artifact confirmation).

**Discovery feature-id added.** The log-analyst's cross-run analysis joins on feature_id. Without it, discovery runs are orphaned — you can see what discovery logged but you can't correlate it to the architect/engineer/review runs for the same feature. This was an identified gap in the original review that the external critique missed.

**Synthesis artifact at Stage 7 (before outcome recording), not after.** Outcome recording is a future-facing step (logging what actually happened vs. expected). The synthesis is a present-tense snapshot. A downstream team (QA) can start working as soon as the synthesis exists, without waiting for outcome recording which can be slow or skipped. Producing synthesis first also means outcome recording findings could in principle be used to update it — though that's not implemented.

**`{NNN}-summary.md` naming (no sequence number).** Every other artifact in the feature directory has a sequence number because it's a pipeline stage document. The summary is a terminal synthesis — it's not part of the sequence, it's the conclusion of it. Omitting the sequence number signals "this is the file to hand off" and makes it trivially findable without knowing the round count.

**QA team as standalone, not embedded in engineering pipeline.** The QA team has an environment dependency (running server, seeded database) that makes it too fragile to require as a default pipeline step. If `bin/rails server` doesn't start cleanly, the engineering pipeline would block. As a standalone on-demand team, it runs when the environment is ready, not when the pipeline says to. It can also run against the full app independently of features.

**Engineer constraints kept in agent file, not moved to CLAUDE.md.** Robert's explicit decision. These constraints (no Devise, no Redis, Minitest only, no service objects) are engineering philosophy for his stack, not project-specific configuration. The agent holds them as values; CLAUDE.md can override via the existing "if CLAUDE.md contradicts, defer to CLAUDE.md" pattern that was already present.

## Roads Not Taken

**Dropping events entirely.** The external review suggested dropping all event logging. Rejected: test_run events (with duration) and file_write events (artifact confirmation) have per-run debugging value even if they don't feed pattern detection. Only file_read events were dropped. **Do not remove test_run or file_write event logging because they are the primary debugging signal for per-run diagnosis.**

**Moving engineer constraints (no Devise, Minitest, Solid Stack) to CLAUDE.md.** Proposed as a generalization fix so the team would work for projects using different stacks. Robert explicitly declined — these are intentional opinions, not generalization failures. The right fix for adoptability is making them overridable via CLAUDE.md, not relocating them. **Do not move these constraints out of engineer.md unless Robert decides to generalize the team for other stacks — which is not a current goal.**

**QA agent embedded in the engineering pipeline as a 4th parallel reviewer.** Simpler integration, but fragile — environment dependency (running server) would occasionally block the pipeline. Also prevents QA from running independently on the full app. **Do not embed QA in the engineering pipeline because environment dependencies make it unreliable as a required step; on-demand standalone is the right shape.**

**Sequential QA placement (after static reviews pass, before pipeline complete).** Would avoid testing broken code. Rejected in favor of standalone — the pipeline is already long enough, and QA provides different value (behavioral, not code-correctness) that shouldn't be gated on code review pass. **Do not add QA as a sequential pipeline stage because it conflates code correctness (what static reviews catch) with behavioral correctness (what QA catches) — these are independent dimensions.**

**Synthesis produced by a separate synthesis agent.** The orchestrator already has the full pipeline context and has been reading these files throughout. A separate agent would need to be spawned, load all the artifacts fresh, and produce the same output. **Do not create a synthesis agent because the orchestrator is the only entity with cross-pipeline visibility by design; adding a specialist for this task would fragment that knowledge.**

## Key Discoveries

**Q: Why are discovery runs invisible to the log-analyst's cross-run queries?**
A: Discovery never passed `--feature-id` to `bin/agent-log run start`. The log-analyst's cross-agent correlation queries join on `feature_id`. Without it, discovery runs are indexed but unlinked — visible in `query runs` but excluded from cross-feature pattern detection. Fixed by adding `--feature-id {NNN}` to the discovery start command. The NNN is available in context because the orchestrator assigns it before adopting the discovery identity in-session.

**Q: Does the agent-log skill's CLI reference carry the lifecycle protocol?**
A: No — it only had the CLI syntax. The lifecycle contract (when to start, when to close, the two reflection patterns, the gap-query pattern) was duplicated across 9 agent files with near-identical prose and identical bash commands. The skill was the right home for it but hadn't been used that way. Fixed.

**Q: What does the `assumptions` reflection type in bin/agent-log do?**
A: Nothing useful currently. The bin/agent-log CLI accepts `--type assumption` as a valid reflection type and `query assumptions` exists as a query. But no agent logs assumption reflections — those are captured as `gap` decisions instead. The query will always return empty. This is a known dead-end in the current schema; not fixed this session.

**Q: Where does the design agent go when a separate design team exists?**
A: The current design agent does feature-level UX specification (stage 3: architect spec → design spec → engineer). A separate design team would work at a different altitude: design system ownership, component library, visual standards, HTML/CSS mockups. The feature-level design step would be replaced by a dispatch to the design team, which returns mockups rather than a written spec. The current design agent would be removed from the engineering pipeline entirely, not repurposed.

## Open Questions & Next Steps

**Build the QA team.** Architecture is fully designed this session (4 specialist agents + orchestrator, on-demand via `/qa`, scoped to feature ID or broad sweep). Not built. The functional and accessibility agents need playwright-mcp tool access specified in their frontmatter — that toolset needs to be confirmed as available in the project environment.

**The-point skill.** When the design team is built, a skill describing how to correctly implement the-point CSS framework classes will be needed. Named as a future requirement this session; not started. Both the design team and the engineering team's engineer agent would load it.

**Design team architecture.** Direction confirmed (HTML/CSS mockups → engineering team), design agent extracted from engineering pipeline. Not built. The engineering team's stage 3 currently reads a written design spec; it would need to be updated to read mockup files instead. The `/feature` command and orchestrator's launch prompts for the engineer would need updating.

**Rayspec integration.** The synthesis artifact (`{NNN}-summary.md`) is designed as the inter-team handoff contract for rayspec. The rayspec main agent doesn't exist in this repo — it lives elsewhere. The contract (brief + summary → QA team dispatch) is clear in principle but the actual rayspec dispatch format is unknown.

**Outcome recording coverage.** The log-analyst's Pattern Type 4 (outcome deltas) is noted as thin because engineers don't consistently log observed outcomes. No fix attempted this session. The synthesis artifact may indirectly improve this because it makes the acceptance criteria and review findings more visible, giving the engineer clearer signal to log against.

**`assumptions` reflection type.** Dead query in the current schema — no agent logs it, `query assumptions` always returns empty. Low priority but worth either removing the type from the CLI or wiring it to an agent. Not addressed this session.

## Files Changed

- `skills/agent-log/SKILL.md` — added "Lifecycle Protocol" section at top (run start/end, gap-query, struggle/skill_gap reflection commands, event logging guidance). This is now the authoritative source for the shared lifecycle contract. [Constraint: all agents reference this section now — changes here affect all 9 agents simultaneously. Do not restructure or remove the Lifecycle Protocol section without updating agent Activity Logging sections.]

- `agents/architect.md` — Activity Logging section trimmed from ~63 lines to ~20 lines. Agent-specific content only; lifecycle delegated to skill.

- `agents/engineer.md` — Activity Logging section trimmed. Duplicate "Decision Logging Criteria" section removed (content merged into Activity Logging). Decision criteria now consolidated in one place.

- `agents/discovery.md` — Activity Logging trimmed. `--feature-id {NNN}` added to run start command. [Constraint: the NNN must be available in context when discovery runs — this is only true because the orchestrator assigns it before adopting the discovery identity. If discovery ever runs as a true subagent (not in-session), feature-id linkage will break.]

- `agents/code-review.md` — Activity Logging trimmed. file_read events dropped.

- `agents/security-review.md` — Activity Logging trimmed. file_read events dropped.

- `agents/performance-review.md` — Activity Logging trimmed. file_read events dropped.

- `agents/design.md` — Writer residue removed from Identity section ("focused writing tool" → "Read CLAUDE.md to understand this project's primary user"). `bp-app-layout`, `bp-sidebar`, `bp-main-content` class references removed from codebase scan and design spec format template. Activity Logging trimmed.

- `agents/orchestrator.md` — Stage 7 (Feature Synthesis) added, Stage 8 (Outcome Recording) renamed from 7. Synthesis produces `{FEATURE_DIR}/{NNN}-summary.md`. Pipeline complete communication example updated to surface summary path. Activity Logging trimmed.

- `agents/skill-builder.md` — Activity Logging trimmed.

- `bin/agent-log` — `check` subcommand added (verifies ruby and sqlite3 on PATH, reports database path). Added to help text.

- `skills/writer-design-system/SKILL.md` — deleted. The skill's own body said "this directory can be safely deleted." No agents were loading it.

- `VERSION` — created at repo root with `1.0.0`. First versioned release marker.

---
*Note: This document was written from conversation context. The session was long; sections marked [uncertain] reflect areas where early-session details may be less precise than later ones. No sections flagged uncertain — the key decisions were made and implemented in the latter half of the session with clear tracking.*
