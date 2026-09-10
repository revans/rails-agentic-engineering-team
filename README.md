# Rails Agentic Engineering Team

A Claude Code plugin that runs thirteen specialized AI agents to take Rails features from discovery interview to an open pull request, keep the resulting backlog ordered against who the product is actually for, turn a bug report or an idea into a labeled GitHub issue in under a minute of conversation, and verify and rank that bug queue on demand.

## What This Is

Rails Agentic Engineering Team installs a full feature pipeline into any Rails project using Claude Code. You describe a feature, and a team of agents handles the rest: one interviews you to understand the requirement, one reads the codebase and writes a spec, one designs the UI, one builds the feature with test-driven development, and four reviewers check the work in parallel — three for code quality, security issues, and performance problems, and a fourth that checks whether the implementation still matches the plan and the plan still solves the problem the interview captured. The whole pipeline runs isolated in its own git worktree and ends with an open pull request, never a self-merge. Every decision each agent makes is recorded to a SQLite database. After enough runs accumulate, a learning analyst reads those records and proposes improvements to the agents' own rules.

Two things run alongside the pipeline rather than inside it. First, backlog capture: any agent that notices something out of scope names it instead of building it or losing it, and it lands in `TODO.md`; a roadmap analyst can turn that backlog into an actual build order, weighed against one or more `docs/icp/` persona files describing who the product is actually for. Second, GitHub intake: `/bug` and `/request` interview you about a bug or an idea, search the codebase for supporting context, and file a labeled GitHub issue — a separate, lighter front door than starting the full pipeline with `/feature`. A bug triage agent is the harder-verification pass behind that front door: it reproduces or confirms each open bug against the actual code, ranks the queue by severity and whether the broken flow is one your ICP uses, and recommends a fix route for each — never taking that action itself.

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
5. Verify `gh` is installed and authenticated — the orchestrator's pull request step and the `/bug`/`/request` intake commands both depend on it:
   ```bash
   gh auth status
   ```
   Adding an issue to a GitHub Project also needs the `project` scope: `gh auth refresh -s project`.

Run `/init-project` in Claude Code to generate `AGENTS.md` from your existing codebase, with `CLAUDE.md` kept as a symlink to it for compatibility. This is what makes the agents project-aware rather than generic. It will also offer `/define-icp` if `docs/icp/` has no persona file yet.

## How to Use

Start a new feature pipeline with `/feature` in Claude Code:

```
/feature Add a dashboard showing sync status for all customer listings
```

Claude will interview you about the requirement, produce a discovery brief, commit it to `main`/`master`, then run the full pipeline in a dedicated git worktree — architecture, design, implementation, and four parallel reviews. If a reviewer flags a blocking issue, the engineer reruns and all four reviewers check the updated code. Once everything passes, Claude pushes the feature branch and opens a pull request; it never merges one itself, that stays a human call.

Along the way, any agent that notices something out of scope — a real feature idea or a piece of tech debt — logs it to `TODO.md` instead of building it or letting it evaporate. Run `/roadmap` whenever you want that backlog turned into an actual build order, weighed against the persona files in `docs/icp/`:

```
/roadmap
```

Found a bug, or have an idea that isn't ready to build yet? `/bug` and `/request` interview you and search the codebase for supporting context — separate from this repo's local backlog, for anything that belongs in GitHub instead. Where the two land is different on purpose: `/bug` files a plain, labeled GitHub issue and stops there — `/triage` is what ranks it, not a board column. `/request` files a labeled issue and also adds it to the GitHub Project board's `Ready` column, where `/roadmap` and you can weigh it against the rest of the backlog:

```
/bug The export button on the listings page throws a 500 for large accounts
/request A way to bulk-approve pending listings instead of one at a time
```

First run of either asks for your GitHub project's owner and number, then remembers it in `team.yml` at the project root — a small structured config file every GitHub-facing agent reads, alongside `AGENTS.md` and `TODO.md`. See the `github-cli` skill for its full schema.

Once bugs have accumulated on the board, run `/triage` to verify and rank them:

```
/triage
```

For each open bug, this confirms it still reproduces against the current code (or says plainly that it doesn't, or that it's already fixed), weighs severity and blast radius against whether the broken flow is one your `docs/icp/` persona actually uses, and recommends a route — a direct fix, escalation to `/feature` when the fix turns out to need a real decision, or closing the issue. It never fixes anything, closes an issue, or files one itself.

When triage recommends a direct fix, run it:

```
/fix 42
```

This is the orchestrator's Bug Fix Mode — the same engineer and four parallel reviewers the feature pipeline uses, running against the GitHub issue itself as the spec. No discovery interview, no architect stage, no design stage — the issue already says what's wrong; the pipeline just verifies the fix as rigorously as it verifies a feature. It ends the same way `/feature` does: an open pull request, never a self-merge, with `Closes #42` in the body so the issue closes itself when the PR merges.

## Documentation

| Doc | About |
|---|---|
| [Pipeline](docs/pipeline.md) | How a feature moves through all eleven stages, artifact naming, and how to resume a stopped pipeline |
| [Agents](docs/agents.md) | What each agent does, what it reads, and what it produces |
| [Agent Log](docs/agent-log.md) | The logging CLI, database schema, and how to query accumulated run data |
