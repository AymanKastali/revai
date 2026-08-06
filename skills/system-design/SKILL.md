---
name: system-design
description: Owns the system-level mechanics between domain shape and code — capacity estimation, high-level architecture diagramming, API/protocol selection across a boundary, storage-engine selection, communication patterns (sync/async, concurrency control), scalability and resilience mechanics, security and compliance architecture, observability strategy, and infrastructure/CI-CD topology. Use when estimating scale, drawing a system's high-level shape, choosing a protocol or storage engine, or planning how a system deploys, secures, observes, and operates itself in production.
---

# System design

## Overview

`domain-driven-design` shapes *what the system means* — its domain, boundaries, and types.
`best-practices` governs *how a line of code implements* a choice once it's made. This skill is the
layer between them: the system-level mechanics — how big, how it's shaped, what talks to what and
over which protocol, what it runs on. Always considered for an Architecture decision, at a depth
proportional to the stakes — a small internal tool gets a two-line capacity note and a one-box
diagram; a system with a real scale question gets the full math and a multi-service diagram. No
tiers to choose between, same as the rest of this harness — every dimension gets a stated answer or
a one-line "not in play here," never a silent skip.

This skill is consulted by `domain-driven-design`'s `reference/architecture-fit.md` at its "Edges"
step, alongside `best-practices` — the two are peers there: this skill decides the system-level
shape (which protocol, which storage engine, how it scales, what it runs on), `best-practices`
governs the code-level implementation once that shape is chosen. Where a reference below names a
`best-practices` file, that's the line between them — don't re-derive the code-level rule here.

## Quick reference

| Need | Reference |
|---|---|
| Traffic, storage, and bandwidth math | `reference/capacity-estimation.md` |
| Block-diagramming the request path, ingress layer | `reference/high-level-architecture-diagramming.md` |
| Choosing a protocol across a system boundary (REST/GraphQL/gRPC/WebSocket) | `reference/api-contract-design.md` |
| Choosing a storage engine by access pattern, ER shape, sharding | `reference/data-layer-architecture.md` |
| Sync vs. async, message queues, concurrency control | `reference/communication-patterns.md` |
| Horizontal scaling, DB scaling, circuit breakers, rate limiting | `reference/scalability-and-resilience.md` |
| Defense-in-depth layering, authn/authz model, network isolation | `reference/security-and-compliance.md` |
| What must be visible to operate this safely, SLOs | `reference/observability-strategy.md` |
| IaC, containerization/orchestration, CI/CD strategy | `reference/infrastructure-and-cicd.md` |

Requirements/NFR clarification and domain discovery aren't duplicated here — `/revai:decide`'s
dimension checklist and `domain-driven-design`'s discovery reference already own that ground.

## Common mistakes

- **Skipping capacity estimation because scale "feels" obvious.** A two-line back-of-envelope check
  costs little and regularly surfaces a bottleneck (a write-heavy path assumed read-heavy, a
  bandwidth number nobody sized) that "it's probably fine" would have missed.
- **Picking a database or protocol by familiarity, not access pattern.** Reaching for Postgres or
  REST because it's the default reflex, without checking whether the actual read/write shape or
  boundary calls for something else.
- **Treating security, observability, or infra as an afterthought.** Bolting these on after the
  architecture is fixed is more expensive than designing them alongside it — each has a home in the
  design doc from the start, not a follow-up note.
- **Re-deriving best-practices' code-level conventions here.** This skill decides *that* REST is the
  protocol or *that* a circuit breaker is needed; `best-practices/api-design.md` and
  `resilience-and-timeouts.md` own the endpoint shape and the retry code once that's decided.
- **Gold-plating a small system with infrastructure it doesn't need.** A two-user internal tool
  doesn't need a multi-region deploy topology or a service mesh — proportional judgment applies here
  exactly as it does everywhere else in this harness.
