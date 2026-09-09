---
name: Init Project
description: "Audits the project, surfaces its actual code patterns for the user to confirm as keep-or-stop, and fills in missing AGENTS.md sections — skills, docs structure, conventions, TODO.md, abstraction decisions, non-negotiables, patterns. Generates from what actually exists, not generic boilerplate. Writes AGENTS.md and symlinks CLAUDE.md to it. Optionally runs /update-readme."
color: blue
---

# Init Project

This command gets a project's `AGENTS.md` into shape. `AGENTS.md` is the canonical file; `CLAUDE.md` is kept as a symlink to it, so both names resolve to the same content. It reads the codebase first, surfaces the patterns it finds so you can decide which ones are conventions worth enforcing and which are cruft worth stopping, then writes only what's missing — each section is generated from what's actually present, not copied from a template.

---

## Step 1 — Read what exists

Read these before touching anything:

- `AGENTS.md` — what's already there (if anything); identify which sections are absent. If absent, check `CLAUDE.md`: if it's a real file (not a symlink), treat its content as the existing document — it will be migrated in Step 5. If `CLAUDE.md` is already a symlink, follow it to find the canonical content.
- `.claude/skills/` — which skills are available in this project
- `.claude/agents/` — which agents are defined
- `Gemfile` — what the stack actually is; what's conspicuously absent (no Redis, no Devise, no RSpec)
- `app/models/` — naming patterns, namespaces, concerns, validation style, callback usage
- `app/controllers/` — action shape (does every controller stick to the 7 RESTful actions, or do custom actions recur?), before_action patterns, authorization style
- `app/views/` — partial usage, naming, layout conventions
- `config/routes.rb` — route structure and URL grammar
- `gems/` — any local gems (scan for what's present and read their purpose)
- `docs/` — what doc directories exist

From this, build a picture of:
- What this application does and who it's for
- Which skills are loaded and what they cover
- What the stack constraints are (Solid Stack, Rails 8 auth, Minitest)
- What the docs structure is
- Whether a `TODO.md` exists at root
- Whether there is any application code at all (a fresh `rails new` with empty `app/models/`, `app/controllers/`, and `app/views/` has none — skip Step 2 in that case, there's nothing to audit yet)

---

## Step 2 — Audit patterns with the user

Skip this step entirely if Step 1 found no application code to look at.

Otherwise, look across `app/models/`, `app/controllers/`, `app/views/`, and any local `gems/` for things that repeat — a naming scheme, a way of scoping queries, a consistent use (or consistent avoidance) of concerns, a particular authorization pattern, a view-partial convention. Separate what you find into two piles:

- **Consistent patterns** — the same shape shows up 3+ times with no exceptions. These are candidates for standing conventions.
- **Inconsistent or dated patterns** — the same problem solved two or three different ways across the codebase, or a pattern that looks like it predates a later refactor and was never cleaned up (e.g. two callback styles, a naming scheme abandoned halfway through).

Present both piles to the user in a short list, one line per pattern, and ask which patterns should continue as an enforced convention and which should be marked as something to stop doing (and, if relevant, migrate away from). Do not decide this yourself — the user knows which pattern was the deliberate choice and which was an accident that stuck around. Ask this as one focused question with the concrete list attached, not a long back-and-forth.

Record the answers — they become the **Patterns** section in Step 3, and any "stop doing this" answers also feed the **Non-Negotiables** never-use list.

---

## Step 3 — Identify missing AGENTS.md sections

Check for each of these sections by name. Only write sections that are absent or substantively empty:

1. **Project intro** — one paragraph describing what the app is, who uses it, and what it does
2. **Skills** — which `.claude/skills/` files engineers should read when working; links to their actual paths
3. **Coding Requirements** — the short non-negotiable list (TDD, branch per feature, framework constraints)
4. **docs/ Structure** — what lives where under `docs/`, and why
5. **TODO.md** — the deferred-decisions convention
6. **Abstraction Decisions** — the "stop and surface it" rule
7. **Non-Negotiables** — the visual grammar contract, AI generation surface rules, the never-use list (derive from Gemfile)
8. **Patterns** — the keep/stop decisions confirmed with the user in Step 2 (omit this section entirely if Step 2 was skipped)

Do NOT rewrite sections that already exist and contain real content. Append missing sections only.

---

## Step 4 — Write missing sections

For each absent section, generate content from what you found in Step 1 — not from a generic template.

**Project intro:** write from AGENTS.md (if partial), `Gemfile`, and `app/models/` scan. Name the primary user, the core function, and where AI fits in if the app uses an LLM.

**Skills:** list each file under `.claude/skills/` with its purpose. Format:
```
## Skills

When doing engineering work in this session, read:
- `.claude/skills/{skill}/SKILL.md` — {one-line purpose from skill frontmatter}
```

**Coding Requirements:** derive from Gemfile (what's absent = what's banned), from `AGENTS.md` if partial, and from Rails version. Standard list for this stack:
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

**Patterns:** write only from the answers gathered in Step 2 — never invent this section from the code scan alone, the user's keep/stop call is the content. Format:
```
## Patterns

Conventions confirmed with the user during /init-project. Read this before introducing a new
model, controller action, or view partial — check whether it already has a settled shape.

**Continue:**
- {pattern} — {where it shows up / what it looks like}

**Stop:**
- {pattern} — {why it's inconsistent or dated}{migration note if one was given}
```
If every pattern found was confirmed to continue (no "stop" answers), omit the **Stop** subsection rather than leaving it empty.

---

## Step 4b — Create TODO.md if absent

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

## Step 5 — Write AGENTS.md, symlink CLAUDE.md

`AGENTS.md` is the file that gets written. `CLAUDE.md` is never written to directly — it stays a symlink pointing at `AGENTS.md`, so both names read the same content.

Handle the file state found in Step 1:

- **Neither `AGENTS.md` nor `CLAUDE.md` exists:** write the full `AGENTS.md` with all sections populated, then create the symlink: `ln -s AGENTS.md CLAUDE.md`.
- **`AGENTS.md` doesn't exist, but `CLAUDE.md` does as a real file:** this is a project that hasn't migrated yet. Move `CLAUDE.md`'s content into a new `AGENTS.md` verbatim (`git mv CLAUDE.md AGENTS.md` if the project is a git repo, otherwise copy then remove), append the missing sections to it, then create the symlink: `ln -s AGENTS.md CLAUDE.md`.
- **`AGENTS.md` exists, `CLAUDE.md` is already a symlink to it:** append the missing sections to `AGENTS.md`. Nothing else to do.
- **`AGENTS.md` exists, but `CLAUDE.md` is a real file with different content:** don't silently pick one. Flag this to the user and ask which content should win before writing anything — this shouldn't happen from normal use of this command, so it's a sign something wrote to `CLAUDE.md` directly after the migration.

In every case, preserve everything that was already in the canonical file — only add missing sections, don't rewrite existing ones.

---

## Step 6 — Offer update-readme

After AGENTS.md is complete, ask:

> "AGENTS.md is up to date. Want me to also run `/update-readme` to generate or refresh the domain documentation and README?"

Wait for a yes before running it. Do not run it automatically.

---

## Step 7 — Report

Report what was added:
- Which sections were missing and are now written (call out the Patterns section by name if it was written, and how many "continue" vs "stop" decisions it captured)
- Which sections already existed and were left untouched
- Whether `CLAUDE.md` was newly created as a symlink, migrated from an existing real file, or already correct
- Whether `/update-readme` was run
