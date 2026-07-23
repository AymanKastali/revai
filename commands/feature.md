---
description: Drive a feature from planning to an open PR — gated at plan and PR — following the project's rules, revai's skills, and its review + verify guardrails.
argument-hint: <feature description, or path to a spec file>
---

# /revai:feature

Take a feature from a description to an open pull request through eight stages: **Set up →
Understand → Plan ⏸ → Build → Refine → Verify → Review → Ship ⏸**. You **orchestrate** — the
`superpowers` skills, `code-simplifier`, and revai's guardrails do the actual planning, execution,
TDD, review, and PR work; don't reimplement any of it.

This command owns only **Plan + Build** (stages 3–4); every other stage lives in the shared
**`shipping-a-change`** skill — follow it where pointed so all three change workflows stay identical
outside their middle.

**Two hard stops:** after planning (before any code) and before opening the PR. Everything between
runs automatically — never skip a gate.

The argument (`$ARGUMENTS`) is the feature: inline text, or a path to a spec file — read the file
if it's a path.

## 1. Set up

Follow **`shipping-a-change` → Before you begin**. Branch prefix: **`feat/`**.

## 2. Understand

Follow **`shipping-a-change` → Understand**, scoped to the area the feature will touch — the modules
it extends, the patterns and contracts already there, the tests around them. Ground the plan in what
the survey finds instead of planning blind.

## 3. Plan  ⏸ GATE

- If the change is classified **Micro** (`shipping-a-change` → **Size the change**), skip straight
  to the Micro plan bullet below — brainstorming/divide-and-conquer/writing-plans exist for
  ambiguity and scope this change doesn't have.
- If the user already has an approved plan from **`/revai:prepare`** for this exact scope, confirm
  it still matches the Understand survey above and use it directly — skip straight to presenting
  it. Otherwise:
- If the feature has genuine open design questions, invoke the **`superpowers:brainstorming`**
  skill and resolve them one question at a time — weigh candidate approaches through
  **`best-practices`**' standard-first bias. If it's already well-specified, skip to plans.
- If the Understand survey shows the feature is too big for one PR (see the **`divide-and-conquer`**
  signal check — spans multiple bounded contexts, would take multiple sessions, bundles
  independently-valuable capabilities), invoke it first to decide the slice sequence, then scope
  this plan to slice 1 only.
- Invoke the **`superpowers:writing-plans`** skill to produce a written, step-by-step
  implementation plan, built on the Understand survey.
- The plan **must** make revai's concerns explicit:
  - the **module / bounded context** the work belongs to (see `bounded-contexts`);
  - the **layers** touched — `domain` / `app` / `infra` — and the command/query split where it
    applies (see `hexagonal-architecture`);
  - which **skills** are in scope (`domain-modeling`, `api-design`, `data-access-patterns`,
    `safe-schema-changes`, …);
  - the **tests** to write first (TDD), and anything that genuinely can't be TDD'd, called out.
- **Micro plan (only for a Micro-classified change):** state, inline, in place of the full plan
  document — the exact file and change, why it's safe (what Understand confirmed), and whether a
  test is needed and why/why not. Still a plan — same gate below, not a lighter one.
- **Present the plan and STOP.** Wait for the user's explicit approval. **Write no code before it.**
  If they ask for changes, revise and re-present. Only continue once they approve.

## 4. Build  (auto, after the gate)

- Execute the approved plan with the **`superpowers:executing-plans`** skill (use
  **`superpowers:subagent-driven-development`** when the plan's tasks are independent). A Micro
  change is a single task by definition — execute it directly; don't dispatch subagents for it.
- **TDD by default** — invoke the **`superpowers:test-driven-development`** skill: failing test →
  implement → pass → refactor, per behavior. (Only skip for the pieces the plan flagged as
  un-TDD-able.)
- **Verify each increment as you go** — run the relevant checks after each behavior lands
  (**`superpowers:verification-before-completion`**) rather than saving all verification for the
  end. Catch drift early.
- Follow the project `CLAUDE.md` conventions and **hold the clean-code standard + consistency bar**
  from `shipping-a-change` → **Write clean code** throughout — `naming-and-structure` and
  `best-practices` stay always-on, and the area skills (`hexagonal-architecture`, `domain-modeling`,
  `api-design`, `data-access-patterns`, …) surface automatically as the work touches them. **Never
  modify a "Do not touch" path.**
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

Follow **`shipping-a-change` → Finish/Review**.

## 8. Ship  ⏸ GATE

Follow **`shipping-a-change` → Finish/Ship**.
