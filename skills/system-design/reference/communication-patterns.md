# Communication patterns

## Contents
Sync vs. async · message queues/streams · concurrency control for shared state · pointer to
`best-practices` · examples.

Owns the *shape* of how two components talk — blocking request/response vs. decoupled
publish/consume — and the *decision* to add concurrency control where state is shared. The actual
retry/backoff code (`best-practices/resilience-and-timeouts.md`), the message contract and
idempotent-consumer rules (`best-practices/event-driven-messaging.md`), and shared-state code safety
(`best-practices/concurrency-and-context-safety.md`) live there, not here.

## Sync vs. async

- **Synchronous (HTTP/gRPC).** The caller needs the result *now* to proceed — a checkout flow
  reading back a payment authorization, a read that must reflect the latest write. Default choice
  when nothing below applies.
- **Asynchronous (queue/stream — Kafka, RabbitMQ, SQS).** Reach for this when any of these actually
  hold, not as a default "more scalable" upgrade:
  - The caller doesn't need the result before responding to *its* caller (fire-and-forget: send a
    welcome email, emit an analytics event).
  - The work is heavy enough that doing it inline would blow the caller's latency budget (see
    `reference/capacity-estimation.md`) — hand it to a background worker instead.
  - Traffic arrives in bursts and the downstream can't (or shouldn't have to) scale to the peak —
    the queue absorbs the spike and the consumer drains it at a steady rate.
  - Two components should be decoupled — the producer shouldn't fail or block because a consumer is
    down.

State which one applies per interaction in the design's diagram/cross-cutting section — "async
because X" or "sync because the caller needs Y back immediately," never silently defaulted.

## Concurrency control

Where two requests can race to modify the same piece of state (double-booking a seat, two transfers
overdrawing the same balance), state the mechanism:

- **Optimistic locking** — a version/timestamp column checked on write; the losing writer retries
  or fails visibly. Default when contention is rare — cheap, no held lock.
- **Distributed lock** (Redis/ZooKeeper-based) — a lock held for the duration of a critical section
  across processes. Reach for this only when optimistic retry genuinely can't work (the operation
  isn't idempotent/retryable) — a held lock is a correctness tool, not a default concurrency
  strategy, and it introduces its own failure mode (a lock holder that dies without releasing it).

This is a system-level decision that a given aggregate needs *some* concurrency guard; the actual
locking code is `best-practices/concurrency-and-context-safety.md`'s territory.

## Checklist

- [ ] Every interaction between two components states sync or async, with the reason
- [ ] Async is chosen because a specific trigger (decoupling, spike absorption, heavy background
      work, fire-and-forget) holds — not as a default "more scalable" choice
- [ ] Any shared, concurrently-writable state names its concurrency-control mechanism
- [ ] A distributed lock is proposed only where optimistic retry genuinely doesn't work, with the
      reason stated
- [ ] The message contract, idempotent-consumer rule, and retry/backoff code are left to
      `best-practices`, not re-specified here
