# Agent Log

A SQLite-backed CLI tool that records what agents do during feature pipeline runs.

## What It Is

The agent log works like a flight recorder for AI agents. Every time an agent makes a decision, logs a struggle, or finds a code review issue, it writes a record to `db/agent_log.sqlite3`. Over time those records accumulate into a dataset the `rails-log-analyst` agent reads to find patterns and propose improvements.

The CLI is a single Ruby script at `bin/agent-log`. It calls the `sqlite3` command-line tool directly. No Ruby gems are required.

## How It Works

Each agent session starts a run, logs events and decisions during the session, then closes the run when done. Here is a typical lifecycle:

Start a run at the beginning of a session:

```bash
RUN_ID=$(bin/agent-log run start \
  --agent-name engineer \
  --feature-id 001 \
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
| `reflections` | End-of-run notes: struggles, skill gaps, assumptions, and input-quality ratings |

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

Find every input-quality rating, chronologically per agent — every agent logs one of these every run, unconditionally, not just when something's wrong (see the `agent-log` skill):

```bash
bin/agent-log query input-quality
```

Each line starts `Rating: N/10 —` and names the upstream artifact rated (the discovery brief, the architect spec, the design spec, the engineer report). Reading the sequence within one `agent_name` shows whether that artifact type is trending better or worse over time, not just whether the last one was good.

The `struggles`, `skill-gaps`, `assumptions`, and `input-quality` queries do not need a run ID. They aggregate across the full database.

## Outcome Recording

After a feature pipeline completes, the engineer and architect each log what actually happened against their earlier expected outcomes:

```bash
bin/agent-log outcome \
  --id "eng-001-003" \
  --observed "Concern extraction worked cleanly; Listing dropped from 210 to 140 lines"
```

This closes the hypothesis/result loop. Without it, the log analyst has no signal for Pattern Type 4 (outcome delta analysis).

## Cost

Each run records what it consumed — `tokens_in`, `tokens_out`, `cache_creation_tokens`,
`cache_read_tokens`, `model` — so "what did this feature cost" is answered from the log rather
than estimated.

Agents do not log these. They are reconciled afterwards from session transcripts:

```bash
bin/agent-log usage sweep --dir ~/.claude/projects
bin/agent-log query cost      # per-feature totals
bin/agent-log query billing   # per-period consumption against the allowance
```

The join from a transcript to a run matches a tool result that is *entirely* a known run id
(optionally `RUN_ID=<uuid>` or `Run ID: <uuid>`). It is deliberately that strict: an earlier
"result contains a known id" rule made 295 transcripts claim runs that weren't theirs, because
the skill tells a resumed agent to run `query runs`, which dumps every recent id into a single
result. A run whose id never reaches its transcript simply cannot be costed, and is counted in
the `NoData` column rather than guessed at.

### Setting it up in a project

Nothing about any plan or price is hardcoded, so a project on a different Claude account records
its own figures and gets correct costs with no change to the script:

```bash
bin/agent-log billing setup   # prompts: seat name, cost/month, included $/month, cycle day
```

Model rates are a separate dated rate card (`billing rate`), so an old run keeps costing what it
cost; a model with no rate row is reported as **NOT PRICED** rather than borrowed from another
model's rate.

### The two dollar columns

`query cost` prints **ListUSD** and **BilledUSD**, and they answer different questions. ListUSD is
the list-rate value of the tokens — an attribution *weight*. BilledUSD is the feature's share of
what was actually paid for the enclosing period, apportioned by that weight. Under a subscription
the marginal cost of a token is zero until the allowance is exhausted, so `tokens × list rate`
answers "how much of the seat did this consume", not "what was I charged". BilledUSD conserves:
across all features it sums to exactly the total paid.

Two things the reports refuse to hide: a period holding runs but no reconciled usage prints
**NO USAGE DATA** rather than `$0.00 — 0% of allowance` (zero spend and no visibility are
different facts), and every period line carries its own coverage ratio, so any figure below 100%
coverage reads as the floor it is.

The arithmetic is covered by `test/agent-log/cost_test.rb` — run it with
`ruby -I test/agent-log test/agent-log/cost_test.rb`. Like `test/rubocop/`, it is not vendored.

## Things to Know

- The database creates itself on first use. No setup command is needed.
- Override the default path: `AGENT_LOG_DB=/path/to/other.sqlite3 bin/agent-log ...`
- **This override is required, not optional, for every agent the orchestrator runs inside a feature's git worktree** (everything from Stage 2 onward — see `docs/pipeline.md`). The database resolves against the current working directory by default, so an agent that `cd`s into a worktree without exporting `AGENT_LOG_DB` back at the main checkout's `db/agent_log.sqlite3` silently starts a second, empty database inside the worktree — one that vanishes, unread, the moment that worktree is removed. The orchestrator's launch prompts always include this export; if you're invoking an agent by hand from inside a worktree, set it yourself.
- Logging failures do not halt agent work. If a call fails, the agent continues and notes the gap in its final report.
- Review agents log each finding with a standard category vocabulary (`N+1`, `AUTH_SCOPE`, `MISSING_TEST`, etc.). Consistent categories are what allow the log analyst to detect recurrence across features.
- You can query the database directly with `sqlite3` for cross-run analysis beyond what the CLI provides. The `rails-log-analyst` agent does this extensively.
- **This database is shared with any other team installed in the same target project.** If `rails-qa-team` is also installed here, its runs and this team's runs live in the same `db/agent_log.sqlite3`, distinguished by `--agent-name` — this is why this team's own meta agents log as `rails-orchestrator`, `rails-log-analyst`, and `rails-skill-builder` rather than the bare names: a cross-team `query runs` needs each row unambiguous about which team's agent produced it.
