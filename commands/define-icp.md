---
name: Define ICP
description: "Interviews the user to write or refresh one persona's Ideal Customer Profile in docs/icp/{persona-slug}-icp.md — who they are, what they value, and who it's explicitly not for. Checks for a matching product brief from agentic-ideation-team first and asks only the gaps. Supports multiple personas, one file each. Read by /roadmap to judge which backlog items matter most."
color: purple
---

# Define ICP

`docs/icp/` holds one file per persona — `docs/icp/{persona-slug}-icp.md`. A product can have more than one (a two-sided marketplace has a buyer and a seller; an internal tool might have an admin and an end user), and each persona's picture sharpens on its own schedule as the product ships and learns who its real users are. Don't blend personas into one file — `/roadmap` needs to judge a backlog item against a specific persona, not an averaged composite.

Versioning is git's job, not the filename's — a persona file gets edited in place on a refresh, not duplicated as `-v2`. Git history already gives you every prior version if you need to see what changed.

This is the artifact `/roadmap` leans on to judge product value, not just technical dependency — see `commands/roadmap.md`.

---

## Step 1 — Check what exists

```bash
ls docs/icp/*-icp.md 2>/dev/null
```

- **No files found:** this is a first persona. Skip to Step 2.
- **Files found:** read each one's **Who They Are** section to know what personas already exist. Ask the user: is this a refresh of one of these, or a new persona? If a refresh, read the existing file in full — this run confirms what's still true before asking anything new, it isn't a blank rewrite.

Also read `AGENTS.md`'s Project Intro section, if present, for a first-pass sense of what this application is.

---

## Step 2 — Completeness-Check Bypass

Before interviewing (new persona) or re-deriving from scratch (refresh with no clear prior answer), check whether a whole-product brief from `agentic-ideation-team` already answers some of this ground:

```bash
ls -d docs/product-briefs/[0-9][0-9][0-9]-*/ 2>/dev/null
```

If a brief exists for this product, read `{NNN}-product-brief-{product-name}.md` and pull its **Target Users**, **One-Line Pitch**, and **Problem & Why Now** sections. Per the `product-brief-format` skill's completeness bar, Target Users names at least one specific role and context, and names every user type if there's more than one — each user type it names is a candidate for its own persona file here. Treat a matching entry as the starting draft of **Who They Are** and **The Job They're Hiring This For** below, and confirm it with the user rather than re-deriving it from scratch.

A product brief has no equivalent for **Today, Without This**, **What They Value**, **What Makes Them Leave**, or **Who This Is NOT For** — those always need their own questions, brief or no brief. If no brief exists, or it doesn't follow the `product-brief-format` section list, run the full interview below.

---

## Step 3 — Interview

One or two questions at a time. Explore wide before narrowing — this is closer to discovery's interview style than a form to fill in. Cover, for the one persona this run is defining or refreshing:

1. **Who they are** — specific role and the situation they're in when the problem hits them. "Freelance illustrators tracking invoices across 4+ clients," not "creative professionals."
2. **The job they're hiring this for** — what they're actually trying to accomplish, and what triggers them to go looking for something like this.
3. **Today, without this** — what they currently do instead (a competitor, a spreadsheet, nothing), and specifically why that falls short.
4. **What they value** — the reasons they keep choosing this over the alternative, once they've tried it.
5. **What makes them leave** — the friction or dealbreaker that would make them churn or never adopt in the first place.
6. **Who this is explicitly NOT for** — at least one entry. If the user can't name an excluded segment, push on it once — "who would try this and bounce off it" — before accepting "everyone" as an answer.

If, during this conversation, a second distinct persona becomes obvious (the user starts describing a genuinely different role with different needs), don't blend it in — finish the current persona's file, then ask whether they want to define the second one now as its own run of Step 3.

---

## Step 4 — Confirm before writing

Summarize what this persona's file will contain, and confirm the persona slug (kebab-case, derived from Who They Are — e.g. `technical-founder`, `freelance-illustrator`). Wait for confirmation before writing — this file gets read by `/roadmap` to make prioritization calls, so it's worth getting right rather than fast.

---

## Step 5 — Write the persona file

File: `docs/icp/{persona-slug}-icp.md`

```markdown
# ICP — {Persona Name}

**Last updated:** YYYY-MM-DD
**Source:** [Interview | Product brief {NNN}-{product-name}, refined by interview]

## Who They Are

Specific role and context — enough detail to picture one real person.

## The Job They're Hiring This For

What they're trying to accomplish, and what triggers them to look for something like this.

## Today, Without This

What they currently do instead, and specifically why it falls short.

## What They Value

What makes them choose and keep choosing this over the alternative.

## What Makes Them Leave

Churn signals and dealbreakers — friction that loses them.

## Who This Is NOT For

Explicit anti-persona for this profile. At least one entry. Used by `/roadmap` to reject backlog ideas that only serve an excluded segment.
```

If refreshing an existing file, preserve sections the user confirmed are still accurate — only rewrite what changed. Note what changed and why at the bottom: `**Revision:** {date} — {what changed}`. Git history carries every prior version; this line is just a quick note for a human skimming the file, not a changelog you need to maintain exhaustively.

---

## Step 6 — Report

Report:
- Which persona file was written, and whether it was a first draft or a refresh (note what changed if a refresh)
- Whether a product brief was found and used as a starting point
- How many persona files now exist under `docs/icp/` in total, and whether the interview surfaced a second persona worth a follow-up run
