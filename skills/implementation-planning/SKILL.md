---
name: implementation-planning
description: Applies the implementation-planning standard — turn an approved system design into an ordered sequence of right-sized slices, each handed to superpowers:writing-plans one at a time so a plan's file and module structure inherits the design's own boundaries instead of guessing at them. Use when running /revai:plan, turning a design document into an implementation plan, deciding what to build first after a design is approved, splitting a design's delivery slice that still spans more than one module, or sequencing a multi-slice build.
---

# Implementation planning

A design document is not yet buildable work. Turning it into buildable work means deciding, in
order, which slice is small enough to plan for real — one module, one shippable behavior — and
handing exactly that much to a plan-writer that can turn it into bite-sized tasks. Handing over too
much produces a plan that guesses at boundaries the design already settled; handing over the whole
design produces speculation about a codebase that doesn't exist yet.

Scope: this standard owns **how an approved design becomes an ordered sequence of right-sized,
plannable slices**. It does not own what the slices are supposed to be — `system-design` rules
118–122 already produce a first cut in the design's own delivery section — and it does not own how a
chosen slice becomes bite-sized TDD tasks — `superpowers:writing-plans` already does that well. This
standard is the seam between the two: read what the design decided, split what still isn't small
enough, order what's left, and hand over one slice at a time without letting the handoff redraw
boundaries the design already drew.

## Contents

- **Implementation-planning rules** — 27 rules in seven groups: applicability, reading the design
  before slicing, right-sizing a slice, ordering the slices, detecting progress, handing off one
  slice, and validating the breakdown. Rule 1 gates the standard on there being an approved design to
  plan from; rule 2 treats each group as a procedure stage rather than an independently-gated
  concern. Not injected — reached only through `/revai:plan`.
- **Depth** — a worked example of splitting a coarse slice along a module boundary, and the exact
  shape of a one-slice handoff to `writing-plans`.
- **Anti-pattern scan list** — coded by group, to work down while reviewing a proposed breakdown.

<!-- HARD-RULES:START -->
## Implementation-planning rules

These are not aspirations. A breakdown that violates one is a guess at what to build next, not a
plan. Rule 1 decides whether the rest apply; rule 2 says how to read the groups below it.

### Rules 1-2 — what applies

1. This standard governs turning an approved system-design document into an ordered sequence of right-sized, independently-plannable slices, and handing exactly one to `superpowers:writing-plans` at a time. It does not apply without a design document to plan from — say so and stop.
2. Each group below is a stage in the procedure, applied in the order it appears; skip a stage only when it is genuinely empty for this design, never to save time.

### Reading the design before slicing — always applies

3. Read section 14 (delivery) for the design's own named slices before inventing new ones; a design that already answers "what ships first" is the starting point, not a blank page.
4. Read sections 6 and 7 (architecture, data ownership) for the module and storage boundaries the design already settled; a slice's scope is read from these, never re-derived.
5. Read section 12 (decisions) for anything that already bounds sequencing — a decision recorded as "defer until X" is a dependency, not a suggestion.
6. A design with no section-14 slice, or one section-14 "slice" that is really the whole system, has not actually been sliced yet; treat the whole document as one candidate slice and right-size it.

### Right-sizing a slice — applies to every candidate slice

7. A slice is right-sized when it touches one module or capability, ships one coherent piece of observable behavior, and can be built, tested and shipped without another slice existing first — except where an explicit dependency says otherwise.
8. A slice spanning more than one module from section 6 is not right-sized; split it along the module boundary, never down the middle of one.
9. A slice whose data ownership (section 7) spans more than one store or more than one owning module is not right-sized, for the same reason `modular-monolith` rule 63 forbids one transaction writing two modules' storage.
10. A slice that bundles an independently-valuable capability with another is two slices, even when the design described them together.
11. A slice that is only infrastructure with nothing observable to ship — a schema nothing reads yet, a client with no caller — is not yet a slice; fold it into the first slice that actually uses it.
12. Splitting stops once every resulting slice passes rules 7–11; a piece smaller than one module's worth of one capability is a task, not a slice, and belongs inside `writing-plans`' own task breakdown instead.

### Ordering the slices — applies once slices are right-sized

13. Order by dependency first: a slice another slice's code calls, reads, or is gated behind comes first, regardless of which the design described first.
14. Where dependency order leaves a choice, the thinnest end-to-end path wins — the design's own rule 119, applied to a full sequence instead of one headline slice.
15. A slice with no dependency and no priority signal from the design goes last, not first — an unforced choice should not consume the first, most valuable slot.
16. Record the ordered sequence and the reason for each slice's position; re-ordering later without a stated reason is the undocumented decision `system-design` rule 102 already forbids.

### Detecting progress — applies on every run

17. Before proposing a slice to plan, search `docs/superpowers/plans/` for a plan whose `**Spec:**` header names this design document; a fully-checked plan means that slice is done, a partly-checked one means it is already in progress.
18. Recommend the next undone slice in sequence as the default, but always confirm before committing to it — only the person who built the last slice knows whether the sequence still holds.
19. If the codebase already contains work the design doesn't mention, say so before proposing the next slice, and adjust the sequence rather than planning over it silently.

### Handing off one slice — applies to the slice chosen this run

20. Hand `writing-plans` exactly one slice per run, never the whole sequence — a plan for a slice three steps away is speculation about a codebase that doesn't exist yet.
21. State the slice's module and data ownership verbatim from sections 6–7 in the handoff, so `writing-plans`' file-structure step inherits the design's boundaries instead of drawing its own.
22. State what the slice explicitly excludes — the boundary with the next slice matters as much as the boundary with the last one, and an unstated one invites scope creep.
23. Never repeat `writing-plans`' own job in the handoff: task granularity, TDD step shape and file-level structure inside the slice are its call once it has the scoped requirement, not this standard's to pre-decide.
24. Name `golang` or `postgres` in the handoff when the slice's module was built on that stack, so `writing-plans` writes tasks that already respect that stack's idioms instead of generic pseudocode.

### Validating the breakdown — before showing it

25. Every slice traces to a requirement or a section-14 slice in the design; a slice with no such trace is scope invented here, not read from the design.
26. Every requirement in the design's section 4 is covered by some slice in the sequence; an uncovered requirement is a gap to report, not to silently drop.
27. The sequence has no cycle; a cycle means the design's own module boundaries are wrong, and that is a finding for the design, not something resolved here by picking an arbitrary order.
<!-- HARD-RULES:END -->

## Depth

### Rules 8, 10 — splitting a coarse slice along a module boundary

A design's section 14 named one slice: "Slice 1: courier delivery-slot claiming." Section 6 shows two
modules — `scheduling` (owns delivery slots) and `notifications` (tells a courier their claim
succeeded). The slice as named touches both.

Bad — plan the named slice as-is:

```text
Slice 1: courier delivery-slot claiming
  touches: scheduling, notifications
```

`writing-plans` would now have to invent its own file structure across two modules with no
declared boundary between them in the plan — exactly the drift rule 21 exists to prevent.

Good — split along the module boundary rule 8 names, order by dependency (rule 13: a courier cannot
be notified of a claim that doesn't exist yet):

```text
Slice 1: claim a delivery slot (module: scheduling)
  ships: a courier can claim an open slot; a claimed slot cannot be claimed twice
  excludes: telling the courier it worked — that's slice 2

Slice 2: notify on a successful claim (module: notifications)
  depends on: slice 1's SlotClaimed fact existing
  ships: the courier sees a confirmation after a successful claim
```

### Rules 20-24 — the shape of a one-slice handoff

What actually gets handed to `superpowers:writing-plans` for the "Slice 1" example above — not a
description of what to hand over, the handoff itself:

```text
Spec: docs/design/courier-delivery-slots.md
Slice: claim a delivery slot
Module: scheduling (section 6) — owns the delivery-slot schema and its claim state (section 7)
Ships: a courier can claim an open slot; a claimed slot cannot be claimed twice
Excludes: notifying the courier (slice 2), cancelling a claim (not in this design's section 4)
Stack: none named for this module in section 6 — plan generically
```

## Anti-pattern scan list

Codes: `A` applicability, `R` reading, `Z` right-sizing, `O` ordering, `P` progress, `H` handoff,
`V` validating.

| Code | Anti-pattern | Settled by |
| --- | --- | --- |
| A1 | Slicing attempted with no approved design to read | 1 |
| A2 | A group skipped to save time rather than because it was empty | 2 |
| R1 | New slices invented with no look at the design's own section 14 | 3 |
| R2 | A slice's scope re-derived instead of read from sections 6–7 | 4 |
| R3 | A "defer until X" decision in section 12 ignored by the sequence | 5 |
| R4 | The whole design treated as done being sliced with no section-14 slice to show it | 6 |
| Z1 | A slice spanning more than one module handed off as one | 8 |
| Z2 | A slice's data ownership spanning more than one store or module | 9 |
| Z3 | Two independently-valuable capabilities bundled into one slice | 10 |
| Z4 | An infrastructure-only slice with nothing yet observable to ship | 11 |
| Z5 | Splitting continued past one module's worth of one capability | 12 |
| O1 | Dependency order ignored in favor of the design's narration order | 13 |
| O2 | A broad-first sequence chosen over the thinnest end-to-end path | 14 |
| O3 | An unforced slice given the first, most valuable slot | 15 |
| O4 | A sequence reordered with no stated reason | 16 |
| P1 | A slice replanned from scratch while an existing plan for it is in progress | 17 |
| P2 | The next slice assumed instead of confirmed | 18 |
| P3 | Undocumented codebase work planned over silently | 19 |
| H1 | More than one slice handed to `writing-plans` in a single run | 20 |
| H2 | A handoff with no module or data-ownership statement | 21 |
| H3 | A handoff with no stated exclusion boundary | 22 |
| H4 | Task-level detail pre-decided in the handoff instead of left to `writing-plans` | 23 |
| H5 | A Go or Postgres module handed off with no stack named | 24 |
| V1 | A slice with no traceable requirement or section-14 origin | 25 |
| V2 | A section-4 requirement covered by no slice in the sequence | 26 |
| V3 | A cyclic slice sequence resolved by picking an arbitrary order | 27 |
