---
description: Drive a behaviour-preserving refactor to an open PR — gated after scope+safety-net, then at PR — tests stay green throughout, zero behaviour change.
argument-hint: <what to refactor and why — the smell, the target shape>
---

# /revai:refactor

Take a refactor from intent all the way to an open pull request, in one gated pipeline:
**scope → safety net → transform → verify → review → PR**. You **orchestrate**; the transformation
itself leans on the `code-simplifier` plugin and revai's guardrails.

This command owns only the **transform middle**. The shared spine — preconditions, branch, the
consistency bar, and the verify → review → open-PR finish — lives in the **`shipping-a-change`**
skill. Follow it as noted below.

**The iron rule of this workflow: no behaviour change.** A refactor changes the shape of the code,
never what it does. The existing tests do **not** change and must stay green the entire time; you add
no test that asserts *new* behaviour. If a change would alter behaviour, it isn't a refactor — stop
and route it through `/revai:feature` or `/revai:bugfix` instead.

**Two hard stops.** You STOP and wait for the user's explicit approval **after scoping** (before
touching code) and **before opening the PR**. Never skip a gate.

The argument (`$ARGUMENTS`) is the refactor: the smell to remove, the target shape, or a path — read
the file if it's a path.

## 1. Set up

Follow **`shipping-a-change` → Before you begin**. Branch prefix: **`refactor/`**.

## 2. Scope & safety net  ⏸ GATE

- **Bound the scope.** State exactly what will change and — just as important — what must **not**:
  the public API, the observable behaviour, the contracts. A refactor with a fuzzy boundary becomes
  a rewrite.
- **Pin the behaviour before touching it.** Behaviour must be covered by tests *before* you
  transform. Confirm a **characterization safety net** exists over the code in scope. If coverage is
  thin, **add characterization tests first** — the one place in this workflow you write tests. They
  capture *current* behaviour exactly as it is (warts and all), not behaviour you wish it had.
- **Present and STOP.** Show the scope (what changes / what's frozen), what the safety net covers,
  and the seam you'll work along. Wait for the user's explicit approval. **Transform nothing before
  it.**

## 3. Transform  (auto, after the gate)

- Apply **behaviour-preserving transformations** — lean on the **`code-simplifier`** plugin's skills
  (or dispatch the `code-simplifier` agent) for the actual reshaping.
- Work in **small steps and keep the tests green between each one.** If a test goes red, you changed
  behaviour — revert that step and rethink. The existing tests are not edited to "make them pass".
- Hold the public contract identical unless the approved scope explicitly said otherwise.
- Follow the project `CLAUDE.md` and the relevant revai skills, and **hold the consistency bar** from
  `shipping-a-change` throughout. **Never modify a "Do not touch" path.**
- **Model policy** — the scope and seam are approved, so run the transformation with a **simple,
  cheap model**; reserve capable models for scoping and for anything the plan left ambiguous. See
  `shipping-a-change → Model policy`.

## 4. Finish

Follow **`shipping-a-change` → Finish** (verify → review → open PR). At verify, the **same** tests
that were green before must be green after — that is the proof behaviour didn't change. In review,
the emphasis is **zero behaviour change** and an **identical public contract**.
