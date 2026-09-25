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
                                    # another automatic engineer re-route — see rails-orchestrator.md
                                    # "Round Tracking". Naming a persisting category (the warning,
                                    # not the escalation) still happens the first time any category
                                    # repeats across two rounds — that part isn't configurable, it's
                                    # the earliest point repetition can even be detected.

cadence:
  log_analyst_interval: 15         # completed pipeline/bug-fix cycles between orchestrator nudges
                                    # to run rails-log-analyst — see rails-orchestrator.md Stage 9/B10.
                                    # The spec's starting guess, not a law; tune it once real data on
                                    # real-pattern-vs-noise rails-log-analyst runs accumulates.
```

Read this file before running any project command. If it doesn't exist yet, ask the user for the owner and project number once, and offer to write `team.yml` so future runs don't ask again — `gh project list --owner {owner}` will list available projects and their numbers if the user isn't sure. Leave `cadence.log_analyst_interval` at its default (`15`) unless the user asks to change it; don't invent a value.

**`github.repo` specifically is written by `bin/rails-team-setup-project`** (run via `/rails-install`), not by hand-rolled `Edit` calls scattered across agents — it does a comment-preserving targeted line update, not a full YAML re-dump. If you're writing an agent that needs to set this field programmatically, call that script rather than reimplementing the same line-editing logic a second time; `intake` and `rails-installer`'s own `project.owner`/`project.number` fields are the two remaining fields still set by an agent's own targeted `Edit`, since no script covers those yet.

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
gh label list --repo OWNER/REPO --search LABEL --json name   # fails clearly if missing — run /rails-install, doesn't auto-create mid-file
gh issue create --repo OWNER/REPO --title "TITLE" --body-file PATH --label LABEL
# feature/tech-debt only, after the issue exists:
gh project item-add NUMBER --owner OWNER --url ISSUE_URL
gh project item-edit NUMBER --owner OWNER --url ISSUE_URL --field "Status" --value "Ready"
```

`item-add` is a no-op error if the issue is already on the board — the script proceeds to `item-edit` regardless of `item-add`'s own exit code, since only `item-edit`'s result decides whether the board step actually succeeded. `--field`/`--value` take the field's and option's *display names* exactly as they appear on the board. If the target status doesn't exist as an option on the Status field yet, this fails — `/rails-install`'s `bin/team-setup-project-status` is what adds it (see `docs/installer.md`, "Status Field Options"); a failure here on an already-installed repo usually means `default_status` in `team.yml` was changed by hand without re-running `/rails-install`.

---

## Checking for Duplicates Before Filing — `bin/team-find-issues`

```bash
bin/team-find-issues --type {feature|bug|tech-debt} --query "keywords" [--repo owner/repo] [--dir /path]
```

Always search before creating — a report that duplicates an open issue wastes a human's triage time. Returns candidates, never decides relevance:

```json
{"status":"ok","matches":[{"number":42,"title":"...","url":"...","state":"OPEN"}]}
```

`matches: []` is a normal, successful result — only then create a new issue. If something clearly matching turns up, **update the existing issue with whatever new information this pass surfaced, rather than just skipping** — a new instance, a new symptom, confirmation it's still real, a clearer fix approach:

```bash
gh issue comment MATCH_NUMBER --repo OWNER/REPO --body "Also observed during {this context}: {what's new — don't just repeat the original report}."
```

Where there's a human to ask mid-pipeline (`intake`), surface the match and ask whether to still file a new issue, comment on the existing one, or drop it — comment-on-existing is the recommended default, not a neutral third option. Where there's no human to ask (the orchestrator's scope-capture filing, or any autonomous batch-filing pass), comment automatically and note the existing issue number in the final report — don't silently skip with no comment just because a match exists; that discards real, newly-surfaced information the original filer didn't have. Only skip with no comment at all if this pass genuinely found nothing beyond what the existing issue already says. Internally, the search itself: `gh issue list --repo OWNER/REPO --search "QUERY in:title,body" --label LABEL --state all --limit 10 --json number,title,url,state`.

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

**Closing more than one issue in the same PR body or commit message needs one keyword per issue, each on its own line — a comma-separated list silently closes only the first one.** `Closes #153, #114, #161, #160` closes #153 and does nothing for the other three; GitHub's closing-keyword parser doesn't recognize a comma-separated reference list, and it fails with no error, no warning — the other issues are just still open. Write `Closes #153\nCloses #114\nCloses #161\nCloses #160` instead, one line per issue. Verify with `gh issue view {N} --json state` after any multi-issue close, don't assume the whole list took.

**Write the keyword bare — `Closes #N` alone on its own line, no bold, no colon, no surrounding markdown.** A long-running series of silent close failures in a downstream project traced to a PR-body template that emitted `**Closes:** #N` instead. GitHub's closing-keyword parser does not reliably recognize the bolded, colon-suffixed form, and it fails the same way a comma-separated list does: no error, no warning, the issue just stays open. A bundle that hit this reformatted to bare `Closes #N` lines before opening its PR and all six of its issues then closed correctly on merge. `**Closes:** #N` reads fine to a human and is easy to introduce when a summary document uses bold key/value lines elsewhere — so check the rendered keyword, not just that the number is present.

That accounts for most of the observed failures but has not been proven to account for every one, so **treat `gh issue view {N} --json state` after *every* merge — not just multi-issue ones — as a required step, not a spot-check.** If it's still open, close it by hand with `gh issue close {N}` rather than re-merging or investigating further in the moment.

**A commit message containing a closing keyword (`fix`/`fixes`/`fixed`/`close`/`closes`/`resolve`/`resolves`/`resolved` immediately followed by `#N`) closes the issue the moment that commit reaches GitHub — not just when it's later referenced in a merged PR body.** This has bitten Bug Fix Mode specifically: a mid-pipeline commit phrased `"fix #154: ..."` closed the issue hours before review even started, with no PR yet open to reopen against. Never use a closing keyword in an intermediate commit message for work still in progress — save it for the one place it's actually meant to fire (the final PR body, closing on merge). See `rails-orchestrator.md`'s Bug Fix Mode commit templates for the phrasing this team uses instead ("issue #{N} ..." rather than "fix #{N} ...").

Once the PR exists, request a Copilot code review on it — every PR this team opens gets one:

```bash
gh pr edit PR_URL_OR_NUMBER --add-reviewer @copilot
```

`--add-reviewer @copilot` is a `gh` special value (not a literal username) that requests an automated Copilot review, the same as picking "Copilot" from the Reviewers list in the GitHub UI. It only requests the review — it doesn't wait for it or block on it. It fails if Copilot code review isn't enabled for the org/repo; treat that as a real error to surface, not something to retry or silently swallow, and it doesn't mean the PR itself failed to open.

---

## Reading Issues

```bash
gh issue view NUMBER --repo OWNER/REPO
gh issue list --repo OWNER/REPO --label LABEL --state open
```

## Checking a Card's Board Status Before Starting Work

**Before starting Bug Fix Mode (or any pipeline) on an issue, check whether its board card is already "In Progress" — never start a second pipeline on an issue someone (or something) else is already working.** This matters most when picking issues from a list to work through in a batch, or when multiple concurrent sessions/orchestrators share the same repo — the "In Progress" status Stage B1 sets when work actually starts (see `rails-orchestrator.md`'s Bug Fix Mode) exists specifically so this check is possible; skipping the check makes that marking pointless.

There's no single-item `gh project item-view` — list and filter client-side:

```bash
gh project item-list PROJECT_NUMBER --owner OWNER --format json --limit 250 \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in data['items']:
    c = item.get('content', {})
    if c.get('number') == ISSUE_NUMBER:
        print(item.get('status'))
"
```

If the result is `In Progress`, stop and surface it rather than starting duplicate work — name the issue and ask whether to proceed anyway (the existing work may be stale/abandoned) or pick a different issue. `Todo`, `Ready`, or not on the board at all (a plain `bug`, which never reaches the board — see "Creating an Issue" above) are all safe to start. This check costs one extra `gh` call; a duplicate pipeline running on the same issue costs a full review cycle and a real risk of two PRs racing to close the same issue.
