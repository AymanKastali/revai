---
description: Drive a feature from planning to an open PR — gated at plan and PR — following the project's rules, revai's skills, and its review + verify guardrails.
argument-hint: <feature description, or path to a spec file>
---

# /revai:feature

Take a feature from a description all the way to an open pull request, in one gated pipeline:
**plan → implement → verify → review → PR**. You **orchestrate**; the real work is done by the
`superpowers` skills and revai's own guardrails. Do **not** reimplement planning, plan execution,
TDD, code review, or PR creation — invoke the existing skills for those.

**Two hard stops.** You STOP and wait for the user's explicit approval **after planning** (before
writing any code) and **before opening the PR**. Everything between those two gates runs
automatically. Never skip a gate.

The argument (`$ARGUMENTS`) is the feature: inline text, or a path to a spec file — read the file
if it's a path.

## 0. Preconditions & branch

- **Confirm revai is attached.** Check that both `CLAUDE.md` and `.revai/verify.json` exist in the
  repo root. If either is missing, tell the user to run `/revai:attach` first, and **stop**.
- **Read the project `CLAUDE.md`** into context — the stack, conventions, verify commands, and the
  **"Do not touch"** paths. These govern everything you do below.
- **Get onto a feature branch.** If the current branch is the default (`main`/`master`), create
  `feat/<slug>` off it (derive `<slug>` from the feature). If already on a non-default branch, stay
  on it. **Never work directly on the default branch.**

## 1. Plan  ⏸ GATE 1

- If the feature has genuine open design questions, invoke the `superpowers` **`brainstorming`**
  skill and resolve them one question at a time. If it's already well-specified, skip to plans.
- Invoke the `superpowers` **`writing-plans`** skill to produce a written, step-by-step
  implementation plan.
- The plan **must** make revai's concerns explicit:
  - the **module / bounded context** the work belongs to (see `bounded-contexts`);
  - the **layers** touched — `domain` / `app` / `infra` — and the command/query split where it
    applies (see `hexagonal-architecture`);
  - which **skills** are in scope (`domain-modeling`, `api-design`, `data-access-patterns`,
    `safe-schema-changes`, …);
  - the **tests** to write first (TDD), and anything that genuinely can't be TDD'd, called out.
- **Present the plan and STOP.** Wait for the user's explicit approval. **Write no code before it.**
  If they ask for changes, revise and re-present. Only continue once they approve.

## 2. Implement  (auto, after Gate 1)

- Execute the approved plan with the `superpowers` **`executing-plans`** skill (use
  **`subagent-driven-development`** when the plan's tasks are independent).
- **TDD by default** — invoke the `superpowers` **`test-driven-development`** skill: failing test →
  implement → pass → refactor, per behavior. (Only skip for the pieces the plan flagged as
  un-TDD-able.)
- Follow the project `CLAUDE.md` conventions and the relevant revai skills — they surface
  automatically when the work touches their area. **Never modify a "Do not touch" path.**
- **Be consistent — always.** The generated code must look like it was written by the same hand as
  the rest of the repo, and like the rest of itself:
  - **With the codebase** — before writing a unit, read a neighbouring one and match its patterns,
    naming, file/layer layout, error handling, and test shape. Reuse existing helpers over adding
    near-duplicates. Don't introduce a second way to do something the repo already does one way.
  - **Within the feature** — one name per concept across every layer, the same pattern for the same
    problem, uniform ordering and structure. No drift between files you touched in this run.
  - When the existing code is itself inconsistent, follow the dominant convention and note the
    exception in the plan/summary rather than adding a third variant.

## 3. Verify  (auto)

- Run the check commands from `.revai/verify.json` and **read their output** — this is the
  `superpowers` **`verification-before-completion`** rule: evidence before assertions, never claim
  something passes without running it. (The verify-on-Stop hook is the backstop; run them here
  yourself and fix what fails.)
- `test` and `lint` are **blocking**; `build` and `format` are advisory.
- If a blocking check can't be made to pass after a few honest attempts, **STOP and report** — do
  not carry a broken build into review or a PR.

## 4. Review  (auto)

- Dispatch revai's **`backend-review`** agent on the change set to audit it against all the skills.
  For a change with no backend surface, use the `superpowers` **`requesting-code-review`** skill
  instead.
- Work the findings: fix every 🔴 High and 🟡 Medium, then **re-verify (step 3) and re-review**,
  looping until the review is clean or only accepted Low/Questions remain.
- Treat any **consistency** finding (inconsistent naming/vocabulary, a duplicate way to do something
  the repo already does, or drift between the files you touched) as worth fixing regardless of its
  severity label — consistency is a hard requirement here, not a nicety.
- If a High finding can't be resolved, **STOP and surface it** rather than shipping around it.

## 5. Open PR  ⏸ GATE 2

- Present a **completion summary**: what changed (by module and layer), the verify results, the
  review verdict, and a proposed **PR title and body**.
- **STOP.** Wait for the user's explicit approval to open the PR.
- On approval, use the `superpowers` **`finishing-a-development-branch`** skill to finish up:
  - commit any uncommitted work (the secrets hook runs on commit as usual);
  - `git push -u origin <branch>`;
  - open the PR with `gh pr create`.
- Footers:
  - commit message ends with
    `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`;
  - PR body ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Report the PR URL to the user.
