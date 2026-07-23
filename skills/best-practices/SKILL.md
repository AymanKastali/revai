---
name: best-practices
description: Ensures every piece of code, technical decision, or proposed approach follows an established, proven engineering practice instead of an invented one. Use when writing any code, or handling API design, data access, migrations, config/secrets, error handling, resilience, concurrency, caching, messaging, authentication/authorization, observability, or testing — anywhere an implementation choice is being made.
---

# Best practices

## The habit

Most problems that feel novel in the moment aren't. Someone has already solved retry logic,
pagination, idempotency keys, rate limiting, cache eviction, password hashing, and auth flows — and
the solution is well-known and already sitting in a standard library or a dominant package.
Reinventing it costs time now and correctness later (the standard solution has already had its edge
cases found by everyone else). Before writing anything bespoke, ask: **has this already been solved,
and by what standard?** Ask it *before* the first line of a new function or type, not during
self-review after the fact.

## The search order

Work down this list. Only drop to the next tier when the current one is checked and doesn't fit —
not skipped out of habit or unfamiliarity.

1. **Standard library, or something already a dependency in this repo.** Cheapest and safest —
   already vetted by the ecosystem and, if already used here, by this codebase.
2. **The ecosystem's dominant, well-maintained library for exactly this problem.** Check license,
   dependency weight, and maintenance status before adopting it.
3. **An established protocol, format, or convention**, even implemented by hand — RFC 3339
   timestamps, semver, OpenAPI shapes, OAuth2/OIDC flows, HTTP status codes used as intended.
4. **A recognized design pattern or algorithm from the literature** — exponential backoff with
   jitter, token-bucket rate limiting, LRU eviction, circuit breaker, the outbox pattern.

Only after exhausting 1–3 does bespoke enter — and even then, shape it like the recognized pattern
in tier 4 rather than inventing structure freestyle. Bespoke is right only when the behaviour is
genuinely domain-specific, a real constraint rules the standard option out, or the standard option
is a poor fit and you can say exactly why. Name the reason wherever the decision is recorded —
"didn't think to check" is never a reason.

## Quick reference

| Concern | Reference |
|---|---|
| HTTP APIs/endpoints | `reference/api-design.md` |
| Queries/repositories/transactions | `reference/data-access-patterns.md` |
| Migrations/schema changes | `reference/safe-schema-changes.md` |
| Config/secrets/startup | `reference/config-and-secrets.md` |
| Error paths/logging | `reference/error-handling-and-logging.md` |
| Network calls/retries/shutdown | `reference/resilience-and-timeouts.md` |
| Goroutines/async/shared state | `reference/concurrency-and-context-safety.md` |
| Driving implementation with TDD | `reference/tdd.md` |
| What a backend test runs against | `reference/backend-testing.md` |
| Sizing work into shippable PRs | `reference/pr-sizing.md` |
| Publishing/consuming events or messages | `reference/event-driven-messaging.md` |
| Identity and permission checks | `reference/authn-and-authorization.md` |
| Metrics and distributed tracing | `reference/observability.md` |
| Caching a data source | `reference/caching.md` |

## Common mistakes

- Asking the "has this been solved" question only when convenient, not every time.
- Skipping a search-order tier out of unfamiliarity rather than a real, stated reason.
- Treating unfamiliarity or preference as a valid reason to go bespoke.
- Gold-plating a one-off, low-stakes throwaway with a heavyweight library or "proper" protocol —
  proportional judgement applies both ways.
- Stalling in comparison-shopping when several standards are equally dominant — name the trade-off
  and pick one.
