---
description: Take an approved decision (from /revai:decide, or a trivial inline change) and drive it to an open PR — build/fix/reshape, self-review, verify, review, ship. The only place in the harness where the repo actually gets mutated.
argument-hint: <path to a /revai:decide artifact, or an inline description of a trivial change>
---

# /revai:implement

Take an already-approved decision and turn it into working, tested, reviewed code through eight
stages: **Set up → Load the decision → Approve & branch ⏸ → Build/Fix/Transform → Refine → Verify →
Review → Ship ⏸**. You **orchestrate** — the `superpowers` skills, the `code-simplifier` and
`backend-review` agents, and revai's guardrails do the actual execution, TDD, review, and PR work;
don't reimplement any of it.

**This is the only command in the harness that mutates the repo** — creates the branch, writes
code, commits, opens the PR. `/revai:decide` never does; if you don't have a decision yet, run that
first.

**Two hard stops:** right before the branch is created (so declining leaves the repo untouched),
and before opening the PR. Everything between runs automatically — never skip a gate.

The argument (`$ARGUMENTS`) is a path to a `/revai:decide` artifact (`docs/design/<slug>.md`,
`docs/superpowers/plans/...`, or `docs/decisions/<slug>.md`), or — for a change trivial enough not
to need one — an inline description.

## 1. Set up

- **Confirm revai is attached.** Check that both `CLAUDE.md` and `.revai/verify.json` exist in the
  repo root. If either is missing, tell the user to run `/revai:attach` first, and **stop**.
- **Read the project `CLAUDE.md`** into context — the stack, conventions, verify commands, and the
  **"Do not touch"** paths. These govern everything you do below.

## 2. Load the decision

- **Given a path:** read it and classify by its shape — an Architecture slice (`docs/design/`, a
  named build-order slice), a Plan (`docs/superpowers/plans/`), or a Defect/Reshape
  (`docs/decisions/`, by its `type:` header). If it's a multi-slice Architecture doc, confirm which
  slice this run targets.
- **Given inline text with no artifact:** classify it as **Micro** using this bar, with no
  exceptions —
  - the exact lines to touch are already known, right now, without exploring further;
  - touches at most 2 files with a small diff (rough guide: under ~20 changed lines) — pure wiring,
    config, comments/docs, or a one-line logic fix;
  - introduces no new type, exported function/method signature, endpoint, public contract, or
    dependency;
  - touches no schema/migration, no auth/payments/security-sensitive path, crosses no
    bounded-context boundary — these are **never** Micro regardless of size;
  - no open design question, no real doubt about correctness.
  State the one-line decision right here, in place of a doc: the exact file and change, and why it's
  safe. Still a decision — same gate below, not a lighter one.
- **If a real artifact was loaded:** do a light re-check against the current repo state — dispatch
  an Explore subagent off your main context to confirm the files/contracts it references still
  look as described, reporting back only a short structured note (drift found or not), not a raw
  file dump. This is not a full re-survey; flag drift rather than silently trusting a plan that may
  have gone stale.

## 3. Approve & branch  ⏸ GATE

- **Present** what's about to be built/fixed/reshaped — from the loaded decision, or the inline
  Micro statement — and **STOP**. Wait for the user's explicit approval.
- **Only on approval**, get onto a branch: if on the default branch (`main`/`master`), create
  `<prefix>/<slug>` off it — `feat/` for an Architecture-slice or Plan, `fix/` for a Defect,
  `refactor/` for a Reshape. If already on a non-default branch, stay on it. **Never create the
  branch, or touch the repo in any way, before this gate is approved** — declining here must leave
  the repo exactly as it was.

## 4. Build / Fix / Transform  (auto, after the gate)

Execute per the loaded classification:

- **Architecture-slice / Plan:** run the approved plan with `superpowers:executing-plans` (use
  `superpowers:subagent-driven-development` when its tasks are independent). **TDD by default** —
  `superpowers:test-driven-development`: failing test → implement → pass → refactor, per behaviour.
  Verify each increment as it lands (`superpowers:verification-before-completion`) rather than
  saving all checks for the end.
- **Defect:** first, write the regression test `/revai:decide` **described** — confirm it fails
  (RED) against the current, buggy code. Then make the **minimal** change that turns it green
  (`superpowers:test-driven-development`, green-then-refactor) — fix the **root cause**, not the
  symptom. **No scope creep** — anything else you notice becomes a follow-up note, not an in-scope
  fix.
- **Reshape:** first, write the characterization test(s) `/revai:decide` flagged as missing —
  confirm they pass against the **current** behaviour; this is the safety net, not the change. Then
  apply **behaviour-preserving** transformations via the `code-simplifier` agent, in small steps,
  keeping tests green between each one. If a test goes red, you changed behaviour — revert that
  step and rethink; never edit the test to make it pass, and never edit a "Do not touch" path.
- **Throughout, regardless of classification:** `clean-code` and `best-practices` stay always-on
  (intention-revealing names, one responsibility per unit, standard-solution-first); `best-practices`'
  own reference set (api-design, data-access-patterns, safe-schema-changes, config-and-secrets,
  resilience-and-timeouts, concurrency-and-context-safety, backend-testing, error-handling-and-logging,
  event-driven-messaging, authn-and-authorization, observability, caching) surfaces automatically as
  the work touches each concern; `domain-driven-design` (its tactical-patterns and
  architecture-and-layering references, plus event-sourcing and process-managers-and-integration
  where the diff actually touches an event-sourced aggregate or a multi-step/cross-context workflow)
  surfaces for aggregates/invariants and layering/bounded contexts. Match the surrounding repo's
  existing patterns — don't introduce a second way to do something it already does one way.
- **Model policy** — the decision is approved and clear, so build with a **simple, cheap model**;
  escalate back to a capable model only if execution turns out not to be mechanical after all.

## 5. Refine

- **Self-review.** Read your own diff critically against the loaded decision, the project
  `CLAUDE.md`, and the in-scope skills. Fix what you'd flag in someone else's code — dead code,
  unclear names, a leaked abstraction, an untested branch, drift from the surrounding style.
- **Simplify.** Dispatch the `code-simplifier` agent over the diff, then re-run the tests so
  simplification changed nothing. **For a Micro change**, do this pass yourself inline instead of
  dispatching the agent.
- **Reshape variant:** restructuring *is* the Build here, so Refine is the behaviour-preserved
  self-check — confirm zero behaviour change and that the same tests are still green — plus the
  same critical clarity read, not a second round of reshaping.

## 6. Verify

- Run the check commands from `.revai/verify.json` and **read their output** — evidence before
  assertions, never claim something passes without running it.
- `test` and `lint` are **blocking**; `build` and `format` are advisory.
- If a blocking check can't be made to pass after a few honest attempts, **STOP and report** — don't
  carry a broken build into review or a PR.

## 7. Review

- Dispatch revai's `backend-review` agent on the change set — tell it, from what was loaded/built,
  which modules/layers/skills the diff actually touches, so it spends depth there instead of
  speculatively ruling out irrelevant domains. For a change with no backend surface, use
  `superpowers:requesting-code-review` instead.
- Work the findings with `superpowers:receiving-code-review`: fix every 🔴 High, 🟡 Medium, and any
  **consistency** finding (inconsistent naming/vocabulary, a duplicate way to do something the repo
  already does, drift between the files you touched) regardless of severity label.
- **Re-verify after every fix round, always.** Re-dispatching the full `backend-review` agent is
  capped at **one repeat** (two dispatches total):
  - **Skip the re-dispatch** — targeted self-check of just the changed lines, confirm verify is
    still green, proceed — whenever nothing but 🔵 Low/Questions remains: either none were found, or
    every 🔴/🟡 fix was a same-file, same-function, mechanical edit.
  - **Re-dispatch once** if any 🔴/🟡 fix was *not* mechanical in that sense — added a
    branch/condition, changed a signature, touched a file the first review didn't cover, or touched
    schema/auth/security-sensitive code.
  - If a second full review still leaves a High/Medium unresolved, **STOP and surface it** rather
    than looping again.

## 8. Ship  ⏸ GATE

- Present a **completion summary**: what changed (by module and layer), the verify results, the
  review verdict, and a proposed **PR title and body**.
- **STOP.** Wait for the user's explicit approval to open the PR.
- On approval, use `superpowers:finishing-a-development-branch`:
  - commit any uncommitted work (the secrets hook runs on commit as usual);
  - `git push -u origin <branch>`;
  - open the PR with `gh pr create`.
- Footers:
  - commit message ends with `Co-Authored-By: Claude <model in use> <noreply@anthropic.com>` — name
    whichever model actually did the work, never a fixed one;
  - PR body ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Report the PR URL to the user.
