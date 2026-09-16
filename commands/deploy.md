---
name: Deploy
description: "Regenerates manifest.yml (the sha256 of every agent/skill/command/bin file this team vendors into installed repos), summarizes what changed since the last commit, and asks before staging and committing it. Source-repo maintainer tool, not something an installed target repo runs. Usage: /deploy"
color: blue
---

# Deploy

This is a source-repo maintainer tool, not one of the team's agents — it has no live GitHub or system-dependency steps, so it doesn't need a dedicated `agents/*.md` identity the way `/install` and `/update` do. Run its steps directly.

## What This Does

`manifest.yml` at this repo's root is what `bin/team-update` (vendored into every installed target repo) reads to detect drift — see `docs/updates.md` for the full design. This command keeps it current.

### Step 1 — Regenerate the manifest

```bash
bin/team-manifest
```

Read the last line as JSON. `status: "failed"` — report `detail` verbatim and stop (this usually means `VERSION` is missing or `git remote get-url origin` doesn't resolve — neither should happen in a normal checkout of this repo). `status: "ok"` — continue.

### Step 2 — Summarize what changed

```bash
git diff --stat -- manifest.yml
```

If `manifest.yml` wasn't tracked before this run, say "first manifest generated — N files" instead of diffing. Otherwise, read both versions and report, by path, which files were added, removed, or changed hash — not just a line count, since `manifest.yml`'s lines don't map one-to-one to files in an obviously readable diff:

```bash
git show HEAD:manifest.yml > /tmp/manifest-before.yml 2>/dev/null || echo "(no previous manifest)"
```

Compare the two `files:` maps (by key) and report three lists: added, removed, changed. A file whose hash didn't change isn't worth listing.

### Step 3 — Check `VERSION`

Report the current value. This repo's convention (see `git log -p -- VERSION`) is that version bumps ride along with the commit that makes the structural change, not a mechanical action on every deploy — so don't bump it automatically. If the changes summarized in Step 2 look like a structural change (new agent/skill/command, not just a wording tweak) and `VERSION` hasn't already been bumped as part of this same change, mention that and offer to bump it (a plain `Edit` to the `VERSION` file) before continuing. Wait for a yes.

### Step 4 — Ask before committing

Show the final file list (`manifest.yml`, and `VERSION` if it changed) and ask explicitly whether to stage and commit them — never commit without that, per this session's git safety conventions. If yes:

```bash
git add manifest.yml VERSION   # only VERSION if it actually changed
git commit -m "..."
```

Never push. Pushing `master` is a separate, larger action the user asks for on its own.
