---
description: Generate a calibrated, self-contained learning document on a topic — tailored to you, grounded by real web research, progressively structured, and your source of truth on it — then keep tutoring interactively.
argument-hint: <topic to learn, e.g. "SSE (server-sent events)">
---

# /revai:learn

Turn a topic into **the one document you need to understand it** — tailored to who's asking,
grounded in real sources, structured so you can grasp it in 60 seconds or study it in depth, with
runnable Python examples — then stay available to tutor you further. You **orchestrate**; the
`writing-learning-docs` skill owns the doc's shape and rules.

This command runs **seven explicit stages** with **one gate**:

```
Calibrate → Outline ⏸ → Draft → Ground → Refine → Deliver → Tutor ↺
```

Two of these are the quality levers that make the output actually teach *you*: **Calibrate** (tune
the doc to your level and goal before writing) and **Refine** (read the finished doc as the learner
before delivering it).

The argument (`$ARGUMENTS`) is the topic to learn. If it's empty, ask what to learn and stop.

## 1. Calibrate

The single biggest lever on output quality — a doc for a curious beginner and one for an expert
chasing edge cases are different documents. Establish who's asking and why **before** writing.

- Ask a short batch (use `AskUserQuestion`) — pre-fill sensible defaults from the user's profile
  (a Go/Python engineer) so it's fast to answer:
  - **Familiarity** — new to this / know the basics / experienced and want depth.
  - **Goal** — build something with it / prep for an interview / debug a specific problem / general
    conceptual understanding. The goal decides what to emphasize and what to cut.
  - **Depth** — a quick working grasp, or comprehensive.
- Derive a kebab-case slug from the topic (e.g. `SSE (server-sent events)` → `sse`). The target file
  is `docs/learning/<slug>.md` in the current repo; create `docs/learning/` if missing.
- If the file already exists, tell the user and ask whether to **refresh** it (regenerate) or
  **extend** it (add to what's there). Never silently overwrite.

## 2. Outline  ⏸ GATE

- Propose the **tailored table of contents** — the `writing-learning-docs` sections, scaled to the
  calibrated depth (drop what the goal doesn't need, expand what it does) — plus the **mental-model
  spine**: the one idea the whole doc hangs on.
- Mark where the **runnable Python example(s)** will land and which **claims will need grounding**
  (versions, API shapes, anything the reader will act on).
- **Present it and STOP.** Get one nod before drafting. If the user redirects the scope, adjust and
  re-present. **Draft nothing before approval** — the gate exists so a full draft isn't spent on the
  wrong shape.

## 3. Draft  (auto, after the gate)

- Invoke the **`writing-learning-docs`** skill and follow its template + rules for the whole doc.
- Write the full doc from your own knowledge. Get the **mental model** and the **how it works** right
  first — that's the spine everything else hangs on.
- Put **runnable Python** where it demonstrates the point (Python-first, always). Don't add code for
  its own sake, but do reach for a small runnable demo even on "conceptual" topics — running it beats
  reading about it.

## 4. Ground

- **Verify the load-bearing claims with real research.** Dispatch a **research subagent** *off your
  main context*, armed with **WebSearch** / **WebFetch**, to check anything version-specific, any
  API/behaviour the reader will act on, and anything you're less than sure of. Require it back as a
  short list: claim → verdict → source URL.
- Correct the draft against what it finds. Fill the **Sources** section with the links it surfaces.
  If research contradicts a claim you can't resolve, **cut the claim** rather than ship it — correct
  over comprehensive.

## 5. Refine

Read the whole doc **as the calibrated learner would**, before anyone else sees it:

- Does the **mental model land before any detail** arrives?
- Is **every term introduced before it's used** — no forward references, no unexplained jargon?
- Does **every example run as written** and earn its place?
- Is there **any noise or repetition**? Cut it. Straightforward prose, no filler.

Fix what you'd flag, then move on — this is the learner's-eyes pass, not a rewrite.

## 6. Deliver

- Save the finished doc to `docs/learning/<slug>.md`.
- Report the path, give a **3–5 line summary** of what the doc covers, and state plainly **what was
  grounded** against sources versus **what remains uncertain** (if anything).

## 7. Tutor  ↺

- Offer to keep going: answer questions, expand a section, add examples — and **actively check
  understanding** by offering a couple of quick self-check questions or a small exercise.
- Apply every update to the **same file** so it stays the single source of truth.
- Re-run the **Ground** pass for any new load-bearing claim. Keep going until the user is done.
