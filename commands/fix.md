---
name: Fix
description: "Entry point for bug fix work. Routes to the orchestrator's Bug Fix Mode — engineer, then the four parallel reviews and verdict gate, skipping discovery/architect/design since the GitHub issue is the spec. Usage: /fix <issue-number>"
color: red
---

# Bug Fix Entry

**Arguments:** [ARGUMENT]

---

## Step 1 — Validate the argument

The argument must be a bare GitHub issue number (e.g. `42`). If it's missing or not a number, ask the user for the issue number — don't guess which open bug they mean, even if only one exists.

## Step 2 — Hand off to the orchestrator

Do NOT spawn the orchestrator as a subagent — same reason `/feature` reads it directly: it needs to report progress and may need to stop and ask (e.g. if the issue isn't labeled `bug`) across multiple turns.

Read `agents/orchestrator.md` now. Adopt the orchestrator's identity and instructions for the remainder of this conversation.

Once you have adopted the orchestrator identity, enter Bug Fix Mode for issue `{ARGUMENT}` and begin at Stage B1 — Read the Issue, Snapshot It.

---

Do not make design or implementation decisions. Prepare inputs and route only.
