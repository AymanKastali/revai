---
name: domain-driven-design
description: Applies modern domain-driven design — strategic design (bounded contexts, ubiquitous language, context mapping), tactical modeling (aggregates, value objects, invariants, domain events), hexagonal/modular-monolith architecture, and the judgment for how much DDD ceremony a system actually needs. Use when modelling a domain, drawing a service/module boundary, defining a type with business rules, or designing a new system's or bounded context's architecture.
---

# Domain-driven design

## Overview

DDD earns its place where real complexity actually lives: genuine invariants and business rules
that must always hold, more than one subdomain, a real core worth protecting from the rest, or
non-trivial workflows and state transitions. It is never forced onto a thin CRUD problem — a plain
script, a wrapper over someone else's service, or a handful of straightforward validations don't
need a bounded context, an aggregate, or a hexagon; a clear module with good names is the whole
design. Judge the weight neutrally from what the problem actually shows, not from habit, and pick
the lightest structure that still protects what matters. See `reference/architecture-fit.md` for
the full judgment and how it drives a design doc.

## Quick reference

| Need | Reference |
|---|---|
| Domain boundaries, ubiquitous language, integration patterns | `reference/strategic-design.md` |
| Aggregates, value objects, invariants, domain events | `reference/tactical-patterns.md` |
| Module layout, layering, ports/adapters, CQRS | `reference/architecture-and-layering.md` |
| How much of this a given system actually needs | `reference/architecture-fit.md` |

Strategic comes before tactical, which comes before structural — draw the boundary and fix the
language first, then model the types inside it, then decide where the code lives. `architecture-fit`
is consulted first, to decide how much of the other three to actually use.

## Common mistakes

- **Forcing the hexagon on a thin domain.** Layers, ports, and aggregates on a CRUD problem with no
  real invariants — pure ceremony that slows every future change without protecting anything.
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

