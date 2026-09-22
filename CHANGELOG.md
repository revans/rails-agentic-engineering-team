# Changelog

Notable changes to this project, newest first. Each entry corresponds to a bump in `VERSION`. Version bumps ride along with the commit that makes the structural change rather than a fixed release cadence, so numbering isn't strictly sequential (there is no 1.2.0 or 1.4.0) — see `git log -p -- VERSION` for the exact commit behind any entry below.

Maintained by `/rails-deploy` — see [Updates](docs/updates.md).

## [1.18.0] - 2026-09-21

### Changed

- Renamed this team's `/install`, `/update`, and `/deploy` commands to `/rails-install`, `/rails-update`, and `/rails-deploy`, and their agents (`installer.md`, `updater.md`) to `rails-installer`/`rails-updater` — same collision-avoidance reason as [1.17.0]'s agent rename, one layer up: `commands/install.md`/`update.md`/`deploy.md` vendor to the same bare path in a target project regardless of which team they came from, and the slash command Claude Code offers resolves from whichever file landed there last. `rails-qa-team` already made the identical move (`/qa-install`/`/qa-update`/`/qa-deploy`, VERSION 0.8.0).
- Fixed `bin/team-manifest`'s hardcoded `commands/deploy.md` exclusion — it would otherwise have started vendoring `commands/rails-deploy.md` into every installed target repo, a source-repo-only maintainer tool that has no reason to exist there.
- Fixed two H1 headings in `agents/rails-orchestrator.md` and `agents/rails-log-analyst.md`/`agents/rails-skill-builder.md` (`# Orchestrator` → `# Rails Orchestrator`, etc.) missed in [1.17.0] — `rails-qa-team`'s own agent files prefix this heading too, only `docs/agents.md`'s per-team-agnostic section headings stay bare.
- Updated every in-repo reference to the renamed identities: `agents/bug-triage.md`, `agents/intake.md`, `bin/team-create-issue`, `bin/team-update`, `commands/roadmap.md`, `commands/triage.md`, `docs/agents.md`, `docs/backlog.md`, `docs/installer.md`, `docs/updates.md`, `README.md`, and `skills/github-cli/SKILL.md`, `skills/team-sync/SKILL.md`.

## [1.17.0] - 2026-09-21

### Changed

- Renamed this team's three cross-team-collidable agents to carry an explicit `rails-` prefix: `orchestrator` → `rails-orchestrator`, `log-analyst` → `rails-log-analyst`, `skill-builder` → `rails-skill-builder` — both the file (`agents/orchestrator.md` → `agents/rails-orchestrator.md`, etc.) and the `name:` frontmatter, so both the Claude Code identity and the `--agent-name` value logged to `db/agent_log.sqlite3` carry the prefix. This team was the first built, so it kept the bare names while sibling teams (`tauri-agentic-engineering-team`, `go-agentic-engineering-team`, `rails-security-team`, `tauri-security-team`, `tauri-qa-team`, `rails-qa-team`) disambiguated themselves against it — several still collide on bare `log-analyst`/`skill-builder`. This closes the asymmetry from this team's side; see `docs/agents.md`'s "Why `rails-orchestrator`, `rails-log-analyst`, and `rails-skill-builder`, Not the Bare Names" for the full reasoning.
- `agents/skill-builder.md` was a symlink to a file shared by roughly a dozen other teams at the `agentic-teams` root. Forked it into this team's own independent `agents/rails-skill-builder.md` (same move `rails-qa-team` already made) — required to rename it safely, since a shared symlink can't be given a team-specific identity without breaking it for every other team still using it. This team no longer auto-inherits future edits to that shared file.
- Updated every in-repo reference to the renamed identities: cross-agent pointers in `architect.md`, `code-review.md`, `design.md`, `discovery.md`, `engineer.md`, `fidelity-review.md`, `performance-review.md`, `security-review.md`; the `agents/rails-orchestrator.md` file path in `commands/feature.md` and `commands/fix.md`; the `team.yml` template comments in `bin/team-setup-project` and `skills/github-cli/SKILL.md`; and `docs/agent-log.md`/`docs/agents.md`/`docs/pipeline.md`. Left untouched, deliberately: bare `orchestrator`/`log-analyst` used as casual prose (e.g. "the orchestrator passes…") rather than as an identifier, `skills/agent-log/SKILL.md`'s generic "each team's `log-analyst`" phrasing (shared boilerplate describing the fleet-wide pattern, not this team specifically), and every historical `CHANGELOG.md` entry and `docs/sessions/`/`docs/portable-upgrades/` file, which describe what was true at the time and stay as written.

## [1.16.4] - 2026-09-21

### Fixed

- `bin/team-update`'s `git clone` call passed `source_repo` (from `--source-repo`, or from `team.yml`'s `team.source_repo` — hand-editable by anyone with write access to the target repo) as a bare positional argument. A value starting with `-` gets parsed as a git flag instead of a repository — flagged by automated security review, on `rails-qa-team`'s ported copy of this same file, as argument injection (`--upload-pack=<cmd>` runs `<cmd>` as the clone's pack generator). Fixed with a `--` separator before the value. Also found, while fixing it, a second gap the `--` fix doesn't touch: `ext::<cmd>` is a git transport scheme that runs a command directly, no flag parsing needed, currently blocked only by this git version's default protocol allowlist rather than by anything in this script. Added a `validate_source_repo!` allowlist (plain `https://` or `git@`-style URLs only) so the fix doesn't depend on git's own defaults staying as they are.

## [1.16.3] - 2026-09-21

### Fixed

- `orchestrator.md`'s log-analyst cadence check (Stage 9/B10) sorted `docs/agent-analysis/*.md` filenames assuming every one is a bare `YYYY-MM-DD.md`. A non-date filename in that directory sorts after any real date in ASCII, permanently masking the true last-analysis date. Now filters to the strict date pattern before sorting.
- Runs left in `status='running'` were never reconciled — nothing closed a run on an agent's behalf when its work was superseded by a fresh agent spawn, or lost track of it via `isolation: "worktree"`'s separate physical database copy. `bin/agent-log` gains `run update` (backfill feature-id/status without a full `run end`) and `query stale` (surface running rows past a plausible session length). `orchestrator.md` now checks for and closes a stale run before spawning a replacement agent for the same work, and both `orchestrator.md`'s Worktree Model and the `agent-log` skill's Database section now warn that `isolation: "worktree"` launches must still point `AGENT_LOG_DB` at the main checkout.

## [1.16.2] - 2026-09-21

### Added

- **CI Gate** (`orchestrator.md` Stage 4b / Bug Fix Mode Stage B3b): after the engineer completes and before the four parallel reviewers launch, the orchestrator independently re-runs `bin/ci` (or `bin/rubocop` + `bin/rails test` if the project has no `bin/ci`) rather than trusting the engineer's own self-reported Validate step. Not clean → routes back to the engineer exactly like a Stage 6 NEEDS WORK verdict, incrementing `$SEQ` by 5. Nothing reaches Stage 7c without passing this gate.
- `engineer.md`'s TDD Workflow now requires running the **entire** test suite before starting a task (not just files expected to be touched) and fixing anything already red before proceeding — a red baseline makes it impossible to tell, once done, which failures are the engineer's own. Its Validate/End-of-Work steps now also run `bin/rubocop` (or `bin/ci`'s style step) and treat any offense, any pre-existing red test surfaced by the change, and any dependency-audit finding as the engineer's own to fix, not to note and defer.
- `security-review.md` now runs `bin/bundler-audit` (or `bundle exec bundler-audit check --update`) alongside Brakeman at the start of every run, as its own "Dependency Audit" review category — any advisory is NEEDS WORK unless demonstrated inapplicable. New `DEPENDENCY_AUDIT` category added to the `agent-log` skill's finding vocabulary.
- `/install` (`installer.md` Step 9) now offers to run `/init-project` once its checklist finishes clean — waits for an explicit yes, never chains automatically, same rule every other handoff in the installer follows.

### Fixed

- 1.16.1's fix for `bin/team-create-issue`'s project-board step was itself broken: it swapped `gh project item-edit`'s `--url` for `--id` while keeping the `--field`/`--value` friendly-name flags, but `gh` rejects that combination — `--field`/`--value` only work with `--url`. Corrected to resolve the project's node id and the Status field's real field-id/option-id once (via `gh project view`/`field-list`, a schema read whose cost doesn't grow with board size), then call `item-edit` with the fully-typed `--id`/`--project-id`/`--field-id`/`--single-select-option-id` form. Falls back to the old `--url`/friendly-name path only if that resolution fails. Verified end-to-end against a real board.

## [1.16.1] - 2026-09-21

### Fixed

- `bin/team-create-issue`'s project-board step resolved the project item to update via `gh project item-edit --url`, which makes `gh` search/paginate the project's existing items to find a match — cost that grows with board size. A burst of ~90 issues filed in one run against a growing board exhausted the account's hourly GraphQL quota partway through. `item-add --format json` now captures the created item's own id, and `item-edit` uses `--id` (a direct lookup, flat cost) instead, falling back to the old `--url` resolution only if `item-add` didn't hand back a usable id.

## [1.16.0] - 2026-09-16

### Fixed

- `commands/deploy.md` was a tracked file, so it vendored into every target repo even though `/deploy` only works in this source repo (it depends on `bin/team-manifest`, which never vendors anywhere else). It's now excluded from `manifest.yml` the same way `bin/team-manifest` already was; a repo that vendored it before this fix sees it under `removed_upstream` on its next `/update` and can clean it up.
- `bin/team-update`'s `load_lock` silently treated a `team.lock.yml` that exists but fails to parse the same as "never synced," discarding every file's sync history without telling anyone. It now fails the sync cleanly with `{"status":"failed"}` instead.

## [1.15.0] - 2026-09-16

### Added

- `CHANGELOG.md` (this file) — human-readable release notes for this project itself, backfilled from `VERSION`'s full history. `/deploy` now drafts and asks about a new entry whenever `VERSION` changes, distinct from `docs/updates-log.md` (a mechanical per-file record generated in each *target* repo, not this one).

## [1.14.0] - 2026-09-16

### Added

- `/update` and `/install`'s first vendor now write `docs/updates-log.md` in the target repo: a dated, newest-first record of exactly what each sync did (vendored / updated from upstream / conflicts resolved each way / removed), skipped entirely when a sync changes nothing.

### Fixed

- README's doc table said `/install` runs "four bootstrap scripts" — there have been five since 1.9.0. `docs/installer.md` already said five; the README was just stale.

## [1.13.0] - 2026-09-16

### Added

- `/install` now vendors this team's whole file tree itself (Step 0.5), instead of assuming it was already manually copied in. It bootstraps a temporary `bin/team-update` via a shallow clone when the target repo has no vendored copy yet — true on every first install — then runs the same sync procedure `/update` uses. Closes the long-standing "install `bin/agent-log` into a repo that doesn't have it" gap for real, not just for that one file.
- New `team-sync` skill: the shared plan/apply procedure, referenced by both `agents/installer.md` and `agents/updater.md` instead of being duplicated across both.

### Fixed

- `bin/team-update` crashed with a raw Ruby backtrace instead of the promised `{"status":"failed"}` JSON line when `manifest.yml` was malformed or missing its `files` key — every caller reads only the last stdout line as JSON, so the crash silently broke that contract.

## [1.12.0] - 2026-09-16

### Added

- `/deploy` and `/update`: `bin/team-manifest` hashes every vendored `agents`/`commands`/`skills`/`bin` file into `manifest.yml`; `bin/team-update` 3-way-compares it against a target repo's `team.lock.yml` to classify each file as new, a clean upstream update, a conflict, a local-only edit, or removed upstream — applying what's safe automatically and asking before touching anything that conflicts with a hand-edit. Replaces the manual, per-change `docs/portable-upgrades/*.md` instruction-writing process.

## [1.11.0] - 2026-09-11

### Added

- `docs/installer.md` and `docs/backlog.md` — dedicated doc pages for `/install` and the scope-capture/roadmap/triage backlog system, following `docs/pipeline.md`'s shape.

### Fixed

- A stale README line claiming bugs accumulate on the project board — they never do, `bug`-labeled issues stay plain repo issues.

## [1.10.0] - 2026-09-10

### Added

- Every pipeline agent now logs an unconditional `input_quality` reflection each run, rating the specific upstream artifact it consumed 1–10 — silence used to be ambiguous between "the input was great" and "nobody checked." `log-analyst` gains Pattern Type 7: rating trends over time per artifact type, and cross-agent outcome mismatches (an engineer rating a spec highly when a later review round still finds a spec-attributable gap).

## [1.9.0] - 2026-09-10

### Added

- `bin/team-setup-git` and `bin/team-setup-sqlite` — `/install` now checks for `git` and `sqlite3`, not just `gh`, before proceeding. Both are hard dependencies every stage or `bin/agent-log` needed all along but never verified.

### Fixed

- Stale "not yet built" claims in `docs/agents.md`/README about GitHub labels (shipped two commits earlier) and project board columns (a permanent `gh` limitation, not a pending gap).

## [1.8.0] - 2026-09-10

### Fixed

- The orchestrator now commits each pipeline artifact (architect spec, design spec, engineer report, review reports, summary) right after the stage that produces it confirms the file exists, instead of batching everything into one commit at the very end — a stopped or crashed mid-pipeline run no longer leaves real work sitting uncommitted with no git history.

## [1.7.0] - 2026-09-10

### Added

- `bin/team-create-issue` and `bin/team-find-issues` — the routing rule (a `bug` stays a plain repo issue; a `feature`/`tech-debt` also reaches the GitHub Project board) now lives in one script instead of four independently-duplicated call sites (`intake`, scope-capture filing, `roadmap-analyst`, `bug-triage`'s reclassify case).

## [1.6.0] - 2026-09-10

### Changed

- Scope-capture findings (a missing feature, tech debt, or an unrelated bug noticed mid-pipeline) now file as labeled GitHub issues instead of appending to `TODO.md`, which keeps only its `Deferred` section from here on. `roadmap-analyst` and `discovery` read open GitHub issues instead of `TODO.md` accordingly. Added the `tech-debt` label alongside `feature`/`bug`.

## [1.5.0] - 2026-09-10

### Added

- `/install` — `bin/team-setup-gh` installs and authenticates `gh`; `bin/team-setup-project` detects the repo from `git remote`, writes `team.yml` with a comment-preserving targeted edit, migrates `db/agent_log.sqlite3`, and builds the `docs/` skeleton.

## [1.3.0] - 2026-09-10

### Added

- `bug-triage` and Bug Fix Mode (`/fix`) — verifies open `bug`-labeled issues against the actual codebase, ranks the queue by severity and ICP fit, and routes a direct fix through the same engineer and four parallel reviewers the feature pipeline uses, with the issue itself standing in for a spec.
- `team.yml` — cross-agent settings (GitHub repo/board/labels, review escalation threshold, log-analyst cadence) move out of prose in `AGENTS.md` and hardcoded numbers into one structured, script-readable config file.

## [1.1.0] - 2026-08-13

### Added

- `fidelity-review` — a fourth parallel reviewer checking whether the implementation still matches the architect's plan, and whether the plan itself still solves the problem the discovery brief described. Previously the only check for either question was retrospective, after the feature had already shipped.

## [1.0.0] - 2026-07-24

### Added

- First versioned release. Agent activity logging refactored and extended.
