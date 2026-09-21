---
description: gh CLI reference for this team — how bin/team-create-issue and bin/team-find-issues route a feature request to the GitHub Projects (v2) board while a bug stays a plain labeled repo issue, isolating pipeline work in a git worktree, and opening pull requests. Every command here was verified against a real `gh --help`/`git worktree --help` output, not written from memory.
---

# GitHub CLI Reference

## Prerequisites

- `gh` installed and authenticated: `gh auth status`. If not authenticated, stop and tell the user — don't attempt `gh auth login` yourself, it's interactive.
- Adding an issue to a project requires the `project` OAuth scope. If a project command fails with an authorization error, tell the user to run `gh auth refresh -s project` themselves rather than guessing at a workaround.
- All commands below assume you already know which repo you're working in. `gh` infers it from the current directory's git remote; pass `--repo OWNER/REPO` explicitly if that's ever ambiguous (e.g. this team's own meta-repo vs. the Rails project it's installed into).

## Where Project Config Lives

`gh project` commands need an **owner** (the org or user that owns the board) and a **project number** — neither is inferable from a git remote the way the repo is. This team stores that, and a handful of other cross-agent settings, in `team.yml` at the project root — a plain root-level file, alongside `AGENTS.md` and `TODO.md`, not under `.claude/` (which holds the agent/skill/command *definitions*, not this team's runtime state — same reason `TODO.md`, `docs/roadmap.md`, and `docs/triage.md` all live at the root too).

Structured YAML instead of a markdown section in `AGENTS.md` on purpose: every agent that needs a field parses it deterministically (`ruby -ryaml`, always on `PATH` per this team's own install prerequisites) instead of grepping prose for a heading that might have drifted, and the installer (once it exists) can write and verify this file programmatically instead of doing markdown surgery on `AGENTS.md`.

```yaml
# team.yml — created automatically on first use of /bug, /request, or /triage if missing.
# Safe to hand-edit; agents read this file, they don't need to ask again once it's populated.

github:
  repo: owner/repo                # gh infers this from the git remote, but explicit beats guessed
                                   # once a fork remote or multiple repos make that ambiguous
  project:
    owner: owner-or-org            # who the GitHub Project (v2) board belongs to
    number: 4                      # gh project list --owner OWNER to find it
  default_status: Ready            # status column new feature-request issues land in — bugs
                                    # never reach the board, see "Where Project Config Lives" below
  labels:
    feature: feature
    bug: bug
    tech-debt: tech-debt

review:
  escalation_rounds: 3             # same [CATEGORY] finding persisting this many consecutive
                                    # review rounds triggers escalation to the user instead of
                                    # another automatic engineer re-route — see orchestrator.md
                                    # "Round Tracking". Naming a persisting category (the warning,
                                    # not the escalation) still happens the first time any category
                                    # repeats across two rounds — that part isn't configurable, it's
                                    # the earliest point repetition can even be detected.

cadence:
  log_analyst_interval: 15         # completed pipeline/bug-fix cycles between orchestrator nudges
                                    # to run log-analyst — see orchestrator.md Stage 9/B10. The
                                    # spec's starting guess, not a law; tune it once real data on
                                    # real-pattern-vs-noise log-analyst runs accumulates.
```

Read this file before running any project command. If it doesn't exist yet, ask the user for the owner and project number once, and offer to write `team.yml` so future runs don't ask again — `gh project list --owner {owner}` will list available projects and their numbers if the user isn't sure. Leave `cadence.log_analyst_interval` at its default (`15`) unless the user asks to change it; don't invent a value.

**`github.repo` specifically is written by `bin/team-setup-project`** (run via `/install`), not by hand-rolled `Edit` calls scattered across agents — it does a comment-preserving targeted line update, not a full YAML re-dump. If you're writing an agent that needs to set this field programmatically, call that script rather than reimplementing the same line-editing logic a second time; `intake` and `installer`'s own `project.owner`/`project.number` fields are the two remaining fields still set by an agent's own targeted `Edit`, since no script covers those yet.

**Reading a field from a script:**

```bash
ruby -ryaml -e "c = YAML.load_file('team.yml'); puts c.dig('github','repo')"
ruby -ryaml -e "c = YAML.load_file('team.yml'); puts c.dig('github','project','owner')"
ruby -ryaml -e "c = YAML.load_file('team.yml'); puts c.dig('github','project','number')"
```

`.dig` returns `nil` (prints nothing) rather than raising on a missing key — check for an empty result before using a value, don't assume the field is populated.

**The project board and the issue board are two different things, and the three label types split across them on purpose:**

- **`feature` and `tech-debt` issues** go on the GitHub Project board (`github.project`) — that's what `roadmap-analyst` reads to weigh backlog value, and what a human looks at to decide what to build next. They're ranked together (see `roadmap-analyst.md`) — a `tech-debt` issue just skips the discovery interview a `feature` issue would need first.
- **`bug` issues stay plain repo issues** — no project, no status column. `bug-triage` reads them straight off the repo's Issues tab (`gh issue list --label bug`), verifies and ranks them itself, and writes `docs/triage.md`. Putting a bug on the project board too would just be a second, unranked opinion sitting next to a better one.

`github.project` in `team.yml` is read by feature/tech-debt filing (`intake`, the orchestrator's scope-capture filing, `roadmap-analyst`) and `roadmap-analyst`'s own read pass. `bug-triage` never touches it.

All three labels can be filed two ways: directly, by a human via `/bug`/`/request`, or automatically, by the orchestrator sweeping a pipeline run's **Scope ideas noticed** entries (see the `scope-capture` skill) once the run reaches a final verdict. Same labels, same destinations, same duplicate-check — the only difference is whether a human confirmed it live or the orchestrator confirmed it against existing issues instead, since Stage 7b can't pause a pipeline mid-run to ask.

**Neither path constructs the raw `gh` calls below directly anymore.** `bin/team-create-issue` and `bin/team-find-issues` (see the next two sections) are what every agent that files or searches actually runs — `intake`, the orchestrator's scope-capture filing, `roadmap-analyst`, and `bug-triage`'s reclassify case all call the same two scripts. The point isn't just avoiding duplicated code; it's that the routing rule (`feature`/`tech-debt` → project board, `bug` → never) lives in one script a human can read, instead of four call sites each expected to remember it correctly. The raw `gh` recipes further down are what those scripts do internally — read them to understand or modify the scripts, not to reimplement them in a new agent.

---

## Creating an Issue — `bin/team-create-issue`

```bash
bin/team-create-issue --type {feature|bug|tech-debt} --title "TITLE" \
  (--body-file /path/to/body.md | --body "inline text") \
  [--repo owner/repo] [--dir /path] [--dry-run]
```

Reads `team.yml` at `--dir` (default: current directory) for the repo, the label name for `--type`, and — only when `--type` is `feature` or `tech-debt` — the project board and status column. Routing is fixed inside the script, not exposed as a flag: a `bug` cannot reach the project board no matter what's passed, and a `feature`/`tech-debt` cannot skip it — if `team.yml`'s project isn't configured yet, the script fails *before* creating anything rather than filing an orphaned issue that silently misses the board.

`--dry-run` runs every check (label exists, project configured if needed) without making any `gh` write call — prints what would happen instead. Use it to preview, or when testing a caller against this script without touching real GitHub state.

Output, one JSON object on the last line of stdout:

```json
{"status":"ok","number":57,"url":"https://github.com/o/r/issues/57","type":"feature","on_project_board":true,"detail":"created #57 labeled 'feature', added to project #4 (Ready)"}
{"status":"dry_run","would_create":{"repo":"...","label":"...","title":"...","on_project_board":true,"project":{"owner":"...","number":4,"status":"Ready"}}}
{"status":"failed","detail":"..."}
```

A `failed` result after the issue was already created (the board-add step failed, not the issue creation) still includes `number`/`url` — the issue exists, just not on the board yet; the `detail` says what to do about it.

Internally this script does what the two subsections below describe — read them if you're modifying `bin/team-create-issue` itself, not as a recipe to copy into a new agent.

### Body formatting

`--body-file`/`--body` is what a human sees first — as the card preview on the project board, and as the rendered issue page. Write it as clean, structured markdown, never a wall of prose:

- Section headers (`##`) per logical chunk — Summary, Steps to Reproduce/User Story, Codebase Context, Additional Notes are the ones `intake`'s "Issue Body Format" already names; keep using headers even in a one-off body a different agent writes (`bug-triage`'s reclassify filing, `roadmap-analyst`'s gap-found filing, the orchestrator's scope-capture filing).
- **Bold** the label on any key/value line (`**Expected:**`, `**Actual:**`, `**Route:**`) rather than writing it as plain lead-in text.
- Bullet or numbered lists for anything enumerable — repro steps, affected files, multiple findings — never comma-spliced into one paragraph.
- Fenced code blocks for error text, stack traces, file paths, or command output — never inlined into prose.
- Short paragraphs (2-3 sentences) inside a section; split a longer one into a list instead of extending it.

Every agent that calls `bin/team-create-issue` follows this, using `intake.md`'s "Issue Body Format" as the template unless it defines its own equally-structured one.

### What it does: label check, then create, then (conditionally) add to the board

```bash
gh label list --repo OWNER/REPO --search LABEL --json name   # fails clearly if missing — run /install, doesn't auto-create mid-file
gh issue create --repo OWNER/REPO --title "TITLE" --body-file PATH --label LABEL
# feature/tech-debt only, after the issue exists:
gh project item-add NUMBER --owner OWNER --url ISSUE_URL
gh project item-edit NUMBER --owner OWNER --url ISSUE_URL --field "Status" --value "Ready"
```

`item-add` is a no-op error if the issue is already on the board — the script proceeds to `item-edit` regardless of `item-add`'s own exit code, since only `item-edit`'s result decides whether the board step actually succeeded. `--field`/`--value` take the field's and option's *display names* exactly as they appear on the board. If the target status doesn't exist as an option on the Status field yet, this fails — `/install`'s `bin/team-setup-project-status` is what adds it (see `docs/installer.md`, "Status Field Options"); a failure here on an already-installed repo usually means `default_status` in `team.yml` was changed by hand without re-running `/install`.

---

## Checking for Duplicates Before Filing — `bin/team-find-issues`

```bash
bin/team-find-issues --type {feature|bug|tech-debt} --query "keywords" [--repo owner/repo] [--dir /path]
```

Always search before creating — a report that duplicates an open issue wastes a human's triage time. Returns candidates, never decides relevance:

```json
{"status":"ok","matches":[{"number":42,"title":"...","url":"...","state":"OPEN"}]}
```

`matches: []` is a normal, successful result. If something clearly matching turns up, the calling agent surfaces it and asks whether to still file, comment on the existing one instead, or drop it (`intake`) — or, where there's no human to ask mid-pipeline, skips filing and notes the existing issue number (the orchestrator's scope-capture filing). Internally: `gh issue list --repo OWNER/REPO --search "QUERY in:title,body" --label LABEL --state all --limit 10 --json number,title,url,state`.

---

## Git Worktrees for Pipeline Isolation

The orchestrator runs every stage past discovery inside its own git worktree — a second working directory checked out to the feature branch, sitting alongside the main checkout rather than inside it. This means nobody has to switch branches out from under a running conversation, and the main checkout stays clean and mergeable at all times.

```bash
git worktree add "../{NNN}-{feature-name}" -b "feature/{NNN}-{feature-name}"
```

Creates the branch and the worktree in one step. If a worktree at that path already exists — resuming an in-progress pipeline — this fails; check first and reuse it instead of erroring:

```bash
git worktree list --porcelain | grep -q "{NNN}-{feature-name}" \
  && echo "reuse existing worktree" \
  || git worktree add "../{NNN}-{feature-name}" -b "feature/{NNN}-{feature-name}"
```

Once the feature's pull request has merged, the worktree is no longer needed:

```bash
git worktree remove "../{NNN}-{feature-name}"
```

This isn't automated — see the orchestrator's own instructions for when it prompts the user to clean one up rather than doing it silently, since a worktree might still be in active use if the PR is still open.

---

## Opening a Pull Request

Detect the actual default branch rather than assuming `main` — plenty of repos still use `master`:

```bash
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
```

The branch must already be pushed, or `gh pr create` prompts interactively to push it — in a non-interactive agent context, push explicitly first:

```bash
git push -u origin BRANCH
gh pr create --title "TITLE" --body-file PATH_TO_BODY_FILE --base "$DEFAULT_BRANCH"
```

`--body-file` reads the PR description from a file rather than a string on the command line — use it whenever the body is already a written document (this team's `{NNN}-summary.md` is exactly that; no need to re-derive PR prose from scratch when the feature synthesis doc already says everything a reviewer needs). `--body` (a literal string) or `--fill` (autofill from commit messages) are the alternatives when there's no existing document to point at.

Reference the closing issue in the body (`Closes #123`) if this PR resolves an issue filed via `/bug` or `/request` — GitHub closes it automatically on merge.

---

## Reading Issues

```bash
gh issue view NUMBER --repo OWNER/REPO
gh issue list --repo OWNER/REPO --label LABEL --state open
```
