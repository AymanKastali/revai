# Scalability & resilience (system topology)

## Contents
Horizontal scaling · database scaling · resiliency patterns at the topology level · pointer to
`best-practices` · examples.

Owns the *system-topology* shape of scaling and failure tolerance — where redundancy and headroom
live in the diagram. The per-call retry/backoff/circuit-breaker code is
`best-practices/resilience-and-timeouts.md`'s territory; this reference decides *that* a breaker or
a redundant path belongs at a given point in the system, not how it's coded.

## Horizontal scaling

- **Application services must be stateless** to scale horizontally — no in-memory session or
  request state that a later request to a different instance would need. Session/state that must
  persist belongs in the datastore or cache layer, addressable by any instance.
  A service that's stateful for a real reason (a long-lived streaming connection, an in-memory
  cache warmed per instance) should say so explicitly, since it changes how it scales and deploys.
- State the scaling trigger — CPU/memory threshold, request-rate threshold, queue depth for a
  worker — rather than leaving "it scales horizontally" unstated and unmeasured.

## Database scaling

In order of increasing cost/complexity — reach for the next one only once the current one is
measured as insufficient, not pre-emptively:

1. **Connection pooling** (PgBouncer or equivalent) — the near-free first move; a connection-starved
   DB is often mistaken for a scaling problem when it's a pooling problem.
2. **Read replicas** — for read-heavy load (see `reference/capacity-estimation.md`'s ratio), route
   reads that can tolerate slight staleness to a replica, writes to the primary.
3. **Sharding** — see `reference/data-layer-architecture.md`; only once the dataset or write
   throughput itself exceeds one primary's capacity, not as a default "scale-ready" posture.

## Resiliency patterns, at the topology level

- **Circuit breaker** — placed in the diagram between a service and a downstream dependency that
  can fail slow or hard; state which dependency it guards and what it falls back to when open.
- **Bulkhead** — give each downstream dependency its own resource pool (connections, threads,
  goroutines) rather than one shared pool for everything, so one dependency that's slow or failing
  exhausts only its own pool, not the capacity every other call needs too. Pairs directly with the
  circuit breaker above — name which dependencies get an isolated pool, not just which get a breaker.
- **Rate limiting / throttling** — at the ingress layer (see
  `reference/high-level-architecture-diagramming.md`) to protect the system from a traffic spike or
  a bad actor, stated as a topology decision even though the token-bucket/algorithm detail is
  `best-practices`' territory.
- **Graceful degradation** — name what the system serves when a non-critical dependency is down
  (stale cached data, a reduced feature set) rather than failing the whole request. State explicitly
  which paths fail-closed (reject) vs. fail-open (degrade) — this is the same distinction
  `/revai:decide`'s "Reliability & failure semantics" checklist dimension asks about; this reference
  supplies the mechanism, not a new rule.

## Checklist

- [ ] Every application service in the diagram is stated stateless, or its statefulness is named
      and justified
- [ ] The scaling trigger for each service/worker is stated, not left implicit
- [ ] Database scaling follows pooling → read replicas → sharding in that order, each justified by
      a measured or estimated need, not applied pre-emptively
- [ ] Each circuit breaker/rate limiter in the design names what it protects and its fallback
      behavior
- [ ] Each downstream dependency with a real failure risk has its own isolated resource pool
      (bulkhead), not one shared pool with every other dependency
- [ ] Fail-open vs. fail-closed is stated per critical path, consistent with the existing
      "Reliability & failure semantics" checklist dimension
