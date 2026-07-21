---
description: Turn one or more existing plan/design file(s) (or a rough spec) into a written, step-by-step implementation plan — grounds it in a real survey of the codebase, slices it down to one PR-sized plan where needed, then hands off to /revai:feature to execute. Read-only + one plan doc; no code, no branch, no PR.
argument-hint: <path(s) to plan/design file(s), or inline text describing what to build>
---

# /revai:prepare

Turn already-decided intent — one or more plan/design files, or a rough spec — into a written,
step-by-step implementation plan, through four stages: **Gather → Survey → Plan ⏸ → Hand off ↺**.
You **orchestrate**; the actual drafting is `superpowers:writing-plans`' job, the cross-PR sizing
judgment is `divide-and-conquer`'s. This command doesn't re-decide architecture — that's
`/revai:design` — and doesn't execute anything — that's `/revai:feature`.

It is **read-only plus one plan doc** — no code, no branch, no PR.

The argument (`$ARGUMENTS`) is one or more paths to plan/design file(s), or inline text describing
what to build — read each file that's a path.

## 1. Gather

- Resolve `$ARGUMENTS`. If **multiple** files are given, read all of them and reconcile — call out
  any overlap or conflict explicitly rather than silently picking one.
- If a given file is a `docs/design/<slug>.md` design doc (has a "Build order (the slices)"
  section), treat that section as the candidate slice sequence directly — don't re-derive it from
  scratch.
- If the input is a raw idea with genuine open **architecture** questions and no design decided
  yet (no chosen weight, no module boundaries), say so and point to **`/revai:design`** first —
  this command turns an already-decided plan into steps, it doesn't make the architecture call.

## 2. Survey

- Ground in the actual codebase the plan touches: dispatch Explore / `explaining-code` subagents
  off main context for existing patterns, public contracts/tests, dependencies, and any "Do not
  touch" paths.
- **Model policy** — cheapest tier that can do the survey; reserve capable models for the Plan
  stage next.

## 3. Plan  ⏸ GATE

- If open design questions remain within the chosen scope, invoke **`superpowers:brainstorming`**
  and resolve them — weigh candidate approaches through **`best-practices`**, leading with the
  standard/established option and requiring a stated reason for a bespoke one to win.
- Check the **`divide-and-conquer`** signal: if the combined input is too big for one PR-sized
  plan (spans bounded contexts, reads as independently-shippable pieces, would span multiple
  sessions), invoke it — reusing the input's own Build-order slice sequence where one already
  exists (see Gather) rather than re-deriving it — then scope **this run's plan to slice 1 only**.
  The rest is a short backlog note; each later slice becomes its own future `/revai:prepare` run.
- Invoke **`superpowers:writing-plans`** to produce the written, step-by-step implementation plan,
  built on the Gather input and the Survey findings.
- The plan **must** make revai's concerns explicit:
  - the **module / bounded context** the work belongs to (see `bounded-contexts`);
  - the **layers** touched — `domain` / `app` / `infra` — and the command/query split where it
    applies (see `hexagonal-architecture`);
  - which **skills** are in scope (`domain-modeling`, `api-design`, `data-access-patterns`,
    `safe-schema-changes`, …);
  - the **tests** to write first (TDD), and anything that genuinely can't be TDD'd, called out.
- **Present the plan and STOP.** Wait for the user's explicit approval. If they ask for changes,
  revise and re-present.

## 4. Hand off  ↺

- Report the plan file's path (written by `writing-plans`, normally to
  `docs/superpowers/plans/YYYY-MM-DD-<name>.md`), a short summary, and which workflow fits next —
  normally **`/revai:feature`** to execute it.
- If `divide-and-conquer` produced more than one slice, offer to prepare the next slice's plan
  next (loop back to Gather/Survey/Plan for slice 2, etc.).
- **No code, no branch, no PR — the preparation ends here.**
