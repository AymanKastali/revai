---
description: Drive a bug from reproduction to an open PR — gated after root-cause, then at PR — reproduce first, capture it in a failing test, fix the cause not the symptom.
argument-hint: <bug description, the wrong behaviour, or an issue reference>
---

# /revai:bugfix

Take a bug from a report all the way to an open pull request, in one gated pipeline:
**reproduce → failing test → root cause → minimal fix → verify → review → PR**. You
**orchestrate**; the real work is done by the `superpowers` skills and revai's guardrails.

This command owns only the **diagnose-and-fix middle**. The shared spine — preconditions, branch,
the consistency bar, and the verify → review → open-PR finish — lives in the **`shipping-a-change`**
skill. Follow it as noted below.

**Two hard stops.** You STOP and wait for the user's explicit approval **after diagnosis** (before
writing the fix) and **before opening the PR**. Never skip a gate.

The argument (`$ARGUMENTS`) is the bug: a description, the observed wrong behaviour, or a path/issue
reference — read the file if it's a path.

## 0. Set up

Follow **`shipping-a-change` → Before you begin**. Branch prefix: **`fix/`**.

## 1. Reproduce & diagnose  ⏸ GATE 1

- Invoke the `superpowers` **`systematic-debugging`** skill — don't guess at a fix. Work from the
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

## 2. Fix  (auto, after Gate 1)

- Make the **minimal** change that turns the red test green — invoke the `superpowers`
  **`test-driven-development`** skill (green, then refactor). Fix the **root cause**, not the symptom.
- **No scope creep.** Fix only the diagnosed bug. Anything else you notice — a nearby smell, a
  second latent bug — gets noted as follow-up in the summary, not fixed in this run.
- Follow the project `CLAUDE.md` and the relevant revai skills, and **hold the consistency bar** from
  `shipping-a-change` throughout. **Never modify a "Do not touch" path.**
- **Model policy** — with the root cause diagnosed, the fix is a clear, small change: implement it
  with a **simple, cheap model**, escalating only if it turns out not to be clear-cut. See
  `shipping-a-change → Model policy`.

## 3. Finish

Follow **`shipping-a-change` → Finish** (verify → review → open PR). At verify, confirm the new
regression test now passes and the rest of the suite is still green. In review, the emphasis is that
the fix addresses the **root cause** and the regression guard is in place.
