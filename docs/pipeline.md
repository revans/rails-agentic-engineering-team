# Pipeline

A feature moves through ten stages in a fixed sequence. Each stage writes an artifact file. The next stage cannot start until that file exists.

## What It Is

Think of the pipeline like an assembly line. Each station has one job and one output. The discovery station writes a requirements brief. The architect station reads that brief and writes a technical spec. The design station reads the spec and writes a UI design. The engineer station builds the feature. Four review stations check the work in parallel — three check the code itself (quality, security, performance); the fourth checks the whole chain, whether the code still matches the plan and the plan still solves the original problem. If any reviewer flags a blocking issue, the feature goes back to engineering and the cycle repeats.

Nothing advances until the previous artifact exists. The orchestrator detects which artifacts are present and re-enters from the first missing stage automatically.

The discovery brief is the one artifact that lands directly on `main`/`master`. Everything after it — spec, design, code, review reports — happens in a dedicated git worktree on its own feature branch, so no other work in the main checkout gets disturbed while the pipeline runs. When the pipeline reaches a final verdict, the orchestrator pushes that branch and opens a pull request; it never merges one itself.

## How It Works

Here is how a feature moves from idea to an open pull request:

```mermaid
flowchart TD
    A[User describes feature] --> B[Discovery interview]
    B --> C[Brief written]
    C --> C2[Brief committed to main/master]
    C2 --> C3[Feature worktree created]
    C3 --> D[Architect reads codebase]
    D --> E[Spec written]
    E --> F[Design agent reads spec]
    F --> G[Design spec written]
    G --> H[Engineer implements]
    H --> I[Code review]
    H --> J[Security review]
    H --> K[Performance review]
    H --> N[Fidelity review]
    I --> L{All pass?}
    J --> L
    K --> L
    N --> L
    L -->|Yes| M[Summary written, TODO.md updated on main]
    M --> P[Branch pushed, pull request opened]
    L -->|No| H
```

All four review agents run in parallel. The engineer reruns only after all four complete.

## Artifact Naming

Every feature gets a number and a directory under `docs/briefs/`. All artifacts for that feature live in that directory, named by stage and round:

```
docs/briefs/001-feature-name/
  001.01-dis-feature-name.md   ← discovery brief
  001.02-arc-feature-name.md   ← architect spec
  001.03-des-feature-name.md   ← design spec
  001.04-eng-feature-name.md   ← engineer report, round 1
  001.05-cr-feature-name.md    ← code review, round 1
  001.06-sec-feature-name.md   ← security review, round 1
  001.07-perf-feature-name.md  ← performance review, round 1
  001.08-fid-feature-name.md   ← fidelity review, round 1
  001.09-eng-feature-name.md   ← engineer report, round 2
  ...
```

Sequence numbers increase monotonically. Prior-round files are never deleted. The full review history for a feature is always visible by listing the feature directory.

## Example

Start a new feature:

```
/feature Add a dashboard showing sync status for all customer listings
```

Claude assigns the next feature number, interviews you to produce a brief, then hands the brief to the architect. The architect reads your codebase before writing the spec. From there the pipeline continues automatically.

## Things to Know

- The discovery stage runs in the main conversation, not as a subagent. It needs to talk to you interactively.
- Resume any in-progress pipeline by feature number: `/feature resume 001`
- Skip discovery if you already have a brief: `/feature architect path/to/brief.md`
- If the same review category fails in two consecutive rounds, the orchestrator names it explicitly rather than silently re-routing.
- If a category fails three rounds in a row, the orchestrator escalates to you. Three rounds of the same problem is a signal the spec or the agent skill is wrong, not the engineer.
- After a pipeline completes, the engineer and architect each record what actually happened against their earlier expected outcomes. Those records feed the learning loop.
- Any agent can notice something that should exist but isn't part of the current feature. Rather than build it or let it evaporate, it names the idea in its own report, tagged `needs-discovery` or `tech-debt`; at pipeline completion the orchestrator sweeps every report and files new ones into the matching `TODO.md` section. See the `scope-capture` skill. `/roadmap` later reads both sections against every persona file under `docs/icp/` and the codebase to propose a build order.
- The feature branch and its worktree stay around after the pull request opens — they're still needed if review comments come back. Remove the worktree yourself (`git worktree remove ../{NNN}-{feature-name}`) once the PR is actually merged; the orchestrator won't do it automatically.
- `db/agent_log.sqlite3` is shared across every worktree — every agent launch is told to `export AGENT_LOG_DB` pointing back at the main checkout's copy, so decisions logged mid-feature don't end up scattered across per-worktree databases nobody reads.
