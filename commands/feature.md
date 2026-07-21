---
description: Drive a feature from planning to an open PR — gated at plan and PR — following the project's rules, revai's skills, and its review + verify guardrails.
argument-hint: <feature description, or path to a spec file>
---

# /revai:feature

Take a feature from a description all the way to an open pull request, through eight explicit stages:
**Set up → Understand → Plan ⏸ → Build → Refine → Verify → Review → Ship ⏸**. You **orchestrate**;
the real work is done by the `superpowers` skills, the `code-simplifier` agent, and revai's
guardrails. Do **not** reimplement exploration, planning, plan execution, TDD, code review, or PR
creation — invoke the existing skills for those.

This command owns only the **Plan + Build middle** (stages 3–4). Every other stage is the shared
spine and lives in the **`shipping-a-change`** skill — follow it where pointed so all three workflows
stay identical outside their middle.

**Two hard stops.** You STOP and wait for the user's explicit approval **after planning** (before
writing any code) and **before opening the PR**. Everything between those two gates runs
automatically. Never skip a gate.

The argument (`$ARGUMENTS`) is the feature: inline text, or a path to a spec file — read the file
if it's a path.

## 1. Set up

Follow **`shipping-a-change` → Before you begin**. Branch prefix: **`feat/`**.

## 2. Understand

Follow **`shipping-a-change` → Understand**, scoped to the area the feature will touch — the modules
it extends, the patterns and contracts already there, the tests around them. Ground the plan in what
the survey finds instead of planning blind.

## 3. Plan  ⏸ GATE

- If the feature has genuine open design questions, invoke the **`superpowers:brainstorming`**
  skill and resolve them one question at a time. If it's already well-specified, skip to plans.
- Invoke the **`superpowers:writing-plans`** skill to produce a written, step-by-step
  implementation plan, built on the Understand survey.
- The plan **must** make revai's concerns explicit:
  - the **module / bounded context** the work belongs to (see `bounded-contexts`);
  - the **layers** touched — `domain` / `app` / `infra` — and the command/query split where it
    applies (see `hexagonal-architecture`);
  - which **skills** are in scope (`domain-modeling`, `api-design`, `data-access-patterns`,
    `safe-schema-changes`, …);
  - the **tests** to write first (TDD), and anything that genuinely can't be TDD'd, called out.
- **Present the plan and STOP.** Wait for the user's explicit approval. **Write no code before it.**
  If they ask for changes, revise and re-present. Only continue once they approve.

## 4. Build  (auto, after the gate)

- Execute the approved plan with the **`superpowers:executing-plans`** skill (use
  **`superpowers:subagent-driven-development`** when the plan's tasks are independent).
- **TDD by default** — invoke the **`superpowers:test-driven-development`** skill: failing test →
  implement → pass → refactor, per behavior. (Only skip for the pieces the plan flagged as
  un-TDD-able.)
- **Verify each increment as you go** — run the relevant checks after each behavior lands
  (**`superpowers:verification-before-completion`**) rather than saving all verification for the
  end. Catch drift early.
- Follow the project `CLAUDE.md` conventions and **hold the clean-code standard + consistency bar**
  from `shipping-a-change` throughout — `naming-and-structure` (intention-revealing names, one
  responsibility per unit, IO at the edges) is always-on, and the area skills (`hexagonal-architecture`,
  `domain-modeling`, `api-design`, `data-access-patterns`, …) surface automatically as the work touches
  them. **Never modify a "Do not touch" path.**
- **Model policy** — the plan is approved and clear, so dispatch the build with a **simple, cheap
  model**; reserve capable models for planning and for any step the plan left ambiguous. See
  `shipping-a-change → Model policy`.

## 5. Refine

Follow **`shipping-a-change` → Refine**: self-review your own diff against the approved plan, the
project `CLAUDE.md`, and the in-scope skills, then run the `code-simplifier` agent over it — before
handing anything to review.

## 6. Verify

Follow **`shipping-a-change` → Finish/Verify**.

## 7. Review

Follow **`shipping-a-change` → Finish/Review**: dispatch `backend-review`, work the findings with
**`superpowers:receiving-code-review`**, and loop until clean.

## 8. Ship  ⏸ GATE

Follow **`shipping-a-change` → Finish/Ship**: present the completion summary and proposed PR, STOP
for approval, then open the PR.
