# Changelog

Notable changes to this project, newest first. Each entry corresponds to a bump in `VERSION`. Version bumps ride along with the commit that makes the structural change rather than a fixed release cadence, so numbering isn't strictly sequential (there is no 1.2.0 or 1.4.0) — see `git log -p -- VERSION` for the exact commit behind any entry below.

Maintained by `/rails-deploy` — see [Updates](docs/updates.md).

## [1.22.0] - 2026-10-07

### Added

- **`bin/agent-log` now records what a run consumed, and prices it against the plan actually being paid for.** The log could say what an agent did but not what it cost, so "what did this feature cost me" was unanswerable from the data and had to be estimated. Six columns on `runs` (`tokens_in`, `tokens_out`, `cache_creation_tokens`, `cache_read_tokens`, `model`, `usage_source`) hold the usage; a dated `model_rates` card and a `billing_plans`/`billing_periods` pair hold the money. Agents log none of it — `usage sweep` reconciles it afterwards from session transcripts, so no agent definition changed and nothing new can fail mid-run.

  **Nothing about any plan or price is hardcoded.** `billing setup` prompts for the seat name, its monthly cost, the included token allowance and the cycle day; `billing plan` is the scriptable form. One plan row derives one period per cycle covering every month that holds a run, so a project on a different Claude account gets correct costs with no change to the script. Rates are dated, so an old run keeps costing what it cost, and a model with no rate row is reported as **NOT PRICED** instead of being silently priced at another model's rate.

  `query cost` prints two dollar columns on purpose. **ListUSD** is the list-rate value of the tokens — an attribution *weight*. **BilledUSD** is the feature's share of what was really paid for the enclosing period, apportioned by that weight. Under a subscription the marginal cost of a token is zero until the allowance is exhausted, so `tokens × list rate` answers "how much of the seat did this consume", not "what was I charged". BilledUSD conserves: across all features it sums to exactly the total paid.

- **`test/agent-log/cost_test.rb` — the script's first automated test coverage**, which 1.21.0 noted was missing. Eight tests run the real script against a throwaway database, covering the parts where a silent error is expensive rather than merely annoying: that the apportioned column sums to exactly what was paid, that it weighs by token value and not run count, that a run is priced at the rate in force on its own date, that an unpriced model is reported, that a no-data period says so, that coverage is disclosed, that regenerating periods updates in place and preserves a hand-entered overage, and that `billing setup` refuses non-interactively. Verified by mutation: breaking the date-aware rate lookup, the value-weighted apportionment, and the no-data guard each fails the specific test written for it. Not vendored, same as `test/rubocop/`.

### Fixed

- **The usage sweep globbed only `*.output` and so swept nothing, while exiting 0.** Session transcripts are `*.jsonl`, under `~/.claude/projects`; `*.output` is background-job output, under `~/.claude/jobs`. Reading one pattern meant a sweep that found no files reported success and updated zero runs, which is indistinguishable from a sweep that genuinely had nothing to do. It now reads both shapes and aborts when a directory yields neither.

- **The transcript-to-run join matched any mention of a run id, not the id itself.** "Result contains a known id" made 295 transcripts claim runs that weren't theirs — the skill tells a resumed agent to run `query runs`, which dumps every recent id into one tool result — and produced a confident, badly inflated total. The rule is now that the *whole* result must be the id, optionally behind `RUN_ID=` or `Run ID:` (the shape the skill's own `run start` snippet produces). Widening from bare-uuid-only to those three forms was measured before it was applied: coverage rose from 17% to 77% of runs with still zero runs claimed by two different transcripts — the number that matters, since a transcript legitimately holds many runs but a run belongs to exactly one transcript.

- **A billing period holding runs but no reconciled usage rendered as `$0.00 — 0% of allowance`.** Zero spend and no visibility are different facts and were printing identically, which reads as a measured underspend and understates what the seat bought. Such a period now prints **NO USAGE DATA** with its run count, and every period line carries its own coverage ratio so any consumption figure below 100% coverage reads as the floor it is.

## [1.21.0] - 2026-10-07

### Added

- **Two review rules, both earned the expensive way.** A feature took five review rounds for roughly 200 lines of production code, and every finding sat in an assumption rather than in the new code. The two mechanisms behind that now live in the agents that needed them.

  `fresh-eyes-review` gains **"enumerate; do not trace from what you were told."** A verification that inherits the assumption it is testing will always confirm it: walking the subclass tree a spec names cannot, by construction, find an implementer outside that tree. The instance — a spec asserted a table was written exclusively by one method, four documents repeated it, three reviewers passed it, and a second writer had shipped days earlier. A later round's three *independent* enumerations then all scoped to the application and library trees and all missed a third writer in the seeds file, which is why the rule names `db/`, `test/`, task directories and fixtures explicitly. Treat "exclusively", "the only" and "all of" as the assertions most likely to be false, because they are the ones nobody re-derived.

  `fidelity-review` gains **"an empty diff against an excluded entity proves it was not written to, not that it is unaffected"** — check the read direction separately from the write direction. This one is subtler than an unverified assumption: the premise is correctly verified and only the inference is wrong, so it survives the careful check that catches the cruder version. It shipped a display regression into a table the feature never touched, reached through an enrichment fallback. `fidelity-review` also gets a compact form of the enumeration rule, since its own early check had that shape.

### Fixed

- **`bin/agent-log` no longer stores the next flag name as a flag's value.** Every flag the tool defines takes a value, but the parser accepted a bare flag and silently consumed whatever followed — so `--run-id $RUN_ID --title "x"` with `RUN_ID` unset became `--run-id --title "x"`, stored `"--title"` as the run id, and reported success. Rows then landed under an id matching no run, invisible to every query, while the caller believed the write had worked. Agents hit this routinely because each shell invocation is a fresh process, so a variable set in one call is empty in the next — this is a silent log-corruption bug, not a typo guard. A bare flag now errors with a message naming both flags and the likely cause; `--flag=value` is the escape hatch for a value that genuinely begins with `--`. Verified by execution across the bare-flag, missing-value, normal, `=`-form and dash-leading-value cases. The script still has no automated test coverage — worth adding.

## [1.20.2] - 2026-10-06

### Added

- **`RailsPrinciples/FindThroughAssociation` gained an `AllowedModels` option, for models nothing owns.** Found by installing the cops on a scratch Rails 8.1 app: a stock scaffold's `Listing.find(params.expect(:id))` tripped the cop, correctly, because a top-level model has no owner to go through, but the only way out was a `rubocop:disable` at every lookup, and an engineer agent told never to disable a cop to pass would have nowhere to go. An app now lists such models once in its own `.rubocop.yml` (`AllowedModels: [Account, Billing::Tenant]`, written as in code; a namespaced name must match in full, so allowing `Billing::Account` does not allow a plain `Account`; default none, so nothing changes until an app opts a model in). The offense message now ends with "If nothing owns `Listing`, list it under AllowedModels in .rubocop.yml", so the fix is in front of the agent when it hits the rule. Five new tests; `docs/rubocop-cops.md` documents the option. Sync with `/rails-update`; put overrides in the app's `.rubocop.yml`, not in the vendored `default.yml`, where a hand-edit would surface as a conflict.

## [1.20.1] - 2026-10-06

### Fixed

- **`skills/rails-principles/SKILL.md`'s convention-based-resolution paragraph recommended `.classify` without noting what the method is actually for.** A downstream project traced two CRITICAL incidents and a shipped spec defect to the same root cause: an agent hand-deriving a `.classify` result instead of knowing the rule — `classify` maps a plural table-shaped name to its singular class name (`blog_posts` → `BlogPost`), so the output is always singular, not a per-case guess. The paragraph now states that rule directly, and keeps "never assert a derived name without executing the derivation" as a backstop for the genuinely ambiguous cases (irregular plurals, uncountable nouns) where even the rule can surprise — naming the failure mode as silent whenever resolution runs through `safe_constantize`: `nil`, a skipped class, and a green test suite, with nothing to catch it later.

## [1.20.0] - 2026-10-03

### Added

- **`security-review` gained a ninth review category, "Framework-Mounted Engine Routes," and it is never diff-gated.** Found by `rails-security-team`'s `pentest-security` agent against a real running app (not a theoretical review): Active Storage mounts `POST /rails/active_storage/direct_uploads` the moment the gem is in the `Gemfile`, with zero authentication, regardless of whether any model ever calls `has_one_attached`. A live PoC created a blob, wrote arbitrary bytes, and read them back with no session and no token. Every other category here only looks at the diff; this one can't, since the exposure exists from the moment the gem is present, not from whatever a given diff touched — so it now runs `bin/rails routes` and checks every non-`app/controllers` route unconditionally, on every review. New `ENGINE_ROUTE` category tag in `skills/agent-log/SKILL.md`'s vocabulary. `skills/rails-principles/SKILL.md` gained a matching "Gem-Mounted Engine Routes Are Not Authenticated By Default" note right next to its existing "use Active Storage" recommendation, so the lesson reaches the architect and engineer too, not only the reviewer catching it after the fact.
- **Four RuboCop cops now check the `rails-principles` rules a machine can decide, instead of leaving them to a reviewer's memory.** A code reviewer reads for intent and misses shape, so the rules that are pure shape moved into `skills/rails-principles/rubocop/`: `RailsPrinciples/ControllerActions` (a public controller method that isn't one of the seven REST actions), `RailsPrinciples/FindThroughAssociation` (`Listing.find(params[:id])` instead of `current_account.listings.find(params[:id])`; only id lookups, so email/token/slug lookups with no owner are left alone), `RailsPrinciples/NoServiceObjects` (`...Service`/`...Presenter`/`...Decorator`/`...Form` names, files under `app/services` and similar, and plain classes whose entry point is `call`/`perform`/`execute`/`run`), and `RailsPrinciples/ForbiddenGems` (`redis`, `devise`, `rspec`, `factory_bot`, `sidekiq` and the rest of the never-use list, each with what to use instead). The shared config also switches on rubocop-rails's own `Rails/StrongParametersExpect`, which is off by default there. Judgment calls (KISS, naming quality, when to extract) deliberately stay in the skill. No agent changed to enforce them: the engineer already runs `bin/rubocop` and fixes every offense, and the orchestrator's CI gate re-runs it, so a cop an app loads is enforced for free.
- **The cops ship inside the skill, so there is no gem to publish.** `skills/**` is already vendored into every app by `/rails-install` and `/rails-update` with the same drift detection, which means the cops and the prose that defines them can never be at different versions. `bin/rails-team-setup-project` gains a `rubocop` step that adds one `inherit_from` line to the app's `.rubocop.yml`. It is idempotent and never rewrites the file: it inserts a line, re-reads the result, and puts the original back if the check fails. It reports `needs_input` with a plain next step when the cops aren't on disk yet, there is no `.rubocop.yml`, `rubocop-rails` is missing or `rubocop` is older than 1.72, or `inherit_from` is written inline and can't be edited safely (in which case it prints the exact line to add by hand). `agents/rails-installer.md` documents the step and tells the user, after `ok` on an app with existing code, that `bin/rubocop` may now go red and by how many offenses; a new app starts clean.
- **`docs/rubocop-cops.md`** covers how an app gets the cops, what each checks and configures, the unsafe-autocorrect caveat on `params.expect` (it accepts one hash where `permit` accepted one or an array), how to disable a cop for one line with the reason beside it, and how to add a cop. `skills/rails-principles/SKILL.md` gained an "Enforced by RuboCop" section listing which rules are machine-checked. The cops have 48 Minitest tests in `test/rubocop/`, including `installer_wiring_test.rb`, which runs the real installer against throwaway projects. `test/` is not vendored, so the tests stay in this repo.

## [1.19.19] - 2026-09-29

### Fixed

- **`skills/agent-log/SKILL.md` was instructing the bare feature number (`042`) and explicitly *not* the `F-` form — and that was the root cause of a namespace collision.** Bare numbers put Bug Fix Mode issue numbers and Pipeline Mode feature numbers into one namespace, where issue `#100` and feature `F-100` are indistinguishable. A downstream audit found **501 runs across 120 ids** affected: the same bug fix logged as `F-249`, `249` and `issue-249`, with bug fixes landing in the `F-` namespace and silently contaminating every feature-level query, so "rounds per feature" was wrong in both directions. `--feature-id` is now `F-{NNN}` or `bugfix-{N}`, never bare.
- **`bin/agent-log` had drifted behind a downstream copy by two real bug fixes.** It was still calling `sqlite3` with no busy timeout, so sqlite3's default of **0ms** meant a second writer arriving during a write lock failed immediately with "database is locked" and the write vanished with nobody noticing — the confirmed cause of log loss under concurrent pipelines. It also lacked the named decision-id collision message. Both are now present, along with a `SHARED_TOOL_VERSION` bump to `1.1.0` so the next divergence is detectable rather than discovered by accident.

### Added

- **Runs are now classified and bugs can be attributed to a feature.** `runs` gains `work_type` (`feature`/`bugfix`) and `related_feature_id`, with `--type` and `--related-feature` flags. `work_type` is derived from `--feature-id` when omitted, so a forgetful caller still produces a classified row rather than a NULL that drops out of every grouped query; `--related-feature` names the feature a bug belongs to (`F-030`), which is what makes "which feature generates the most bugs" answerable at all. Both validate, and `--related-feature` rejects a bug id with an error explaining the distinction. Because `SCHEMA` uses `CREATE TABLE IF NOT EXISTS` and so never alters an existing table, the columns are also added by an idempotent guarded `ALTER` for databases created before this change.
- `rails-orchestrator.md`'s launch preamble grows a third line carrying the canonical id and classification, since the human-readable "Feature number: {NNN}" in the stage templates is what agents were logging verbatim.

## [1.19.18] - 2026-09-28

### Fixed

- **Negation does not disarm a closing keyword: "The PR does not close #275" closes #275.** GitHub's parser matches the substring `close #275` and has no concept of the "does not" in front of it. A downstream bundle deliberately left one issue of four unresolved, wrote exactly that sentence as its disposition note, and — because the Bug Fix Summary becomes the PR body verbatim — closed the issue on merge anyway; it had to be reopened by hand. What makes this one dangerous is that the phrasing is the first thing a careful writer reaches for: the more clearly you explain that you are *not* closing something, the more likely you are to close it.
- The rule in `skills/github-cli/SKILL.md` is now stronger than "format your `Closes` lines correctly": never place any closing verb (`close`/`closes`/`closed`/`fix`/`fixes`/`fixed`/`resolve`/`resolves`/`resolved`) immediately before `#N` anywhere in a PR title or body for an issue you don't intend to close — not in prose, a parenthetical, a negation or a quotation — with worked ✅/❌ phrasings for writing about a deliberately-unclosed issue. `rails-orchestrator.md` carries the same warning at Stage B6, where the summary prose is actually written.
- This is the fourth confirmed variant of the same parser footgun, after the comma-separated list, the bolded `**Closes:**` form, and the PR title vector. The first three were intended closes that silently failed; this one is the opposite — an unintended close that silently fired. The post-merge verification step accordingly checks both directions.

## [1.19.17] - 2026-09-28

### Fixed

- **Stage 7c's safety-net commit used a bare `git add -A`.** A blanket add sweeps in whatever else is sitting in the tree — a stray credential file, a large binary, or, where several worktrees share one checkout, another session's in-flight work. The step already runs `git status --porcelain` immediately above it, so it now stages the paths that listing printed, by name.
- **Backported a fix this repo never received: Stage 5 and Stage B4 still combined all four review-report globs into a single `git add`.** A multi-pathspec add aborts entirely — staging nothing, for any of the four — the moment one pathspec fails to match. Both are now one `git add` per glob.

### Added

- **A staged-content assertion before every multi-file commit: `git diff --cached --name-only`.** Splitting the adds stops one bad pathspec from silently discarding the others, but nothing was confirming the adds staged anything at all. A downstream project lost a reviewed security fix for a full round to exactly this — an add whose pathspec matched nothing, followed by a commit that looked entirely normal and contained none of the intended change, caught only because three of four reviewers independently re-derived the evidence instead of trusting the report. One line, no new infrastructure, read before committing.

## [1.19.16] - 2026-09-28

### Fixed

- **The Bug Fix Mode PR title was a second, uncontrolled issue-closing vector: `gh pr create --title "Fix #{N}: {Title}"`.** GitHub parses the PR *title* for closing keywords, not just the body — so a bundle that deliberately omitted one issue from its body still closed it on merge, because the number appeared in a title beginning "Fix #...". That issue had been investigated and its fix reverted as a confirmed no-op, so closing it was exactly wrong, and it had to be reopened by hand. The title now reads `Issue #{N}: {Title}`, applying the same rule Stage B3 already applies to commit messages.
- This also completes the explanation for the long-running partial-close mystery (see 1.19.15). The primary issue was closing reliably *via the title* while non-primary issues depended on body lines that weren't parsing, which is why a four-issue bundle would close exactly one and look inexplicable. With the title neutralised, closing depends solely on the bare `Closes #{N}` body lines — explicit, one per issue, and controllable. `skills/github-cli/SKILL.md` now also says to verify in both directions after a merge: an issue that should have closed and didn't, and an issue that closed when it was deliberately excluded.

## [1.19.15] - 2026-09-24

### Fixed

- **Found the likely cause of the long-running "a correct `Closes #N` silently didn't fire on merge" mystery: the Bug Fix Summary template emitted `**Closes:** #{N}`, bolded and colon-suffixed, and Stage B8 feeds that file straight to `gh pr create --body-file`.** GitHub's closing-keyword parser does not reliably recognize that form, and it fails exactly the way a comma-separated list does — no error, no warning, the issue just stays open. It went unnoticed for so long because `**Closes:** #N` reads perfectly well to a human and fits naturally beside the bold key/value lines the rest of that template uses. Caught when a downstream bundle reformatted to bare `Closes #N` lines before opening its PR and all six of its issues then closed correctly, against a same-day baseline where three of four in another bundle had to be closed by hand. The template now emits a bare `Closes #{N}` on its own line, and both `rails-orchestrator.md` and `skills/github-cli/SKILL.md` say explicitly to check the rendered keyword rather than just that the number is present. The post-merge `gh issue view {N} --json state` verification requirement from 1.19.6 stays mandatory — this explains most of the observed failures, not provably all of them.

## [1.19.14] - 2026-09-24

### Added

- **`code-review.md` now walks Sibling-Path Verification as its own numbered Review Category (2b), not just background reading.** The relevant detection guidance already lived in the `rails-principles` skill, loaded by this agent, but had no operationalized checklist step of its own — a downstream project measured a full-diff, no-inherited-trust regression pass catching a real, confirmed bug on 44% of its gate cycles *after* the standard four-reviewer battery had already returned a clean verdict, with this exact gap (a check, fix, or field applied to one path but not a structurally parallel sibling) accounting for nearly half of everything that pass found — almost none of which the standard battery caught first. Added the category to `code-review.md`'s Review Categories and a matching status section to its report template, so a sibling path left unaudited is now a named, walked step rather than passive skill content the reviewer may or may not apply.
- **`security-review.md` now carries the same "re-derive the evidence independently" instruction already present in `code-review.md`/`performance-review.md`.** Added as step 2 of "What You Do," matching the sibling agents' wording, adapted to security evidence (re-run Brakeman/bundler-audit yourself, re-verify a vulnerable path via `git show`/a fresh clone rather than trusting the live working tree, especially after a concurrent session or a recent merge). A downstream project confirmed a real instance motivating this: a merge conflict silently reverted a previously-reviewed sensitive-data fix to its pre-fix state in the committed tree while the working tree still showed the fix applied, and security-review only caught it after every other reviewer in the round had already found the same discrepancy independently.
- **`rails-orchestrator.md` now logs `run start` as the literal first line of Stage 1 and Stage B1**, ahead of even `PROJECT_ROOT=$(pwd)`, instead of relying on the separate "Activity Logging" section near the bottom of the file to be read and remembered mid-session. A downstream project measured this directly: at least a fifth of its completed orchestrator runs showed `run start` logged within seconds of `run end` — meaning it was actually called retroactively at session close, after the work was already done — making it the single most commonly skipped logging step across that project's whole pipeline.
- **`engineer.md`'s TDD Workflow gains a "Pre-migration check" step** requiring, for every new `belongs_to`/`references`, a paired `foreign_key: true`/`add_foreign_key` in the same migration and a reciprocal `has_many`/`has_one` where the association should be traversed both ways. A downstream project found this the single highest-severity-rate finding category in its code-review history, recurring across five distinct features — catching it before the migration runs is free; catching it in review costs a round.

## [1.19.13] - 2026-09-24

### Changed

- **`skills/agent-log/SKILL.md`'s git-safety guidance now bans `git stash` outright, in any form.** The 1.19.8 fix documented the root cause of the `db/agent_log.sqlite3` data-loss pattern but still recommended "scope the stash to specific paths" as the safe alternative — and that recommendation turned out to be broken. A downstream project confirmed six distinct incidents in a single day: `git stash push -- <path>` silently no-ops ("No local changes to save," not an error) whenever the target path has no working-tree diff, which is the normal case in bug-fix-mode review since the fix under test is already committed — and the reflexive `git stash pop` that follows then has no way to detect nothing was pushed, so it pops whatever is on top of the stash stack, which is shared repo-wide across every concurrent worktree on the same `.git`, not scoped to the current session. Replaced the guidance with an outright ban on `git stash` for both `db/agent_log.sqlite3` safety and mutation-testing isolation, naming the silent-no-op failure mode explicitly, and giving three concrete non-stash alternatives: an Edit-tool revert, a `git diff`/`git apply` scratch patch, or `git show <parent>:<path>` for read-only comparison.

## [1.19.12] - 2026-09-24

### Changed

- **Standing merge authorization now has a hard, explicit CI-status check attached to it.** The orchestrator's default has always been "opens the PR and stops — merging is a human decision," but a session can grant standing authorization to merge automatically once tests pass. That grant never specified *which* tests: the earlier stage's local CI run, or the PR's own live remote checks. Made explicit in Stage 7c (and inherited by Stage B8/Bug Fix Mode): merging always requires `gh pr checks "$PR_URL"` immediately before the merge command, and any check that is failing, pending, or simply hasn't reported yet blocks the merge outright — no `--admin` bypass, no falling back to an earlier local result. "Tests pass" means green right now, not at some earlier pipeline stage.

## [1.19.11] - 2026-09-24

### Fixed

- **A real, confirmed bug: the orchestrator can silently stall an entire pipeline by ending its turn right after an async agent launch.** Every `Agent` tool call returns immediately with an async acknowledgment; the orchestrator is a subagent itself, not the interactive top-level session, so nothing resumes it if it treats that acknowledgment as completion and stops. Caught live on a downstream project: a Bug Fix Mode run launched its engineer, said "I'll wait for it to complete," ran one `sleep 1`, and ended its turn — the harness marked the orchestrator's own run "completed" while the issue stayed open, no PR ever opened, and the engineer kept running unsupervised in the background with no one left to pick up its output. Added a canonical "Blocking on Async Agent Launches" section right after "Three Modes," plus a `until ls {expected-output} 2>/dev/null; do sleep 30; done`-style poll at every stage that launches an agent (discovery, architect, design, engineer, the four parallel reviews, the fresh-eyes gate, and their Bug Fix Mode equivalents) — a Bash call's timeout running out is documented explicitly as not a reason to stop polling.

## [1.19.10] - 2026-09-24

### Changed

- **The default on a duplicate-issue match is now to update the existing issue, not just skip filing.** The prior convention ("skip filing and note the existing issue number") silently discarded whatever new information a pass surfaced — a new instance, a new symptom, a clearer fix approach. `rails-orchestrator.md`'s Stage 7b/B7 (autonomous, no human to ask) now comments on the existing issue automatically; `intake.md`'s Step 5 (interactive) leads with commenting-on-existing as the recommended action rather than presenting it as a neutral third option. `skills/github-cli/SKILL.md`'s "Checking for Duplicates Before Filing" section documents the actual `gh issue comment` command and the new default for both paths. Only skip with no comment when a pass genuinely finds nothing beyond what the existing issue already says.

## [1.19.9] - 2026-09-24

### Added

- **Stage B1 now checks a card isn't already "In Progress" before starting Bug Fix Mode on it.** The "In Progress" status set when work actually starts exists specifically to make this check possible — picking issues from a batch list without checking risks two concurrent pipelines starting on the same issue, a mistake confirmed to happen for real on a downstream project. `skills/github-cli/SKILL.md` documents the actual `gh project item-list` + client-side filter query (there's no single-item project lookup), and Stage B1 now runs it right before the existing marking step.

## [1.19.8] - 2026-09-24

### Added

- **`skills/agent-log/SKILL.md` documents the real root cause behind a recurring, previously vague "concurrent git operations" data-loss pattern.** A bare `git stash` on a worktree with pending `bin/agent-log` writes stashes `db/agent_log.sqlite3` along with everything else — restoring it (`stash pop`, or a conflict resolved via `git checkout --ours`) only guarantees *some* valid git state, not the one with the most recent row-level writes still in it. This looks clean at every git-level check (no conflict markers, empty `git stash list`) and is only diagnosable by direct SQLite querying. Confirmed as the root cause of a real instance on a downstream project. Guidance: never run a bare `git stash`/`checkout .`/`reset --hard` while agent-log writes might be pending — scope any such operation to specific paths and leave the database file out of it.

## [1.19.7] - 2026-09-24

### Fixed

- **A real, confirmed bug: Bug Fix Mode's Stage B2 defined `BUGFIX_DIR="${PROJECT_ROOT}/docs/bugfixes/{N}-{slug}"`** — an absolute path back into the main checkout, not the fix worktree. Every subsequent engineer/review report written against that path landed in `$PROJECT_ROOT` instead of `$WORKTREE_DIR`, and since nothing in Stage B3 onward commits from `$PROJECT_ROOT`, those reports were left as uncommitted stray files in the shared main checkout — caught live via a stray file left behind by a real Bug Fix Mode run on a downstream project. Fixed to be worktree-relative (`BUGFIX_DIR="docs/bugfixes/{N}-{slug}"`), matching how `$FEATURE_DIR` already works correctly in Pipeline Mode — the new worktree already has its own copy of everything Stage B1 committed to master before creating it.

## [1.19.6] - 2026-09-24

### Added

- **`skills/github-cli/SKILL.md` now requires verifying issue closure after *every* merge, not just multi-issue closes.** A single, correctly-formatted `Closes #N` in a PR body was observed to silently not fire on merge in one real case, with no clear single root cause (ruled out "squash merges use the commit list instead of the PR body" — plenty of squash merges closed correctly off the identical pattern). Rather than guess at the mechanism, the guidance is to always verify with `gh issue view {N} --json state` and close by hand if needed.

## [1.19.5] - 2026-09-24

### Fixed

- **Bug Fix Mode's commit templates used "docs: fix #{N} ..." for intermediate round commits** — a real, repeated mistake: GitHub's issue-closing keywords (`fix`/`fixes`/`fixed`/`close`/`closes`/`resolve`/...) trigger on any commit reaching GitHub, not just a merged PR body, so this closed issues hours before review even started, with no PR yet open to reopen against. Every intermediate commit now reads "docs: issue #{N} ..." instead; the actual close-on-merge is unaffected, since it happens via Stage B6's summary `**Closes:** #{N}` line in the PR body at merge time, the one place this behavior belongs.
- **`engineer.md`'s per-round commit rule existed but kept getting silently violated** — promoted from a single trailing sentence to its own numbered TDD step with the "why" spelled out (every downstream review agent needs `git diff` to scope its review), and gave the orchestrator (both Pipeline Mode's Stage 4 and Bug Fix Mode's Stage B3) a formal backstop: verify `git status --porcelain` is clean after every engineer run rather than trusting the report, commit on the engineer's behalf if not, and surface that the backstop fired rather than working around it silently forever.

### Added

- **`skills/github-cli/SKILL.md` documents two GitHub closing-keyword gotchas**: a comma-separated `Closes #A, #B, #C` list only closes the first issue (needs one `Closes #N` per line), and a closing keyword in an intermediate commit message closes on push, not on merge — both discovered live, both now documented so any agent authoring a commit or PR body knows the rules up front.

## [1.19.4] - 2026-09-24

### Added

- **Bug Fix Mode's Stage B1 now marks the GitHub Project card "In Progress" the moment work actually starts**, reading the same `team.yml` `github.project.owner`/`github.project.number` config `team-create-issue` already reads. Confirmed via live testing against a real project board that `gh project item-edit` against an issue that isn't a project item (a plain `bug`, which never reaches the board per `team-create-issue`'s own routing) is a safe, silent no-op — so the step runs unconditionally, with no per-issue board-membership check needed first, and is skipped entirely (also silently) when a project isn't configured in `team.yml` at all.

## [1.19.3] - 2026-09-23

### Added

- **New agent: `agents/fresh-eyes-review.md`** — a full-diff, no-inherited-trust reviewer, reverse-engineered from an observed pattern on a project running this pipeline: an external, whole-PR reviewer caught real bugs six separate times on one feature, each time on a PR the standard code-review/security-review/performance-review/fidelity-review battery had already passed clean. The common cause was scoping, not any one category of bug — every specialized reviewer inherits trust in its own prior "PASS" and only re-examines what changed since then, which structurally can't see a bug living entirely inside an already-reviewed region (including a regression an earlier "fix" just introduced there). `fresh-eyes-review` counters this by diffing the whole branch against the true base branch every time, generalist across eight reverse-engineered failure patterns (full-diff blind spots, regressions from earlier fixes, sibling-path gaps, field-propagation gaps, nullable-display bugs, state-machine completeness gaps, external-call gating, identifier conflation) rather than specializing in one dimension, with the same mutation-test verification discipline the other four reviewers already hold themselves to.
- **`agents/rails-orchestrator.md`** wires this in as **Stage 6b / B5b** — a final gate that runs once the standard four reach a clean combined verdict, repeated until `fresh-eyes-review` itself also comes back clean, not part of the per-round Stage 5/B4 parallel battery. Chosen deliberately over running every round: a full-diff-against-base review doesn't care when a bug was introduced, so running it once at the end catches the same bugs a mid-pipeline cadence would, at a fraction of the cost. A NEEDS WORK verdict from this gate routes back to the engineer with just the fresh-eyes report (not all four standard reports again), and re-review after the fix is narrower too — `fresh-eyes-review` plus only the standard reviewer(s) whose category vocabulary owns the finding.
- **`skills/agent-log/SKILL.md`** gains six new category tags for the failure classes fresh-eyes-review introduces that don't already have one: `SIBLING_PATH_GAP`, `FIELD_PROPAGATION_GAP`, `NULL_DISPLAY_GAP`, `STATE_COMPLETENESS_GAP`, `EXTERNAL_CALL_GATING`, `IDENTIFIER_CONFLATION`.

## [1.19.2] - 2026-09-22

### Added

- `agents/rails-orchestrator.md`'s Stage 7c (and B8, which inherits its mechanics) now requests a Copilot code review right after `gh pr create` succeeds — `gh pr edit "$PR_URL" --add-reviewer @copilot`. It's a fire-and-forget request, not a gate: a failure (Copilot review not enabled for the org/repo) is surfaced to the user rather than retried, and doesn't count as the PR itself failing to open. The `github-cli` skill's "Opening a Pull Request" section documents the same command for direct/manual use.

## [1.19.1] - 2026-09-21

### Fixed

- **`team.lock.yml` was flat and unnamespaced — a real, confirmed bug, found and fixed first on `rails-qa-team`'s ported copy of this same file, mirrored here.** A flat lock file lets one team's recorded hash for a genuinely shared file (`bin/agent-log`, `bin/team-setup-git`/`-gh`/`-sqlite`) be misread by a *different* team's `bin/<team>-team-update` as that team's own prior baseline — a since-diverged copy then silently auto-applies as a routine "clean update" instead of surfacing a conflict. Verified directly in both directions: simulated this team already installed, ran `rails-qa-team`'s `bin/qa-team-update plan` against it (misclassified `bin/agent-log` before the fix, correctly flagged as a conflict after); and the reverse, simulated `rails-qa-team` already installed, ran this team's own `bin/rails-team-update plan` against it (same result). Fixed: `team.lock.yml` namespaced under `teams:`, keyed by `source_repo` — this team's own `bin/rails-team-update` now only reads/writes its own section. A pre-existing flat-format lock file migrates transparently on first read.
- Same root cause, confirmed separately: `team.lock.yml`'s top-level `source_repo`/`synced_version`/`synced_at` were being silently overwritten by whichever team synced last. Fixed by the same namespacing.

### Added

- `bin/agent-log` gains a `SHARED_TOOL_VERSION` constant (printed by `check` and `help`), matching `rails-qa-team`'s copy, so a human resolving a now-correctly-surfaced conflict on this file has an at-a-glance signal: compare versions, take the higher one by default.
- `docs/updates.md`: "Keeping Shared Tools in Sync" and "Adding a Team-Specific Database Table" — the latter states the rule directly: a team-specific table must never be added to this team's own `bin/agent-log` schema (makes table existence depend on which team wins a future sync conflict); it must be created by code only that team owns.

## [1.19.0] - 2026-09-21

### Changed

- Renamed `bin/team-setup-project` → `bin/rails-team-setup-project` and `bin/team-update` → `bin/rails-team-update` — the same collision-avoidance reason as [1.17.0]/[1.18.0]'s agent/command renames, one layer down: unlike `bin/agent-log`, `bin/team-setup-git`, `bin/team-setup-gh`, and `bin/team-setup-sqlite` (which are interchangeable between teams — a collision is harmless), these two are not. `bin/rails-team-update` in particular hardcodes `DEFAULT_SOURCE_REPO` to this team's own repo; another team's copy landing on top of it in a shared `bin/` directory would silently point this team's syncs at the wrong upstream. `rails-qa-team` already made the identical move (`bin/qa-team-setup-project`, `bin/qa-team-update`). `bin/team-manifest` doesn't need it — it's excluded from vendoring entirely, so it never reaches a target repo to collide in the first place.
- Updated every in-repo reference to the two renamed scripts: `agents/rails-installer.md`, `agents/rails-updater.md`, `bin/team-manifest`, `bin/team-setup-sqlite`, `commands/rails-deploy.md`, `docs/agents.md`, `docs/installer.md`, `docs/updates.md`, `skills/github-cli/SKILL.md`, `skills/team-sync/SKILL.md`.

## [1.18.0] - 2026-09-21

### Changed

- Renamed this team's `/install`, `/update`, and `/deploy` commands to `/rails-install`, `/rails-update`, and `/rails-deploy`, and their agents (`installer.md`, `updater.md`) to `rails-installer`/`rails-updater` — same collision-avoidance reason as [1.17.0]'s agent rename, one layer up: `commands/install.md`/`update.md`/`deploy.md` vendor to the same bare path in a target project regardless of which team they came from, and the slash command Claude Code offers resolves from whichever file landed there last. `rails-qa-team` already made the identical move (`/qa-install`/`/qa-update`/`/qa-deploy`, VERSION 0.8.0).
- Fixed `bin/team-manifest`'s hardcoded `commands/deploy.md` exclusion — it would otherwise have started vendoring `commands/rails-deploy.md` into every installed target repo, a source-repo-only maintainer tool that has no reason to exist there.
- Fixed two H1 headings in `agents/rails-orchestrator.md` and `agents/rails-log-analyst.md`/`agents/rails-skill-builder.md` (`# Orchestrator` → `# Rails Orchestrator`, etc.) missed in [1.17.0] — `rails-qa-team`'s own agent files prefix this heading too, only `docs/agents.md`'s per-team-agnostic section headings stay bare.
- Updated every in-repo reference to the renamed identities: `agents/bug-triage.md`, `agents/intake.md`, `bin/team-create-issue`, `bin/team-update`, `commands/roadmap.md`, `commands/triage.md`, `docs/agents.md`, `docs/backlog.md`, `docs/installer.md`, `docs/updates.md`, `README.md`, and `skills/github-cli/SKILL.md`, `skills/team-sync/SKILL.md`.

## [1.17.0] - 2026-09-21

### Changed

- Renamed this team's three cross-team-collidable agents to carry an explicit `rails-` prefix: `orchestrator` → `rails-orchestrator`, `log-analyst` → `rails-log-analyst`, `skill-builder` → `rails-skill-builder` — both the file (`agents/orchestrator.md` → `agents/rails-orchestrator.md`, etc.) and the `name:` frontmatter, so both the Claude Code identity and the `--agent-name` value logged to `db/agent_log.sqlite3` carry the prefix. This team was the first built, so it kept the bare names while sibling teams (`tauri-agentic-engineering-team`, `go-agentic-engineering-team`, `rails-security-team`, `tauri-security-team`, `tauri-qa-team`, `rails-qa-team`) disambiguated themselves against it — several still collide on bare `log-analyst`/`skill-builder`. This closes the asymmetry from this team's side; see `docs/agents.md`'s "Why `rails-orchestrator`, `rails-log-analyst`, and `rails-skill-builder`, Not the Bare Names" for the full reasoning.
- `agents/skill-builder.md` was a symlink to a file shared by roughly a dozen other teams at the `agentic-teams` root. Forked it into this team's own independent `agents/rails-skill-builder.md` (same move `rails-qa-team` already made) — required to rename it safely, since a shared symlink can't be given a team-specific identity without breaking it for every other team still using it. This team no longer auto-inherits future edits to that shared file.
- Updated every in-repo reference to the renamed identities: cross-agent pointers in `architect.md`, `code-review.md`, `design.md`, `discovery.md`, `engineer.md`, `fidelity-review.md`, `performance-review.md`, `security-review.md`; the `agents/rails-orchestrator.md` file path in `commands/feature.md` and `commands/fix.md`; the `team.yml` template comments in `bin/team-setup-project` and `skills/github-cli/SKILL.md`; and `docs/agent-log.md`/`docs/agents.md`/`docs/pipeline.md`. Left untouched, deliberately: bare `orchestrator`/`log-analyst` used as casual prose (e.g. "the orchestrator passes…") rather than as an identifier, `skills/agent-log/SKILL.md`'s generic "each team's `log-analyst`" phrasing (shared boilerplate describing the fleet-wide pattern, not this team specifically), and every historical `CHANGELOG.md` entry and `docs/sessions/`/`docs/portable-upgrades/` file, which describe what was true at the time and stay as written.

## [1.16.4] - 2026-09-21

### Fixed

- `bin/team-update`'s `git clone` call passed `source_repo` (from `--source-repo`, or from `team.yml`'s `team.source_repo` — hand-editable by anyone with write access to the target repo) as a bare positional argument. A value starting with `-` gets parsed as a git flag instead of a repository — flagged by automated security review, on `rails-qa-team`'s ported copy of this same file, as argument injection (`--upload-pack=<cmd>` runs `<cmd>` as the clone's pack generator). Fixed with a `--` separator before the value. Also found, while fixing it, a second gap the `--` fix doesn't touch: `ext::<cmd>` is a git transport scheme that runs a command directly, no flag parsing needed, currently blocked only by this git version's default protocol allowlist rather than by anything in this script. Added a `validate_source_repo!` allowlist (plain `https://` or `git@`-style URLs only) so the fix doesn't depend on git's own defaults staying as they are.

## [1.16.3] - 2026-09-21

### Fixed

- `orchestrator.md`'s log-analyst cadence check (Stage 9/B10) sorted `docs/agent-analysis/*.md` filenames assuming every one is a bare `YYYY-MM-DD.md`. A non-date filename in that directory sorts after any real date in ASCII, permanently masking the true last-analysis date. Now filters to the strict date pattern before sorting.
- Runs left in `status='running'` were never reconciled — nothing closed a run on an agent's behalf when its work was superseded by a fresh agent spawn, or lost track of it via `isolation: "worktree"`'s separate physical database copy. `bin/agent-log` gains `run update` (backfill feature-id/status without a full `run end`) and `query stale` (surface running rows past a plausible session length). `orchestrator.md` now checks for and closes a stale run before spawning a replacement agent for the same work, and both `orchestrator.md`'s Worktree Model and the `agent-log` skill's Database section now warn that `isolation: "worktree"` launches must still point `AGENT_LOG_DB` at the main checkout.

## [1.16.2] - 2026-09-21

### Added

- **CI Gate** (`orchestrator.md` Stage 4b / Bug Fix Mode Stage B3b): after the engineer completes and before the four parallel reviewers launch, the orchestrator independently re-runs `bin/ci` (or `bin/rubocop` + `bin/rails test` if the project has no `bin/ci`) rather than trusting the engineer's own self-reported Validate step. Not clean → routes back to the engineer exactly like a Stage 6 NEEDS WORK verdict, incrementing `$SEQ` by 5. Nothing reaches Stage 7c without passing this gate.
- `engineer.md`'s TDD Workflow now requires running the **entire** test suite before starting a task (not just files expected to be touched) and fixing anything already red before proceeding — a red baseline makes it impossible to tell, once done, which failures are the engineer's own. Its Validate/End-of-Work steps now also run `bin/rubocop` (or `bin/ci`'s style step) and treat any offense, any pre-existing red test surfaced by the change, and any dependency-audit finding as the engineer's own to fix, not to note and defer.
- `security-review.md` now runs `bin/bundler-audit` (or `bundle exec bundler-audit check --update`) alongside Brakeman at the start of every run, as its own "Dependency Audit" review category — any advisory is NEEDS WORK unless demonstrated inapplicable. New `DEPENDENCY_AUDIT` category added to the `agent-log` skill's finding vocabulary.
- `/install` (`installer.md` Step 9) now offers to run `/init-project` once its checklist finishes clean — waits for an explicit yes, never chains automatically, same rule every other handoff in the installer follows.

### Fixed

- 1.16.1's fix for `bin/team-create-issue`'s project-board step was itself broken: it swapped `gh project item-edit`'s `--url` for `--id` while keeping the `--field`/`--value` friendly-name flags, but `gh` rejects that combination — `--field`/`--value` only work with `--url`. Corrected to resolve the project's node id and the Status field's real field-id/option-id once (via `gh project view`/`field-list`, a schema read whose cost doesn't grow with board size), then call `item-edit` with the fully-typed `--id`/`--project-id`/`--field-id`/`--single-select-option-id` form. Falls back to the old `--url`/friendly-name path only if that resolution fails. Verified end-to-end against a real board.

## [1.16.1] - 2026-09-21

### Fixed

- `bin/team-create-issue`'s project-board step resolved the project item to update via `gh project item-edit --url`, which makes `gh` search/paginate the project's existing items to find a match — cost that grows with board size. A burst of ~90 issues filed in one run against a growing board exhausted the account's hourly GraphQL quota partway through. `item-add --format json` now captures the created item's own id, and `item-edit` uses `--id` (a direct lookup, flat cost) instead, falling back to the old `--url` resolution only if `item-add` didn't hand back a usable id.

## [1.16.0] - 2026-09-16

### Fixed

- `commands/deploy.md` was a tracked file, so it vendored into every target repo even though `/deploy` only works in this source repo (it depends on `bin/team-manifest`, which never vendors anywhere else). It's now excluded from `manifest.yml` the same way `bin/team-manifest` already was; a repo that vendored it before this fix sees it under `removed_upstream` on its next `/update` and can clean it up.
- `bin/team-update`'s `load_lock` silently treated a `team.lock.yml` that exists but fails to parse the same as "never synced," discarding every file's sync history without telling anyone. It now fails the sync cleanly with `{"status":"failed"}` instead.

## [1.15.0] - 2026-09-16

### Added

- `CHANGELOG.md` (this file) — human-readable release notes for this project itself, backfilled from `VERSION`'s full history. `/deploy` now drafts and asks about a new entry whenever `VERSION` changes, distinct from `docs/updates-log.md` (a mechanical per-file record generated in each *target* repo, not this one).

## [1.14.0] - 2026-09-16

### Added

- `/update` and `/install`'s first vendor now write `docs/updates-log.md` in the target repo: a dated, newest-first record of exactly what each sync did (vendored / updated from upstream / conflicts resolved each way / removed), skipped entirely when a sync changes nothing.

### Fixed

- README's doc table said `/install` runs "four bootstrap scripts" — there have been five since 1.9.0. `docs/installer.md` already said five; the README was just stale.

## [1.13.0] - 2026-09-16

### Added

- `/install` now vendors this team's whole file tree itself (Step 0.5), instead of assuming it was already manually copied in. It bootstraps a temporary `bin/team-update` via a shallow clone when the target repo has no vendored copy yet — true on every first install — then runs the same sync procedure `/update` uses. Closes the long-standing "install `bin/agent-log` into a repo that doesn't have it" gap for real, not just for that one file.
- New `team-sync` skill: the shared plan/apply procedure, referenced by both `agents/installer.md` and `agents/updater.md` instead of being duplicated across both.

### Fixed

- `bin/team-update` crashed with a raw Ruby backtrace instead of the promised `{"status":"failed"}` JSON line when `manifest.yml` was malformed or missing its `files` key — every caller reads only the last stdout line as JSON, so the crash silently broke that contract.

## [1.12.0] - 2026-09-16

### Added

- `/deploy` and `/update`: `bin/team-manifest` hashes every vendored `agents`/`commands`/`skills`/`bin` file into `manifest.yml`; `bin/team-update` 3-way-compares it against a target repo's `team.lock.yml` to classify each file as new, a clean upstream update, a conflict, a local-only edit, or removed upstream — applying what's safe automatically and asking before touching anything that conflicts with a hand-edit. Replaces the manual, per-change `docs/portable-upgrades/*.md` instruction-writing process.

## [1.11.0] - 2026-09-11

### Added

- `docs/installer.md` and `docs/backlog.md` — dedicated doc pages for `/install` and the scope-capture/roadmap/triage backlog system, following `docs/pipeline.md`'s shape.

### Fixed

- A stale README line claiming bugs accumulate on the project board — they never do, `bug`-labeled issues stay plain repo issues.

## [1.10.0] - 2026-09-10

### Added

- Every pipeline agent now logs an unconditional `input_quality` reflection each run, rating the specific upstream artifact it consumed 1–10 — silence used to be ambiguous between "the input was great" and "nobody checked." `log-analyst` gains Pattern Type 7: rating trends over time per artifact type, and cross-agent outcome mismatches (an engineer rating a spec highly when a later review round still finds a spec-attributable gap).

## [1.9.0] - 2026-09-10

### Added

- `bin/team-setup-git` and `bin/team-setup-sqlite` — `/install` now checks for `git` and `sqlite3`, not just `gh`, before proceeding. Both are hard dependencies every stage or `bin/agent-log` needed all along but never verified.

### Fixed

- Stale "not yet built" claims in `docs/agents.md`/README about GitHub labels (shipped two commits earlier) and project board columns (a permanent `gh` limitation, not a pending gap).

## [1.8.0] - 2026-09-10

### Fixed

- The orchestrator now commits each pipeline artifact (architect spec, design spec, engineer report, review reports, summary) right after the stage that produces it confirms the file exists, instead of batching everything into one commit at the very end — a stopped or crashed mid-pipeline run no longer leaves real work sitting uncommitted with no git history.

## [1.7.0] - 2026-09-10

### Added

- `bin/team-create-issue` and `bin/team-find-issues` — the routing rule (a `bug` stays a plain repo issue; a `feature`/`tech-debt` also reaches the GitHub Project board) now lives in one script instead of four independently-duplicated call sites (`intake`, scope-capture filing, `roadmap-analyst`, `bug-triage`'s reclassify case).

## [1.6.0] - 2026-09-10

### Changed

- Scope-capture findings (a missing feature, tech debt, or an unrelated bug noticed mid-pipeline) now file as labeled GitHub issues instead of appending to `TODO.md`, which keeps only its `Deferred` section from here on. `roadmap-analyst` and `discovery` read open GitHub issues instead of `TODO.md` accordingly. Added the `tech-debt` label alongside `feature`/`bug`.

## [1.5.0] - 2026-09-10

### Added

- `/install` — `bin/team-setup-gh` installs and authenticates `gh`; `bin/team-setup-project` detects the repo from `git remote`, writes `team.yml` with a comment-preserving targeted edit, migrates `db/agent_log.sqlite3`, and builds the `docs/` skeleton.

## [1.3.0] - 2026-09-10

### Added

- `bug-triage` and Bug Fix Mode (`/fix`) — verifies open `bug`-labeled issues against the actual codebase, ranks the queue by severity and ICP fit, and routes a direct fix through the same engineer and four parallel reviewers the feature pipeline uses, with the issue itself standing in for a spec.
- `team.yml` — cross-agent settings (GitHub repo/board/labels, review escalation threshold, log-analyst cadence) move out of prose in `AGENTS.md` and hardcoded numbers into one structured, script-readable config file.

## [1.1.0] - 2026-08-13

### Added

- `fidelity-review` — a fourth parallel reviewer checking whether the implementation still matches the architect's plan, and whether the plan itself still solves the problem the discovery brief described. Previously the only check for either question was retrospective, after the feature had already shipped.

## [1.0.0] - 2026-07-24

### Added

- First versioned release. Agent activity logging refactored and extended.
