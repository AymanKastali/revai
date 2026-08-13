---
description: Turn an approved design document into an ordered sequence of right-sized implementation plans, one slice at a time
argument-hint: <path to a /revai:design document>
---

# /revai:plan

The design: **$ARGUMENTS**

Turn this design into the next right-sized implementation plan, against the `implementation-planning`
standard.

**Read `${CLAUDE_PLUGIN_ROOT}/skills/implementation-planning/SKILL.md` in full before anything else.**
Its 27 rules are the specification for what you do here. Nothing below repeats them; this file is
only the procedure.

Terminal state: **one implementation plan on disk, and a short summary in chat.** Write no
implementation code, create no branch, and never hand more than one slice to
`superpowers:writing-plans` in a single run.

## 1. Load the design

The argument is a path to a document `/revai:design` produced. No argument, or nothing readable at
that path: say so and stop (rule 1) — there is nothing to slice without an approved design.

## 2. Read, then right-size

Apply rules 3–6: read section 14 for the design's own named slices, sections 6–7 for the module and
data-ownership boundaries, section 12 for anything that already bounds sequencing. If section 14 has
no slice, or its one "slice" is really the whole system, treat the whole document as one candidate
slice (rule 6).

Then right-size every candidate against rules 7–12: one module, one shippable behavior, no bundled
independent capability, nothing infrastructure-only left dangling. Split along a module boundary
wherever a candidate still fails — never down the middle of one (rule 8).

## 3. Order the sequence

Apply rules 13–16: dependency first, the thinnest end-to-end path where dependency order leaves a
choice, an unforced slice last rather than first. Record the sequence and the reason for each
position — a later re-ordering with no stated reason is the undocumented decision `system-design`
rule 90 already forbids.

## 4. Detect progress

Apply rules 17–19. Search `docs/superpowers/plans/` for any plan whose `**Spec:**` header names this
design document. A fully-checked plan means that slice is done; a partly-checked one means it's
already in progress. If the codebase already contains work the design doesn't mention, say so now and
adjust the sequence rather than silently planning over it.

## 5. Confirm the slice

Recommend the next undone slice in the sequence as the default. Use `AskUserQuestion` with that
default first — accepting it is one click, same pattern `/revai:design` uses for its own question
round — but always ask; never commit to a slice without confirming (rule 18).

## 6. Hand off exactly one slice

Apply rules 20–24. Invoke `superpowers:writing-plans`, handing it:

- This design document's path, as the spec.
- The chosen slice's module and data ownership, verbatim from sections 6–7 — not re-derived, so
  `writing-plans`' own file-structure step inherits these boundaries instead of drawing its own.
- What the slice ships, and what it explicitly excludes (the boundary with the next slice, not just
  the last one).
- The stack skill (`golang` or `postgres`) if section 6 named one for this module — otherwise plan
  generically.

Never hand over more than this one slice, and never pre-decide what `writing-plans` already owns:
task granularity, TDD step shape, file-level structure inside the slice.

## 7. Validate, then report

Before showing anything, check rules 25–27 against the full sequence: every slice traces to a
requirement or a section-14 slice, every section-4 requirement is covered by some slice, the sequence
has no cycle. Fix what fails rather than reporting it.

Report, briefly:

- The full ordered sequence, so the user sees what's ahead.
- Which slice was just planned, and why it was next.
- The resulting plan's path.

Then stop. Do not start building, and do not hand off a second slice in the same run.
