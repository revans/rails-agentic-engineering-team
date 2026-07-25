---
project: rails-agentic-engineering-team
date: 2026-07-23
time: 12:04
working_directory: /home/rre/Work/mrgrampz-marketplace/rails-agentic-engineering-team
previous_session: 2026-07-23-1140-agentic-team-refactor.md
---

# Session: Discovery Team Extraction

## Summary

This session established that the discovery agent should be extracted from the rails engineering team and built as a standalone discovery team scoped to "software applications" — not Rails-specific, not web-only. The core insight is that the discovery brief is engineering-agnostic and should feed any downstream team (Rails, mobile, Django), while `/idea` does something categorically different: it explores whether something is worth building. Nothing was built; this was a design decision and a sharp boundary definition. Next session picks up by designing the standalone discovery team itself.

## What We Did

- Identified that the rails engineering team's discovery agent is scoped wrong — its identity is tied to a Rails context but its actual job (user flows, acceptance criteria, key scenarios) is language and framework agnostic.
- Established the boundary between `/idea` and a discovery team by examining `/idea`'s actual output format: raw capture + open-ended brainstorm → strategic takeaways. No user flows, no acceptance criteria, no edge cases.
- Compared that to what the discovery brief produces: key scenarios, acceptance criteria, edge cases, concrete behavioral spec. Different altitude, different job.
- Decided the discovery team scope: **software applications** (web, mobile, desktop) — not Rails-specific, not web-only.
- Decided the web/mobile/desktop distinction belongs in **skills** loaded by the architect, not in separate discovery teams.
- Decided the rails engineering team's first stage becomes "read the discovery brief" — discovery is an external input, not an internal pipeline stage.

## Why We Did It This Way

**Software applications scope, not web-only.** The discovery questions that shape a good brief are universal: who is the user, what problem do they have, what does a completed interaction look like, what are the edge cases. Web vs mobile vs desktop doesn't change those questions — it changes the constraint vocabulary downstream (sessions vs tokens vs local state, URLs vs gestures vs keyboard shortcuts). That constraint vocabulary belongs in an architect skill, not in a different discovery team. Scoping discovery to web-only would create artificial boundaries that don't map to where the real differences live.

**Skills carry the web/mobile/desktop distinction, not separate teams.** One discovery team with different skills loaded is leaner than three parallel teams asking nearly identical questions. The discovery conversation is fundamentally the same; only the technical framing differs slightly.

**Discovery extracted from the engineering team entirely.** The discovery brief is already the handoff artifact between discovery and architect in the current rails team. That artifact's format doesn't change when discovery moves out — it just has a different producer. The engineering team receives it as an input rather than generating it internally. This also makes the engineering team reusable: any discovery team (web, mobile, internal tool) can produce a brief the rails engineering team can consume.

**The `/idea` → discovery team boundary is clean.** `/idea` answers "is this worth exploring?" — strategic, validation-oriented, founder-facing. The discovery team answers "what specifically should the engineering team build?" — requirements, behavioral spec, acceptance criteria. No overlap. `/idea` is pre-decision; discovery is post-decision. The handoff is: idea marked "worth building" → discovery team → discovery brief → engineering team.

## Roads Not Taken

**Scoping the discovery team to web apps only.** Robert's initial framing suggested web-specific discovery. Rejected because the discovery questions that produce a useful brief are the same for web, mobile, and desktop. The differences are technical constraints that appear in the architecture phase, not the discovery phase. **Do not create a web-only discovery team because the discovery conversation is medium-agnostic — unless discovery needs to ask "should this be native or web?" in which case a pre-architecture framing step might belong in discovery rather than the architect.**

**Keeping discovery inside the engineering team.** The existing structure has discovery as Stage 1 of the rails pipeline. Rejected because: (1) the discovery brief is already engineering-agnostic in format, (2) pulling it out makes the engineering team reusable across any project that can produce a brief, (3) in the rayspec architecture, discovery should be orchestratable independently of engineering. **Do not keep discovery inside the engineering team because it couples a language-agnostic process to a Rails-specific team, preventing reuse and parallel orchestration.**

**Splitting discovery into three teams (web, mobile, desktop).** If the domain differences were large enough, three specialist discovery teams might make sense. Rejected because the questions are identical; only the vocabulary differs slightly. Three teams would duplicate 90% of the work. **Do not create separate discovery teams per platform because skills handle the vocabulary difference more efficiently than team separation — unless platform differences grow large enough that the brainstorm conversations diverge fundamentally (e.g., hardware-specific products like embedded systems).**

**Making `/idea` do discovery.** `/idea` already does open-ended brainstorming and could theoretically be extended with user flow and acceptance criteria sections. Rejected because `/idea` is pre-commitment (exploring whether something is worth pursuing) while discovery is post-commitment (defining what to build). Mixing the two would make `/idea` sessions unwieldy and would conflate validation thinking with requirements thinking. **Do not extend `/idea` to produce discovery artifacts because the two tools serve different mental modes — validation vs specification — and conflating them produces worse output from both.**

## Key Discoveries

**Q: Does `/idea` produce anything that overlaps with a discovery brief?**
A: No. `/idea` produces raw capture, open-ended brainstorm Q&A, and strategic takeaways. It explicitly does not produce user flows, acceptance criteria, or edge cases. The discovery brief contains all three. The gap between them is real, clean, and currently unfilled — there is no artifact that bridges `/idea`'s "worth building" verdict to the engineering team's "build this" input.

**Q: Where does the web/mobile/desktop distinction actually live in the pipeline?**
A: In the architect's constraint vocabulary, not in the discovery conversation. Discovery asks what the user needs; the architect asks how to build it given the platform. The discovery brief is the same document regardless of target platform — the architect then loads a platform-specific skill to translate that brief into an appropriate technical architecture.

**Q: What does the engineering team's Stage 1 become when discovery is extracted?**
A: "Read the discovery brief." The orchestrator's first act in a feature pipeline becomes locating and reading `docs/briefs/{NNN}-{feature-name}/discovery.md` (or equivalent) rather than running discovery in-session. The brief is a pre-condition for the pipeline, not a pipeline output.

**Q: Is the `/idea` → discovery team → engineering team chain the complete picture?**
A: For the software product pipeline, yes. The chain is: `/idea` (validation) → discovery team (specification) → engineering team (implementation) → QA team (verification). The design team sits between discovery and engineering: discovery brief → design team (mockups) → engineering team (implementation from mockups). The synthesis artifact from the engineering team then closes the loop back to the QA team.

## Open Questions & Next Steps

**Design the standalone discovery team.** Architecture not started. Key questions to answer in the next session:
- What agents does it contain? (A discovery orchestrator + specialist agents, or just a single discovery agent?)
- What is the orchestrator's identity and entry point? (`/discover <feature-name>`?)
- Does it run as a single long session or stage-by-stage like the engineering team?
- What is the exact format of the discovery brief it produces? (The engineering team currently reads a brief produced by its own discovery agent — does the format change when a separate team produces it?)

**Update the rails engineering team's orchestrator.** When the discovery team is built, Stage 1 of the engineering pipeline changes from "run discovery" to "read discovery brief." The orchestrator.md needs updating to reflect that. Not done yet — waiting until the discovery team design is finalized so the brief format is locked.

**Decide the brief handoff location.** Currently: `docs/briefs/{NNN}-{feature-name}/`. If the discovery team is standalone and external to the rails team, does it still write into the rails project's `docs/briefs/` directory? Or does it write to a shared location that both teams can read? The answer likely depends on whether rayspec coordinates file paths centrally or each team manages its own directory.

**The gap between `/idea` and discovery team.** There is currently nothing that moves an idea from `~/.dna/ideas/<slug>/idea.md` to a discovery team kickoff. Some kind of dispatch or routing step is needed — either a manual step (Robert reads the idea and kicks off `/discover`) or an automated handoff. Not designed yet.

## Files Changed

No files were changed this session. This was a design and decision session only.

---
*Note: This document was written from conversation context. No code was written; all content reflects the design conversation accurately.*
