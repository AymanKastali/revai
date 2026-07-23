# PR sizing (splitting a big plan into a sequence of small PRs)

Use at the Decide gate of `/revai:decide` (any classification — architecture, plan, defect, or
reshape) when the survey/spec shows the change is too big for one PR, or when
`domain-driven-design`'s architecture-fit reference is ordering a build. Judges whether the work
should become a sequence of small, independently shippable PRs instead of one, and how to order
that sequence. Does not own task/step granularity within a single PR — that's
`superpowers:writing-plans`' job.

`superpowers:writing-plans` already right-sizes **tasks** and **steps** inside one implementation
plan, and `superpowers:subagent-driven-development`/`executing-plans` already execute those one at a
time with a review gate between each. This skill sits one level above that: deciding whether the
**whole plan is too big for one PR**, and if so, sequencing it into a series of small, independently
shippable PRs so review and maintenance stay tractable across the sequence — not just within one of
them. It owns the cross-PR judgment only; hand task/step granularity to `writing-plans` once a slice
is chosen.

## When a plan is too big for one PR (the signal check)

Judge from what the Understand survey or the spec actually shows — not a default. Split when:

- the change spans more than one bounded context/module without one shared seam connecting them;
- the spec already reads as several independent capabilities, not sequential steps of one;
- it would span multiple sessions, or a reviewer couldn't hold the whole diff in mind at once;
- part of the change is independently valuable and shippable before the rest exists;
- it bundles a schema migration with the feature code that depends on it (see
  `safe-schema-changes` — expand→contract alone is often two PRs, not one);
- for a refactor, the smell spans enough call sites that one transform would dwarf what a single
  sitting can review.

**Skip this skill entirely when none apply.** Most features, bugfixes, and refactors are one PR —
invoking this as ceremony on a small change is waste, not rigor.

## Slice vertically, not horizontally

A slice must be independently **mergeable, testable, and revertable** — and ideally independently
valuable on its own. Never slice by technical layer (all models in PR 1, all handlers in PR 2,
wiring in PR 3): none of those PRs can ship or be tested end to end alone, so review gains nothing
and risk goes up. Slice by **capability** instead — each PR is a thin, complete path through the
change, even if later slices extend it.

## Sequencing the slices

- **Foundation/walking-skeleton first** when later slices depend on it — the thinnest end-to-end
  path that proves the seam works, before building it out.
- **Order by real dependency, not preference.** A slice can't precede what it needs; among slices
  with no dependency between them, order by risk or value, not habit.
- **Keep `main` shippable after every slice.** Hide an incomplete capability behind a feature flag
  or branch-by-abstraction rather than leaving the codebase half-working between PRs.
- **End each slice at a real behavioral checkpoint** — something demoable or testable — not an
  arbitrary line or file count.

## What this hands off

- Present the full slice sequence at the Decide gate, but scope *this run's* plan, diagnosis, or
  scope to **slice 1 only**. The rest is a short backlog note — each future slice becomes its own
  later `/revai:decide` run (then `/revai:implement` to execute it).
- Once slice 1 is chosen, its internal task/step decomposition is **`superpowers:writing-plans`'s**
  job (task right-sizing by reviewability, bite-sized steps) — don't re-derive that here.
- Building the chosen slice still runs through `/revai:implement`'s normal Build/Fix/Transform
  stage — TDD, `superpowers:subagent-driven-development`/`executing-plans` — this skill only
  decides slice boundaries and order, never how a slice gets built.

## The rules

- Judge from the survey's evidence, not a default — most changes are one PR; only split when the
  signals above are real and named.
- **One slice = one PR = one full Ship gate.** Working incrementally is never an excuse to skip or
  shortcut the Ship gate for any slice.
- State the sequence and the reasoning behind the order when presenting it, so the user approves
  slice 1 with visibility into what's coming next.
- Never apply this skill's logic at task/step granularity inside a single PR — that boundary
  belongs to `writing-plans`, not here.
