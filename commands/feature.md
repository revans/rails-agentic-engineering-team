---
name: Feature
description: "Entry point for feature work. Routes to the orchestrator at the right pipeline stage. Usage: /feature | /feature <description> | /feature architect <path-or-content> | /feature resume F-00X"
color: blue
---

# Feature Pipeline Entry

**Arguments:** [ARGUMENT]

---

## Step 1 — Determine mode

Parse the first word of the arguments (case-insensitive):

| First word | Mode | Meaning |
|---|---|---|
| `architect` | Brief-first | User has a brief; skip discovery, go straight to architect |
| `resume` | Resume | Continue an in-progress pipeline from the first missing artifact |
| *(empty or anything else)* | Full pipeline | Start from Stage 1 — Discovery |

---

## Step 2 — Prepare inputs

**Brief-first mode (`architect`):**

The text after "architect" is either:
- A file path — read the file and treat its contents as the brief
- Inline content / description — treat the raw text as the brief body itself

If it is a readable file path, read it now. Otherwise treat the argument text as the brief content directly.

If the content is not already a file in `docs/briefs/`, write it there now using a kebab-case filename derived from the content (e.g. `docs/briefs/my-feature-brief.md`). This is the brief path you will pass to the orchestrator.

**Resume mode (`resume`):**

Extract the feature ID (e.g. `F-001`). No further preparation needed.

**Full pipeline mode:**

No preparation needed. Pass any description the user included as initial context.

---

## Step 3 — Hand off to the orchestrator

Do NOT spawn the orchestrator as a subagent. The orchestrator needs to interact with the user across multiple turns — it must run in this conversation.

Read `.claude/agents/orchestrator.md` now. Adopt the orchestrator's identity and instructions for the remainder of this conversation.

Once you have adopted the orchestrator identity, begin with the appropriate entry point based on mode:

**Full pipeline (no args or bare description):**
Enter Pipeline Mode. This is a new feature — assign a feature number and begin Stage 1 — Discovery.

**Brief-first (`architect` mode):**
Enter Pipeline Mode. Discovery is complete — the brief is at `{path to file in docs/briefs/}`. Assign a feature number and begin Stage 2 — Architecture.

**Resume (`resume` mode):**
Enter Pipeline Mode. Resume pipeline for `{F-00X}` — check which artifacts exist and resume from the first missing stage.

---

Do not make design or implementation decisions. Prepare inputs and route only.
