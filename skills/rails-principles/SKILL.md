---
name: rails-principles
description: Rails engineering principles — Rails-first design, DRY, SRP, concerns (3-method rule), REST, no service objects, business logic in models, dependency discipline. Shared by architect (designs to these), engineer (builds to these), and review agents (checks against these).
---

# Rails Engineering Principles

## Convention Is the Interface

Rails resolves behavior through naming: routes predict controllers, controllers predict models, models predict tables. Nothing is registered — the name IS the address. Build custom code the same way.

**Generic over specific when only the variant changes.** A job that takes `(provider:, operation:)` as parameters is better than N identical jobs differing only in which class they call. A new provider means adding a correctly-named class — not editing existing jobs, not adding to a dispatch table, not registering anywhere. The test: can a new variant be added by creating one correctly-named class with the right method signatures, without touching existing code? If yes, the interface is convention-based. If no, you have a list to maintain.

**Convention-based resolution.** When code resolves class names from strings — `"Provider::#{name.classify}::Extractor".constantize` — the naming convention IS the interface contract. Every class in that namespace must honor the same method signatures. An LLM reading existing examples in the namespace can infer exactly what a new class must look like. This is the same leverage Rails gets from its conventions: pattern recognition scales.

**Naming is resolution.** Every name in the codebase — class, method, variable, URL, route, column — is a signal that code and people use to navigate. A method named `generate_content` tells you what it does; a method named `run_pipeline` tells you nothing. A URL `/projects/1/documents` tells you the resource hierarchy; `/api/get_project_documents?id=1` requires reading to understand. Strong naming means the reader rarely needs to look at more than one file to understand what a piece of code does. This matters equally for humans debugging and for LLMs generating new code in the same patterns — both rely on pattern recognition, and both are slowed by inconsistency.

**When Rails doesn't cover it, design as if Rails built it.** A new abstraction earns its place only if it looks like Rails: a named concern with an `included` block, a scope lambda, a bang method for state transitions, a class method that returns a relation. A pattern that feels foreign to Rails — bare class methods, free-standing service objects, custom middleware for something Rails already handles — is a competing dialect. One dialect is learnable. Two dialects require every reader to hold two definitions simultaneously and pick the right one.

## Design for Addition, Not Modification

A well-designed system grows by adding new files in the right places — not by editing dispatch tables, conditional branches, or registration blocks. Rails itself works this way: new controllers and models are discovered by convention, not registered anywhere. Apply the same discipline to custom code.

**YAML drives variants; base class drives behavior.** When a feature has many variants that share the same mechanics but differ in configuration (paths, parameters, limits, rate rules), put the mechanics in a base class and the variation in YAML. The YAML loader hydrates typed value objects at startup; the base class consumes them without knowing which variant it's running. Adding a new variant is adding YAML — no new Ruby. This only works when the base class is complete enough to need no per-variant code. Design the base first; YAML-drive the variants second.

**Resolution chains over case statements.** Instead of `case type; when :amazon then AmazonHandler; when :ebay then EbayHandler`, try class names by convention and fall through to the base:
```ruby
def self.for(type, operation)
  ["Namespace::#{type.classify}::#{operation.classify}", "Namespace::#{type.classify}::Handler"]
    .each { |name| return name.constantize rescue NameError }
  self  # base class as fallback
end
```
Adding a type means creating one correctly-named file. The resolution logic never changes.

**`raise NotImplementedError` as interface declaration.** When a base class defines abstract methods with `raise NotImplementedError`, it is documenting its own contract. Subclasses know exactly what they must provide; everything else is inherited. An explicit `raise` fails loudly with a clear message; a missing method fails confusingly at call time. Define the contract at the base; override only what's specific.

**Value objects for data transport.** Use `Data.define` to create immutable, named value objects for data flowing through a pipeline. A `Data.define(:entity, :status, :requested_at, :response_ms)` object is self-documenting, prevents "what keys does this hash have?" uncertainty, and fails loudly when required fields are missing. Loose hashes are acceptable at system boundaries (params, API responses); inside the system, give data a type.

**Single public entry point per domain.** Each domain exposes one method that generates a session ID and dispatches. The caller doesn't know how many jobs fan out, which providers run, or how pagination works. The interface is stable as internals grow. The internal fan-out is a private concern.

Together these produce the minimum-code-to-add-a-variant outcome: the next provider, endpoint, or operation slots in by following the naming convention and implementing the declared interface. The system handles the rest.

## Rails-First

Before anything else: does Rails provide this natively? Rails first. Ruby stdlib second. Approved gems third. No outside-the-list dependencies without explicit justification.

## KISS — Simplest Thing That Works

Two implementations: choose the simpler one unless there is a concrete reason for the complex one. "We might need flexibility later" is not a concrete reason.

## DRY — But Not Premature

Don't extract abstractions before you have two or three concrete uses. Premature abstraction is harder to debug than duplicated code — it obscures what's actually happening. Three concrete uses is the extraction signal.

## YAGNI — With One Exception

Build for actual needs. Don't add fields, methods, or abstractions for hypothetical futures.

**The exception:** every controller action supports JSON via jbuilder by default. AI consumers are real and likely. The cost of retrofitting JSON exceeds the cost of building it inline. This is not a YAGNI violation — it's recognizing a changed probability threshold.

## Defer to the Signal

Choose the simpler design. Name — explicitly — the condition under which it degrades. That condition is not a future problem; it is a diagnostic that tells you exactly what to build next.

**The test:** before shipping the simpler version, can you name what "this design failing" looks like? If yes, you've deferred correctly. If you can't name the failure mode, you're not deferring — you're hoping.

Examples:
- Joins are fine. When every domain query joins 4+ tables, that's not a performance problem to patch — it's a signal that a materialized view or analytics layer is the right next thing.
- Inline transform is fine. When transform latency starts affecting extraction freshness, that's the signal to separate the jobs.

**The failure mode on the other side: deferral that becomes permanent.**

Deferral is a contract, not an escape hatch. Three ways the contract breaks:

- **The signal is vague.** "We'll optimize when it gets slow" is a feeling, not a signal. Feelings get overridden by sprint pressure. A measurable trigger — "when per-domain queries join 4+ tables" or "when p95 latency exceeds 200ms" — doesn't.
- **The signal moves.** You defined 5 joins as the threshold. You hit 5. It's not actually slow yet, so you move it to 7. This is avoidance dressed as deferral. When the signal fires, act — don't renegotiate.
- **Nobody is watching.** You named the signal but it lives in a decision doc nobody reads. If no one is monitoring for the condition, the deferral is fiction.

Never defer without the trigger. "We'll add it later" is hope. "We'll add a materialized view when per-domain queries join 4+ tables" is a contract.

## Naming Is the Most Important Thing

Every name is an opportunity for the code to explain itself. If a method's name doesn't tell you what it does, rename it. If you reach for a comment to explain code, ask whether better naming would make it unnecessary. Code that needs no explanatory comments because it explains itself is the goal.

## Class Naming — State, Not Process

Model names should describe what the data **is**, not what produced it or what acts on it.

Past participles name state: `GeneratedDraft`, `PublishedDocument`, `CompletedGeneration` — you know what you have before opening the file. Verb forms name logic: `Generator`, `DocumentPublisher`, `ContentNormalizer` — these hold methods, not records.

**The test:** can you explain what an instance of this class *is* without describing the process that created it? If yes, the name is state. If the explanation starts "this is what the system does when it..." — the name is process, and it belongs on a model method or concern, not a class.

Namespaces obey the same rule. A namespace with mixed state models and logic classes is ambiguous — both developers reading cold and LLMs generating code in that namespace must hold two meanings simultaneously. Keep state namespaces pure (models only) and process namespaces pure (logic only).

## Code Comments

One test before writing any comment: **would a plausible, correct-looking change break this if the comment weren't here?** Yes → write it. No → don't.

Write when the code cannot speak for itself:
- Runtime constraints invisible in the code: `# expires in 2 minutes — streaming must complete before the token does`
- "Why not the obvious thing": `# insert! not insert — guarantees uniqueness; a conflict means the session table is broken`
- Non-obvious coupling between distant parts: `# call normalize_params before render — rendering reads the normalized keys`
- Domain facts that cannot be inferred from the code: `# rate limit is API-key scoped — heavy generation by one document reduces the budget for all`

Never write:
- What a well-named method does — `def access_token` needs no `# Returns the access token`
- Section headers and visual dividers — `# ── Generation ──────────────`
- "ADDING A NEW X: do Y, Z" instructions — encode this as a descriptive `raise` at the failure point instead; comments drift, raised errors don't

## Single Responsibility

Every class has one reason to change. Every method does one thing. When a class has methods that change for different reasons, split it — often into a concern.

## Concerns — Two Distinct Uses, Both Valuable

**Shared behavior:** logic used across multiple models or controllers.

**Feature extraction — the 3-method rule:** when a single feature requires 3 or more methods on a model, extract them into a named concern even if no other model uses it. `Listing::Syncable` used only by `Listing` is still justified — it makes the feature's logic locatable, keeps the model readable, and makes changes to that feature easier to reason about without being buried in hundreds of lines.

Apply in both directions:
- **New code:** if a feature adds 3+ methods to a model, it is a concern from the start
- **Existing code:** if auditing code where 3+ methods serve a single unnamed feature in a large model, flag for extraction

## Business Logic in Models

Controllers translate HTTP into intentions. Models fulfill intentions.

When a controller saves an article and approves it, it calls `article.approve!` — one method that names the user intention. The model handles the persistence, callbacks, and side effects. The controller does not chain multiple model calls.

Use bang methods (`approve!`, `publish!`, `archive!`) for atomic state transitions — they either succeed completely or raise. No partial-success states for the controller to handle.

## Callbacks for Side Effects, Not Decisions

Callbacks fire for side effects of persistence. When saving triggers a notification — that's a callback. When deciding whether to save — that's validations or controller authorization, not a callback.

Callbacks must be:
- Targeted with `if:` conditions
- Scoped to feature concerns
- Using `after_commit` for anything that touches the outside world (jobs, external calls, emails)

Operations expected to take longer than ~100ms in a callback belong in a background job. The job calls back into the model. Business logic stays in the model layer.

## Controllers: Seven Public Actions Only

Index, show, new, create, edit, update, destroy. Custom state transitions live in nested singular resource controllers — `Listings::SyncsController#create` for syncing a listing, not a custom action on ListingsController. No public helper methods on controllers.

## REST Always — Association Traversal

`account.listings.find(id)` — not `Listing.find(id)`. Explicit about what's being accessed through what relationship. Fails loudly when relationships aren't right.

## Helpers Contain View Logic

Any conditional in a view is a code smell. Move it to a helper where it can be tested. Helpers are testable; views are not. Even simple conditionals belong in helpers.

## Partials for Reusability and Simplification

Both reasons are valid independently. A partial used once that reduces a 200-line view to a 20-line view calling named partials is as valuable as a partial used in three places.

## No Service Objects

Service objects fragment business logic away from the models that own the data. They produce file-jumping debugging experiences. Implement the logic as model methods organized into concerns.

## Testing Standard

Minitest with fixtures. No RSpec, no factory_bot.

Cover every branch:
- Happy paths — every valid input that should succeed
- Sad paths — every validation failure, authorization rejection, missing-record case
- Edge cases — nil inputs, empty collections, boundary values

If you can delete a conditional from the implementation and no test would catch it, the coverage is incomplete.

## Approved Dependencies

**Approved dependencies are project-specific.** Read the project's `CLAUDE.md` and `Gemfile` for the authoritative approved list.

**Standard Rails 8 baseline (typical defaults):**

Runtime: rails, propshaft, sqlite3, puma, importmap-rails, turbo-rails, stimulus-rails, jbuilder, solid_cache, solid_queue, solid_cable, bootsnap, kamal, thruster, image_processing

Development/test: debug, bundler-audit, brakeman, rubocop-rails-omakase, web-console, capybara, selenium-webdriver

**Typical "never use" for Rails 8 projects (check CLAUDE.md for project overrides):**
- No Redis — Solid Stack only (Solid Queue, Solid Cache, Solid Cable)
- No Devise — Rails 8 `rails generate authentication`
- No RSpec — Minitest with fixtures
- No Sidekiq/Resque/GoodJob — use Solid Queue
- No Carrierwave/Shrine — use Active Storage
- No service objects

## SQLite Search

If this project uses SQLite (the Rails 8 default), use SQLite native search instead of search gems:
- `LIKE` / `GLOB` — simple substring matching
- FTS5 virtual tables — full-text search with ranking (`CREATE VIRTUAL TABLE documents_fts USING fts5(...)`)
- `MATCH` operator — FTS5 query syntax

Search logic lives in model scopes. When a model has 3+ search-related methods, extract to a `Searchable` concern.

If this project uses a different database, consult its native search capabilities before reaching for an external gem.

## Anti-Patterns

- **No service objects** — use model methods and concerns
- **No JSON serializer libraries** — use jbuilder
- **No conditional logic in views** — use helpers
- **No background jobs over collections** — fan out one job per object; each job is atomic and individually retryable
