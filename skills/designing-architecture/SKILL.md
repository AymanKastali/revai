---
name: designing-architecture
description: Use when designing the architecture for a new project or a major new area — deciding what structure fits before code exists. Owns the neutral architecture-fit judgment (when a rich DDD + hexagonal design earns its place versus a simple layered app or a plain script/library — match weight to the problem, never force ceremony), the order to bring the atomic architecture skills to bear (strategic → tactical → structural → edges), and the design-doc template. Driven by /revai:design.
---

# Designing architecture (the fit judgment + design-doc shape)

The job is to choose the architecture that **fits the problem** and write it down as a design the
build can follow. The hard part is not applying a pattern — it's picking the *right weight*. A rich
domain-driven, hexagonal design is powerful and expensive; a thin CRUD app drowns in it. This skill
owns the judgment (which weight), the sequencing (which skills, in what order), and the deliverable
(the design doc). The atomic architecture skills own the *how* of each tactic; `superpowers:brainstorming`
owns the question-asking that feeds this — bring them in where pointed.

## Match the weight to the problem (the fit judgment)

Judge **neutrally** from what the interrogation and any code survey actually surfaced — not from a
default. The deciding signal is **where the real complexity lives**: in the *domain rules*, in the
*integration surface*, or nowhere in particular. Classify the subdomains first (core / supporting /
generic — see `bounded-contexts`), then pick the lightest structure that still protects what matters.

- **Rich domain → modular monolith, internally hexagonal, strategic + tactical DDD.** Choose it when
  there are genuine invariants and business rules that must always hold, more than one subdomain, a
  real **core** worth protecting from the rest, or non-trivial workflows/state transitions. The cost
  (ports, adapters, aggregates, layered modules) buys isolation the domain will actually use.
- **Moderate → a simple layered app or a light service; DDD tactics only where they pay.** Choose it
  when there are some rules but mostly straightforward flows, one dominant subdomain, and CRUD with a
  handful of validations. Reach for a value object or a rich model **only** on the pieces that have
  real invariants; leave the rest plain. Don't stand up the full hexagon for this.
- **Thin → a plain CRUD app, a script, or a library; no ceremony.** Choose it when there is no
  persistent domain to protect: data in and out, a one-shot tool, a wrapper over someone else's
  service. Layers, ports, and aggregates here are pure overhead — a clear module with good names is
  the whole design.

**Never force the hexagon on a thin domain.** `domain-modeling`'s rule holds at the architecture
level too: pragmatic, not dogmatic — apply the pattern that earns its place and leave the rest simple.
When it's a genuine toss-up, name the tie and recommend the lighter option; it's cheaper to add
structure later than to unwind it. State the constraints that moved the decision (team size, deadline,
expected scale, existing stack) — they are part of the reasoning, not noise.

## Sequence the skills by concern

Once the weight is chosen, bring the atomic skills to bear in this order — and **stop early at lighter
weights**, skipping the layers a thin design doesn't need. `naming-and-structure` applies throughout.

1. **Strategic — `bounded-contexts`** (rich/moderate): draw the boundaries, fix the ubiquitous
   language inside each, classify subdomains, and choose the integration pattern with each neighbour.
   This is the map; do it before any tactical modelling.
2. **Tactical — `domain-modeling`** (rich; moderate only on the pieces with real rules): sketch the
   aggregates, value objects, invariants, and domain events for the core — model what has rules, leave
   the rest.
3. **Structural — `hexagonal-architecture`** (rich): lay out the modules (one per context), the three
   layers per module, the dependency direction, and the command/query split.
4. **Edges — the concrete backend skills** as the design touches them: `api-design` (the contract),
   `data-access-patterns` (persistence, one aggregate per transaction), `safe-schema-changes`
   (migrations), `config-and-secrets` (startup/config), `resilience-and-timeouts` (external calls),
   `backend-testing`/`tdd` (what to test per layer).

## The design-doc template

Write these sections to `docs/design/<slug>.md`, in this order. **Right-size ruthlessly** — omit any
section a lighter architecture doesn't need and say nothing rather than pad. A thin design may be four
short sections; a rich one uses them all.

1. **Problem & context** — what's being built and why, in a few sentences. The need it serves, who
   uses it, and the constraints that bound the design (scale, deadline, team, existing stack).
2. **Domain & ubiquitous language** — the core concepts and the exact words for them. The vocabulary
   the code will speak. *(Trim to a glossary line for a thin design.)*
3. **Subdomain map** — each subdomain classified **core / supporting / generic**, so effort is spent
   where it differentiates. *(Rich/moderate only.)*
4. **Recommended architecture — and why** — the chosen weight and shape, the reasoning tied to the
   evidence above, and the **alternatives considered** with the trade-off that ruled each out. This is
   the load-bearing section; make the decision defensible.
5. **Module / bounded-context breakdown** — the top-level partition and what each module owns
   (including its data). How they contact each other (published interface or event).
6. **Layers & CQRS per module** — the `domain`/`app`/`infra` split and the command/query sides.
   *(Hexagonal designs only — omit for lighter ones and describe the simpler layering instead.)*
7. **Domain-model sketch** — the key aggregates, value objects, invariants, and events. Types and
   rules, not full code. *(Rich/moderate only.)*
8. **Integration / context map** — external systems and the pattern for each seam (ACL, open-host,
   integration events). *(Only if there are real integrations.)*
9. **Cross-cutting** — API contract, persistence, config/secrets, resilience, and the testing
   approach, each in a line or two, pointing at the skill that governs it.
10. **Build order (the slices)** — the sequence of vertical slices to implement, smallest useful first,
    each one a candidate for `/revai:feature`. This is what turns the design into work.
11. **Open questions & risks** — what's still undecided, what could invalidate the design, and what to
    revisit once real usage arrives.

## The rules

- **Ground every decision in the interrogation and the survey.** A recommendation the answers don't
  support is a guess. If a needed answer never came, say what's assumed and flag it as an open
  question — don't invent a requirement to justify a shape.
- **Correct over comprehensive.** A shorter design you can defend beats a longer one padded with
  patterns nobody asked for. Cut every section that doesn't earn its place.
- **Right-size, don't showcase.** The goal is the design that fits, not a demonstration of DDD. The
  simplest structure that protects the real invariants wins.
- **Straightforward prose.** Short sentences, plain words, no filler. Diagrams as simple ASCII/indented
  structure (terminal markdown) — no renderer-only diagrams.
- **Speak the ubiquitous language** throughout, and name everything per `naming-and-structure` — the
  design sets the vocabulary the code will inherit.
- **Design, don't build.** The output is the document and the slice order; writing the code is
  `/revai:feature`'s job, not this one.
