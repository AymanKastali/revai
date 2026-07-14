---
description: Drive a feature from planning to an open PR — gated at plan and PR — following the project's rules, revai's skills, and its review + verify guardrails.
argument-hint: <feature description, or path to a spec file>
---

# /revai:feature

Take a feature from a description all the way to an open pull request, in one gated pipeline:
**plan → implement → verify → review → PR**. You **orchestrate**; the real work is done by the
`superpowers` skills and revai's own guardrails. Do **not** reimplement planning, plan execution,
TDD, code review, or PR creation — invoke the existing skills for those.

This command owns only the **plan-and-build middle**. The shared spine — preconditions, branch, the
consistency bar, and the verify → review → open-PR finish — lives in the **`shipping-a-change`**
skill. Follow it as noted below.

**Two hard stops.** You STOP and wait for the user's explicit approval **after planning** (before
writing any code) and **before opening the PR**. Everything between those two gates runs
automatically. Never skip a gate.

The argument (`$ARGUMENTS`) is the feature: inline text, or a path to a spec file — read the file
if it's a path.

## 0. Set up

Follow **`shipping-a-change` → Before you begin**. Branch prefix: **`feat/`**.

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
  automatically when the work touches their area, and **hold the consistency bar** from
  `shipping-a-change` throughout. **Never modify a "Do not touch" path.**

## 3. Finish

Follow **`shipping-a-change` → Finish** (verify → review → open PR). At verify, `test`/`lint` are
blocking; in review, dispatch `backend-review` and loop fix→verify→review until clean.
