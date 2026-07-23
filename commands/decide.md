---
description: Every judgment call that must happen before code changes — a new architecture, a feature's plan, a bug's root cause, a refactor's scope — classified automatically and scaled to the stakes, ending in exactly one written, approved artifact. Read-only, always — no code, no branch, ever. Works with or without an attached repo.
argument-hint: <the idea, spec, bug description, or refactor target — or a path to any of these>
---

# /revai:decide

Every kind of judgment call a change needs before any code is touched — lives here, in one place,
through four stages: **Frame → Survey → Decide ⏸ → Deliver & hand off ↺**. You **orchestrate** —
`superpowers:brainstorming`, `domain-driven-design` (its architecture-fit reference),
`systematic-debugging`, `writing-plans`, and `best-practices` (its pr-sizing reference) do the
actual thinking; don't reimplement any of it.

**This command never touches the repo.** No code, no branch, no commit — under any classification,
with no exceptions. Its only output is one written artifact and your explicit approval of it. That
is what makes it safe to run on a bare idea with no repo at all, and safe to hand its output to
`/revai:implement` in a different session, possibly a different day.

**One hard stop:** the Decide gate. Nothing before it commits you to anything; nothing after it
runs without your approval.

The argument (`$ARGUMENTS`) is the thing to decide: inline text, or a path to a brief/spec/design —
read the file if it's a path. If it's empty, ask what to decide and stop.

## 1. Frame

- Read the input. If **multiple** paths are given, read all of them and reconcile — call out any
  overlap or conflict explicitly, never silently pick one.
- **Classify** the request into exactly one of:
  - **Architecture** — a new system, or a substantial new area/bounded context of an existing one.
    Signals: no chosen shape yet, open questions about the domain, who uses it, scale.
  - **Plan** — a new capability/behaviour to add to an existing system whose shape is already
    settled; only the steps to get there aren't decided.
  - **Defect** — something is currently behaving wrong.
  - **Reshape** — restructure the code with **zero** behaviour change.
  Read the language: "add X" / "design X" reads as Architecture or Plan depending on whether the
  shape is already decided; "X is wrong/broken/silently does Y" reads as Defect; "extract/rename/
  simplify X, same behaviour" reads as Reshape. **If the text is genuinely ambiguous, ask exactly
  one clarifying question before doing anything else** — never silently guess.
- If a decision doc already exists for this exact scope (`docs/design/<slug>.md` or
  `docs/decisions/<slug>.md`), say so and ask whether to **refresh** or **extend** it — never
  silently overwrite.
- If a project `CLAUDE.md` exists, read it for stack and conventions — but **do not require
  `/revai:attach`**; Architecture decisions must work on a bare idea with no repo at all.

## 2. Survey

- **Skip entirely** for a greenfield Architecture decision — there is nothing to survey.
- Otherwise, ground in the actual codebase before deciding: dispatch Explore subagent(s) **off your
  main context**, scoped to whatever the classification implies — the existing architecture and
  module boundaries (Architecture, fitting into a live repo), the feature's target modules and
  their contracts/tests (Plan), the buggy code path and its collaborators (Defect), or the code in
  refactor scope (Reshape). Ask for a **structured survey note**, not a raw file dump — what it
  does, the stack/entry points, the architecture as simple indented text, the key modules and their
  responsibilities, one representative flow traced end-to-end, and any relevant "Do not touch"
  path. Ground every claim in real files; omit what can't be verified rather than guess.
- **Model policy** — run the survey on the cheapest tier that can do it; save the capable model for
  the Decide stage next.

## 3. Decide  ⏸ GATE

Apply the method that matches the classification, at a depth proportional to the stakes — never
more ceremony than the decision warrants, never less rigor than it requires:

- **Architecture:** invoke `superpowers:brainstorming` and keep asking, one question at a time,
  until the architecture-determining unknowns are resolved — the domain and its invariants, who
  uses it and the key flows, the subdomains and which is core, scale/consistency/latency needs,
  integrations, and constraints (team, deadline, stack). Then invoke `domain-driven-design`'s
  **architecture-fit reference** for the neutral fit judgment — **rich** (modular monolith,
  hexagonal, strategic + tactical DDD), **moderate** (simple layered app, DDD tactics only where
  they pay), or **thin** (script/CRUD, no ceremony). Present the recommendation, the module/context
  boundaries, the subdomain map, and **2–3 alternatives with the trade-off that ruled each out**.
- **Plan:** if genuine open design questions remain, resolve them with `superpowers:brainstorming`,
  weighing candidate approaches through `best-practices`' standard-first bias. Check
  `best-practices`' **pr-sizing reference** — if the scope spans multiple bounded contexts, would
  take multiple sessions, or bundles independently-valuable capabilities, apply it and scope
  **this** decision to slice 1 only; the rest becomes a short backlog note. Invoke
  `superpowers:writing-plans` for the step-by-step plan, making explicit: the module/bounded
  context, the layers touched (domain / app / infra, and the command/query split where it
  applies), the skills in scope, and the tests to write first. For a trivial one-liner (exact lines
  already known, ≤~2 files/~20 lines, no new contract, no schema/auth/bounded-context crossing, no
  open question), state the **Micro decision** inline instead of a full plan doc — still gated,
  just lighter.
- **Defect:** invoke `superpowers:systematic-debugging` — don't guess at a fix. **Reproduce the bug
  deterministically first**; if you can't, say so and stop, an unreproducible bug can't be fixed,
  only guessed at. Identify and name the **root cause**, not the surface symptom. **Describe** the
  regression test that would pin the correct behaviour — what it asserts and at which layer, per
  `best-practices`' **tdd reference** — without writing it; that happens in `/revai:implement`,
  after approval, never here. If fixing the root cause properly is itself large, apply
  `best-practices`' **pr-sizing reference** to sequence a minimal fix + regression test now against
  broader hardening as a documented follow-up.
- **Reshape:** bound the scope explicitly — state exactly what changes and what's frozen (public
  API, observable behaviour, contracts). Apply `best-practices`' **pr-sizing reference** if the
  smell spans too much for one PR. Check whether a **characterization safety net** already covers
  the code in scope; if coverage is thin, **describe** what needs to be added (without writing it —
  same rule as Defect).
- **Present the recommendation/plan/diagnosis/scope and STOP — every classification, no exceptions.**
  Wait for the user's explicit approval. **Write no code, create no branch, before or after this
  gate.** If they disagree or want changes, adjust and re-present.

## 4. Deliver & hand off  ↺

Write **exactly one** artifact, after the gate is approved:

- **Architecture** → `docs/design/<slug>.md` — the chosen architecture at its agreed weight
  (sequence `domain-driven-design`'s strategic-design → tactical-patterns →
  architecture-and-layering references for a rich design; only proportionate structure for lighter
  ones), named per `clean-code`'s naming reference, plus the **build-order (the slices)** and open
  questions/risks.
- **Plan** → wherever `superpowers:writing-plans` writes it (its own convention,
  `docs/superpowers/plans/YYYY-MM-DD-<name>.md`) — report that path, don't relocate it.
- **Defect / Reshape** → `docs/decisions/<slug>.md` — a `type: defect` or `type: reshape` header,
  the root cause / bounded scope, the test(s) described (not yet written) in step 3, and any open
  risk.

Report the path, a short summary, and point to **`/revai:implement <path>`** to execute it. For a
multi-slice Architecture decision, name the next slice and offer to decide it in a follow-up run.
No code, no branch, no PR — deciding ends here.

**Model policy:** run this whole command on a capable model — deciding is where the hard reasoning
earns its cost; `/revai:implement` is where execution gets cheap.
