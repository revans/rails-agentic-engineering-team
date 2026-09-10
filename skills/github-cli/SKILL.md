---
name: github-cli
description: gh CLI reference for this team — creating and searching issues, filing them to a GitHub Projects (v2) board with a label and status column, isolating pipeline work in a git worktree, and opening pull requests. Every command here was verified against a real `gh --help`/`git worktree --help` output, not written from memory.
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
  default_status: Ready            # status column new intake issues land in
  labels:
    feature: feature
    bug: bug

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

**Reading a field from a script:**

```bash
ruby -ryaml -e "c = YAML.load_file('team.yml'); puts c.dig('github','repo')"
ruby -ryaml -e "c = YAML.load_file('team.yml'); puts c.dig('github','project','owner')"
ruby -ryaml -e "c = YAML.load_file('team.yml'); puts c.dig('github','project','number')"
```

`.dig` returns `nil` (prints nothing) rather than raising on a missing key — check for an empty result before using a value, don't assume the field is populated.

**Only one GitHub Project board exists in this team's current design** — `feature` and `bug` issues both land on it, distinguished by label, not by separate boards. `docs/triage.md` and `docs/roadmap.md` both read this same `github.project`. If a project later needs bugs kept off the shared board entirely (a plain repo-issues-only path, with its own `bug_project` config block), that's a deliberate design change to make explicitly — not something to infer from this file's shape.

---

## Creating an Issue

```bash
gh issue create --repo OWNER/REPO --title "TITLE" --body "BODY" --label LABEL
```

If the label doesn't exist in the repo yet, this fails. Check first:

```bash
gh label list --repo OWNER/REPO --search LABEL
```

If it's not there, create it before filing the issue:

```bash
gh label create LABEL --repo OWNER/REPO --description "DESCRIPTION" --color HEXCOLOR
```

`gh issue create` prints the issue URL on success — capture it, every subsequent step needs it.

### Adding straight to a project at creation time

`gh issue create` also takes `--project TITLE` (the project's *display title*, not its number) to add the issue to a board in the same call:

```bash
gh issue create --repo OWNER/REPO --title "TITLE" --body "BODY" --label LABEL --project "PROJECT TITLE"
```

This does **not** set a status column — it just adds the item at whatever the board's default status is. Setting a specific column is a separate step below regardless of which path you used to add it.

---

## Checking for Duplicates Before Filing

Always search before creating — a report that duplicates an open issue wastes a human's triage time:

```bash
gh issue list --repo OWNER/REPO --search "KEYWORDS in:title,body" --label LABEL --state all --limit 10
```

If something clearly matching turns up, surface it to the user and ask whether to still file a new issue, comment on the existing one instead, or drop it. Don't decide silently.

---

## Setting a Project Item's Status Column

Once the issue exists and is on the board (via `--project` at creation, or `item-add` below), set its status by **name** — no manual GraphQL ID lookup needed for the normal case:

```bash
gh project item-add NUMBER --owner OWNER --url ISSUE_URL
gh project item-edit NUMBER --owner OWNER --url ISSUE_URL --field "Status" --value "Ready"
```

`item-add` is a no-op error if the issue is already on the board (e.g. because `gh issue create --project` already added it) — in that case skip straight to `item-edit`.

`--field` takes the field's display name (e.g. `"Status"`) and `--value` takes the option's display name (e.g. `"Ready"`) exactly as they appear on the board. If the target status column doesn't exist as an option on the project's Status field yet, this fails — **don't try to invent or auto-create the column via a GraphQL mutation**; tell the user the column is missing and ask them to add it in the GitHub UI (Project → Settings → Status field). Field/option creation isn't a clean single-command operation in `gh project`, and guessing at the GraphQL schema is more likely to corrupt the field than to help.

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
