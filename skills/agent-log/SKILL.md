---
name: agent-log
description: CLI reference for bin/agent-log — agent activity logging tool. Provides run lifecycle management, decision logging, event logging, and query commands backed by db/agent_log.sqlite3.
---

# agent-log CLI Reference

## Lifecycle Protocol

Every agent run follows this structure. See the CLI sections below for flag details.

### Session start

**First action:** `bin/agent-log run start` with the appropriate agent-specific flags. Capture the returned UUID as `$RUN_ID` — every subsequent command requires it. If this call fails, continue working and surface the logging gap in your final artifact.

**This applies only the first time you're invoked for a given task.** If you're being resumed — a follow-up message on an agent that already ran (mid-session interruption, a coordinator sending you an amendment before you finished, a later "go do X for the same feature") — do not call `run start` again. See "Resuming a run" below.

### Resuming a run

Before logging anything on a resumed or continued invocation, check whether you already have a live `$RUN_ID` from earlier in this same conversation. If you do, reuse it — do not start a second run for work that's a continuation of the first.

If you don't have `$RUN_ID` in hand (a fresh process picked the task back up, or you genuinely can't tell whether you already have a run open), find it before logging anything new:

```bash
bin/agent-log query runs   # look for your own agent-name + feature-id, most recent first
bin/agent-log query decisions --run-id {that-run-id}   # what you already logged
```

Confirmed, real failure mode (feature 119, 2026-09-01): an architect-tauri run was resumed twice for the same feature. The resumed session couldn't tell it already had `$RUN_ID` in hand, so it called `run start` again — a second, mostly-empty run for the same work — and separately re-logged three decisions it had already recorded, under fresh sequential IDs (`-008` relogged as `-017`, `-009` as `-019`, `-010` as `-020`) instead of recognizing the same reasoning was already captured. Both mistakes trace to the same root cause: query before you assume you're starting clean. A decision ID collision is cheap to check for and expensive to leave silent — a duplicated decision inflates whatever count a `log-analyst` later reads off this run without anyone noticing.

### As you work — two separate signals, log both when both apply

An assumption or struggle can matter in two different, independent ways, and each has its own logging channel. They are not alternatives to pick between — the same gap often deserves both:

1. **It traces to a specific input that should have specified this — an upstream artifact OR a human-provided prompt, both count equally.** The input this agent is working from fell short: an upstream artifact was silent (the brief didn't say, the spec had a hole in it, an earlier stage's document didn't name the thing), *or* — just as valid a trigger, not a lesser one — the raw plain-language prompt a human handed this agent directly (a feature description, an idea, a target string) was too thin or ambiguous to work from without guessing. Log it as a `decision --type gap` either way, with the rationale naming the actual source that fell short — the specific artifact, or "the user's initial prompt/description" if there was no artifact at all. This is what each team's `log-analyst` mines directly (by querying `decision_type = 'gap'` against the database) to find "which input keeps failing to give this agent what it needs" — a per-team pattern (`log-analyst.md`'s own "Pattern Type 3" section names the specific input chain for that team), and it's exactly what `handoff-analyst` correlates *across* teams for the artifact case specifically. **Any agent whose first real step reads a human-supplied prompt directly — a discovery/interview agent, an orchestrator resolving initial arguments, any first stage in a pipeline with `consumes: null` — needs this trigger in its own "Log a decision when" list just as much as a downstream agent reading an artifact does.** Don't write the artifact case and silently drop the human-prompt case just because the artifact case is more common.

   ```bash
   bin/agent-log decision --run-id $RUN_ID --id "prefix-001-NNN" \
     --title "short title" --type gap \
     --rationale "what was assumed, and which input's silence forced the assumption — name the specific artifact, or say 'the user's initial prompt' if there was no artifact" \
     --alternatives "what else was considered, if anything"
   ```

2. **It's a standing knowledge gap in *this agent*, independent of which artifact was involved** (a default you'd fill in the same way regardless of what the brief said, a place you personally got stuck). Log it as a `reflection`, the moment it happens — not retroactively at the end, since these are easy to forget once you've moved past them:

   ```bash
   bin/agent-log reflection --run-id $RUN_ID --type assumption \
     --description "what was assumed — the basis for it, and what would need to change if it's wrong"
   ```

   Struggles and skill gaps use the same `reflection` command with a different `--type` — see "Before closing" below.

### Before writing your artifact

Query your run's assumption reflections to populate the artifact's Agent Notes section:

```bash
bin/agent-log query reflections --run-id $RUN_ID
```

Filter for `type: assumption`. Each entry becomes a bullet in Assumptions Made. If the same assumption was also logged as a `decision --type gap` (because it traced to a specific upstream artifact), that's expected — it's doing double duty, feeding two different downstream analyses, not a duplicate to clean up.

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

**Log an `input_quality` reflection every single time — never skip this one.** Every trigger above ("skip if nothing qualifies") is conditional on something having gone wrong; this one isn't, on purpose. If only gap/struggle reflections exist, silence is ambiguous — it could mean the input was excellent, or it could mean nobody checked. Rating every run, good or bad, is what makes the signal usable: `log-analyst` can trend it over time and tell "this artifact type is getting better" from "this artifact type is always this bad," neither of which is visible from complaints alone.

Rate the specific upstream artifact you consumed this run (see your own agent file for which one that is — the discovery brief, the architect spec, the design spec, the engineer report). Use a 1-10 scale, the same range `run end`'s `--quality-score` already uses, so the two are directly comparable:

```bash
bin/agent-log reflection --run-id $RUN_ID --type input_quality \
  --description "Rating: N/10 — {artifact name}: {one or two sentences — what was missing if low, what made it complete if high}"
```

Always name the artifact and lead with `Rating: N/10` in exactly that format — `log-analyst` and `bin/agent-log query input-quality` both parse it back out of the description text, there's no separate numeric column for it.

If you consume more than one upstream artifact (the engineer reads both the architect spec and the design spec), log one `input_quality` reflection per artifact, not one blended rating — a spec that named every field clearly and a design spec that left three components unspecified are two different signals, and averaging them into one number would hide which one actually needs attention.

### Session end

**Last action:** `bin/agent-log run end` with status, quality score, and output summary.

### Event logging

Log events for: test runs (`test_run`), significant bash commands (`bash`), artifacts written (`file_write`). Do not log file reads — they carry no analytical signal and the Bash call adds noise.

---

## Database

Default path: `db/agent_log.sqlite3` (relative to project root)
Override: `AGENT_LOG_DB=/path/to/other.sqlite3 bin/agent-log ...`

The database and schema are created automatically on first use. No setup required.

**If you were launched with the Agent tool's `isolation: "worktree"` parameter** (a separate temporary checkout, not the same thing as a manually-created git worktree an orchestrator `cd`s you into), you have your own physical copy of `db/agent_log.sqlite3` in that checkout. Writes there do not automatically reach the main checkout's copy — whether they survive depends on how that binary file's git merge resolves, which is not guaranteed. If the agent that launched you did not already set `AGENT_LOG_DB` to point at the main checkout's path, set it yourself before your first `bin/agent-log` call.

---

## Run Lifecycle

### Start a Run

```bash
RUN_ID=$(bin/agent-log run start \
  --agent-name NAME \
  --feature-id 001 \
  --input-mode MODE \
  --input-summary "one-line description")
echo "Run ID: $RUN_ID"
```

Returns a UUID. Capture it as `$RUN_ID` — every subsequent command in the session requires it.

| Flag | Required | Notes |
|---|---|---|
| `--agent-name` | yes | `architect`, `engineer`, `discovery`, or other agent identifier |
| `--feature-id` | no | The bare feature number (`001`, `042`) — the same `{NNN}` used in that feature's artifact directory name (`docs/briefs/{NNN}-...`, `docs/go-briefs/{NNN}-...`, etc.), not an `F-`-prefixed form. Use `unknown` if not yet determined. |
| `--input-mode` | no | `structured_feature`, `feature_design`, `feature_discovery`, `ad_hoc` |
| `--input-summary` | no | One-line description of the session's purpose |

### End a Run

```bash
bin/agent-log run end \
  --run-id $RUN_ID \
  --status completed \
  --quality-score 8 \
  --output-summary "brief description of what was produced"
```

| Flag | Required | Notes |
|---|---|---|
| `--run-id` | yes | UUID from `run start` |
| `--status` | no | `completed`, `failed`, or `abandoned` (default: `completed`) |
| `--quality-score` | no | Integer 1–10 |
| `--output-summary` | no | One-line description of what was produced |

---

## Decision Logging

```bash
bin/agent-log decision \
  --run-id $RUN_ID \
  --id "prefix-001-001" \
  --title "short decision title" \
  --rationale "why this choice was made" \
  --alternatives "what else was considered" \
  --type implementation \
  --expected-outcome "what should be true after this"
```

| Flag | Required | Notes |
|---|---|---|
| `--run-id` | yes | UUID from `run start` |
| `--id` | no | Agent-scoped ID (e.g., `eng-001-001`, `arch-001-001`, `disc-001-001` — bare feature number, not `F`-prefixed); auto-generated UUID if omitted |
| `--title` | yes | Short, scannable title |
| `--rationale` | yes | The reasoning — written for future review |
| `--alternatives` | no | What else was considered and why it was rejected |
| `--type` | no | `implementation`, `deviation`, `dependency`, `gap` (default: `implementation`) — **`gap` marks a decision that filled in for a specific upstream artifact's silence** (the brief/spec/prior-stage document didn't specify this). Each team's `log-analyst` mines `decision_type = 'gap'` directly via SQL to find which upstream document template keeps coming up short (see that team's `log-analyst.md`, "Pattern Type 3"). It is a *different* signal from `reflection --type assumption/struggle/skill_gap/input_quality`, which feeds `query assumptions`/`query struggles`/`query skill-gaps`/`query input-quality` instead — log both a `gap` decision and an `input_quality` reflection when the same silence is worth tracking both ways (see Lifecycle Protocol above). |
| `--expected-outcome` | no | The bet — what should be true if this decision was right |

---

## Event Logging

```bash
bin/agent-log event \
  --run-id $RUN_ID \
  --type file_read \
  --description "what happened and what it revealed" \
  --duration-ms 120
```

| Flag | Required | Notes |
|---|---|---|
| `--run-id` | yes | UUID from `run start` |
| `--type` | yes | `tool_call`, `file_read`, `file_write`, `bash`, `test_run` |
| `--description` | no | What happened — include what the event revealed, not just what it was |
| `--duration-ms` | no | Elapsed milliseconds |
| `--started-at` | no | ISO timestamp if tracking precise timing |
| `--completed-at` | no | ISO timestamp if tracking precise timing |

---

## Outcome Recording

Record observed outcomes against earlier decisions — the learning signal that closes the hypothesis/result loop.

```bash
bin/agent-log outcome \
  --id "eng-001-001" \
  --observed "what actually happened vs what was expected"
```

| Flag | Required | Notes |
|---|---|---|
| `--id` | yes | The decision ID to update |
| `--observed` | yes | What actually happened — be specific about divergence from expected |

---

## Finding Logging

Review agents log each issue they find as a finding. This feeds the pattern-detection pipeline — the same category appearing across multiple features is a skill candidate.

```bash
bin/agent-log finding \
  --run-id $RUN_ID \
  --category N+1 \
  --severity NEEDS_WORK \
  --file app/controllers/listings_controller.rb \
  --line 42 \
  --description "listing.account called inside loop without includes(:account)"
```

| Flag | Required | Notes |
|---|---|---|
| `--run-id` | yes | UUID from `run start` |
| `--category` | yes | Standard category tag — see vocabulary below |
| `--severity` | no | `NEEDS_WORK` or `PASS_WITH_NOTES` (default: `NEEDS_WORK`) |
| `--file` | no | File path relative to project root |
| `--line` | no | Line number or range (e.g., `42` or `42-58`) |
| `--description` | no | Specific issue — written clearly enough for the engineer to act on |

### Standard Category Vocabulary

Use these exact strings for `--category`. Consistent vocabulary makes cross-feature pattern detection reliable.

**Code quality (code-review agent):**
| Category | What it flags |
|---|---|
| `MISSING_TEST` | Missing test coverage — happy path, sad path, edge case, or branch |
| `RAILS_CONVENTION` | Rails convention violated (controller actions, callback usage, association options) |
| `NAMING` | Unclear or inconsistent naming on any identifier |
| `PATTERN_CONFLICT` | New code conflicts with an established codebase pattern |
| `DATA_INTEGRITY` | Validation not backed by a database constraint |
| `FAT_CONTROLLER` | Business logic in a controller instead of a model |
| `DEAD_CODE` | Debug artifact, commented-out code, or TODO/FIXME left in |
| `DESIGN_SYSTEM` | Visual grammar violation or AI generation trigger UX contract violation |
| `CONCERN_EXTRACTION` | 3-method rule not applied — feature methods not extracted to a concern |
| `COMMENT_MISSING` | Hard-to-follow code without an explanatory comment |
| `JBUILDER_MISSING` | Controller action has no `.json.jbuilder` template |

**Security (security-review agent):**
| Category | What it flags |
|---|---|
| `AUTH_SCOPE` | Record lookup not scoped through user associations |
| `MASS_ASSIGNMENT` | Strong params missing or too permissive |
| `XSS` | Unescaped user content in output |
| `SQL_INJECTION` | String interpolation inside a SQL fragment |
| `SENSITIVE_DATA` | Credentials, PII, or internal state exposed in logs or responses |
| `CSRF` | CSRF protection bypassed without documented reason |
| `BRAKEMAN` | Brakeman scanner warning (include confidence level in description) |
| `DEPENDENCY_AUDIT` | bundler-audit advisory on a gem dependency (include gem name and advisory ID in description) |

**Performance (performance-review agent):**
| Category | What it flags |
|---|---|
| `N+1` | Association accessed inside a loop without eager loading |
| `MISSING_INDEX` | Foreign key or high-traffic column without a database index |
| `BLOCKING_CALLBACK` | Long-running operation in a model callback (should be a background job) |
| `UNSCOPED_QUERY` | Collection loaded without scope or pagination |
| `MISSING_CONSTRAINT` | Validation not backed by a database constraint (overlaps DATA_INTEGRITY for performance context) |

**QA verification, checked against the running application (rails-qa-team specialists):**
| Category | What it flags | Specialist |
|---|---|---|
| `FUNCTIONAL_BUG` | The feature itself doesn't do what the synthesis artifact says it should | functional-qa |
| `REGRESSION` | The feature broke something that worked before, elsewhere in the app | functional-qa |
| `ACCESSIBILITY` | WCAG violation — keyboard nav, screen-reader, contrast, focus order | accessibility-qa |
| `CROSS_BROWSER` | Behavior or rendering differs across browser engines or viewports | cross-browser-qa |
| `LOAD_PERF` | Degrades or fails under load/stress against the running app (distinct from `N+1`/`MISSING_INDEX`, which are static code-level findings) | load-qa |
| `VISUAL_INCONSISTENCY` | Rendered UI doesn't match the app's own established visual-design conventions | visual-design-qa |
| `COPY_INCONSISTENCY` | UI text doesn't match the app's own established voice, terminology, or punctuation conventions | copywriting-qa |

**Security verification, checked against the running application (rails-security-team specialists):**
| Category | What it flags | Specialist |
|---|---|---|
| `PENTEST_FINDING` | A vulnerability found or demonstrated via real reconnaissance or authorized active testing (Kali-driven tooling) against the live target | pentest-security |
| `MISSING_HEADER` | A security response header or cookie flag absent or misconfigured on the running server | headers-config-security |
| `TLS_CONFIG` | TLS/certificate misconfiguration — expired cert, weak protocol version, weak cipher | headers-config-security |
| `EXPOSED_SURFACE` | An exposed debug/admin surface on the running app (`/rails/info`, `.env`, a debug-mode stack trace, an unauthenticated admin/job dashboard) | headers-config-security |
| `VULNERABLE_DEPENDENCY` | A known CVE/GHSA advisory against a gem in the actual deployed dependency manifest | dependency-security |

---

## Queries

```bash
bin/agent-log query runs                        # Last 20 runs across all agents
bin/agent-log query decisions   --run-id $RUN_ID  # All decisions for a run
bin/agent-log query events      --run-id $RUN_ID  # All events for a run
bin/agent-log query findings    --run-id $RUN_ID  # All findings for a run
bin/agent-log query reflections --run-id $RUN_ID  # All reflections (assumption/struggle/skill_gap/input_quality) for a run
bin/agent-log query summary     --run-id $RUN_ID  # Full summary for a run

bin/agent-log query skill-gaps      # Cross-run aggregate: every skill_gap reflection, across all agents/features
bin/agent-log query struggles       # Cross-run aggregate: every struggle reflection, across all agents/features
bin/agent-log query assumptions     # Cross-run aggregate: every assumption reflection, across all agents/features
bin/agent-log query input-quality   # Cross-run aggregate: every input_quality reflection, chronological per agent
```

The first three are what `log-analyst` reads (via these CLI aggregates) to find recurring per-agent patterns worth turning into a skill — the same struggle or standing assumption showing up across multiple features/agents is the signal these three are watching for. `query input-quality` is a different shape of signal — each entry is a one-off rating, not a recurring phrase, so it's read as a trend line (is this agent's rating of its upstream artifact drifting up or down over time), and cross-referenced against whether the *next* stage's review found problems the earlier agent didn't flag — see that team's own `log-analyst.md` for exactly what pattern that feeds. Only `reflection` entries feed any of these four. `log-analyst` separately mines `decision_type = 'gap'` directly against the database (not through a CLI query command) for a different pattern — see "As you work" above and that team's own `log-analyst.md`.

---

## Failure Handling

Logging failures do not halt work. If a `bin/agent-log` call fails:
- Log the failure to stderr
- Continue the session
- Surface the logging gap in the final report or written artifact

The work is more important than the log.
