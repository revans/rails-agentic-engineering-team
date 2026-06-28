# Rails Agentic Engineering Team

A Claude Code plugin that runs nine specialized AI agents to take Rails features from discovery interview to reviewed implementation.

## What This Is

Rails Agentic Engineering Team installs a full feature pipeline into any Rails project using Claude Code. You describe a feature, and a team of agents handles the rest: one interviews you to understand the requirement, one reads the codebase and writes a spec, one designs the UI, one builds the feature with test-driven development, and three reviewers check the work in parallel for code quality, security issues, and performance problems. Every decision each agent makes is recorded to a SQLite database. After enough runs accumulate, a learning analyst reads those records and proposes improvements to the agents' own rules.

## Origin

Extracted and generalized from an internal writer application by Robert Evans. The original commit message: "I am alive - this has be abstracted out of my writer-v3 application and been made a bit more generic."

## Installation

This is a Claude Code plugin. Install it through the mrgrampz marketplace in Claude Code, then copy the logging script to your Rails project:

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

Run `/init-project` in Claude Code to generate `CLAUDE.md` from your existing codebase. This is what makes the agents project-aware rather than generic.

## How to Use

Start a new feature pipeline with `/feature` in Claude Code:

```
/feature Add a dashboard showing sync status for all customer listings
```

Claude will interview you about the requirement, produce a discovery brief, then run the full pipeline automatically through architecture, design, implementation, and three parallel reviews. If a reviewer flags a blocking issue, the engineer reruns and all three reviewers check the updated code.

## Documentation

| Doc | About |
|---|---|
| [Pipeline](docs/pipeline.md) | How a feature moves through all nine stages, artifact naming, and how to resume a stopped pipeline |
| [Agents](docs/agents.md) | What each agent does, what it reads, and what it produces |
| [Agent Log](docs/agent-log.md) | The logging CLI, database schema, and how to query accumulated run data |
