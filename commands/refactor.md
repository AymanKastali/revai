---
description: Drive a behaviour-preserving refactor to an open PR — gated after scope+safety-net, then at PR — tests stay green throughout, zero behaviour change.
argument-hint: <what to refactor and why — the smell, the target shape>
---

# /revai:refactor

Take a refactor from intent all the way to an open pull request, through eight explicit stages:
**Set up → Understand → Scope & safety net ⏸ → Transform → Refine → Verify → Review → Ship ⏸**. You
**orchestrate**; the transformation itself leans on the `code-simplifier` agent and revai's
guardrails. Do **not** reimplement exploration, safety-net construction, transformation mechanics,
code review, or PR creation — invoke the existing skills for those.

This command owns only the **scope + transform middle** (stages 3–4). Every other stage is the
shared spine and lives in the **`shipping-a-change`** skill — follow it where pointed.

**The iron rule of this workflow: no behaviour change.** A refactor changes the shape of the code,
never what it does. The existing tests do **not** change and must stay green the entire time; you add
no test that asserts *new* behaviour. If a change would alter behaviour, it isn't a refactor — stop
and route it through `/revai:feature` or `/revai:bugfix` instead.

**Two hard stops.** You STOP and wait for the user's explicit approval **after scoping** (before
touching code) and **before opening the PR**. Everything between those two gates runs
automatically. Never skip a gate.

The argument (`$ARGUMENTS`) is the refactor: the smell to remove, the target shape, or a path — read
the file if it's a path.

## 1. Set up

Follow **`shipping-a-change` → Before you begin**. Branch prefix: **`refactor/`**.

## 2. Understand

Follow **`shipping-a-change` → Understand**, scoped to the code in scope for the refactor — the unit
to reshape, everything that depends on it, and the tests that currently pin its behaviour. This tells
you where the seam is and what the public contract to preserve actually is.

## 3. Scope & safety net  ⏸ GATE

- **Bound the scope.** State exactly what will change and — just as important — what must **not**:
  the public API, the observable behaviour, the contracts. A refactor with a fuzzy boundary becomes
  a rewrite.
- If the scope is large (the smell spans enough files/call sites that one diff would dwarf a single
  review), invoke **`divide-and-conquer`** to sequence it into a series of small,
  behaviour-preserving PRs (strangler-fig style) — each keeping tests green and `main` shippable —
  instead of one sprawling transform.
- **Pin the behaviour before touching it.** Behaviour must be covered by tests *before* you
  transform. Confirm a **characterization safety net** exists over the code in scope. If coverage is
  thin, **add characterization tests first** (`tdd`) — the one place in this workflow you write
  tests. They capture *current* behaviour exactly as it is (warts and all), not behaviour you wish it
  had.
- **Present and STOP.** Show the scope (what changes / what's frozen), what the safety net covers,
  and the seam you'll work along. Wait for the user's explicit approval. **Transform nothing before
  it.**

## 4. Transform  (auto, after the gate)

- Apply **behaviour-preserving transformations** — lean on the **`code-simplifier`** agent for the
  actual reshaping.
- Work in **small steps and keep the tests green between each one** (**`superpowers:verification-before-completion`**). If a test goes red, you changed behaviour — revert that step
  and rethink. The existing tests are not edited to "make them pass".
- Hold the public contract identical unless the approved scope explicitly said otherwise.
- Follow the project `CLAUDE.md` and **hold the clean-code standard + consistency bar** from
  `shipping-a-change` throughout — reshaping toward `naming-and-structure` (clear names, single
  responsibility, IO at the edges, layers that don't leak) is the point of most refactors, so treat it
  as the target, not a side note. Where the smell is bespoke logic duplicating a standard solution,
  prefer reshaping toward that standard shape (see `best-practices`) — behaviour held fixed
  throughout. **Never modify a "Do not touch" path.**
- **Model policy** — the scope and seam are approved, so run the transformation with a **simple,
  cheap model**; reserve capable models for scoping and for anything left ambiguous. See
  `shipping-a-change → Model policy`.

## 5. Refine

Follow **`shipping-a-change` → Refine** — the behaviour-preserved variant: since transforming *is*
the Build, Refine is the self-check that behaviour didn't change (the same tests are still green) plus
a critical clarity read of the diff, not a second round of reshaping.

## 6. Verify

Follow **`shipping-a-change` → Finish/Verify**. The **same** tests that were green before must be
green after — that is the proof behaviour didn't change.

## 7. Review

Follow **`shipping-a-change` → Finish/Review**: dispatch `backend-review`, work the findings with
**`superpowers:receiving-code-review`**, following its capped re-dispatch rule (at most one repeat,
then STOP and surface) — the emphasis is **zero behaviour change** and an **identical public
contract**.

## 8. Ship  ⏸ GATE

Follow **`shipping-a-change` → Finish/Ship**: present the completion summary and proposed PR, STOP
for approval, then open the PR.
