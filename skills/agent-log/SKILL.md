---
name: agent-log
description: CLI reference for bin/agent-log — agent activity logging tool. Provides run lifecycle management, decision logging, event logging, and query commands backed by db/agent_log.sqlite3.
---

# agent-log CLI Reference

## Database

Default path: `db/agent_log.sqlite3` (relative to project root)
Override: `AGENT_LOG_DB=/path/to/other.sqlite3 bin/agent-log ...`

The database and schema are created automatically on first use. No setup required.

---

## Run Lifecycle

### Start a Run

```bash
RUN_ID=$(bin/agent-log run start \
  --agent-name NAME \
  --feature-id F-001 \
  --input-mode MODE \
  --input-summary "one-line description")
echo "Run ID: $RUN_ID"
```

Returns a UUID. Capture it as `$RUN_ID` — every subsequent command in the session requires it.

| Flag | Required | Notes |
|---|---|---|
| `--agent-name` | yes | `architect`, `engineer`, `discovery`, or other agent identifier |
| `--feature-id` | no | F-00X identifier; use `unknown` if not yet determined |
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
  --id "prefix-F001-001" \
  --title "short decision title" \
  --rationale "why this choice was made" \
  --alternatives "what else was considered" \
  --type implementation \
  --expected-outcome "what should be true after this"
```

| Flag | Required | Notes |
|---|---|---|
| `--run-id` | yes | UUID from `run start` |
| `--id` | no | Agent-scoped ID (e.g., `eng-F001-001`, `arch-F001-001`, `disc-F001-001`); auto-generated UUID if omitted |
| `--title` | yes | Short, scannable title |
| `--rationale` | yes | The reasoning — written for future review |
| `--alternatives` | no | What else was considered and why it was rejected |
| `--type` | no | `implementation`, `deviation`, `dependency`, `gap` (default: `implementation`) |
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
  --id "eng-F001-001" \
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

**Performance (performance-review agent):**
| Category | What it flags |
|---|---|
| `N+1` | Association accessed inside a loop without eager loading |
| `MISSING_INDEX` | Foreign key or high-traffic column without a database index |
| `BLOCKING_CALLBACK` | Long-running operation in a model callback (should be a background job) |
| `UNSCOPED_QUERY` | Collection loaded without scope or pagination |
| `MISSING_CONSTRAINT` | Validation not backed by a database constraint (overlaps DATA_INTEGRITY for performance context) |

---

## Queries

```bash
bin/agent-log query runs                        # Last 20 runs across all agents
bin/agent-log query decisions --run-id $RUN_ID  # All decisions for a run
bin/agent-log query events    --run-id $RUN_ID  # All events for a run
bin/agent-log query findings  --run-id $RUN_ID  # All findings for a run
bin/agent-log query summary   --run-id $RUN_ID  # Full summary for a run
```

---

## Failure Handling

Logging failures do not halt work. If a `bin/agent-log` call fails:
- Log the failure to stderr
- Continue the session
- Surface the logging gap in the final report or written artifact

The work is more important than the log.
