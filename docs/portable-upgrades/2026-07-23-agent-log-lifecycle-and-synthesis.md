# Upgrade: Lifecycle Logging Consolidation + Feature Synthesis Artifact

**Source:** rails-agentic-engineering-team, session 2026-07-23
**Target:** any other Rails agentic engineering team repo with the same agent/skill structure (agents in `agents/` or `.claude/agents/`, skills in `skills/` or `.claude/skills/`, a `bin/agent-log` CLI, and a `db/agent_log.sqlite3` logging database)

**Explicitly excluded from this upgrade:** any change to the `design` agent. That work was specific to removing writer-app residue from a *different* (already-generalized) copy of this team and does not apply here — leave `design.md` untouched.

---

## Why this upgrade exists

Think of each agent file today like a contractor who carries their own copy of the building code in their toolbox — every contractor's copy is nearly identical, so when the code changes, you have to walk around and update everyone's copy by hand. This upgrade moves the building code into one shared binder (the `agent-log` skill) that every contractor references. Update the binder once, every agent behaves consistently.

Concretely, six independent problems are being fixed:

1. **Boilerplate duplication** — the run-start/run-end/reflection/gap-query lifecycle pattern is copy-pasted near-verbatim across every agent file (~40-60 lines each). A change to that pattern currently requires editing 8-9 files.
2. **Noisy event logging** — agents log a `file_read` event for every file they read. This event type carries no analytical signal (the log-analyst's pattern detection never queries it) and adds Bash-call overhead to every session.
3. **A silent cross-run correlation bug** — the discovery agent's `run start` command is missing `--feature-id`, so discovery runs are invisible to any query that joins on feature ID. Every other agent passes it; discovery doesn't.
4. **Duplicate decision-logging guidance in the engineer agent** — a full "Decision Logging Criteria" section repeats content that's already in the Activity Logging section, just phrased slightly differently.
5. **No environment/version story** — there's no way to check "is this team correctly installed" without manually running commands, and no version marker.
6. **No terminal handoff artifact** — when the pipeline finishes, the only way to know what was built is to read every stage's report file individually. There's no single document a downstream consumer (a QA team, a human reviewer, another coordinating agent) can read to get the full picture.

None of these fixes touch engineering philosophy, review categories, or agent identity. They're structural/operational cleanup only.

---

## Before you start

Read these files in your target repo so you know what you're working with:

```bash
ls agents/ 2>/dev/null || ls .claude/agents/
cat skills/agent-log/SKILL.md 2>/dev/null || cat .claude/skills/agent-log/SKILL.md
cat bin/agent-log
```

Confirm the agent directory contains files equivalent to: `discovery`, `architect`, `engineer`, `code-review`, `security-review`, `performance-review`, `orchestrator`, `skill-builder`. If any are missing or named differently, adapt the file paths below accordingly — the *pattern* of each change matters more than the exact filename.

If any file's current content differs meaningfully from what's shown below (e.g., different section headers, different wording), don't force a literal string match — read the file, find the section that serves the same purpose, and apply the same transformation described in the rationale.

---

## Change 1 — Add the Lifecycle Protocol to the `agent-log` skill

**File:** `skills/agent-log/SKILL.md` (or `.claude/skills/agent-log/SKILL.md`)

This is the foundational change — every other change in this upgrade depends on this section existing, because each agent's Activity Logging section will be trimmed down to reference it instead of repeating it.

Insert this new section immediately after the `# agent-log CLI Reference` title and before the first existing section (likely `## Database` or similar):

```markdown
## Lifecycle Protocol

Every agent run follows this structure. See the CLI sections below for flag details.

### Session start

**First action:** `bin/agent-log run start` with the appropriate agent-specific flags. Capture the returned UUID as `$RUN_ID` — every subsequent command requires it. If this call fails, continue working and surface the logging gap in your final artifact.

### Before writing your artifact

Query your run's gap decisions to populate the artifact's Agent Notes section:

```bash
bin/agent-log query decisions --run-id $RUN_ID
```

Filter for `decision_type: gap`. Each entry becomes a bullet in Assumptions Made or Where I Struggled.

### Before closing

Log a `struggle` reflection for each topic where context was insufficient, a judgment call went beyond your guidelines, or the work took significantly longer than expected. Skip if nothing qualifies.

```bash
bin/agent-log reflection --run-id $RUN_ID --type struggle \
  --description "what was hard and why — what information or skill would have resolved it"
```

Log a `skill_gap` reflection for each specific knowledge absence where a skill file would have told you what to do — not general uncertainty, but a targeted gap. Skip if nothing qualifies.

```bash
bin/agent-log reflection --run-id $RUN_ID --type skill_gap \
  --description "what was missing — what a skill should contain and which agents would benefit"
```

### Session end

**Last action:** `bin/agent-log run end` with status, quality score, and output summary.

### Event logging

Log events for: test runs (`test_run`), significant bash commands (`bash`), artifacts written (`file_write`). Do not log file reads — they carry no analytical signal and the Bash call adds noise.

---
```

Do not remove or restructure anything else in the skill file — this is a pure addition. Everything below the CLI reference sections (Run Lifecycle, Decision Logging, Event Logging, Queries, etc.) stays exactly as it is.

---

## Change 2 — Trim every agent's Activity Logging section

Now that the lifecycle protocol lives in the skill, every agent's own `## Activity Logging` section should shrink to *only* what's specific to that agent: its start/end flags, its decision-logging criteria, and its decision ID format. Everything about the general run-start/run-end/reflection mechanics gets deleted from the agent file and replaced with one reference line.

**The target shape for every agent's Activity Logging section:**

```markdown
## Activity Logging

See the `agent-log` skill for the full lifecycle protocol and CLI reference.

**Start:** `--agent-name {agent-name}`, `--feature-id {however this agent identifies the feature}`, `--input-mode {mode}`, `--input-summary "{one-line description}"`.

**End:** `--status completed`, `--quality-score {1-10}`, `--output-summary "{what this agent produced}"`.

**Log a decision when:**
- {agent-specific criterion 1}
- {agent-specific criterion 2}
- ...
- An assumption traces to a hole in a specific upstream artifact — log as `decision --type gap`, naming which artifact fell short; this feeds `log-analyst`'s Pattern Type 3
- An assumption or struggle is a standing gap in this agent's own judgment, independent of any artifact — log as `reflection --type assumption` / `--type struggle`; the same gap often deserves both, so log both when it does

Decision ID format: `{prefix}-{feature-number}-{NNN}`. [Include rationale/alternatives guidance if the agent had it.]

**Log events for:** {only the specific event types this agent logs — test_run, bash, file_write as applicable}. Do NOT include file_read.
```

**What to delete from each agent file:**
- Any restated "first action / last action" framing of run start/end (now covered by the skill)
- Any bash code block showing the gap-query-before-writing pattern (now covered by the skill)
- Any bash code blocks showing the struggle/skill_gap reflection commands (now covered by the skill)
- `file_read` from every "Log events for:" list
- Any standalone "Failure Handling" subsection whose content is "logging failures don't halt the work" (now covered by the skill's general framing — if your target repo's skill file doesn't already state this, keep the subsection; otherwise remove the duplicate)

**What to keep in each agent file:**
- The exact `--agent-name`, `--input-mode`, `--input-summary` values for that agent's `run start`
- The exact `--output-summary` content for that agent's `run end`
- The full list of agent-specific decision-logging criteria (this is real signal — what counts as "log a decision" differs meaningfully by agent role)
- The decision ID format and prefix for that agent
- Which non-file_read event types that agent actually logs

Apply this to each of: `discovery.md`, `architect.md`, `engineer.md`, `code-review.md`, `security-review.md`, `performance-review.md`, `orchestrator.md`, `skill-builder.md`. (Skip `design.md` per the exclusion at the top of this document.)

For a concrete worked example of the target end-state, here is `engineer.md`'s Activity Logging section after this change (adapt the specifics to your repo, but match this shape and level of detail):

```markdown
## Activity Logging

See the `agent-log` skill for the full lifecycle protocol and CLI reference.

In **structured feature mode**, logging is mandatory. In **ad-hoc mode**, log if `AGENT_LOG_DB` is set; otherwise, surface significant decisions inline in your response.

**Start:** `--agent-name engineer`, `--feature-id {feature-id}`, `--input-mode structured_feature`, `--input-summary "{feature title}"`.

**End:** `--status completed`, `--quality-score {1-10}`, `--output-summary "{brief summary of what was built}"`.

**Log a decision when:**
- You choose between two valid Rails approaches and pick one
- You extract (or don't extract) a concern or PORO
- You deviate from the plan — name what changed and why
- You choose a dependency from the approved list
- You resolve an ambiguity without asking the user
- You make a database schema choice (column type, index strategy, constraint)
- You choose a background job pattern
- An assumption traces to a hole in the spec or design doc — it was silent on this case — log as `decision --type gap`, naming which artifact fell short; this feeds `log-analyst`'s Pattern Type 3
- An assumption or struggle is a standing gap in your own Rails judgment, independent of what the spec said — log as `reflection --type assumption` / `--type struggle`; the same gap often deserves both, so log both when it does

Do NOT log a decision for: reading a file, running tests, following the obvious single implementation path.

Decision ID format: `eng-{feature-number}-{NNN}` where `feature-number` is the bare feature number itself (e.g., `001`). Example: `eng-001-001`. Always include rationale, alternatives considered, and expected outcome.

**Log events for:** test runs (`test_run`), significant bash commands (`bash`), artifacts written (`file_write`).
```

Note the "Do NOT log a decision for: ..." line — if your target repo's `engineer.md` has a separate "Decision Logging Criteria" section duplicating this list under different wording, that's Change 4 below; fold it into this single section rather than keeping two.

---

## Change 3 — Fix the discovery agent's missing `--feature-id`

**File:** `discovery.md`

**The bug:** every other agent's `run start` command in its Activity Logging section passes `--feature-id`. Discovery's does not. This means discovery runs never get linked to a feature in the database — any cross-run query that correlates activity by feature ID (e.g., "show me everything that happened across all agents for feature 001") silently excludes discovery.

**The fix:** in discovery's Activity Logging section (after Change 2 is applied), the `**Start:**` line must include `--feature-id {NNN}`:

```markdown
**Start:** `--agent-name discovery`, `--feature-id {NNN}`, `--input-mode feature_discovery`, `--input-summary "{one-line description of what is being explored}"`. The feature number is assigned by the orchestrator before this session begins and is available in context.
```

The important part is the trailing note: *the feature number is available in context because the orchestrator assigns it before adopting the discovery identity* (discovery typically runs in-session, not as a spawned subagent, precisely because it requires a live user interview). If your target repo's discovery agent runs differently — e.g., it truly is a subagent that never sees the orchestrator's context — this fix doesn't apply cleanly; flag that to the user rather than forcing it.

---

## Change 4 — Remove engineer.md's duplicate decision-logging section

**File:** `engineer.md`

If `engineer.md` has a section titled something like "Decision Logging Criteria" that is separate from "Activity Logging" and repeats substantially the same list of "when to log a decision" bullets — delete that separate section entirely. Merge any bullet from it that isn't already present into the single "Log a decision when:" list inside Activity Logging (see the Change 2 worked example above, which already reflects the merged, de-duplicated list).

The end state should have exactly one place in `engineer.md` that defines decision-logging criteria, not two.

---

## Change 5 — Add a `VERSION` file

**File:** `VERSION` (repo root)

Create it with:

```
1.0.0
```

This is a first release marker — no other file references it yet, but it establishes a place to bump when future structural changes ship.

---

## Change 6 — Add a `check` subcommand to `bin/agent-log`

**File:** `bin/agent-log`

**Why:** there is currently no way to verify the environment is correctly set up (Ruby and sqlite3 on PATH) without manually running each command and inspecting output. This adds a one-command smoke test.

Insert this `when "check"` branch into the main `case subcommand` block, positioned immediately before the `when "help", nil` branch:

```ruby
when "check"
  ok = true
  [["ruby", "ruby --version"], ["sqlite3", "sqlite3 --version"]].each do |name, cmd|
    if system(cmd, out: File::NULL, err: File::NULL)
      puts "#{name}: OK"
    else
      puts "#{name}: NOT FOUND"
      ok = false
    end
  end
  if ok
    puts "Environment ready. Database: #{DB}"
  else
    $stderr.puts "Missing dependencies. Install ruby and sqlite3 before using bin/agent-log."
    exit 1
  end
```

Then add documentation for it inside the `when "help", nil` branch's heredoc, in a new `Environment:` section placed after `Queries:` and before the final `Database:` / `Override:` lines:

```
    Environment:
      check      Verify ruby and sqlite3 are on PATH
```

**Verify:** run `bin/agent-log check` — it should print `ruby: OK`, `sqlite3: OK`, and `Environment ready. Database: <path>`.

---

## Change 7 — Add Stage 7 (Feature Synthesis) to the orchestrator

**File:** `orchestrator.md`

**Why:** the pipeline currently ends with outcome recording — a future-facing step that logs whether earlier decisions held up. Nothing produces a *present-tense* snapshot of what was built. Downstream consumers (a QA team, a human reviewer, a coordinating agent in a multi-team setup) currently have to read every stage's individual report file to reconstruct what happened. This adds one canonical handoff document.

**Step 7a — locate the current final stages.** Find the section(s) in your `orchestrator.md` that handle what happens after the review verdict evaluation (likely titled something like "Stage 6 — Verdict Evaluation" followed by an outcome-recording stage, possibly numbered differently than this repo's).

**Step 7b — insert a new stage** between verdict evaluation and outcome recording. If your repo's outcome-recording stage is numbered "Stage 7," renumber it to "Stage 8" (or whatever comes after your new insertion) and insert the following as the new stage in its place:

```markdown
## Stage 7 — Feature Synthesis

When the pipeline reaches a final verdict, produce a synthesis document before closing. This is the canonical handoff artifact — one file that gives any downstream consumer (QA team, human reviewer, future engineer) the full picture without reading seven separate reports.

**File:** `{FEATURE_DIR}/{NNN}-summary.md`

To produce it, read the following sections from the pipeline artifacts:

```bash
# Discovery brief — Key Scenarios
grep -A 30 "## Key Scenarios" ${FEATURE_DIR}/${NNN}.01-dis-*.md

# Architect spec — Acceptance Criteria
grep -A 40 "## Acceptance Criteria" ${FEATURE_DIR}/${NNN}.02-arc-*.md

# Final engineer report — What Was Built, Deviations from Spec, For the Review Agents
# (use the highest-sequence eng file)
ls ${FEATURE_DIR}/${NNN}.*-eng-*.md | sort | tail -1

# Final review reports — PASS WITH NOTES items only
grep -A 5 "PASS WITH NOTES" \
  ${FEATURE_DIR}/${NNN}.$(($SEQ+1))-cr-*.md \
  ${FEATURE_DIR}/${NNN}.$(($SEQ+2))-sec-*.md \
  ${FEATURE_DIR}/${NNN}.$(($SEQ+3))-perf-*.md
```

**Synthesis format:**

```markdown
# Feature Summary — {NNN} Feature Name

**Completed:** YYYY-MM-DD
**Feature directory:** {FEATURE_DIR}
**Review rounds:** {N} — final verdict: [PASS | PASS WITH NOTES]

---

## What Was Built

[From the final engineer report's "What Was Built" section — factual, one short paragraph.
Models, controllers, views, jobs. What exists now that didn't before.]

## User Flows

[From the discovery brief's "Key Scenarios" section — what the user can do.
Written as concrete before/after capabilities, not technical descriptions.
This is what the QA team walks.]

## Acceptance Criteria

[The checklist from the architect spec, verbatim. These are the testable behaviors.
QA maps its test cases to these.]

- [ ] ...
- [ ] ...

## Known Rough Edges

[PASS WITH NOTES findings from all review reports — the things that passed but
were flagged. These are QA's first targets because they're the areas reviewers
had reservations about but didn't block.]

- [source agent] — [finding summary]

## Engineer's Uncertainty Flags

[From the "Assessment" and "Recommendation" subsections of the final engineer
report's "For the Review Agents" section. These are places where the engineer
implemented under uncertainty. QA should pay particular attention here.]

## Deviations from Spec

[From the final engineer report's "Deviations from Spec" section. Where
implementation diverged from what was designed and why. Helps QA know which
parts of the design spec to treat as authoritative vs. superseded.]

## Artifacts

| Stage | File |
|---|---|
| Discovery brief | {FEATURE_DIR}/{NNN}.01-dis-{feature-name}.md |
| Architect spec | {FEATURE_DIR}/{NNN}.02-arc-{feature-name}.md |
| Design spec | {FEATURE_DIR}/{NNN}.03-des-{feature-name}.md |
| Engineer report (final) | {FEATURE_DIR}/{NNN}.{SEQ}-eng-{feature-name}.md |
| Code review (final) | {FEATURE_DIR}/{NNN}.{SEQ+1}-cr-{feature-name}.md |
| Security review (final) | {FEATURE_DIR}/{NNN}.{SEQ+2}-sec-{feature-name}.md |
| Performance review (final) | {FEATURE_DIR}/{NNN}.{SEQ+3}-perf-{feature-name}.md |
```

After writing the summary, confirm it exists:

```bash
ls ${FEATURE_DIR}/${NNN}-summary.md
```
```

**Step 7c — adapt the artifact table** in the synthesis format to match your target repo's actual pipeline stages. If your team doesn't have a separate design-spec stage between architect and engineer, drop that row. If your team has different or additional review agents, adjust the table accordingly — the goal is a complete artifact index, not a literal copy of this repo's exact file naming.

**Step 7d — update the "Pipeline complete" communication example** (near the end of the orchestrator file, in whatever section shows example output messages) to include the summary file path, e.g.:

```
001 complete. 2 review rounds. Final verdict: PASS WITH NOTES (cr, sec), PASS (perf).
Summary: docs/briefs/001-accounts/001-summary.md
Full artifacts: docs/briefs/001-accounts/001.01-dis through 001.11-perf-accounts.md
```

---

## Verification checklist

After applying all changes, confirm:

- [ ] `skills/agent-log/SKILL.md` has a `## Lifecycle Protocol` section near the top, before the CLI reference sections
- [ ] Every agent file except `design.md` has a short Activity Logging section that says "See the `agent-log` skill for the full lifecycle protocol and CLI reference" as its first line
- [ ] No agent file's "Log events for:" list mentions `file_read`
- [ ] `discovery.md`'s Activity Logging `**Start:**` line includes `--feature-id {NNN}`
- [ ] `engineer.md` has exactly one section defining decision-logging criteria, not two
- [ ] `VERSION` exists at repo root with content `1.0.0`
- [ ] `bin/agent-log check` runs successfully and reports `ruby: OK`, `sqlite3: OK`
- [ ] `orchestrator.md` has a "Feature Synthesis" stage between verdict evaluation and outcome recording, and the outcome-recording stage is renumbered after it
- [ ] `orchestrator.md`'s pipeline-complete example output includes the summary file path
- [ ] `design.md` was not touched

If any check fails or a step didn't apply cleanly to your repo's structure, stop and report which one — don't force a fit that breaks the file.
