# Rails Agentic Engineering Team

A Claude Code plugin that runs twelve specialized AI agents to take Rails features from discovery interview to reviewed implementation, keep the resulting backlog ordered against who the product is actually for, and turn a bug report or an idea into a triaged GitHub issue in under a minute of conversation.

## What This Is

Rails Agentic Engineering Team installs a full feature pipeline into any Rails project using Claude Code. You describe a feature, and a team of agents handles the rest: one interviews you to understand the requirement, one reads the codebase and writes a spec, one designs the UI, one builds the feature with test-driven development, and four reviewers check the work in parallel — three for code quality, security issues, and performance problems, and a fourth that checks whether the implementation still matches the plan and the plan still solves the problem the interview captured. Every decision each agent makes is recorded to a SQLite database. After enough runs accumulate, a learning analyst reads those records and proposes improvements to the agents' own rules.

## Origin

Extracted and generalized from an internal writer application by Robert Evans. The original commit message: "I am alive - this has be abstracted out of my writer-v3 application and been made a bit more generic."

## Installation

This is a Claude Code Team. Install it by copying these agents into your Rails project's Claude directory, then copy the logging script:

1. Copy `bin/agent-log` to your Rails project's `bin/` directory.
2. Make the script executable:
   ```bash
   chmod +x bin/agent-log
   ```
3. Verify that `ruby` and `sqlite3` are on your PATH:
   ```bash
   ruby --version && sqlite3 --version
   ```
4. The database at `db/agent_log.sqlite3` creates itself on first use.

Run `/init-project` in Claude Code to generate `AGENTS.md` from your existing codebase, with `CLAUDE.md` kept as a symlink to it for compatibility. This is what makes the agents project-aware rather than generic. It will also offer `/define-icp` if `docs/icp/` has no persona file yet.

## How to Use

Start a new feature pipeline with `/feature` in Claude Code:

```
/feature Add a dashboard showing sync status for all customer listings
```

Claude will interview you about the requirement, produce a discovery brief, then run the full pipeline automatically through architecture, design, implementation, and four parallel reviews. If a reviewer flags a blocking issue, the engineer reruns and all four reviewers check the updated code.

Along the way, any agent that notices something out of scope — a real feature idea or a piece of tech debt — logs it to `TODO.md` instead of building it or letting it evaporate. Run `/roadmap` whenever you want that backlog turned into an actual build order, weighed against the persona files in `docs/icp/`:

```
/roadmap
```

Found a bug, or have an idea that isn't ready to build yet? `/bug` and `/request` interview you, search the codebase for supporting context, and file the result as a labeled GitHub issue in the `Ready` column — separate from this repo's local backlog, for anything that belongs in GitHub's own triage flow instead:

```
/bug The export button on the listings page throws a 500 for large accounts
/request A way to bulk-approve pending listings instead of one at a time
```

First run of either asks for your GitHub project's owner and number, then remembers it in `AGENTS.md`.

## Documentation

| Doc | About |
|---|---|
| [Pipeline](docs/pipeline.md) | How a feature moves through all ten stages, artifact naming, and how to resume a stopped pipeline |
| [Agents](docs/agents.md) | What each agent does, what it reads, and what it produces |
| [Agent Log](docs/agent-log.md) | The logging CLI, database schema, and how to query accumulated run data |
