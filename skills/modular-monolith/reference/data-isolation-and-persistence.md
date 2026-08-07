# Data isolation & persistence

## Contents
The three isolation tiers · the tell for getting it wrong · relationship to storage-engine choice.

Owns *which tier of data isolation* a module gets within one deployable — not which storage engine to
use (`system-design/reference/data-layer-architecture.md`'s territory) and not that a module owns its
own tables at all (`domain-driven-design/reference/architecture-and-layering.md` already states that
as a rule; this file is the concrete tiering underneath it).

## The three tiers

In increasing isolation and operational cost — start at tier 2, escalate only when tier 2 is a
measured, real constraint:

1. **Shared tables across modules.** The anti-pattern. Two modules' code both querying the same table
   is an invisible cross-module dependency that defeats the entire point of drawing a module boundary
   — a schema change one module makes can silently break another with no compiler or CI signal.
2. **Schema-per-module, one database.** The default. Each module gets its own schema; no cross-schema
   joins; still one transactional boundary and one connection pool to operate. This is where most
   modules should live, indefinitely.
3. **Database-per-module.** A further escalation, reached only once schema-per-module is a measured,
   real constraint (e.g. a module's storage/throughput profile genuinely doesn't fit the shared
   instance — see `system-design/reference/capacity-estimation.md`). Anything crossing modules now
   needs eventual consistency via a saga or outbox
   (`domain-driven-design/reference/process-managers-and-integration.md`), because there's no longer a
   single transaction spanning both.

## The tell

**A query joining across two modules' schemas is the concrete signal the isolation tier has already
been violated.** This is the one thing worth grepping for in review — a `JOIN` (or its ORM equivalent)
that spans two modules' tables means the module boundary is cosmetic, not real, regardless of how the
code is organized above the database.

## Checklist

- [ ] Every module's tier is stated explicitly (shared / schema-per-module / DB-per-module) — not left
      to be inferred from the code
- [ ] No query joins across two modules' schemas — that join is refactored into two queries plus an
      in-process facade call or event, per `reference/in-process-communication.md`
- [ ] A module escalated to DB-per-module has a stated, measured reason, not a default "just in case"
      posture
- [ ] Storage-engine choice for a given tier is left to `system-design/reference/data-layer-
      architecture.md`, not re-decided here
