# Architecture fit (sequencing the full DDD toolkit into a design)

## Contents
Sequencing the other six references · the design-doc template · the rules for writing it. This
reference is consulted by `/revai:decide`'s Architecture classification path.

There is no weight judgment left to make here — full strategic + tactical DDD, hexagonal/
modular-monolith architecture is the mandatory baseline for any Architecture decision this skill
applies to (see `SKILL.md`). What this reference still owns: the **order** in which the other
references get applied, and the **deliverable** — the design doc. The other references in this skill
own the *how* of each tactic; `superpowers:brainstorming` owns the question-asking that feeds this —
bring them in where pointed.

## Sequence the references

Bring these to bear in this order. `clean-code` and `best-practices` apply throughout.

1. **Discovery — `reference/discovery-and-modeling-techniques.md`.** Run EventStorming/domain
   storytelling/example mapping with whoever knows the process before drawing anything. Skip this
   stage only when the boundaries, events, and rules are already this well established from prior
   discovery — not because it feels unnecessary this time.
2. **Strategic — `reference/strategic-design.md`.** Draw the boundaries, fix the ubiquitous language
   inside each, classify subdomains, distil the core, and choose the integration pattern with each
   neighbour. This is the map; do it before any tactical modelling.
3. **Tactical — `reference/tactical-patterns.md`.** Model the aggregates, value objects, domain
   services, invariants, and domain events for every context in scope — not just the core, though
   the core gets the most attention.
4. **Tactical extensions, where their own trigger holds:**
   - `reference/event-sourcing.md` — an aggregate whose history is itself a business requirement.
   - `reference/process-managers-and-integration.md` — a workflow spanning more than one aggregate or
     context, or one needing compensation.
   Naming these explicitly and stating whether each one's trigger holds is part of the design — don't
   silently skip them, and don't apply either without its trigger.
5. **Structural — `reference/architecture-and-layering.md`.** Lay out the modules (one per context),
   the three layers per module, and the dependency direction. One set of use-case handlers per
   module by default; split a module into command/query sides (CQRS) only where its own trigger
   holds (a read shape genuinely diverged from the write model) — state per module whether it does.
6. **Edges — `best-practices`** as the design touches them: the API contract, persistence and
   one-aggregate-per-transaction, migrations, startup/config, resilience for external calls, and what
   to test per layer.

## The design-doc template

Write these sections to `docs/design/<slug>.md`, in this order. Every section is always in scope —
there is no lighter architecture to trim it for. A section with nothing new to say for this design
still gets a line stating that, so its absence reads as "considered, not applicable" rather than
"forgotten."

1. **Problem & context** — what's being built and why, in a few sentences. The need it serves, who
   uses it, and the constraints that bound the design (scale, deadline, team, existing stack).
2. **Discovery summary** — what EventStorming/domain storytelling/example mapping surfaced: the event
   timeline, hotspots, and open questions that came out of it (see
   `reference/discovery-and-modeling-techniques.md`).
3. **Domain & ubiquitous language** — the core concepts and the exact words for them, plus the domain
   vision statement for the core.
4. **Subdomain map** — each subdomain classified **core / supporting / generic**, so effort is spent
   where it differentiates, and which bounded context(s) each one maps to — don't assume 1:1 (see
   `reference/strategic-design.md`).
5. **Recommended architecture** — the shape, the reasoning tied to the evidence above, and the
   **alternatives considered** with the trade-off that ruled each out. This is the load-bearing
   section; make the decision defensible.
6. **Module / bounded-context breakdown** — the top-level partition and what each module owns
   (including its data). How they contact each other (published interface or event).
7. **Layers per module** — the `domain`/`app`/`infra` split for each module. For each one, state
   whether CQRS's trigger holds (and it gets a command/query split) or it stays a single set of
   use-case handlers — and separately, whether physical CQRS/event sourcing applies and why.
8. **Domain-model sketch** — the key aggregates, value objects, domain services, and events. Types
   and rules, not full code.
9. **Process managers / sagas** — any multi-step or cross-context workflow, its steps, and its
   compensating actions. State explicitly if none apply to this design.
10. **Integration / context map** — external systems and the pattern for each seam (ACL, open-host,
    Shared Kernel, Separate Ways, integration events).
11. **Cross-cutting** — API contract, persistence, config/secrets, resilience, and the testing
    approach, each in a line or two, pointing at the skill that governs it.
12. **Build order (the slices)** — the sequence of vertical slices to implement, smallest useful
    first, each one a candidate for its own `/revai:decide` → `/revai:implement` run. This is what
    turns the design into work. Use `best-practices`' pr-sizing reference for how to slice and order
    them.
13. **Open questions & risks** — what's still undecided, what could invalidate the design, and what
    to revisit once real usage arrives.

## The rules

- **Ground every decision in discovery and the survey.** A recommendation the sessions and answers
  don't support is a guess. If a needed answer never came, say what's assumed and flag it as an open
  question — don't invent a requirement to justify a shape.
- **Complete, not padded.** Every reference and every template section is in scope — that's the
  mandate — but "in scope" means stating the decision (including "not needed here, because...") for a
  tactical extension whose trigger doesn't hold, not inventing a use for it to look thorough.
- **Straightforward prose.** Short sentences, plain words, no filler. Diagrams as simple ASCII/indented
  structure (terminal markdown) — no renderer-only diagrams.
- **Speak the ubiquitous language** throughout, and name everything per `clean-code` — the design sets
  the vocabulary the code will inherit.
- **Design, don't build.** The output is the document and the slice order; writing the code is
  `/revai:implement`'s job, not this one.
