---
description: Read the codebase and explain it to a human — a clean mental-model map (whole repo, or a scoped area) printed inline, then offered as a saved doc. Read-only.
argument-hint: [optional: an area to focus on, e.g. "the domain layer" — defaults to the whole codebase]
---

# /revai:explain

Point the harness at a codebase and get back the picture you'd want on day one — what it does, how
it's built, how one request actually flows, and how to run it. Clean, human-friendly, no noise, and
**nothing invented**. You **orchestrate**; the `explaining-code` skill owns the output shape and the
writing rules — don't reinvent them here.

This command is **read-only**: survey and explain, never edit, stage, or commit.

The argument (`$ARGUMENTS`) is an optional area to focus on:

- **Empty** → explain the **whole codebase**.
- **Present** (e.g. `"the domain layer only"`) → explain **only that area**, scoped. If the survey
  can't find the named area in the repo, say so and offer the whole-codebase map or a corrected
  focus — never invent a scope that isn't there.

## 1. Scope the run

- State plainly what you're about to explain — the whole repo, or the named area — before you start.
- Get your bearings first: the project's manifest/build files, top-level layout, and README, so the
  survey below is targeted rather than blind.

## 2. Survey (subagents, off your main context)

Dispatch explorer subagent(s) to read the code and return **structured notes** — not raw file dumps —
so the detail stays off your main context (the move `/revai:review` uses to gather findings).

- **Whole codebase** → dispatch a few explorers **in parallel by area**: entry points, domain/core,
  data/infra, and config/build. Each returns notes on its slice.
- **Focused area** → one explorer scoped to the named area, plus how it connects to the rest.

Adapt the slices to what the repo actually is — a library, CLI, or frontend won't split into those
four; rename or drop slices to fit. If there's genuinely no code to explain, say so plainly rather
than forcing the template.

Ask each explorer for: the responsibility of what it read, the key files (with paths), the
dependencies between pieces, and one concrete flow through its slice. **Correct over comprehensive** —
tell them to report only what they verified in the code and to flag what they couldn't confirm.

**Model policy** — run the survey on the cheapest tier that can do it; synthesise the explanation on
your main model, where the prose quality matters.

## 3. Explain

- Invoke the **`explaining-code`** skill and follow its template + rules to turn the notes into the
  explanation. **Print it inline** — this is the deliverable, not a file.
- Ground every claim in the notes and real files. If the survey couldn't confirm something, say so
  or leave it out — never fill a gap with a guess.

## 4. Offer to save

- After printing, offer to save the explanation to a file. Propose a path (e.g.
  `docs/explain/<area-or-"overview">.md`) and **confirm before writing** — never write a file the
  user didn't ask for, and never overwrite content you didn't create.
- Offer to **drill deeper** into any area — that's just a focused re-run scoped to what they name.
