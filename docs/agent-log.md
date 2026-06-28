# Agent Log

A SQLite-backed CLI tool that records what agents do during feature pipeline runs.

## What It Is

The agent log works like a flight recorder for AI agents. Every time an agent makes a decision, logs a struggle, or finds a code review issue, it writes a record to `db/agent_log.sqlite3`. Over time those records accumulate into a dataset the log-analyst agent reads to find patterns and propose improvements.

The CLI is a single Ruby script at `bin/agent-log`. It calls the `sqlite3` command-line tool directly. No Ruby gems are required.

## How It Works

Each agent session starts a run, logs events and decisions during the session, then closes the run when done. Here is a typical lifecycle:

Start a run at the beginning of a session:

```bash
RUN_ID=$(bin/agent-log run start \
  --agent-name engineer \
  --feature-id F-001 \
  --input-summary "Build listing sync status dashboard")
```

Log a decision during the session:

```bash
bin/agent-log decision \
  --run-id $RUN_ID \
  --title "Extract sync methods to Listing::Syncable concern" \
  --rationale "Three sync methods on Listing model triggered the 3-method rule" \
  --alternatives "Leave methods on Listing model" \
  --type implementation \
  --expected-outcome "Listing model stays under 150 lines; concern is reusable"
```

Close the run at the end:

```bash
bin/agent-log run end \
  --run-id $RUN_ID \
  --status completed \
  --quality-score 8 \
  --output-summary "Built sync dashboard, extracted Listing::Syncable concern"
```

The run start command returns a UUID. Every subsequent command for that session requires it.

## The Database

The database has five tables:

| Table | What it stores |
|---|---|
| `runs` | One row per agent session: agent name, feature, status, quality score |
| `decisions` | Choices made during a run: title, rationale, alternatives, expected outcome |
| `events` | Actions taken: file reads, bash commands, test runs |
| `findings` | Review agent findings: category, severity, file path, line number |
| `reflections` | End-of-run notes: struggles, skill gaps, and assumptions |

## Querying

List recent runs across all agents:

```bash
bin/agent-log query runs
```

Expected output: a table showing run ID, agent name, feature, status, quality score, and a summary snippet.

See all decisions for a specific run:

```bash
bin/agent-log query decisions --run-id $RUN_ID
```

Find struggles that appeared across multiple runs:

```bash
bin/agent-log query struggles
```

Find skill gaps across all runs (direct input to the skill builder pipeline):

```bash
bin/agent-log query skill-gaps
```

The `struggles`, `skill-gaps`, and `assumptions` queries do not need a run ID. They aggregate across the full database.

## Outcome Recording

After a feature pipeline completes, the engineer and architect each log what actually happened against their earlier expected outcomes:

```bash
bin/agent-log outcome \
  --id "eng-001-003" \
  --observed "Concern extraction worked cleanly; Listing dropped from 210 to 140 lines"
```

This closes the hypothesis/result loop. Without it, the log analyst has no signal for Pattern Type 4 (outcome delta analysis).

## Things to Know

- The database creates itself on first use. No setup command is needed.
- Override the default path: `AGENT_LOG_DB=/path/to/other.sqlite3 bin/agent-log ...`
- Logging failures do not halt agent work. If a call fails, the agent continues and notes the gap in its final report.
- Review agents log each finding with a standard category vocabulary (`N+1`, `AUTH_SCOPE`, `MISSING_TEST`, etc.). Consistent categories are what allow the log analyst to detect recurrence across features.
- You can query the database directly with `sqlite3` for cross-run analysis beyond what the CLI provides. The log-analyst agent does this extensively.
