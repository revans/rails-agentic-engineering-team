# Updates

`/rails-deploy` and `/rails-update` (plus `/rails-install`, which now uses the same mechanism for its very first vendor) are the halves of one system: keeping every repo that has a copy of this team's `agents/`, `commands/`, `skills/`, and `bin/` files in sync with this source repo, without a human hand-copying files or writing a one-off upgrade doc each time something changes. The actual plan/apply procedure — what to run, what to ask about — lives in one place, the `team-sync` skill, so `agents/rails-installer.md` and `agents/rails-updater.md` both reference it instead of each restating it.

## What This Replaces

Before this existed, getting a change from this repo into an installed target repo meant writing a `docs/portable-upgrades/*.md` instruction document by hand and having an agent apply it file by file — no automated way to tell which files had actually diverged, and no automated way to vendor in a file that was never copied over in the first place. Getting the files there in the *first* place was manual too: `/rails-install` never vendored anything, it only assumed `bin/agent-log` and the rest of the tree were already sitting in the repo. Those historical upgrade documents stay as records of what they did; nothing about them changes. Going forward, a change that needs to reach installed repos goes out via `/rails-deploy` + `/rails-update`, and a repo that's never seen this team before gets everything from `/rails-install`'s own first sync.

## `/rails-deploy` — Source Repo Side

Run in *this* repo only — it's a maintainer tool, not one of the team's agents, and an installed target repo never runs it.

```mermaid
flowchart TD
    A["bin/team-manifest"] --> B[Summarize what changed]
    B --> C{Structural change?}
    C -->|yes, not bumped yet| D[Offer to bump VERSION]
    C -->|no| E{VERSION changed?}
    D --> E
    E -->|yes| F[Draft a CHANGELOG.md entry]
    E -->|no| G[Ask before commit]
    F --> G
    G --> H["git add + git commit (never push)"]
```

`bin/team-manifest` hashes every tracked file (see "Tracked Files" below) with SHA-256 and writes `manifest.yml` at the repo root:

```yaml
version: 1.12.0
generated_at: 2026-09-16T00:00:00Z
source_repo: https://github.com/revans/rails-agentic-engineering-team.git
files:
  agents/architect.md: 3f2a9c...
  bin/agent-log: 91be0d...
  commands/bug.md: 7ac412...
  skills/agent-log/SKILL.md: c04eaa...
  # ...every tracked file, sorted by path
```

`manifest.yml` is generated — don't hand-edit it, `/rails-deploy` regenerates it wholesale every run. `version` comes from the `VERSION` file, not bumped automatically; this repo's own history (`git log -p -- VERSION`) shows bumps ride along with the commit that makes a structural change, so `/rails-deploy` only offers to bump it, never does so on its own.

When `VERSION` did change, `/rails-deploy` also drafts and asks about adding a `CHANGELOG.md` entry — human-readable release notes for this project itself (newest first, one entry per version), distinct from `docs/updates-log.md` (below), which is a mechanical per-file record generated in each *target* repo, not this one. `/rails-deploy` also never commits or pushes without asking first, same as every other action in this repo that touches shared state.

## `/rails-install` — First Vendor

`/rails-install`'s Step 0.5 runs the exact same plan/apply cycle the `team-sync` skill describes and `/rails-update` uses below (see "How a File Gets Classified" and "Snapshot Reuse"), with one difference: the target repo almost certainly has no `bin/team-update` yet to run, since nothing has ever been vendored there. To get around that, it shallow-clones the source repo into a scratch directory purely to obtain a runnable copy of the script, then invokes `ruby {scratch}/bin/team-update ...` in place of `bin/team-update ...` — the script never assumes it's running from inside the directory it's operating on, every path is passed explicitly via `--dir`/`--snapshot-dir`, so this works identically. That scratch directory is separate from (and removed independently of) the snapshot directory `plan` itself creates for the actual file diffing.

On a truly fresh repo this makes almost every tracked file a `new_file` — expected, not a conflict, since there's nothing local to lose. A *second* run of `/rails-install` against an already-vendored repo goes through the identical procedure and simply finds the normal mix of clean updates, conflicts, and unchanged files `/rails-update` would also find; `/rails-install` isn't a separate, weaker sync path, it's the same one, just possibly starting from nothing.

The one thing that can't be automated away: `commands/rails-install.md` and `agents/rails-installer.md` themselves have to exist in the target repo before Claude Code can offer `/rails-install` as a slash command at all — no in-repo mechanism can vendor the file that makes vendoring possible. Everything past that point, including every `bin/` script `/rails-install`'s later steps depend on, is now self-vendoring.

## `/rails-update` — Target Repo Side

Run in an already-installed target repo, on demand — after a `/rails-deploy`, or just periodically.

```mermaid
flowchart TD
    A[Confirm target directory] --> B{team.yml exists?}
    B -->|no| Z[Point at /rails-install, stop]
    B -->|yes| C["bin/team-setup-git / -gh / -sqlite"]
    C --> D["bin/team-update plan"]
    D --> E[Present categorized diff]
    E --> F[Collect per-file decisions]
    F --> G["bin/team-update apply"]
    G --> H[Report]
```

Steps A and E–F are conversational — the updater agent asks and waits. C is the same three scripts `/rails-install` uses, same JSON-status branching. D and G are script calls read as one JSON object off the last line of output.

### Tracked Files

`agents/**`, `commands/**`, `skills/**`, `bin/*` — everything this team vendors into a target repo except two files that only make sense in *this* repo: `bin/team-manifest` (the build tool that produces `manifest.yml` — a target repo never needs to produce one) and `commands/rails-deploy.md` (`/rails-deploy` reads `bin/team-manifest`, so a `/rails-deploy` command vendored into a target repo without that script would just be dead). `docs/`, `README.md`, and `VERSION` aren't tracked as files either; `VERSION`'s value travels as `manifest.yml`'s top-level `version` field instead, since a target repo's own `docs/` holds project-specific content (briefs, ICP personas, bug triage) that has nothing to do with the source repo's copy.

A target repo that vendored `commands/rails-deploy.md` before this exclusion existed isn't stuck with it forever: the next `/rails-update` sees it in `team.lock.yml` but no longer in the manifest, classifies it under `removed_upstream` the same as any other file dropped upstream, and asks whether to delete it.

### `team.lock.yml`

Generated by `bin/team-update`, lives next to `team.yml` in the target repo — don't hand-edit it. It records the hash each tracked file had immediately after the *last successful sync*, which is what makes a three-way comparison possible: without it, `/rails-update` could only see "local differs from upstream," never *why*.

```yaml
source_repo: https://github.com/revans/rails-agentic-engineering-team.git
synced_version: 1.12.0
synced_at: 2026-09-16T00:00:00Z
files:
  agents/architect.md: 3f2a9c...
  # ...every file synced at least once
```

A target repo can point at a different source repo by setting `team.source_repo` in its own `team.yml` (optional — falls back to this repo's own URL if unset). `bin/team-update` also accepts `--source-repo` directly, for testing against a local clone.

### How a File Gets Classified

For every file in the source repo's manifest, `bin/team-update plan` compares three values — the file's hash as of the last sync (`base`, from `team.lock.yml`), its current local hash (`local`), and its current upstream hash (`remote`):

| Situation | Category | What happens |
|---|---|---|
| File doesn't exist locally at all | **New file** | Vendor it in — no local content to lose |
| `local` matches `remote` | **Clean** (counted, not listed, unless `base` is also stale) | Nothing to do — already in sync |
| No sync history (`base` unknown) and `local` ≠ `remote` | **Conflict** | Can't tell a hand-edit from a stale copy — ask |
| `local` == `base`, `remote` ≠ `base` | **Clean update** | Upstream changed it, nothing local touched it — safe to auto-apply |
| `local` ≠ `base`, `remote` == `base` | **Local-only edit** | Hand-edited here, upstream hasn't moved — report only, no action |
| `local` ≠ `base`, `remote` ≠ `base`, `local` ≠ `remote` | **Conflict** | Both sides changed since the last sync — show a diff, ask: take upstream, keep local, or skip |
| Tracked before (`team.lock.yml` has it), gone from the manifest now | **Removed upstream** | Ask: delete locally too, or keep it |

A file on disk that appears in neither the manifest nor `team.lock.yml` is never touched or reported — that's the target repo's own project-specific addition, not this tool's concern. Resolving a conflict as "keep local" updates `team.lock.yml`'s recorded hash to the current upstream value, which means it stops being flagged — it will correctly surface as a conflict again only if upstream changes that file further while the local version still differs.

### `docs/updates-log.md`

Every `apply` that actually changes something prepends a dated entry to `docs/updates-log.md` in the target repo (created on first use, newest entry first) — a running record of what each sync did, replacing the ad hoc "what did that upgrade actually change" question the old `docs/portable-upgrades/*.md` documents existed to answer by hand:

```markdown
## 2026-09-16T22:06:41Z — synced to 1.13.0

**Updated from upstream:**

- commands/bug.md

**Conflicts resolved — took upstream:**

- commands/roadmap.md

**Conflicts resolved — kept local (upstream change acknowledged, not applied):**

- commands/triage.md

**Removed (deleted upstream):**

- commands/feature.md
```

The five possible sections are **Vendored** (never-seen-before files), **Updated from upstream** (clean updates), **Conflicts resolved — took upstream**, **Conflicts resolved — kept local**, and **Removed (deleted upstream)** — only non-empty sections appear, and a sync that changes nothing at all (every file already matched) writes no entry rather than an empty one. `apply` derives these categories itself from `team.lock.yml`'s state *before* it starts writing, so nothing the calling agent passes in needs to distinguish "new" from "updated" — both arrive as plain `--take-upstream` paths. Don't hand-edit this file; a sync only ever prepends, never rewrites, an existing entry.

### Snapshot Reuse

`plan` shallow-clones the source repo into a temp directory once and prints its path (`snapshot_dir`) in its JSON output; `apply` reads from that same directory instead of re-cloning, so a plan-then-apply pair only ever touches the network once. If the user backs out after seeing the plan without applying anything, `bin/team-update cleanup --snapshot-dir SNAP` removes the temp clone.

## Things to Know

- `/rails-deploy` never bumps `VERSION` on its own — it's a deliberate, per-change human/agent decision, not a mechanical part of every deploy.
- `/rails-update` assumes `/rails-install` has already run (`team.yml` must exist) — it doesn't bootstrap GitHub or system-level setup itself, only re-verifies the three dependencies `/rails-install` already checks.
- `apply` always seeds `team.lock.yml` with a baseline hash for every file that already matches upstream, even ones nobody had to decide anything about — a file with no recorded baseline reads as an unexplained conflict the next time either side touches it, so `apply` runs every time `plan` does, even when nothing needed a decision.
- Neither script ever pushes to a remote or force-overwrites a file `/rails-update` can't classify with confidence — a conflict always gets a human answer.
- `bin/team-update` never assumes it's running from inside the repo it's syncing — every path is an explicit `--dir`/`--snapshot-dir` argument. That's what makes `/rails-install`'s bootstrap-clone trick possible: the exact same script, invoked from a scratch temp directory, works identically.
- A `team.lock.yml` or `manifest.yml` that exists but fails to parse (an accidental hand-edit, a wrong-shaped file) fails the sync cleanly with `{"status":"failed"}` rather than silently being treated the same as "nothing here yet" — that distinction matters, since the latter would quietly discard every file's sync history instead of surfacing the problem.
