---
name: domain-driven-design
description: Applies the full modern domain-driven design toolkit as a mandatory baseline — discovery techniques (EventStorming, domain storytelling), strategic design (bounded contexts, ubiquitous language, context mapping), tactical modeling (entities, value objects, aggregates, domain services, factories, specifications, repositories, domain events, event sourcing), process managers/sagas, and hexagonal/modular-monolith architecture. Use when modelling a domain, drawing a service/module boundary, defining a type with business rules, or designing a new system's or bounded context's architecture.
---

# Domain-driven design

## Overview

This is the mandatory baseline for any domain being modelled, any service/module boundary being
drawn, or any type carrying business rules — there is no lighter tier. Strategic design (bounded
contexts, ubiquitous language, context mapping) and tactical modeling (aggregates, value objects,
domain events, domain services) are always in force once this skill applies; hexagonal layering and
the modular-monolith split are the required structure, not an option weighed against a simpler one.

That mandate is about the *core building blocks*, not about instantiating every pattern in the
toolkit on every problem. Entities, value objects, aggregates, domain events, domain services,
repositories, bounded contexts, and hexagonal layering are never optional. Factories,
Specifications, Event Sourcing, Process Managers/Sagas, and CQRS (logical or physical) each carry
their *own* trigger condition (a Factory earns its place when construction itself has multi-step
invariants; Event Sourcing earns its place when an aggregate's history is itself a business
requirement; a Saga earns its place when a workflow spans more than one aggregate or context; CQRS
earns its place when a query's read shape has genuinely diverged from the write model) — applying
one of these without its trigger is over-engineering the same way skipping a mandatory building
block is under-engineering. See `reference/architecture-fit.md` for how the references below
sequence into a design.

## Quick reference

| Need | Reference |
|---|---|
| Discovering contexts, events, and rules with domain experts | `reference/discovery-and-modeling-techniques.md` |
| Domain boundaries, ubiquitous language, context mapping | `reference/strategic-design.md` |
| Entities, value objects, aggregates, domain services, factories, specifications, repositories, domain events | `reference/tactical-patterns.md` |
| Event-sourced aggregates and event stores | `reference/event-sourcing.md` |
| Sagas/process managers, compensation, transactional outbox | `reference/process-managers-and-integration.md` |
| Module layout, layering, ports/adapters, CQRS | `reference/architecture-and-layering.md` |
| Sequencing all of the above into one design | `reference/architecture-fit.md` |

Discovery comes before strategic, which comes before tactical, which comes before structural — surface
the domain's events and language with domain experts first, draw the boundary and fix the language,
then model the types inside it, then decide where the code lives. `architecture-fit` sequences all
six references into one design; it no longer weighs whether to use them.

## Common mistakes

- **Anemic models.** A data bag with public fields, mutated by an external service — the invariant
  lives outside the type (or nowhere), gets duplicated at every call site, and is easy to forget.
- **Missing invariants.** A rule that should always hold is enforced by convention or a stray `if`
  instead of being made unrepresentable in the type — one missed call site and the domain is invalid.
- **One god-aggregate (or one god-model) instead of proper boundaries.** A single `Customer` or
  `Order` type stretched to serve every context, or one transaction spanning several aggregates
  because it was easier than reconciling through an event — both dissolve the consistency boundary
  DDD exists to draw.
- **Skipping strategic design and jumping to types.** Modelling aggregates before the boundary and
  ubiquitous language are settled — "building without a map."
- **Skipping discovery and guessing at boundaries.** Drawing bounded contexts from an org chart or a
  hunch instead of running EventStorming/domain storytelling with the people who know the process.
- **Reaching for Event Sourcing, a Saga, or CQRS without their trigger.** Event-sourcing an aggregate
  with no history requirement, building a process manager for a workflow that's really one
  aggregate's method, or splitting a module into command/query sides when nothing about the read
  shape has diverged — ceremony that outruns the problem is still a mistake, it's just no longer
  justified by "the whole system is thin."
- **Domain services and factories used as an escape hatch.** Moving behaviour into a domain service
  because the aggregate boundary is unclear, instead of fixing the boundary — a domain service is for
  behaviour that genuinely spans more than one aggregate, not a place to dump logic that doesn't fit.

