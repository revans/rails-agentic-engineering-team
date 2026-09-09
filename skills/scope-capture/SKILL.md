---
name: scope-capture
description: When to name something that should exist but isn't part of the current feature, and how to hand it off so it lands in TODO.md without expanding scope or writing outside your feature directory.
---

# Scope Capture

## The Trigger

While doing your job — reading the codebase, writing a spec, implementing, reviewing — you notice something that should exist as its own capability, but isn't required by what you were actually asked to produce right now. A missing feature, a piece of tech debt worth its own pass, a gap adjacent to but not inside your current scope.

Two failure modes to avoid, both silent:

1. **Building it anyway** because it's small and related. Don't. It's unreviewed, untested against any spec, and outside what was actually asked for — the exact thing the Abstraction Decisions convention already guards against for implementation choices. This guards the same boundary for whole features.
2. **Letting it evaporate.** True, useful, and never written down anywhere — the next person to touch this area rediscovers it from scratch, or never does.

## What Qualifies

- A capability, feature, or fix that stands on its own — someone could scope, spec, and build it as its own unit of work later
- Genuinely not required to satisfy what you were asked to produce — if it IS required, this isn't a scope-capture case, it's a gap in the artifact you're producing or reviewing. Name it as a finding instead (a spec gap for the architect, a `[COVERAGE_GAP]` for fidelity-review) — don't launder a real requirement into a deferred idea
- Something you noticed in passing, not something you went looking for. If you're actively evaluating whether a feature needs something, that's the current work, not a scope-capture candidate

## How to Hand It Off

**You do not write to `TODO.md` yourself.** Most agents in this pipeline are restricted to writing inside `{FEATURE_DIR}` — `TODO.md` lives at the project root, outside it. Even engineer, which isn't under that restriction, doesn't write it directly: four review agents run in parallel, and if any of them touched `TODO.md` directly it would be a race against the other three. The orchestrator is the only agent that ever opens `TODO.md` — it sweeps every artifact for these entries once, at pipeline completion.

Your job is just to name it in your own report, in the format below, wherever your report format calls for a **Scope ideas noticed** entry:

```
- **{Idea, short}** — {what surfaced it, one sentence}
```

Example:
```
- **Bulk export for listing audit logs** — noticed while reviewing the listing-approval diff; there's no way to export the audit trail this feature writes, and support has no way to pull it outside the Rails console.
```

Skip the section (or write "None") if nothing qualifies during this run. Don't manufacture an entry to avoid leaving it blank.
