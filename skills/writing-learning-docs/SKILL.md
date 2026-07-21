---
name: writing-learning-docs
description: Use when generating a calibrated, self-contained learning document about a technical topic — the reader's single source of truth. Owns the progressive document template (TL;DR + mental model at the top, then why → how → worked examples → pitfalls → when to use → quick reference → sources) and the authoring rules (written to a stated audience/depth, straightforward prose, Python-first runnable examples, correct over comprehensive, learner's-eyes self-review). Driven by /revai:learn.
---

# Writing learning docs (the source-of-truth template)

A learning doc is meant to be **the one thing the reader needs** to understand a topic. Not a
pointer to other material, not a summary — a complete, self-contained explanation they can return
to. This skill owns the shape and the standards so every doc reads the same way.

**A doc is written to a specific reader.** `/revai:learn` calibrates the audience and depth (level,
goal, how deep) before drafting. Write to *that* reader: emphasize what their goal needs, cut what it
doesn't, and pitch the depth to match. A doc for "I want to build with this" is not the doc for "I
want the mental model" — do not produce a generic one that serves neither.

## The template (progressive — fast path first)

Write these sections, in this order. The top is a **fast path** anyone can grasp in ~60 seconds; the
depth unfolds below it. Scale each section to the topic and the calibrated depth; omit a section only
if it genuinely does not apply, and say nothing rather than pad.

1. **TL;DR + mental model** — open with the one-paragraph plain-language definition **plus** the
   single mental model the whole topic hangs on. The reader should grasp the shape here, before any
   detail. This is the fast path; everything below is the reader choosing to go deeper.
2. **Why it exists** — the concrete problem it solves and what people did before it. Motivation
   before mechanism.
3. **How it works** — the actual mechanism, step by step. Diagrams-in-prose or a small ASCII sketch
   where it helps. This is the core.
4. **Worked examples** — runnable Python where code clarifies (see the Python-first rule). Show the
   smallest complete example first, then one realistic one. Every snippet must run as written.
5. **Common pitfalls & gotchas** — the mistakes people actually make, and how to avoid each.
6. **When to use / when not to** — the decision guidance. Name the alternatives and when they win.
7. **Quick reference** — a cheat-sheet the reader can scan later: key APIs, syntax, or a table.
8. **Sources** — the links from the Ground pass, so claims are checkable.

## The rules

- **Written to the calibrated reader.** Audience and depth are inputs, not afterthoughts — see above.
- **Self-contained.** No "see the docs" gaps. If the reader needs a prerequisite, explain it inline
  briefly rather than sending them away.
- **Straightforward prose.** Short sentences, plain words, no filler — cut anything that doesn't help
  the reader understand.
- **Python-first, always.** Code examples are **always Python, never another language.** Reach for a
  **runnable Python demo even on "conceptual" topics** — simulate OAuth with `requests`, a TCP
  handshake with `socket`, Kafka with a client — because running it beats reading about it. Fall back
  to a diagram or a walked-through trace **only** when Python genuinely cannot demonstrate the point,
  and even then include a Python example alongside if one can. Every example must run as written and
  demonstrate exactly the point being made — no pseudo-code passed off as code.
- **Correct over comprehensive.** Omit what you cannot verify rather than guess. A shorter true doc
  beats a longer doubtful one.
- **Show, then name.** Introduce a concept with a concrete instance before the abstract term. No term
  is used before it's introduced — no forward references.
- **One topic per doc.** If the topic splits into two independent things, say so and offer to write
  the second as its own doc.

## Learner's-eyes self-review (before delivery)

Before the doc is delivered, read it once as the calibrated learner — not as its author:

- Does the **mental model land before any detail** arrives?
- Is **every term introduced before it's used**? No forward references, no unexplained jargon.
- Does **every example run** and earn its place? No code for its own sake.
- Is there **any noise or repetition**? Cut it — the reader's time is the budget.

Fix what you'd flag in someone else's doc, then stop. This is a clarity pass, not a rewrite.
