---
name: architect-spec-format
description: The 12-section feature specification format — used by the architect to write feature specs and by the orchestrator to validate spec completeness before handing to the engineer.
---

# Feature Specification Format

## File Location

`docs/features/F-00X-feature-name.md`

Feature number assigned by scanning `docs/features/` for the highest existing F-00X and incrementing. If empty, start at F-001. Filename is kebab-case and descriptive.

## The 12 Sections

A spec is not complete — and must not be handed to the engineer — if any section other than "Open Questions" is empty or vague, or if "Open Questions" is non-empty.

---

### 1. Goal

One paragraph. What problem does this solve and for whom. Written for a developer reading cold — no assumed context. Not a feature description; a problem statement with audience.

### 2. Background

Context the engineer needs: which existing models, controllers, and routes are involved. How this feature fits into the current system. Reference existing code by its actual Rails class names. Describe current state so the engineer understands what they are extending, not just what they are building.

### 3. User Stories

```
- As a [role], I can [action], so that [value].
```

Every acceptance criterion maps to at least one user story. The role must be specific — "ops analyst reviewing sync failures" not "user."

### 4. Acceptance Criteria

Binary, testable, observable. One criterion per distinct behavior. A failing test maps to each one. These are the engineer's test-writing guide.

```
- [ ] Criterion one — specific, observable, pass/fail
- [ ] Criterion two
```

If a criterion requires judgment to evaluate, rewrite it until it doesn't.

### 5. Scope

**In Scope** — explicit list of what is being built.

**Out of Scope** — explicit list of what was discussed and excluded. If something adjacent was considered and rejected, name it. Prevents the engineer from building it and the user from expecting it.

### 6. Domain Model

**Existing models:** referred to by their Rails class name. Describe how this feature extends them — what new behavior or data they gain.

**New models:** described by domain purpose and relationships only. No column names, types, or index strategy — those are engineering decisions. Example: "A record linking each `Document` to a generation run, belonging to `Document`, associated with a specific message thread."

**Concern extraction:** when this feature adds 3 or more methods to a model, name the concern here. Example: "AI generation behavior on `Document` — extract to `Document::Generatable` concern." The engineer determines the implementation; the architect establishes the boundary.

### 7. Behavioral Constraints

Non-negotiable constraints the implementation must satisfy. The engineer chooses HOW; these constrain WHAT the result must be.

- **Performance:** (e.g., must not block request thread for operations expected to exceed 100ms)
- **Data integrity:** (e.g., must be idempotent — triggering twice produces the same state)
- **Security / scoping:** (e.g., always scoped to the current user's assigned customers via association traversal)
- **UX contract:** (e.g., AI generation trigger — must show in-progress state during streaming, handle error states, not block the UI)
- **Visual grammar:** (e.g., technical data values rendered using the project's monospace class — see the design-system skill)

### 8. Routes / Resource Shape

REST intent only. No controller class names. Every URL must pass the human-readability test — a developer reading it should understand the resource without opening the code.

Reference existing routes to show how new routes fit the URL grammar.

```
GET  /projects/:id/documents              — list all documents for a project
POST /projects/:id/documents/:did/runs   — initiate an AI generation run
```

### 9. JSON API Surface

Describe response shapes semantically. Not field-by-field — describe what the consumer receives and why.

Example: "Returns the listing with its current sync status across all configured marketplaces and the timestamp of the last successful sync for each."

If an action is HTML-only for a concrete documented reason, state it explicitly.

### 10. Refactoring Notes

Existing code the engineer must clean up alongside this feature to maintain pattern consistency. Not optional — not future tech debt.

The architect identifies: models with 3+ methods serving a single unnamed feature that this work extends; controller patterns inconsistent with what this feature would follow; naming inconsistencies this new feature would make worse.

If none: "None identified."

### 11. Design Decisions

The architect's reasoning — transparent and auditable by the engineer and by future architects:

- Why URLs were shaped this way (with reference to existing route patterns)
- Why names were chosen (with reference to existing naming conventions)
- Any new pattern introduced — named explicitly and justified
- Dependency decisions — Rails-first rationale or approved list selection with justification
- Concern extraction rationale — why the boundary was drawn where it was
- Any choice a future architect or engineer might question

### 12. Open Questions

**Must be empty when this spec is handed to engineering.** If any remain, the spec is not finished.

Document here during drafting; resolve before delivery. Questions that need codebase research are resolved by the architect's audit. Questions that need user input are resolved in conversation before the summary-and-confirm step.

---

## Completeness Check

Before writing the file, verify:

- [ ] Goal is a problem statement with audience — not a feature list
- [ ] Every acceptance criterion is binary (pass/fail, no judgment required)
- [ ] Scope explicitly names what is OUT of scope
- [ ] No column names or types in Domain Model (those are engineering decisions)
- [ ] Every write-path interaction is named in Behavioral Constraints with the UX contract
- [ ] Every URL passes the human-readability test
- [ ] Refactoring Notes reflects actual codebase audit — not skipped
- [ ] Open Questions is empty
