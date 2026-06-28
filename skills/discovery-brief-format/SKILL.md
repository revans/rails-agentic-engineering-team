---
name: discovery-brief-format
description: Handoff contract between the discovery agent and the architect agent. Defines what a complete brief contains, what level of detail prevents follow-up questions, and what the architect can derive from the codebase vs. what must come from the user.
---

# Discovery Brief Format — Handoff Contract

## The Purpose of a Brief

The brief carries everything that can only come from the user. The architect derives codebase-side decisions independently — model names, controller patterns, route grammar, concern opportunities. The brief's job is to make that codebase audit purposeful by giving the architect a clear target before they open a single file.

A complete brief means the architect can finish the codebase audit and write the spec without re-interviewing the user. Any question the architect has to bring back to the user is a gap in the brief.

---

## What Must Come From the User (Brief Responsibility)

These cannot be derived from the codebase:

- **User intent** — the WHY and the WHAT from the user's perspective
- **Authorization constraints** — who is allowed to see or act on what; role and ownership rules
- **AI generation intent** — whether the feature calls the LLM, what it generates, and what the UX contract is for triggering and displaying it
- **Scope decisions** — what is explicitly in and explicitly out
- **Decisions made** — which direction was chosen when alternatives were considered, and why
- **Directions rejected** — what was proposed and set aside, with reasons
- **Known edge cases** — the ones the user brought, before the architect finds more in the codebase
- **Key scenarios** — concrete before/after sketches that anchor acceptance criteria

---

## What the Architect Derives (Not Brief Responsibility)

These come from codebase audit:

- Model names, column names, index strategy
- Controller patterns and naming conventions
- Route grammar and existing URL structure
- Concern extraction opportunities
- Refactoring needs in existing code
- Pattern conflicts or naming inconsistencies
- Additional edge cases beyond what the user named

The brief should not speculate on these. "I think there's probably a Listing model involved" belongs in Open Questions, not as a domain model sketch.

---

## Section Completeness Checklist

A brief is complete when every section can be answered without a blank or a "TBD":

| Section | Complete when... |
|---|---|
| Problem Statement | Explains the human need, not the technical solution |
| Who Is This For | Names a specific role and context, not "users" |
| Data and Authorization Scope | Names what's read/written and any ownership constraints |
| AI Generation Operations | Explicitly Yes or No; if Yes, names what is generated, trigger mechanism, streaming vs. batch, and error handling |
| What They Can Do | At least 2 concrete outcome statements |
| Key Scenarios | At least 2 before/after sketches with enough detail to write acceptance criteria |
| Decisions Made | Either lists settled decisions with rationale, or states direction was clear from the start |
| Directions Rejected | Either lists rejected alternatives with reasons, or states none were raised |
| Known Edge Cases | May be empty if user named none — must say "None identified" not be blank |
| Explicit Out of Scope | Must have at least one entry — if nothing was excluded, the scope wasn't discussed enough |
| Open Questions | Categorized as suspicion vs. genuine unknown where possible |

---

## Common Brief Failures

**Too abstract:** "Users can manage their listings" — not useful. The architect needs to know: which users, which listings (scoped how?), what does manage mean (view, edit, push to marketplace?).

**Missing AI generation path:** A feature that calls the LLM is described only in terms of what the user sees before and after, with no mention of the generation trigger or streaming surface. The architect designs no loading/error UX; the engineer ships without progress indicators; the user stares at a frozen UI.

**Merged decisions and rejections:** Brainstorming notes that mix "we thought about X" with "we chose X" leave the architect unsure which direction was actually selected. Decisions Made and Directions Rejected are separate sections for this reason.

**Open Questions that are actually answered:** "Should this be paginated?" is not an open question if the user said "we need to handle thousands of records" — that's a Yes, write it as a constraint. Open Questions are for things genuinely unresolvable without codebase research.

**Key Scenarios too vague:** "The user can see their orders" is not a scenario. "When an ops analyst opens the Orders section, they see all orders for their assigned customers sorted by newest first, with status, marketplace chip, and order total visible without clicking in" is a scenario.

---

## For the Architect: Evaluating Brief Completeness

Before starting the codebase audit, evaluate the brief against this checklist. If any section is incomplete:

- **Missing AI Generation Operations section or left blank:** ask the user before proceeding — designing the AI surface without this is guesswork
- **Key Scenarios missing or too abstract:** the acceptance criteria you write will be vague; one targeted question to the user is cheaper than a spec revision
- **Explicit Out of Scope is empty:** the scope wasn't defined well enough; ask what adjacent things are NOT included
- **All other gaps:** document as an open question in the spec and proceed; these are usually resolvable via codebase audit
