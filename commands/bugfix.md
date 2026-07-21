---
description: Drive a bug from reproduction to an open PR — gated after root-cause, then at PR — reproduce first, capture it in a failing test, fix the cause not the symptom.
argument-hint: <bug description, the wrong behaviour, or an issue reference>
---

# /revai:bugfix

Take a bug from a report all the way to an open pull request, through eight explicit stages:
**Set up → Understand → Reproduce & diagnose ⏸ → Fix → Refine → Verify → Review → Ship ⏸**. You
**orchestrate**; the real work is done by the `superpowers` skills, the `code-simplifier` agent, and
revai's guardrails.

This command owns only the **diagnose + fix middle** (stages 3–4). Every other stage is the shared
spine and lives in the **`shipping-a-change`** skill — follow it where pointed.

**Two hard stops.** You STOP and wait for the user's explicit approval **after diagnosis** (before
writing the fix) and **before opening the PR**. Never skip a gate.

The argument (`$ARGUMENTS`) is the bug: a description, the observed wrong behaviour, or a path/issue
reference — read the file if it's a path.

## 1. Set up

Follow **`shipping-a-change` → Before you begin**. Branch prefix: **`fix/`**.

## 2. Understand

Follow **`shipping-a-change` → Understand**, scoped to the code path around the symptom — the module
that produces the wrong behaviour, its collaborators, and the existing tests over it. This grounds
the diagnosis so you debug the real code, not a guess about it.

## 3. Reproduce & diagnose  ⏸ GATE

- Invoke the **`superpowers:systematic-debugging`** skill — don't guess at a fix. Work from the
  symptom to the cause methodically.
- **Reproduce the bug deterministically** first. If you can't reproduce it, say so and stop — a fix
  you can't prove is a guess.
- **Write a failing test that captures the bug** (RED). Use the `tdd` skill for the right layer and
  what to assert — the test asserts the *correct* behaviour, so it fails against the buggy code.
  **This test is the regression guard** that ships with the fix.
- **Identify the root cause** — the actual defect, not the surface symptom. Name it.
- **Present and STOP.** Show the reproduction, the failing test, and the root cause. Wait for the
  user's explicit approval. **Write no fix before it.** If they disagree with the diagnosis, dig
  again and re-present.

## 4. Fix  (auto, after the gate)

- Make the **minimal** change that turns the red test green — invoke the **`superpowers:test-driven-development`** skill (green, then refactor). Fix the **root cause**, not the symptom.
- **Verify as you go** — confirm the regression test flips to green and the suite stays green
  (**`superpowers:verification-before-completion`**), rather than deferring all checks to the end.
- **No scope creep.** Fix only the diagnosed bug. Anything else you notice — a nearby smell, a
  second latent bug — gets noted as follow-up in the summary, not fixed in this run.
- Follow the project `CLAUDE.md` and **hold the clean-code standard + consistency bar** from
  `shipping-a-change` throughout — `naming-and-structure` is always-on even for a one-line fix, and the
  area skills surface automatically as the fix touches them. **Never modify a "Do not touch" path.**
- **Model policy** — with the root cause diagnosed, the fix is a clear, small change: implement it
  with a **simple, cheap model**, escalating only if it turns out not to be clear-cut. See
  `shipping-a-change → Model policy`.

## 5. Refine

Follow **`shipping-a-change` → Refine**: self-review the diff against the diagnosis, the project
`CLAUDE.md`, and the in-scope skills, then run the `code-simplifier` agent over it — confirming the
fix stayed minimal and on the root cause.

## 6. Verify

Follow **`shipping-a-change` → Finish/Verify**. Confirm the new regression test passes and the rest
of the suite is still green.

## 7. Review

Follow **`shipping-a-change` → Finish/Review**: dispatch `backend-review`, work the findings with
**`superpowers:receiving-code-review`**, and loop until clean — the emphasis is that the fix addresses the **root
cause** and the regression guard is in place.

## 8. Ship  ⏸ GATE

Follow **`shipping-a-change` → Finish/Ship**: present the completion summary and proposed PR, STOP
for approval, then open the PR.
