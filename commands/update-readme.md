---
name: Update README
description: "Audits the codebase and regenerates README.md (intro + setup + domain TOC) and all docs/readme/{domain}.md files to reflect current state."
color: green
---

# Update README

The README has three responsibilities:
1. **Introduction** — what this application is and what problem it solves, written for a developer reading the repo for the first time
2. **Setup** — how to get the app running locally
3. **Domain index** — a table of contents linking to `docs/readme/{domain}.md` for every major domain in the codebase

The deep technical content (models, associations, APIs, data flows) lives in the domain documents, not the README itself. The README stays short; the domain docs stay accurate.

---

## Step 1 — Audit the codebase

Read these to understand the current state before writing anything:

- `CLAUDE.md` — what this application is, who uses it, what it does
- `app/models/` (recursive) — all models, namespaces, and their associations
- `app/jobs/` (recursive) — background jobs and processing pipelines
- `config/routes.rb` — the URL surface
- `db/schema.rb` — actual table reality (authoritative over model files on column details)
- `Gemfile` — stack and dependencies
- `docs/readme/` — what domain documents already exist (read each one; note what's stale or missing)

From this audit, produce:
- A list of distinct domains in the codebase (derive from model namespaces and route structure)
- The actual setup steps needed to run the app (infer from Gemfile, database config, job backend — do not invent steps)
- What's stale in any existing `docs/readme/` files

---

## Step 2 — Write or update domain documents

For each domain identified, write or update `docs/readme/{domain}.md`. Use the domain's actual namespace as the slug (e.g. `identity.md`, `projects.md`, `listings.md`, `generation.md`).

Each domain document covers:

### Document structure

```markdown
# {Domain Name}

One paragraph. What this domain is responsible for and why it exists. No jargon without definition.

## Models

For each model in this domain:
- **`Fully::Qualified::ClassName`** — one-line purpose
- Key associations (belongs_to, has_many) as a flat list
- Notable validations or constraints worth knowing
- Scopes that do non-obvious things

Use actual Rails class names throughout. If the model has a `table_name` override, note it.

## Key APIs

Ruby examples using actual method signatures verified against the source. Only include methods worth calling from outside the model — business logic, named scopes, state transitions. Skip trivial CRUD.

## Data Flow

If this domain has a meaningful write path (generation pipeline, import, sync, processing), describe it as a step-by-step flow. Otherwise omit.

## What's Built

A concise table: what exists and works today.

## What's Next

What's clearly next based on half-assembled infrastructure (columns with no UI, jobs with no downstream consumer, models with no controller). Do not invent things — only surface what the code implies.
```

Rules:
- **Model class names must be exact** — read the `class` declaration, not the README
- **Method signatures must be verified** — read the method definition before documenting it
- **Do not document what doesn't exist** — if the model exists but has no meaningful API, say so in one line
- **Omit Rails boilerplate** — `validates :name, presence: true` is not worth documenting
- Only write `docs/readme/{domain}.md` — do not write anywhere else

---

## Step 3 — Write or update `docs/readme/technical.md`

This document explains the significant technical choices in the codebase and why they were made. It is not a list of tools — it's a record of reasoning. A developer reading it should understand not just what this application uses, but what problems each choice solves and what it rules out.

To write it, read:
- `Gemfile` — what's included and what's conspicuously absent
- `db/schema.rb` — column types, indexes, any FTS5 virtual tables
- `app/models/` — structural choices (concerns, abstract base classes, naming conventions)
- `app/jobs/` — how background processing is organized
- Any local gems under `gems/` — understand their interfaces before documenting them

Extract every decision that has a non-obvious reason — something a developer might look at and ask "why did they do it this way?" Then explain the reason.

### Document structure

```markdown
# Technical Decisions

One paragraph. What kind of document this is and how to use it.

## {Decision Area}

**What:** one sentence describing the choice.  
**Why:** the reasoning — what problem this solves, what it rules out, what tradeoff was accepted.  
**Where:** the specific files or patterns where this shows up in the code.

...repeat for each decision...
```

Decision areas to cover (derive from what you find in the code — do not invent):

- **Job backend** — what runs background jobs and why (Solid Queue, Sidekiq, etc.)
- **Authentication approach** — what handles auth and what was ruled out
- **Testing stack** — framework and fixture strategy
- **No service objects** — where business logic lives instead and why
- **AI/LLM integration** (if applicable) — how the app connects to an LLM; what abstraction it uses
- **Database search** (if applicable) — native search vs. external gem; how it's implemented
- **Streaming** (if applicable) — how real-time updates reach the browser
- **CSS framework** — what framework is in use (Tailwind, custom, local gem, etc.); why; what the project's CSS extension file adds
- **JSON output strategy** — jbuilder, serializers, or other; why

Only document choices that exist in the code. If a gem is listed but not yet used substantively, note that it's positioned for future use rather than inventing a rationale.

---

## Step 4 — Rewrite README.md

Write a short README with exactly three sections.

### Section 1: Introduction

Two to four paragraphs:
- What this application is and what it does — written for a developer who has never seen the repo
- Who uses it and what they need from it
- How any AI or integration features fit in (if applicable)
- Current state: what's live, what's being built

Do not describe models or APIs here. That's what the domain docs are for.

### Section 2: Getting Started

How to get the app running locally. Infer from:
- `Gemfile` — Ruby version, key dependencies
- `config/database.yml` (if it exists) — database setup
- Standard Rails setup steps (bundle, db:create, db:schema:load, server)
- Any local gem setup needed (e.g., gems under `gems/`)

Format as a numbered list of shell commands. Do not include steps that don't apply.

### Section 3: Domains

A table linking to every `docs/readme/{domain}.md` plus `docs/readme/technical.md`:

```markdown
## Domains

| Domain | What it covers |
|---|---|
| [Identity](docs/readme/identity.md) | Users, sessions, authentication |
| [Domain Name](docs/readme/domain.md) | One-line description |
| ... | ... |
| [Technical Decisions](docs/readme/technical.md) | Why the stack and key patterns were chosen |
```

One row per domain. The "What it covers" column is one line. `technical.md` always appears as the last row.

---

## Step 5 — Report

After all files are written, report:
- Which domain documents were created vs. updated
- Whether `technical.md` was created or updated, and which decisions were added or revised
- One sentence on what changed in README.md itself
