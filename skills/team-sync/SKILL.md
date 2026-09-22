---
name: team-sync
description: The shared procedure for vendoring or updating this team's agents/commands/skills/bin files from the source repo, using bin/team-update's plan/apply hash comparison. Used by both the installer (first-ever vendor, on a repo that may not have bin/team-update yet) and the updater (every sync after that). See docs/updates.md for the full manifest.yml/team.lock.yml schema and design rationale — this skill is the operational "what to run, what to ask" reference.
---

# Team Sync Procedure

## Resolving `source_repo`

1. If `team.yml` exists and has `team.source_repo` set, use that.
2. Otherwise, use the default: `https://github.com/revans/rails-agentic-engineering-team.git`

This must match `DEFAULT_SOURCE_REPO` in `bin/team-update` exactly — if one is ever changed, change both, the same drift risk this whole mechanism exists to catch elsewhere.

```bash
ruby -ryaml -e "puts (YAML.load_file('team.yml') rescue {}).dig('team','source_repo')" 2>/dev/null
```

An empty result means no override — use the default. On a genuinely first-ever sync (installer, before `bin/team-setup-project` has run), `team.yml` won't exist yet at all; that's fine, it just means the default applies.

## Getting a Runnable `bin/team-update`

`bin/team-update` takes its target as an explicit `--dir` argument and never assumes it's being run from inside that directory, so it works identically no matter where the script file itself physically lives.

- **If `bin/team-update` already exists at `$TARGET_DIR/bin/team-update`** (true for every `/rails-update` run, since `/rails-install` — see below — vendors it on first use): invoke that copy directly.
- **If it doesn't exist yet** (true only for `/rails-install`'s very first sync on a repo that has never vendored anything): shallow-clone `source_repo` into a scratch temp directory first, purely to get a runnable copy of the script:

  ```bash
  BOOTSTRAP_DIR=$(mktemp -d)
  git clone --depth 1 "$SOURCE_REPO" "$BOOTSTRAP_DIR"
  ```

  Then invoke `ruby "$BOOTSTRAP_DIR/bin/team-update" ...` in place of `bin/team-update ...` for every command below. Remove `$BOOTSTRAP_DIR` once the sync finishes — it served its one purpose (this is separate from, and in addition to, the snapshot directory `plan` itself creates for the actual manifest/file diffing).

## The Sync Itself

### 1. Plan

```bash
bin/team-update plan --dir "$TARGET_DIR"
```

(Or the bootstrapped `ruby "$BOOTSTRAP_DIR/bin/team-update" plan --dir "$TARGET_DIR"` form.) Read the last line as JSON.

- **`status: "failed"`** — report `detail` verbatim and stop. The most common cause is the source repo being unreachable — network, or a stale `team.source_repo` override.
- **`status: "ok"`** — present each non-empty category, in this order:

  1. **`new_files`** — never vendored here before. On a first-ever sync (installer) this is almost every tracked file — that's expected, not a warning sign. Nothing local to lose; ask once whether to vendor all of them in, default yes.
  2. **`clean_updates`** — upstream changed these, nothing local touched them since the last sync. Ask once whether to apply all, default yes (recommended) — offer to review the list first if asked.
  3. **`conflicts`** — both the local file and upstream changed since the last sync (or, `base_sha: null`, there's no sync history at all for a file that already existed locally with different content — this can only happen if something was placed at that path outside this mechanism before the first sync ever ran). For each: `diff -u "$TARGET_DIR/{path}" "{snapshot_dir}/{path}"`, show it, then ask: take upstream, keep local, or skip for now.
  4. **`local_only_edits`** — hand-edited locally, upstream hasn't touched them. Report only; nothing to offer, nothing is out of date.
  5. **`removed_upstream`** — tracked before, gone from the source repo now. Ask per file: delete it locally too, or keep it.

  If every category is empty except `unchanged_count`, say so — but still continue to step 2 below; `apply` needs to run once regardless to record `synced_at`/`synced_version` and seed `team.lock.yml`'s baseline for every already-matching file.

### 2. Apply

Collect the decisions into comma-separated path lists and call once, even when every list is empty:

```bash
bin/team-update apply --dir "$TARGET_DIR" --snapshot-dir "{snapshot_dir}" \
  --take-upstream "path,path,..." \
  --keep-local "path,path,..." \
  --remove "path,path,..."
```

Omit a flag entirely if its list is empty. `new_files` and `clean_updates` the caller approved both go under `--take-upstream`; a conflict resolved as "keep local" goes under `--keep-local` (records that the current upstream version was seen and accepted, so it won't re-surface as a conflict unless upstream changes that file again); a conflict or `removed_upstream` entry left alone entirely goes under neither flag and is reported again next sync.

If the run is abandoned before any decision is made, clean up instead of leaving a stray snapshot:

```bash
bin/team-update cleanup --snapshot-dir "{snapshot_dir}"
```

Read the apply result's last line as JSON; `status: "failed"` — report `detail` verbatim. The snapshot directory is left in place on failure so a corrected re-run of `apply` doesn't require re-cloning.

`apply` also prepends a dated entry to `docs/updates-log.md` (created on first use) recording exactly what it did — vendored, updated, took-upstream, kept-local, and removed paths, each listed by name. Nothing to do here; it's automatic and skipped entirely when a sync changes nothing.

## Logging

Log a decision whenever a conflict is resolved (which side was taken, and why if a reason was given) — that's the signal worth keeping, not the mechanical clean-update applies.
