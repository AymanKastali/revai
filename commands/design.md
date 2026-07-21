---
description: Turn an idea (or a new area of an existing repo) into a right-sized architecture design — interrogates you until it understands, neutrally recommends the fitting architecture, and writes it to docs/design/<slug>.md. Read-only + one doc; hands off to /revai:prepare (or /revai:feature directly for a simple slice).
argument-hint: <the idea to design, a path to a brief, or an area of an existing repo>
---

# /revai:design

Lay the grounds before any code exists. Explain an idea; this command **interrogates it until the
design space is understood**, then **neutrally recommends** the architecture that actually fits — a
rich domain-driven, hexagonal design, a simple layered app, or a plain script/library, whichever the
problem warrants — and writes it up as the design `/revai:feature` will build from. You
**orchestrate**: `superpowers:brainstorming` runs the question-asking, `designing-architecture` owns
the fit judgment and the doc shape, and the atomic architecture skills fill it in.

This is the **upstream** step to the change workflows. It is **read-only plus one doc**: it surveys,
interrogates, and writes a single design file — **no code, no branch, no PR.**

This command runs **six stages** with **one gate**:

```
Frame → Survey → Interrogate → Recommend architecture ⏸ → Design & deliver → Hand off ↺
```

The argument (`$ARGUMENTS`) is the idea: inline text, or a path to a brief — read the file if it's a
path. If it's empty, ask what to design and stop.

## 1. Frame

- Read the idea. If it names an **area of an existing repo**, treat that as the scope.
- If a project `CLAUDE.md` exists, read it for the stack and conventions — but **do not require
  `/revai:attach`**; this command works on a bare idea with no repo at all.
- Detect the situation: **greenfield** (empty or near-empty repo, or a pure idea) vs. an **existing
  codebase** the design must fit into.
- Derive a kebab-case slug from the idea; the target file is `docs/design/<slug>.md` in the current
  repo. If it already exists, tell the user and ask whether to **refresh** it or **extend** it — never
  silently overwrite.

## 2. Survey  (existing codebase only)

- If there's an existing codebase, dispatch `explaining-code` / Explore subagent(s) **off your main
  context** to map the current architecture, module boundaries, naming, and stack — the move
  `/revai:explain` uses — so the design fits what's there instead of fighting it. Ask for structured
  notes, not raw file dumps.
- **Skip this stage entirely for greenfield.** There's nothing to survey.
- **Model policy** — run the survey on the cheapest tier that can do it (see
  `shipping-a-change → Model policy`).

## 3. Interrogate

- Invoke the `superpowers:brainstorming` skill and follow its **one-question-at-a-time** rule.
- **Keep asking until the architecture-determining unknowns are resolved** — do not shortcut to a
  design because the idea sounds clear. Aim the questioning at what actually decides the shape:
  - the **domain** and its rules/invariants — what must always hold true;
  - **who uses it** and the handful of key flows;
  - the **subdomains**, and which is the core worth protecting;
  - **scale, consistency, and latency** needs;
  - **integrations** and external systems it must talk to;
  - **constraints** — team size, deadline, and the existing/required stack.
- Stop the loop only when you could defend an architecture choice from the answers.

## 4. Recommend architecture  ⏸ GATE

- Invoke the `designing-architecture` skill and apply its **fit judgment**: assess **neutrally** where
  the real complexity lives and recommend the lightest structure that still protects what matters —
  **rich** (modular monolith, internally hexagonal, strategic + tactical DDD), **moderate** (simple
  layered app, DDD tactics only where they pay), or **thin** (CRUD/script/library, no ceremony).
- **Present the recommendation and STOP.** Show the recommended weight and shape, the module/context
  boundaries, the subdomain map, the reasoning tied to the interrogation, and **2–3 alternatives with
  the trade-off that ruled each out**. Wait for the user's pick. **Write no design doc before this** —
  the gate confirms the shape before the full design is spent on it. If they choose differently or
  redirect, adjust and re-present.

## 5. Design & deliver  (auto, after the gate)

- Flesh out the chosen architecture **at the agreed weight**, following the `designing-architecture`
  template. For a rich design, sequence the atomic skills — `bounded-contexts` (boundaries, ubiquitous
  language, subdomain classes) → `domain-modeling` (aggregates, value objects, invariants, events) →
  `hexagonal-architecture` (module layout, layers, CQRS) → the edge skills (`api-design`,
  `data-access-patterns`, `safe-schema-changes`, `config-and-secrets`, `resilience-and-timeouts`,
  `backend-testing`). For a lighter design, use only the proportionate structure and **force nothing**.
- Name everything per `naming-and-structure` — the design sets the vocabulary the code inherits.
- Write it to `docs/design/<slug>.md`. Report the path, a short summary, the **recommended build order
  (the slices)**, and the **open questions / risks**.

## 6. Hand off  ↺

- Point to **`/revai:prepare`** to turn the first slice into a step-by-step implementation plan (or
  straight to **`/revai:feature`** if the slice is simple enough to plan inline).
- Offer to refine the design or drill into a single context — apply every edit to the **same file** so
  it stays the one source of truth. **No code, no PR** — the design ends here.
