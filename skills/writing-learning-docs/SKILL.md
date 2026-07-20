---
name: writing-learning-docs
description: Use when generating a canonical, self-contained learning document about a technical topic — the reader's single source of truth. Owns the document template (what it is → why → how → worked examples → pitfalls → when to use → quick reference → sources) and the authoring rules (straightforward prose, self-contained, runnable Python examples, correct over comprehensive). Driven by /revai:learn.
---

# Writing learning docs (the source-of-truth template)

A learning doc is meant to be **the one thing the reader needs** to understand a topic. Not a
pointer to other material, not a summary — a complete, self-contained explanation they can return
to. This skill owns the shape and the standards so every doc reads the same way.

## The template

Write these sections, in this order. Scale each to the topic; omit a section only if it genuinely
does not apply, and say nothing rather than pad.

1. **What it is / mental model** — the one-paragraph plain-language definition, plus the mental
   model that makes the rest click. Lead with this; the reader should grasp the shape before any
   detail.
2. **Why it exists** — the concrete problem it solves and what people did before it. Motivation
   before mechanism.
3. **How it works** — the actual mechanism, step by step. Diagrams-in-prose or a small ASCII
   sketch where it helps. This is the core.
4. **Worked examples** — runnable Python where code clarifies (per the reader's preference). Show
   the smallest complete example first, then one realistic one. Every snippet must run as written.
5. **Common pitfalls & gotchas** — the mistakes people actually make, and how to avoid each.
6. **When to use / when not to** — the decision guidance. Name the alternatives and when they win.
7. **Quick reference** — a cheat-sheet the reader can scan later: key APIs, syntax, or a table.
8. **Sources** — the links from the verification pass, so claims are checkable.

## The rules

- **Self-contained.** No "see the docs" gaps. If the reader needs a prerequisite, explain it inline
  briefly rather than sending them away.
- **Straightforward prose.** Short sentences, plain words, no filler — cut anything that doesn't help the reader understand.
- **Runnable, correct examples.** Prefer Python. Every example must run as written and demonstrate
  exactly the point being made — no pseudo-code passed off as code.
- **Correct over comprehensive.** Omit what you cannot verify rather than guess. A shorter true doc
  beats a longer doubtful one.
- **Show, then name.** Introduce a concept with a concrete instance before the abstract term.
- **One topic per doc.** If the topic splits into two independent things, say so and offer to write
  the second as its own doc.
