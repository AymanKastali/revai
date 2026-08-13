---
name: best-practices
description: Applies the language-agnostic standard for engineering decisions — never invent what the industry already solved. Use when choosing an approach, adopting a library or pattern, or writing anything that touches an API or contract, a query, transaction or migration, configuration or secrets, timeouts, retries or failure handling, concurrency, authentication or authorization, logging, metrics or tracing, caching, queues, background jobs, tests, or how a change is delivered.
---

# Best practices

Almost nothing you are asked to build is novel. Retries, pagination, idempotency, password hashing,
backoff, cache invalidation, schema evolution, delivery semantics — each has a known answer that has
already had its edge cases found by everyone else. Reinventing one costs an hour now and a
production incident later.

This standard governs **what you build with**: which solution, protocol and shape. `clean-code`
governs how the result reads; `domain-driven-design` governs how the domain is modelled. When those
standards apply too, they apply on top of these rules, not instead of them.

## Contents

- **Best-practice rules** — 99 rules in ten groups: choosing the solution, interfaces, data,
  config and lifecycle, resilience, concurrency, security, observability, messaging, tests and
  delivery. Rule 1 gates each group on its concern. Injected every session, so they may already be in
  your context.
- **The answers you are not allowed to reinvent** — 22 concerns, each with its established solution
  named. Start here when rule 2 asks what the standard solution is.
- **Depth** — worked bad/good pairs for the rules that get misread without one.
- **Anti-pattern scan list** — 85 rows, coded by group (`D` decisions, `I` interfaces, `Q` data,
  `C` config, `R` resilience, `X` concurrency, `S` security, `O` observability, `M` messaging,
  `T` tests), to work down while reviewing.

<!-- HARD-RULES:START -->
## Best-practice rules

These are not aspirations. Code that violates one is not finished. Rule 1 decides which groups apply
to the change in front of you — every group after the first names its concern in its heading.

### Choosing the solution — always applies

1. Each group below is gated by its concern: a change with no HTTP interface answers to no interface rule. A change that touches a concern answers to every rule in that group, in any language or stack.
2. Before writing anything past glue, state what the established solution is and adopt it. If you cannot name one, you have not looked yet.
3. Search in this order, stopping at the first tier that fits: the standard library or a dependency this repo already has; the ecosystem's dominant maintained library for exactly this problem; an established protocol, format or convention; a named pattern from the literature.
4. Leave a tier only for a reason you can state out loud. Unfamiliarity is not a reason, preference is not a reason, and "I didn't check" is not a reason.
5. Bespoke is the last tier, needs its reason recorded where the decision lives, and still takes the shape of the closest recognized pattern rather than a new invention.
6. Do it the way this codebase already does it. One approach per concern per codebase; a second one is a migration with a deadline, never a coexistence.
7. Where the industry is genuinely split, follow the convention already present here and apply it everywhere. Never invent a third way to settle a tie.
8. Scale the solution to the stakes and the blast radius. A one-off script gets no circuit breaker; a payment path gets no hand-rolled retry loop.
9. Prefer the reversible choice. The harder something is to undo — a stored data shape, a published contract, a dependency — the less latitude it has to deviate from the standard.
10. A new dependency must earn entry: it does something the standard library does not, you can state its maintenance status and license, and it is worth its transitive weight.

### Interfaces and contracts — when you expose, change or consume an interface others call

11. Contract first: the schema — OpenAPI, protobuf, JSON Schema, a typed client — is written and reviewed before the implementation, and stays the source of truth afterwards.
12. Use the protocol as specified. HTTP verbs carry their defined semantics, GET has no side effects, GET/PUT/DELETE are idempotent, and status codes mean what the standard says they mean.
13. Never return a success status with a failure body, and never answer a caller's mistake with a server error.
14. One error shape across the whole interface, machine-readable, carrying a stable code the caller can branch on — `application/problem+json` (RFC 9457) for HTTP.
15. Error responses leak nothing: no stack trace, no query text, no internal host, path, or identifier.
16. Never break an existing consumer. Additions are optional with a default; no shipped field is removed, renamed, retyped, narrowed, or repurposed.
17. Version only when a break is genuinely unavoidable — then run both versions, publish a deprecation with a sunset date and a migration path, and confirm the traffic is gone before removing anything.
18. Every collection response is paginated with a default and a maximum page size, keyset or cursor based wherever the set can grow without bound.
19. Timestamps cross the wire as RFC 3339 with an explicit offset and are stored in UTC; durations state their unit; money is a minor-unit integer or an exact decimal with its currency, never a float.
20. Validate every input at the boundary against an allowlist of type, range, length and shape, and reject what fails before it reaches any business logic.
21. Never accept from the caller what the server must decide: identity, roles, prices, totals, timestamps of record, or another subject's identifier.
22. Any non-idempotent write a client may retry accepts a client-generated idempotency key, stores the first outcome against it, replays that same outcome on a repeat, and rejects the key if it arrives with different parameters.
23. Identifiers handed to clients are opaque and unguessable; a sequential primary key is never the public handle for something access-controlled.

### Data and persistence — when you read, write or reshape stored data

24. Queries are parameterized or built by the query builder. String-concatenated SQL is never acceptable — not for values, not for identifiers, not for an `IN` list.
25. Every read that could match an unbounded number of rows carries an explicit limit.
26. No query inside a loop over the results of another. Fetch as a set, join, or batch by keys.
27. A transaction spans exactly the writes that must commit together, opens as late as possible, and contains no network call, no queue publish, no user wait and no long computation.
28. Read-then-write on contended state is guarded by an optimistic version check or an explicit lock. Never assume you were the only writer.
29. State the isolation level a piece of logic depends on instead of silently inheriting the default.
30. Every query path you introduce has an index that serves it, and anything touching a large table has its plan checked before merge.
31. Connections come from a pool with a bounded size, an acquisition timeout, and a statement timeout.
32. The schema enforces every invariant the data must always hold — not-null, unique, foreign key, check — rather than trusting application code to be the only writer.
33. Store time in UTC, money in exact numerics, and enumerations as stable explicit values that are never a display string.
34. Every schema change is a versioned migration file in the repo, reviewed like code and applied by the same automation everywhere. No environment is ever hand-edited.
35. A migration is backward compatible with the version already running: expand, backfill, move reads, then contract — a separate deploy each.
36. A destructive change — drop, rename, narrow, add a non-null column without a default — never ships in the same deploy as the code that stops relying on the old shape.
37. Backfills run in bounded resumable batches outside the migration path, and never hold a lock on a hot table for the length of the job.

### Configuration, secrets and lifecycle — when you add config, read a secret, or change startup

38. Configuration comes from the environment. One build artifact runs everywhere, with no per-environment branch in the code.
39. All configuration is validated at startup, and the process dies immediately with a message naming exactly what is missing or invalid.
40. No secret in source, in history, in a log, in an error, in a URL, in a client bundle, or baked into an image.
41. Secrets arrive from a manager or injected environment and can be rotated without a code change.
42. Every default is the safe default — verification on, debug off, permissions closed. A convenient default that weakens security is a defect.
43. Startup checks its dependencies before accepting traffic; shutdown stops accepting, drains in-flight work against a deadline, releases resources, then exits.
44. Liveness and readiness are distinct: readiness says whether dependencies make this instance usable, liveness only whether the process must be restarted.
45. A feature flag has a name, an owner and a removal date, and is deleted once its rollout finishes.

### Failure and resilience — when you call anything that can fail or be slow

46. Every outbound call — network, database, queue, subprocess — has an explicit timeout, inside an overall deadline for the operation.
47. Retry only what is safe to repeat, only on transient failure, with bounded attempts, exponential backoff with jitter, and a total time budget.
48. Never retry a caller error. Honour `Retry-After`, and back off on 429 and 503 instead of tightening the loop.
49. Bound concurrency and queue depth per dependency, so one slow dependency cannot consume every worker.
50. A dependency whose failure would otherwise pile up gets a breaker or load shedding: fail fast while it is down, and recover deliberately.
51. Every dependency has a defined behaviour when it is unavailable — a fallback, a degraded answer, or a fast clear failure. Hanging is not one of them.
52. Nothing grows unbounded: not a queue, buffer, cache, retry loop, page size, batch, or accumulated result set.
53. Distinguish transient from permanent failure and handle them differently at the point of handling.
54. Measure elapsed time with a monotonic clock, never by subtracting wall-clock readings, and never trust a timestamp a client supplied.
55. Every public entry point is rate limited, and the limit is enforced server-side.

### Concurrency — when work runs in parallel or outlives the call that started it

56. Every concurrent task has an owner that waits for it, a bounded lifetime, and a cancellation path. Fire-and-forget is never acceptable.
57. Cancellation and deadlines propagate through every layer of the call chain, and every blocking wait honours them.
58. Shared mutable state is exactly one of: owned by a single task, immutable, or guarded by a stated lock. Never left to chance.
59. Never hold a lock across IO, and acquire multiple locks in one documented order everywhere in the codebase.
60. Check-then-act on shared state is atomic, or it is a bug that only appears under load.
61. Prefer immutability and passing messages over sharing memory and coordinating locks.
62. Sleep is never a synchronization primitive — not in code, not in tests.

### Security defaults — when you handle identity, permissions, credentials or untrusted input

63. Authenticate every request and authorize at the resource, server-side, on every access — never on the strength of a client-supplied role, a hidden field, or an unguessable URL.
64. Deny by default. Permissions are an allowlist, and the absence of a rule is a refusal.
65. Use the ecosystem's standard implementation for authentication, sessions, tokens and crypto. Never hand-roll a token format, a signature scheme, or an encryption routine.
66. Hash passwords with a memory-hard function — Argon2id, or scrypt, or bcrypt at cost 10 or more — with a per-password salt. Never a fast digest, never reversible encryption.
67. Anything security-relevant that must be unpredictable comes from a cryptographically secure random source.
68. Every credential holds the narrowest scope and shortest life that works, including the application's own database user.
69. Encode output for the sink that receives it, and never assemble an interpreted string — SQL, shell, HTML, a template, a filesystem path — out of untrusted input.
70. Transport is encrypted and certificates are verified, between internal services as well. Verification is never disabled to make something work.
71. Secrets, tokens and personal data are redacted at the logger, not by remembering not to log them.
72. A known-vulnerable dependency fails the build. It is not waived on the argument that the vulnerable path looks unreachable.

### Observability — when you add a log line, a metric, an alert or a trace

73. Logs are structured records with a level, an event name and typed fields, written to standard output — never a prose sentence a reader has to parse back into data.
74. One correlation id per request or message, propagated to every downstream call and attached to every log line and span it produces.
75. Handle or log, never both at every layer. An error is logged once, where it is handled, carrying the operation, the identifiers needed to find the record, and the cause chain intact.
76. Log at the level the reader needs: a line that fires on every request wants to be a metric, and an error nobody can act on is noise.
77. Every service reports latency as a distribution, never a mean, alongside traffic, error rate and saturation, per endpoint and per consumer.
78. Metric and label names follow the ecosystem convention and have bounded cardinality. A user id, request id, or raw path is never a label.
79. Alert on what a user feels — error rate and latency against a stated objective — not on internal causes.
80. Instrumentation ships with the change, not after the first incident that needed it.

### Asynchronous work and messaging — when you publish, consume, queue or schedule

81. Assume at-least-once delivery: every consumer is idempotent on a message id or business key, and tolerates duplicates, retries and out-of-order arrival.
82. Never treat a write to a store and a publish to a broker as one atomic act. Commit once, and derive the publish from committed state.
83. Every message carries an explicit schema version and evolves compatibly; consumers ignore fields they do not know rather than failing on them.
84. Consumer failure has a defined path: bounded retry, then a dead-letter queue that is monitored and owned. One poison message never blocks a partition indefinitely.
85. Depend on ordering only per key, and only where the transport actually guarantees it.
86. Work that can outlast a request's deadline is queued and acknowledged, with a documented way for the caller to learn the outcome.
87. Scheduled and background jobs are idempotent, guarded against concurrent runs across replicas, bounded by a timeout, and observable. A job that fails silently is worse than no job.

### Tests and delivering the change — always applies

88. Every behaviour change ships with a test that fails before it and passes after.
89. Most tests are fast and isolated; integration tests cover wiring, queries and serialization against the real engine rather than a stub; end-to-end tests are few and cover critical paths only.
90. Tests are deterministic: time and randomness injected, no network, no sleeping, no shared mutable fixture, no dependence on execution order.
91. Assert observable behaviour through the public surface. Never assert on a private internal, and never verify a call the caller cannot observe.
92. Prefer a fake you control over a mock for anything you own. Mock only at a boundary you cannot run.
93. Cover failure paths, boundaries and empty cases. A suite that only proves the happy path proves very little.
94. A bug fix begins with a failing test at the level the bug actually lives.
95. A flaky test is a defect: quarantine it and fix it, or delete it. Never rerun until green.
96. Formatting, linting and type checking are enforced by the machine on every change, and CI runs the same commands a developer runs locally.
97. Changes arrive small, self-contained and revertible: one concern per commit, no refactor mixed into a behaviour change, and a message that says what changed and why.
98. Anything another repo or team consumes is versioned semantically, with breaking changes stated where its consumers will actually read them.
99. The lockfile is committed, applications install from it exactly, and dependency updates land as reviewed changes rather than a blind bulk bump.
<!-- HARD-RULES:END -->

## The answers you are not allowed to reinvent

Rule 2 asks you to name the established solution. For the concerns that come up constantly, this is
that list. Reaching for something else here needs the stated reason rule 4 demands.

| Concern | The established answer |
| --- | --- |
| Retrying a failed call | Exponential backoff with jitter, bounded attempts, overall time budget |
| Making a retry safe | Client-supplied idempotency key; first outcome stored and replayed |
| Paging a collection | Keyset/cursor pagination; offset only for small bounded sets |
| Storing a password | Argon2id with a per-password salt (scrypt, or bcrypt cost ≥ 10, as fallbacks) |
| Delegated access or third-party login | OAuth 2.x / OIDC through a maintained library |
| Reporting an API error | RFC 9457 `problem+json` with a stable machine-readable code |
| Timestamps on the wire | RFC 3339 with offset, UTC in storage |
| Money | Minor-unit integer or exact decimal, always with a currency code |
| Identifier in a distributed system | UUIDv7 or ULID — time-ordered, collision-free, opaque |
| Protecting a failing dependency | Circuit breaker plus a bulkhead bounding concurrency |
| Publishing after a state change | Derive from committed state (outbox, CDC) — never a dual write |
| Handling a duplicate message | Idempotent consumer keyed on message id or business key |
| Reading through a cache | Cache-aside with jittered TTL; single-flight or stale-while-revalidate |
| Evicting from a cache | The cache's own LRU/LFU policy, not a hand-rolled map plus a sweeper |
| Limiting request rate | Token bucket or sliding window, enforced server-side |
| Evolving a schema | Expand → backfill → switch reads → contract, one deploy each |
| Supplying configuration | Environment-injected, validated at startup, one artifact per build |
| Versioning for consumers | Semantic versioning |
| Running work in parallel | A task group or scope that owns, bounds and cancels its children |
| Defining a serialization contract | A schema you generate from: OpenAPI, protobuf, JSON Schema |
| Answering a long-running request | Queue the work, return an accepted response plus a status handle |
| Correlating across services | W3C `traceparent` propagation, OpenTelemetry instrumentation |

Where consensus genuinely does not exist — JSON casing, layout of a test file, REST versus RPC for
an internal call — rule 7 applies: match what is already here. Two conventions in one codebase is
worse than either convention.

## Depth

Pseudocode is deliberately language-neutral.

### Rule 22 — an idempotency key that actually works

Bad — the key is checked for presence and then ignored, so a retry after a lost response charges
twice:

```text
function charge(request):
    if store.seen(request.idempotencyKey):
        return Error("duplicate request")     # caller retried; now they get an error
    payment = gateway.charge(request.amount)
    store.markSeen(request.idempotencyKey)
    return payment
```

Good — the first outcome is what the key stores, so a replay is indistinguishable from the original:

```text
function charge(request):
    recorded = idempotency.find(request.idempotencyKey)
    if recorded exists:
        if recorded.requestFingerprint != fingerprint(request):
            return Conflict("idempotency key reused with different parameters")
        return recorded.outcome                    # same status, same body, including a failure

    reservation = idempotency.reserve(request.idempotencyKey, fingerprint(request))
    outcome = gateway.charge(request.amount)
    idempotency.record(reservation, outcome)
    return outcome
```

Storing the failure matters as much as storing the success: a caller retrying a request that already
failed must see the same failure, not a second attempt.

### Rules 27, 82 — transaction scope, and the dual write

Bad — a network call inside the transaction holds locks for as long as the broker takes to answer,
and if the publish fails after the commit the two stores disagree forever:

```text
transaction:
    order = orders.insert(order)
    broker.publish(OrderPlaced(order.id))    # network IO inside the transaction
    audit.post(externalService, order)       # and a second one
```

Good — one commit, and the publish is derived from what committed:

```text
transaction:
    order = orders.insert(order)
    outbox.insert(OrderPlaced(order.id))     # same transaction, same store

# a separate, retrying, idempotent relay drains the outbox
function relay():
    for record in outbox.unpublished(limit = 100):
        broker.publish(record)               # at-least-once; consumers are idempotent (rule 81)
        outbox.markPublished(record)
```

### Rules 35, 36 — expand and contract

Renaming a column is not one change; it is four deploys, and each one must run correctly beside the
version already in production:

| Deploy | Schema | Code |
| --- | --- | --- |
| 1 — expand | Add the new nullable column | Write both columns, read the old one |
| 2 — backfill | Copy old to new in batches (rule 37) | Unchanged |
| 3 — switch | Add the constraint the new column needs | Write both, read the new one |
| 4 — contract | Drop the old column | Write and read only the new one |

So `ALTER TABLE customers RENAME COLUMN email TO email_address` as a single migration is never
correct: every request served by an instance still running the old code fails the moment it applies.

### Rules 56, 57, 86 — an owned task, not a fire-and-forget

Bad — nothing waits for it, nothing cancels it, and a failure inside it is invisible:

```text
function handleUpload(request):
    spawn(fn(): thumbnails.generate(request.fileId))    # orphaned
    return Accepted
```

Good — work that outlives the request is queued; work done in parallel is owned and bounded:

```text
function handleUpload(request):
    jobs.enqueue(GenerateThumbnails(request.fileId))    # durable, retried, observable
    return Accepted(statusUrl = "/uploads/" + request.fileId)

function runBatch(deadline, fileIds):                  # in the worker
    group = taskGroup(deadline, maxConcurrent = 8)
    for id in fileIds:
        group.spawn(fn(ctx): thumbnails.generate(ctx, id))
    return group.wait()          # propagates the first failure, cancels the rest
```

### Rules 21, 63 — authorize at the resource

Bad — the caller supplies the role and the owner, so anyone can read anyone's invoice by editing two
fields:

```text
function getInvoice(request):
    if request.body.role == "admin":
        return invoices.find(request.body.invoiceId)
    return invoices.findFor(request.body.customerId, request.body.invoiceId)
```

Good — identity comes from the authenticated principal, and the check happens against the resource
that was actually loaded:

```text
function getInvoice(request):
    principal = authenticate(request)                 # never from the body
    invoice = invoices.find(request.path.invoiceId)
    if invoice is absent: return NotFound
    if not policy.canRead(principal, invoice): return NotFound
    return invoice
```

Returning `NotFound` rather than `Forbidden` for a resource the caller may not know about keeps the
authorization decision from leaking existence.

### Rules 73, 74, 75 — one structured log, once

Bad — prose, no correlation id, the cause discarded, and the same failure logged again by every layer
it passes through:

```text
catch error:
    log("failed to save order for user " + userId + ": " + error.message)
    throw Error("save failed")                 # cause dropped, and the caller logs it again
```

Good — inner layers add context and return; the layer that decides the outcome logs once:

```text
catch error:
    return wrap(error, "persist order")

catch error:                                   # at the boundary
    log.error("order.persist.failed", traceId = ctx.traceId, orderId = order.id, cause = error)
    return ServiceUnavailable(problem("order-not-persisted"))
```

### Rules 90, 92 — a deterministic test

Bad — real time, real network, and a sleep standing in for synchronization. Passes locally, fails in
CI:

```text
test "expires after a day":
    token = issueToken()
    sleep(2)
    assert http.get("https://auth.example.com/verify?t=" + token).status == 401
```

Good — the clock is an input and the boundary is a fake you control:

```text
test "expires after a day":
    clock = FakeClock(at = "2026-01-01T00:00:00Z")
    tokens = TokenService(clock, FakeKeyStore())
    token = tokens.issue(subject = "u-1")

    clock.advance(25.hours)

    assert tokens.verify(token) == Expired
```

## Anti-pattern scan list

A scan list, not rules. Work down it when reviewing a change.

| Code | Anti-pattern |
| --- | --- |
| D1 | A bespoke solution to a solved problem, with no reason recorded |
| D2 | A tier of the search order skipped out of unfamiliarity |
| D3 | A second way to do something this codebase already does one way |
| D4 | A dependency added for what the standard library already provides |
| D5 | A heavyweight pattern on a throwaway path, or a hand-rolled one on a critical path |
| D6 | An irreversible choice — data shape, public contract — made casually |
| I1 | Implementation written first, schema retrofitted to match it |
| I2 | HTTP verb or status code used against its defined meaning |
| I3 | `200` carrying an error, or `500` for a caller's mistake |
| I4 | A second error shape in the same interface |
| I5 | Internals in an error response — stack trace, query, host, path |
| I6 | A shipped field removed, renamed, retyped or repurposed |
| I7 | An unpaginated collection, or a page size with no maximum |
| I8 | A float for money, a naive local timestamp, a bare unitless number |
| I9 | Input reaching business logic unvalidated |
| I10 | A server decision — price, role, identity — taken from the request body |
| I11 | A retriable write with no idempotency key, or a key that is checked and discarded |
| Q1 | A query assembled by string concatenation |
| Q2 | An unbounded read, or a query in a loop (N+1) |
| Q3 | Network IO, a publish, or a long computation inside a transaction |
| Q4 | Read-then-write with no version check and no lock |
| Q5 | A new query path with no index, or an unexamined plan on a large table |
| Q6 | An unbounded connection pool, or one with no acquisition or statement timeout |
| Q7 | An invariant enforced only in application code that the schema could hold |
| Q8 | A schema change applied by hand, or a migration that is not in the repo |
| Q9 | A migration the currently running version cannot survive |
| Q10 | A destructive change shipped with the code that stopped using the old shape |
| Q11 | A backfill inside the migration, unbatched or not resumable |
| C1 | A hardcoded environment value, or an `if production` branch in the code |
| C2 | Configuration validated on first use instead of at startup |
| C3 | A secret in source, history, a log, a URL, or an image |
| C4 | A default that is convenient rather than safe |
| C5 | Traffic accepted before dependencies are ready, or shutdown with no drain |
| C6 | Readiness and liveness answering the same question |
| C7 | A feature flag with no owner and no removal date |
| R1 | A call with no timeout, or an operation with no overall deadline |
| R2 | Retry without jitter, without a budget, or on a non-retriable failure |
| R3 | Unbounded concurrency or queue depth against one dependency |
| R4 | No breaker or shedding where failures would pile up |
| R5 | An undefined behaviour when a dependency is down — including hanging |
| R6 | Anything unbounded: buffer, cache, batch, accumulated result set |
| R7 | Elapsed time measured from wall-clock readings, or a client timestamp trusted |
| R8 | A public entry point with no server-side rate limit |
| X1 | A task nobody owns, waits for, or can cancel |
| X2 | A deadline or cancellation that stops propagating partway down |
| X3 | Shared mutable state with no stated ownership, immutability, or lock |
| X4 | A lock held across IO, or two locks taken in inconsistent order |
| X5 | Check-then-act on shared state that is not atomic |
| X6 | Sleep used to make concurrent code line up |
| S1 | Authorization decided from a client-supplied role, hidden field, or obscure URL |
| S2 | Authorization checked at the edge but not at the resource |
| S3 | A permission model that allows by default |
| S4 | Hand-rolled crypto, token format, or session handling |
| S5 | A password behind a fast digest, or encrypted instead of hashed |
| S6 | A predictable value where unpredictability is the security property |
| S7 | A credential broader or longer-lived than the work requires |
| S8 | An interpreted string built from untrusted input |
| S9 | Certificate verification disabled, or an unencrypted internal hop |
| S10 | Secrets or personal data reaching a log because nothing redacts them |
| S11 | A known-vulnerable dependency waived as unreachable |
| O1 | An unstructured log line, or one that has to be parsed back into fields |
| O2 | No correlation id, or one that stops at a service boundary |
| O3 | The same error logged at every layer, or logged and rethrown |
| O4 | A cause chain flattened into a message string |
| O5 | Latency reported as a mean |
| O6 | An unbounded metric label — user id, request id, raw path |
| O7 | An alert on a cause nobody can tie to user impact |
| M1 | A consumer that breaks on a duplicate or an out-of-order message |
| M2 | A dual write treated as atomic |
| M3 | An unversioned message, or a consumer that fails on an unknown field |
| M4 | No dead-letter path, or one nobody monitors |
| M5 | Ordering assumed where the transport does not guarantee it |
| M6 | Long work held inside a request, or a queued job with no way to check it |
| M7 | A scheduled job that can run twice at once, or fail silently |
| T1 | A behaviour change with no test that fails without it |
| T2 | A test suite inverted — slow end-to-end tests carrying the coverage |
| T3 | A test depending on real time, real network, or another test's leftovers |
| T4 | An assertion on a private internal |
| T5 | A mock for something the test could run for real |
| T6 | Only the happy path covered |
| T7 | A flaky test rerun until it passes |
| T8 | Formatting, linting or typing left to review instead of the machine |
| T9 | A commit mixing a refactor with a behaviour change |
| T10 | A breaking change shipped without a version bump consumers can see |
| T11 | An uncommitted lockfile, or a bulk dependency bump nobody read |
