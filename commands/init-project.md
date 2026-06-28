---
name: Init Project
description: "Audits the project and fills in missing CLAUDE.md sections — skills, docs structure, conventions, TODO.md, abstraction decisions, non-negotiables. Generates from what actually exists, not generic boilerplate. Optionally runs /update-readme."
color: blue
---

# Init Project

This command gets a project's CLAUDE.md into shape. It reads the codebase first, then writes only what's missing — each section is generated from what's actually present, not copied from a template.

---

## Step 1 — Read what exists

Read these before touching anything:

- `CLAUDE.md` — what's already there (if anything); identify which sections are absent
- `.claude/skills/` — which skills are available in this project
- `.claude/agents/` — which agents are defined
- `Gemfile` — what the stack actually is; what's conspicuously absent (no Redis, no Devise, no RSpec)
- `app/models/` — a quick scan for naming patterns, namespaces, concerns
- `config/routes.rb` — route structure and URL grammar
- `gems/` — any local gems (scan for what's present and read their purpose)
- `docs/` — what doc directories exist

From this, build a picture of:
- What this application does and who it's for
- Which skills are loaded and what they cover
- What the stack constraints are (Solid Stack, Rails 8 auth, Minitest)
- What the docs structure is
- Whether a `TODO.md` exists at root

---

## Step 2 — Identify missing CLAUDE.md sections

Check for each of these sections by name. Only write sections that are absent or substantively empty:

1. **Project intro** — one paragraph describing what the app is, who uses it, and what it does
2. **Skills** — which `.claude/skills/` files engineers should read when working; links to their actual paths
3. **Coding Requirements** — the short non-negotiable list (TDD, branch per feature, framework constraints)
4. **docs/ Structure** — what lives where under `docs/`, and why
5. **TODO.md** — the deferred-decisions convention
6. **Abstraction Decisions** — the "stop and surface it" rule
7. **Non-Negotiables** — the visual grammar contract, AI generation surface rules, the never-use list (derive from Gemfile)

Do NOT rewrite sections that already exist and contain real content. Append missing sections only.

---

## Step 3 — Write missing sections

For each absent section, generate content from what you found in Step 1 — not from a generic template.

**Project intro:** write from CLAUDE.md (if partial), `Gemfile`, and `app/models/` scan. Name the primary user, the core function, and where AI fits in if the app uses an LLM.

**Skills:** list each file under `.claude/skills/` with its purpose. Format:
```
## Skills

When doing engineering work in this session, read:
- `.claude/skills/{skill}/SKILL.md` — {one-line purpose from skill frontmatter}
```

**Coding Requirements:** derive from Gemfile (what's absent = what's banned), from `CLAUDE.md` if partial, and from Rails version. Standard list for this stack:
```
* Always start new work in a new git branch
* TDD First Always
* Small git commits after a working feature
* No unnecessary gems — if Rails ships it, use it
* No Redis — Solid Stack only (Solid Queue, Solid Cache, Solid Cable)
* No Devise — Rails 8 `rails generate authentication` if auth needed
* No RSpec — Minitest with fixtures (no factory_bot)
* Only the 7 public controller actions — new controllers for new resource shapes
* When working with LLMs, review the AI library interfaces before writing any code
```
Add or remove based on what Gemfile confirms.

**docs/ Structure:** derive from what directories exist under `docs/`. Use this as the base pattern, adjusting for what's actually present:
```
## docs/ Structure

- `docs/briefs/` — all feature pipeline artifacts, organized as `{NNN}-{feature-name}/` subdirectories
- `docs/sessions/` — session archaeology from /closing; read with /opening to restore context
- `docs/retired/` — pre-pipeline documents; kept for reference, not active specifications
```

**TODO.md:** always write this section the same way:
```
## TODO.md

`TODO.md` at the project root has two sections:

**New Features to Discover** — feature ideas worth exploring that aren't ready for the full
discovery pipeline yet. Captured here so they aren't lost; each entry should name the idea
and the trigger that surfaced it.

**Deferred** — work deliberately set aside during active sessions with full context on why
it was deferred and what decision is needed. Read this before starting work that touches the
deferred area. Update it when deferring something — include the reason and the options
considered so the next session doesn't re-litigate it.
```

**Abstraction Decisions:** always write this section the same way:
```
## Abstraction Decisions

When there is an option to introduce a method, class, or abstraction that would give greater
control over how something functions — a registry, a dispatcher, a pipeline coordinator — stop
and surface it for discussion before implementing the simpler path. Do not silently choose the
minimal version. Name the abstraction, describe what control it buys, and ask whether it's
worth building now.

The pattern that triggers this: "we could just do X, or we could build Y which would let us
control Z." If Y has compounding value as the system grows, it belongs in a conversation, not
a default implementation choice.
```

**Non-Negotiables:** derive the list from what the app actually is. The visual grammar and AI generation rules apply if the app has AI features. The never-use list comes from Gemfile absences. Example:
```
## Non-Negotiables

- **Visual grammar:** Monospace = technical data you can act on (IDs, timestamps, counts). Sans-serif = context, instruction, prose. See the design-system skill for this project's classes.
- **AI generation surface:** any LLM call needs a loading/streaming state, error handling (timeout, provider error, rate limit), and a trigger visually distinct from a regular form submit.
- No Redis (Solid Stack only), no Devise, no RSpec, no service objects
- Do not invent design system classes — add to the project's CSS extension file first
```

---

## Step 3b — Create TODO.md if absent

If `TODO.md` does not exist at the project root, create it with the two-section structure and one example per section. The examples orient the LLM on what belongs in each section — they are illustrative, not real entries, and should be replaced as actual work surfaces.

```markdown
# {Project Name} — TODO

---

## New Features to Discover

Feature ideas worth exploring that aren't ready for the full discovery pipeline yet.
Each entry names the idea and what triggered it.

- [ ] **Example: Mobile-friendly document view**
  Surfaced during a user session — the editor is hard to read on small screens. Not scoped
  yet. Worth a discovery interview before anything is built.

---

## Deferred

Work deliberately set aside mid-session. Each entry includes why it was deferred and what
decision is needed before picking it up.

- [ ] **Example: Background generation job vs. inline streaming**
  Deferred during the generation feature build. Current implementation streams inline via
  Turbo; for very long documents this may need to move to a background job with polling.
  Decision needed: at what document length does streaming become a problem? Measure first.
```

---

## Step 4 — Write CLAUDE.md

Append the missing sections to the existing CLAUDE.md. Preserve everything that was already there — only add, don't rewrite.

If CLAUDE.md didn't exist: write the full file with all sections populated.

---

## Step 5 — Offer update-readme

After CLAUDE.md is complete, ask:

> "CLAUDE.md is up to date. Want me to also run `/update-readme` to generate or refresh the domain documentation and README?"

Wait for a yes before running it. Do not run it automatically.

---

## Step 6 — Report

Report what was added:
- Which sections were missing and are now written
- Which sections already existed and were left untouched
- Whether `/update-readme` was run
