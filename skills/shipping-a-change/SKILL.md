---
name: shipping-a-change
description: Use inside a revai change workflow (/revai:feature, /revai:bugfix, /revai:refactor) for the stages they all share — Set up and branch, Understand the code before deciding, hold the consistency bar while working, Refine (self-review + simplify) the diff, then the Verify → Review → Ship finish. Each command supplies only its distinct Decide + Build middle; this skill owns the shared spine so it stays identical across all three.
---

# Shipping a change (the shared workflow spine)

`/revai:feature`, `/revai:bugfix`, and `/revai:refactor` differ only in their **middle** — the
**Decide** and **Build** stages, how the change is arrived at and made. The spine owns the six stages
around that middle — **Set up**, **Understand**, **Refine**, and the **Verify → Review → Ship**
finish — and lives here so they stay identical and can't drift across the three. You **orchestrate**;
the real work is done by the `superpowers` skills, the `code-simplifier` agent, and revai's
guardrails — don't reimplement exploration, verification, review, or PR creation.

## Before you begin (Set up)

- **Confirm revai is attached.** Check that both `CLAUDE.md` and `.revai/verify.json` exist in the
  repo root. If either is missing, tell the user to run `/revai:attach` first, and **stop**.
- **Read the project `CLAUDE.md`** into context — the stack, conventions, verify commands, and the
  **"Do not touch"** paths. These govern everything you do.
- **Get onto a branch.** If the current branch is the default (`main`/`master`), create
  `<prefix>/<slug>` off it — the calling command supplies the prefix (`feat/`, `fix/`, `refactor/`)
  and you derive `<slug>` from the change. If already on a non-default branch, stay on it.
  **Never work directly on the default branch.**

## Size the change

Before Understand, classify the change so later stages spend effort proportional to risk — this
gates *cost*, never the guarantees themselves.

- **Micro** — all of these hold, with no exceptions:
  - the exact lines to touch are already known, right now, without exploring further;
  - touches at most 2 files with a small diff (rough guide: under ~20 changed lines total) — pure
    wiring, config, comments/docs/annotations, or a one-line logic fix;
  - introduces no new type, exported function/method signature, endpoint, public contract, or
    dependency;
  - touches no schema/migration, no auth/payments/security-sensitive path, and crosses no
    bounded-context boundary — these are **never** Micro, regardless of file/line count;
  - no open design question, no real doubt about correctness.
  - Examples: adding OpenAPI/doc comments to an existing endpoint handler, fixing a typo, adding a
    log line, bumping a constant.
  - Counter-examples (Standard, even though they look small): adding a field to a request/response
    type or a new query parameter (contract changes), touching a migration of any size.
- **Standard/Large** — anything failing a Micro bullet, or that you're not fully sure about.
  **Default here when in doubt** — over-classifying costs minutes; under-classifying quietly skips
  a guarantee.

Gates cost in this shared spine at **Understand** and **Refine**; calling commands may use the same
classification further (see `/revai:feature`'s Plan gate). Never gates Verify, Review, or either
approval gate — those run in full regardless of size. (Orthogonal to `divide-and-conquer`, which
handles the opposite end — work too big for one PR.)

## Understand (before you decide)

Before the command's Decide stage, **actively ground yourself in the code the change will touch** —
don't plan, diagnose, or scope blind. This is the load-bearing first move for producing code that
fits the repo instead of fighting it.

- **For a Micro change, skip the subagent.** Read the 1–2 known files yourself, inline, and note
  what you confirmed — a dispatch round-trip costs more than the read it replaces. Everything else
  in this section still applies; only *how* you ground yourself changes.
- **For anything else, survey off your main context.** Dispatch Explore / `explaining-code`
  subagent(s) to read the relevant area and return **structured notes** — not raw file dumps — so
  the detail stays off your main context (the move `/revai:explain` uses). The calling command
  scopes this to its area (the feature's target, the buggy code path, or the code in refactor scope).
- **Ask for what shapes the change:** the neighbouring units and the patterns/naming they use, the
  public contracts and existing tests in the area, the dependencies between the pieces, and any
  relevant **"Do not touch"** path. **Correct over comprehensive** — report only what's verified in
  the code, and flag what couldn't be confirmed.
- **Model policy:** run the survey on the cheapest tier that can do it (see below).

The result is a short grounding note the Decide stage builds on — it turns "read a neighbouring unit"
from a passive hope into an explicit step.

## Write clean code (the quality standard)

Consistency with the repo is necessary but not sufficient — a poorly-named codebase would just
propagate poorly-named code. Hold an **absolute** clean-code standard throughout the Decide + Build
middle, applied *as you write*, not as a cleanup pass:

- **`naming-and-structure`** is the always-on standard: intention-revealing names (verbs for
  functions, predicates for booleans, no cryptic abbreviations, one term per concept), one
  responsibility per unit, IO at the edges, one level of abstraction per function. This skill surfaces
  automatically — treat it as a hard requirement on every line, not a suggestion.
- **`best-practices`** is the second always-on standard: before building something bespoke, check
  whether a standard library, an established package, a recognized protocol, or a documented
  pattern already solves it. Bespoke needs a stated reason, not just unfamiliarity with the
  standard option.
- **Architecture skills apply by area** — `hexagonal-architecture` (layering / ports / adapters),
  `domain-modeling` (invariants, where a rule lives), `bounded-contexts` (module boundaries), plus the
  concrete backend skills (`api-design`, `data-access-patterns`, `error-handling-and-logging`, …) as
  the change touches them.
- **`code-simplifier` is the *reactive* complement** — it cleans at Refine (below), fixing only what
  slips through. Writing clean the first time is this standard; don't lean on Refine to rescue code
  you could have written well.

## Hold the consistency bar

On top of the clean-code standard, the code you produce must look like it was written by the same
hand as the rest of the repo, and like the rest of itself:

- **With the codebase** — build on the Understand survey: match the neighbouring units' patterns,
  naming, file/layer layout, error handling, and test shape. Reuse existing helpers over adding
  near-duplicates. Don't introduce a second way to do something the repo already does one way.
- **Within the change** — one name per concept across every layer, the same pattern for the same
  problem, uniform ordering and structure. No drift between the files you touched in this run.
- When the existing code is itself inconsistent, follow the dominant convention and note the
  exception in the summary rather than adding a third variant.

## Model policy (plan vs implement)

Spend the expensive reasoning where the ambiguity lives — deciding — and keep execution cheap.

- **Work out *what* to do in the most capable model** (Opus): writing the plan, diagnosing a root
  cause, scoping a refactor. This is where hard reasoning earns its cost.
- **Once that's clear, carry it out with a simple, cheap model.** A well-specified plan makes the
  build mostly mechanical, and running it on a heavy model wastes time and money. When you dispatch
  the Understand survey or implementation subagents, pick the cheapest tier that can execute the step.
- **Escalate execution back to a capable model only when the plan is unclear** or an implementer
  gets stuck — that's a signal the plan needs more thought, not more horsepower.

## Refine (before you hand off)

After Build, before Verify, **critique and clean your own diff** — don't hand raw work to review.
This is what keeps external review focused on real issues instead of mess you could have caught.

- **Self-review.** Read your own diff critically against the approved plan/diagnosis/scope, the
  project `CLAUDE.md`, the in-scope revai skills, the clean-code standard, and the consistency bar
  above. Run the **`naming-and-structure` checklist** over the diff explicitly — every name reveals
  intent, functions are verbs and booleans predicates, one term per concept, each unit has a single
  responsibility, IO at the edges, layers don't leak. Fix what you'd flag in someone else's code —
  dead code, unclear names, a leaked abstraction, an untested branch, drift from the surrounding
  style.
- **Simplify.** Dispatch the **`code-simplifier`** agent over the diff to remove accidental
  complexity, then re-run the tests so simplification changed nothing. **For a Micro change**, do
  this pass yourself inline as part of self-review instead of dispatching the agent.
- **Refactor variant:** for `/revai:refactor`, restructuring *is* the Build, so Refine is the
  behaviour-preserved self-check — confirm zero behaviour change and that the existing tests are
  still green — plus the same critical clarity read, not a second round of reshaping.

## Finish

### Verify

- Run the check commands from `.revai/verify.json` and **read their output** — this is the
  **`superpowers:verification-before-completion`** rule: evidence before assertions, never claim
  something passes without running it. (The verify-on-Stop hook is the backstop; run them here
  yourself and fix what fails.)
- `test` and `lint` are **blocking**; `build` and `format` are advisory.
- If a blocking check can't be made to pass after a few honest attempts, **STOP and report** — do
  not carry a broken build into review or a PR.

### Review

- Dispatch revai's **`backend-review`** agent on the change set — tell it, from the Understand
  survey, which modules/layers/skills the diff actually touches, so it can spend depth there instead
  of speculatively ruling out irrelevant domains. For a change with no backend surface, use
  **`superpowers:requesting-code-review`** instead.
- Work the findings with **`superpowers:receiving-code-review`**: fix every 🔴 High, 🟡 Medium, and
  any **consistency** finding (inconsistent naming/vocabulary, a duplicate way to do something the
  repo already does, or drift between the files you touched) regardless of severity label —
  consistency is a hard requirement here.
- **Re-verify after every fix round, always.** Re-dispatching the full `backend-review` agent is
  capped at **one repeat** (two dispatches total):
  - **Skip the re-dispatch** — do a targeted self-check of just the changed lines against the
    outstanding findings, confirm verify is still green, and proceed — whenever nothing but 🔵
    Low/Questions remains once fixes are applied: either none were found, or every 🔴/🟡 fix was a
    same-file, same-function, mechanical edit.
  - **Re-dispatch the full agent once** if any 🔴/🟡 fix was *not* mechanical in that sense — it
    added a branch/condition, changed a signature, touched a file the first review didn't cover, or
    touched schema/auth/security-sensitive code.
  - If a second full review still leaves a High/Medium unresolved, or a third round would otherwise
    be needed, **STOP and surface it** rather than looping again.

### Ship  ⏸ GATE

- Present a **completion summary**: what changed (by module and layer), the verify results, the
  review verdict, and a proposed **PR title and body**.
- **STOP.** Wait for the user's explicit approval to open the PR.
- On approval, use the **`superpowers:finishing-a-development-branch`** skill to finish up:
  - commit any uncommitted work (the secrets hook runs on commit as usual);
  - `git push -u origin <branch>`;
  - open the PR with `gh pr create`.
- Footers:
  - commit message ends with `Co-Authored-By: Claude <model in use> <noreply@anthropic.com>` —
    name whichever model actually did the work, never a fixed one (it goes stale the moment a
    different tier runs Ship);
  - PR body ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Report the PR URL to the user.
