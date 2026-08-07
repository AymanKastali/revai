---
name: modular-monolith
description: Owns the concrete build-out of a modular monolith once domain-driven-design's module/layer shape applies — boundary-enforcement tooling, in-process communication (published-interface facade or domain event, never a network call between modules), data-isolation tiering, module-scoped testing, observability/feature-flag namespacing per module, and the extraction-to-microservice playbook. Use once modules and hexagonal layers are laid out and it's time to actually build, enforce, test, operate, or extract from that shape.
---

# Modular monolith

## Overview

`domain-driven-design`'s `reference/architecture-and-layering.md` decides *the shape*: modules as
bounded contexts, hexagonal `domain`/`app`/`infra` layers, the inward dependency rule, cross-module
contact via a published interface or a domain event. This skill assumes that shape is already decided
and owns everything below it — the concrete mechanics of building, enforcing, testing, operating, and
selectively extracting from it. Always considered once DDD's modular-monolith shape applies, at a
depth proportional to the stakes — same "no tiers, proportional depth" framing the rest of this harness
uses.

**Core principle, stated once here and enforced everywhere below: modules never communicate over the
network inside one modular monolith.** All cross-module contact is in-process — a published-interface
facade call or a domain-event dispatch — never HTTP, never gRPC, never any socket between two modules
in the same deployable. Reaching for a network call between two modules in the same monolith is
building a distributed system by accident, with none of a real service boundary's benefits.

## Quick reference

| Need | Reference |
|---|---|
| CI-enforced module boundaries, module-scoped tests, contract tests | `reference/boundary-enforcement-and-fitness-functions.md` |
| The published-interface facade, domain-event dispatch, sync vs. async, outbox for reliability | `reference/in-process-communication.md` |
| Which data-isolation tier a module gets (shared tables → schema-per-module → DB-per-module) | `reference/data-isolation-and-persistence.md` |
| Module-tagged logging, correlation IDs, feature-flag namespacing | `reference/observability-and-feature-flags.md` |
| When a module is actually ready to become its own service, and how to cut it over safely | `reference/extraction-to-microservice.md` |

Module/layer shape, bounded contexts, and CQRS's trigger aren't duplicated here —
`domain-driven-design/reference/architecture-and-layering.md` already owns that ground. Cross-service
protocol choice and storage-engine selection aren't duplicated here either —
`system-design/reference/communication-patterns.md` and `reference/data-layer-architecture.md` own
those; this skill answers the different question of what happens *inside* one deployable.

## Common mistakes

- **Reaching for a network call (HTTP/gRPC) between two modules in the same monolith.** This is the
  single most common way to accidentally build a distributed system without any of the benefits of
  one — no independent deployability, no independent scaling, just the latency and failure modes of a
  network call for no reason. Everything in-process goes through the facade or the event dispatcher.
- **Skipping boundary enforcement because "the team already knows not to reach across."** Conventions
  erode under deadline pressure; a CI-enforced check (`boundary-enforcement-and-fitness-functions.md`)
  is what actually holds the line.
- **Shared tables across modules, dressed up as separate modules.** If two modules' code both query
  the same table, the module boundary is cosmetic — see `data-isolation-and-persistence.md`'s isolation
  tiers.
- **Extracting a module before its boundary has actually held up over time.** Extraction-readiness
  (`extraction-to-microservice.md`) requires the same hygiene the other four references already
  enforce, proven out in practice — not a one-time checklist pass right before extracting.
- **Treating every module as an eventual microservice.** Most modules stay in the monolith
  indefinitely — extraction is the exception this skill makes safe when it's genuinely warranted, not
  the implicit goal of applying it.
- **A "shared" module quietly growing past a few small, stable types.** A Shared Kernel
  (`domain-driven-design/reference/strategic-design.md`'s decision, not this skill's) is meant to stay
  tiny and jointly owned — left unchecked it becomes a second Big Ball of Mud that every module
  secretly depends on, with a respectable-sounding name.
