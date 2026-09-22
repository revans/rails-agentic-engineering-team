# Agents

Fifteen agents handle specific stages of the feature pipeline, the learning loop, backlog strategy, intake, or first-time setup and updates. Each agent has one job, defined inputs, and defined outputs.

## What They Are

Each agent is a Claude Code subagent definition: a markdown file that specifies an identity, a set of tools, and skill files that give the agent project-specific knowledge. Think of them as specialists on a consulting team. The interviewer, the planner, the architect, the engineer, and the four code inspectors each own their domain and do not cross into each other's territory.

## Pipeline Agents

### Discovery

Interviews you to understand what you want to build.

**Reads:** `AGENTS.md`, `docs/briefs/`, `TODO.md`'s `Deferred` section, open `feature`/`tech-debt`-labeled GitHub issues  
**Writes:** `{NNN}.01-dis-{feature}.md`  
**Cannot:** Read application code, assign feature numbers

The discovery agent asks one or two questions at a time. It explores wide before narrowing. It does not read the codebase. Drawing conclusions from code is the architect's job. When the agent can write every section of the brief without leaving anything blank, it confirms the contents with you before writing.

### Architect

Reads the brief, audits the codebase, writes a feature specification.

**Reads:** Discovery brief, routes, models, controllers, existing specs  
**Writes:** `{NNN}.02-arc-{feature}.md`  
**Cannot:** Modify any application code

The architect checks new URLs against the existing route grammar, checks model names against existing naming conventions, and flags any refactoring that the new feature would make worse if left unaddressed. It presents the full spec scope to you for confirmation before writing the file.

### Design

Expands the spec's behavioral constraints into a full UI/UX design specification.

**Reads:** Feature spec, existing views  
**Writes:** `{NNN}.03-des-{feature}.md`

The design agent covers user flows, screen layouts, component inventory, AI generation surface patterns, and state design for all views. It reads `app/views/` to understand existing layout and component patterns before designing.

### Engineer

Implements the feature using test-driven development.

**Reads:** Feature spec, design spec  
**Writes:** Implementation code + `{NNN}.{SEQ}-eng-{feature}.md`

The engineer writes tests first, runs them red, writes the minimum code to go green, then refactors. Every non-trivial decision is logged to the agent database. At the end, the engineer writes a report that names deliberate tradeoffs, assumptions, and areas of uncertainty for the review agents to examine.

### Code Review

Checks code quality: Rails conventions, test coverage, naming, and design system compliance.

**Reads:** Feature spec, engineer report  
**Writes:** `{NNN}.{SEQ+1}-cr-{feature}.md`  
**Verdict:** PASS, PASS WITH NOTES, or NEEDS WORK

### Security Review

Checks for authorization scope, mass assignment, injection, and sensitive data exposure.

**Reads:** Feature spec, engineer report  
**Writes:** `{NNN}.{SEQ+2}-sec-{feature}.md`  
**Verdict:** PASS, PASS WITH NOTES, or NEEDS WORK

### Performance Review

Checks for N+1 queries, missing indexes, blocking callbacks, and unscoped collections.

**Reads:** Feature spec, engineer report  
**Writes:** `{NNN}.{SEQ+3}-perf-{feature}.md`  
**Verdict:** PASS, PASS WITH NOTES, or NEEDS WORK

### Fidelity Review

Checks whether the implementation still matches the plan's intent, and whether the plan actually addresses the problem the discovery brief described. Does not check code quality, security, or performance — this is the only reviewer that reads backward across the whole chain instead of forward into one artifact.

**Reads:** Discovery brief, feature spec, engineer report  
**Writes:** `{NNN}.{SEQ+4}-fid-{feature}.md`  
**Verdict:** PASS, PASS WITH NOTES, or NEEDS WORK

## Learning Loop Agents

These two agents run outside the feature pipeline. They read accumulated data and improve the other agents over time.

### Log Analyst

Reads the agent database and proposes specific improvements to agent rules.

**Reads:** `db/agent_log.sqlite3`, current agent definitions  
**Writes:** `docs/agent-analysis/YYYY-MM-DD.md`  
**Cannot:** Modify any agent or skill file

Run the log analyst after `cadence.log_analyst_interval` completed cycles (`team.yml`; 15 by default — feature and bug fix cycles both count). It looks for seven pattern types: decisions that should become standing rules, alternatives that should be documented as anti-patterns, engineer decisions that the architect should have made instead, expected vs. observed outcome mismatches, practices that correlate with high-quality runs, finding categories that recur across multiple features, and input-quality trends — including whether an agent's confidence in an upstream artifact (an engineer rating a spec highly) held up once a downstream agent actually tested it (a review round finding a spec-attributable gap anyway).

You don't have to track the cycle count yourself — the orchestrator does, as the last thing it does at the end of every pipeline or bug fix run (Stage 9 / Stage B10 in `docs/pipeline.md`), and mentions it in the final report once the threshold has passed since the last `docs/agent-analysis/` report. It never runs `rails-log-analyst` for you; it only tells you when it's worth doing yourself.

### Skill Builder

Executes confirmed proposals from a log-analyst report.

**Reads:** A log-analyst report, current skill and agent files  
**Writes:** New skill files, updated agent frontmatter

The skill builder does not approve its own proposals. You review each proposal and confirm which to build. Proposals with high confidence (recurring across 5 or more features) are pre-approved by default. Proposals with medium confidence (3 to 4 features) require per-item confirmation.

## How the Learning Loop Works

Here is how the agents improve over time:

```mermaid
flowchart LR
    A[Agents log decisions] --> B[db/agent_log.sqlite3]
    B --> C[Log analyst reads database]
    C --> D[Proposals in docs/agent-analysis/]
    D --> E[Human approves proposals]
    E --> F[Skill builder writes skill files]
    F --> A
```

Every agent logs decisions, events, struggles, and skill gaps to the SQLite database during each session. After enough cycles, the log analyst can find recurring patterns. The approved changes become skill files that every agent loads at the start of the next session.

## Strategy Agents

These two agents run outside the feature pipeline too, but neither is part of the learning loop — they don't read agent behavior, they read the product backlog and the bug queue.

### Roadmap Analyst

Reads open `feature`- and `tech-debt`-labeled GitHub issues, every persona file under `docs/icp/`, and the codebase, and proposes a build order.

**Reads:** `team.yml`, open GitHub issues (labels `feature`, `tech-debt`), `docs/icp/*-icp.md`, `app/models/`, `config/routes.rb`, `db/schema.rb`, `docs/briefs/`  
**Writes:** `docs/roadmap.md`  
**Cannot:** Modify any file under `docs/icp/`, any application code, or any existing GitHub issue — the one exception is filing a single new backlog issue it surfaced itself, and only after the user confirms it live

Run it via `/roadmap`, on demand — not part of `/feature`. It orders the backlog on two independent axes: technical dependency (does this need something that doesn't exist yet) and product value (does this serve a persona `docs/icp/` describes). An item can be clear-to-build and off-ICP, or blocked and on-ICP — those are different findings, not one combined score. `docs/icp/` can hold more than one persona file — a marketplace's buyer and seller, say — and an item is judged against each one, not an averaged composite. If `docs/icp/` is empty or every file in it is stale, roadmap-analyst ranks by dependency only and says so rather than guessing at a customer.

### Bug Triage

Reads open GitHub issues labeled `bug`, verifies each against the codebase, and proposes a fix order.

**Reads:** `team.yml`, GitHub issues (label `bug`), `docs/icp/*-icp.md`, the codebase, `docs/triage.md` (if it exists — a refresh)
**Writes:** `docs/triage.md`
**Cannot:** Modify application code, close or edit any GitHub issue, or write anywhere except `docs/triage.md` — the one exception is filing a reclassified feature request, and only after the user confirms

Run it via `/triage`, on demand. `/bug` files an issue after a first-pass interview; it doesn't verify anything beyond that or compare one bug against another. Bug triage is the harder-verification pass: it reproduces or confirms each bug from the code before trusting it — "cannot reproduce" is a valid, closing verdict, not a failure to find something. It ranks by severity and blast radius, weighted by whether the broken flow is one a persona in `docs/icp/` actually uses, and recommends one of four routes: a direct fix (`engineer` + the four reviewers, with the issue itself standing in for a spec — no discovery, architect, or design stage), escalation to `/feature` when the fix isn't actually bounded, closing as cannot-reproduce or already-fixed, or reclassifying as a feature request when the "bug" turns out to need a new decision rather than a restored one. It is `roadmap-analyst`'s sibling — same reviewer-class shape, same "propose, don't execute" boundary — but reads `bug`-labeled repo issues instead of the `feature`/`tech-debt`-labeled ones on the project board.

## Intake Agent

This is the one agent shared behind two commands. `/feature` starts building something now; this agent captures something for later — a bug report or an idea, filed to GitHub instead of a local artifact.

### Intake

Interviews the reporter, searches the codebase for supporting context, checks for duplicates, and files a labeled GitHub issue. Where it lands depends on type: a `bug` stays a plain repo issue for `bug-triage` to work from; a `feature` also gets added to the GitHub Project board for `roadmap-analyst` and a human to weigh.

**Reads:** `team.yml`, `docs/icp/*-icp.md` (feature mode only), the application codebase, existing GitHub issues  
**Writes:** A GitHub issue via `gh` — nothing local except, on first run, `team.yml` itself. Never writes to `TODO.md`.  
**Cannot:** Modify application code; close, resolve, or edit an existing issue; file before the user confirms

Run via `/bug` (type `bug`) or `/request` (type `feature`) — same identity, same flow, different interview questions, label, and destination: `/request` lands in the project's `Ready` column, `/bug` stays a plain repo issue (see the `github-cli` skill). Neither runs as a subagent — the interview needs to be live, the same reason discovery and the orchestrator run directly in the conversation.

## Setup & Update Agents

These two agents don't run alongside the pipeline or the learning loop. One runs before either one can, on a repo that's never seen this team before; the other keeps an already-set-up repo's vendored files current afterward.

### Installer

Prepares a fresh repo for the team: vendors the `agents`/`commands`/`skills`/`bin` file tree from the source repo (Step 0.5 — see the Updater below and `docs/updates.md`), confirms the target directory, gets `git`, `gh`, and `sqlite3` installed (and `gh` authenticated), detects the repo and sets up `team.yml`/labels/`db/agent_log.sqlite3`/the `docs/` skeleton, confirms or creates a GitHub Project board, and verifies Issues are reachable.

The agent itself mostly narrates and interprets — Step 0.5 follows the `team-sync` skill's plan/apply procedure (the same one the Updater uses), and the rest of the OS-level, filesystem, and GitHub-API work happens in five scripts it runs and reads structured JSON back from:

- **`bin/team-setup-git`** — installs `git` if missing. Unlike `gh`, there's no clean "download a static binary, no sudo" path for git, so this only runs an install directly when it's genuinely safe to (Homebrew on macOS); everywhere else it opens a terminal with the right package-manager command (or triggers macOS's own Xcode Command Line Tools GUI installer) and waits for the user to complete it.
- **`bin/team-setup-gh`** — installs `gh` if missing (package manager or a direct binary download, no sudo required on Linux), then, if not authenticated, opens a terminal window with `gh auth login` typed and submitted so the user can finish the interactive login themselves. Never runs the login itself — that step is unavoidably a human's.
- **`bin/team-setup-sqlite`** — installs `sqlite3` if missing, same no-sudo-path-doesn't-exist reasoning as `team-setup-git`. `bin/agent-log` shells out to this binary directly for every read and write; without it, no agent in this team can log anything.
- **`bin/rails-team-setup-project`** — detects the repo from `git remote`, writes/updates `team.yml` (a targeted edit that preserves comments and every other field, never a full rewrite), creates the `feature`/`bug`/`tech-debt` repo labels if missing, migrates `db/agent_log.sqlite3` by invoking `bin/agent-log` itself (so the schema lives in exactly one place, not duplicated), and creates the `docs/` skeleton (`docs/briefs/`, `docs/icp/`, `docs/agent-analysis/`, `docs/bugfixes/`).
- **`bin/team-setup-project-status`** — adds a missing option (e.g. `Ready`) to the Project board's Status field via the `updateProjectV2Field` GraphQL mutation, since `gh project` has no CLI command for it. Always reads every existing option's id/name/color/description first and resends the full list plus the new one — leaving any existing option out would silently delete it and orphan any card already set to it. See `docs/installer.md`'s "Status Field Options" for the verification this was checked against before being trusted here.

**Reads:** the target directory's `git remote`, `team.yml` (if it exists — to avoid re-asking what's already set, and for an optional `team.source_repo` override), the source repo's `manifest.yml` (via a shallow clone — its own, or a scratch bootstrap clone if `bin/rails-team-update` isn't vendored yet), the Project board's Status field options  
**Writes:** The vendored `agents`/`commands`/`skills`/`bin` tree and `team.lock.yml` (Step 0.5), `team.yml`, the `feature`/`bug`/`tech-debt` labels, `db/agent_log.sqlite3`, the `docs/` skeleton directories, an option on the Project board's Status field  
**Cannot:** Modify application code, run `gh auth login` or a system package install on the user's behalf, create a GitHub Project without asking first, act on a directory the user hasn't confirmed, overwrite an existing `team.yml` wholesale, or overwrite a vendored file that conflicts with a local hand-edit without asking about that specific file first

Run via `/rails-install`, idempotent — a second run against an already-configured repo verifies everything live again (GitHub state can drift even when `team.yml` hasn't) and reports it all as already present rather than asking the same questions twice. The one thing no in-repo mechanism can automate: `commands/rails-install.md` and `agents/rails-installer.md` themselves have to already exist in the target repo before `/rails-install` is even invocable — everything past that point, including the vendoring itself, is now self-contained.

### Updater

Keeps an already-installed repo's vendored `agents/`, `commands/`, `skills/`, and `bin/` files in sync with the source repo.

**Reads:** `team.yml` (to confirm `/rails-install` has already run), `team.lock.yml` (the hash each file had as of the last sync), the source repo's `manifest.yml` (via a shallow clone)  
**Writes:** New or updated files under `agents/`, `commands/`, `skills/`, `bin/`; `team.lock.yml`  
**Cannot:** Modify application code, run without `team.yml` already present, overwrite a file that conflicts with a local hand-edit or delete a file removed upstream without asking about that specific file first

Run via `/rails-update`, on demand — after the source repo publishes changes (`/rails-deploy`), or just periodically. It re-verifies `git`, `gh`, and `sqlite3` the same three scripts `/rails-install` uses, then follows the `team-sync` skill's plan/apply procedure — the same one `/rails-install`'s Step 0.5 uses for a repo's first-ever vendor: files that exist upstream but were never vendored here get added, files upstream changed with no local edits apply automatically, and anything that changed on both sides is a conflict — shown as a diff, resolved per file (take upstream, keep local, or skip), never silently overwritten. See `docs/updates.md` for the manifest/lock format and the full classification logic.

## Skills

Nine skill files give agents project-specific knowledge that training data alone would not provide:

| Skill | What it contains |
|---|---|
| `agent-log` | CLI syntax and flag reference for `bin/agent-log` |
| `rails-principles` | Rails-first design rules, naming conventions, approved dependencies |
| `design-system` | Visual grammar rules, component classes, AI generation trigger UX contract |
| `architect-spec-format` | The specification template and field descriptions |
| `discovery-brief-format` | The brief template and field descriptions |
| `product-brief-format` | Shared with `agentic-ideation-team`; the section list discovery checks before deciding whether an incoming whole-product brief already answers its own interview questions |
| `scope-capture` | When to name something out-of-scope in a report instead of building it or letting it evaporate; feeds the orchestrator's scope-capture filing stage, which files it to GitHub |
| `github-cli` | How `bin/team-create-issue` and `bin/team-find-issues` route issues, plus `gh` recipes for git worktree isolation and PRs that agents still run directly |
| `team-sync` | The shared plan/apply procedure for vendoring or updating the file tree from the source repo's `manifest.yml`, used by both the Installer (Step 0.5) and the Updater |

New skill files are added by the skill builder as the learning loop matures.

## Shared Tools

Beyond `bin/agent-log`, two more `bin/` scripts are shared across agents rather than owned by one:

| Tool | Used by | What it guarantees |
|---|---|---|
| `bin/team-create-issue` | `intake`, the orchestrator's scope-capture filing, `roadmap-analyst`, `bug-triage`'s reclassify case | A `feature`/`tech-debt` issue always reaches the GitHub Project board; a `bug` issue never does — the routing is fixed inside the script from `--type`, not a flag a caller can get wrong |
| `bin/team-find-issues` | Same four | A consistent duplicate-check before any of them files something — returns candidates, never decides whether one's a real match |

Both were built specifically because those four call sites were each independently constructing `gh issue create`/`gh project item-add` sequences before this — the same category of drift risk `bin/rails-team-setup-project` already solved for `team.yml` writes.

## Why `rails-orchestrator`, `rails-log-analyst`, and `rails-skill-builder`, Not the Bare Names

This team was the first one built, so its orchestrator, log analyst, and skill builder originally registered under the bare names `orchestrator`, `log-analyst`, and `skill-builder`. As sibling teams appeared — `tauri-agentic-engineering-team`, `go-agentic-engineering-team`, `rails-security-team`, `tauri-security-team`, `tauri-qa-team` — most disambiguated their own copies of these same three agents (`tauri-orchestrator`, `go-orchestrator`, `security-orchestrator`, and `rails-qa-team`'s `qa-orchestrator`/`qa-log-analyst`/`qa-skill-builder`), while `log-analyst` and `skill-builder` stayed bare and colliding in several of them. This team's own bare names were the one remaining asymmetry: every other team had to name itself relative to this one, instead of every team — including this one — naming itself the same way.

Two identities are affected by a name like this, not just one:

- **Claude Code identity** — the file and its `name:` frontmatter. Two agents from two different teams vendored into the same project's `agents/` directory under the same bare `name:` would collide silently; whichever file the filesystem happens to load last for that name wins, and the other disappears.
- **agent-log database identity** — the `--agent-name` value passed to `bin/agent-log`. Two teams installed against the same target project share one `db/agent_log.sqlite3`; a bare `orchestrator` row from this team would be indistinguishable from `rails-qa-team`'s `qa-orchestrator` rows if both ever logged under the same short name — hence `rails-orchestrator`, `rails-log-analyst`, `rails-skill-builder` here, not the bare forms.

`agents/skill-builder.md` was, until this rename, a symlink to a file shared by roughly a dozen other teams at the `agentic-teams` root — renaming it meant forking it into this team's own independent copy first (`rails-qa-team` had already made the same move for the same reason). This team no longer automatically inherits a future edit to that shared file; any such edit now needs porting in by hand.

`rails-installer` and `rails-updater` were renamed from the bare `installer`/`updater` the same way and for the same reason — see their own sections above. The `/install`, `/update`, and `/deploy` *commands* had the identical collision one level up: `commands/install.md`, `commands/update.md`, and `commands/deploy.md` are vendored to that same bare path in a target project regardless of which team they came from, and the slash command Claude Code offers is resolved from whichever file landed there last. Renamed to `commands/rails-install.md`/`commands/rails-update.md`/`commands/rails-deploy.md`, invoked as `/rails-install`/`/rails-update`/`/rails-deploy` — see `docs/installer.md`'s "Things to Know" for the same note in that doc.
