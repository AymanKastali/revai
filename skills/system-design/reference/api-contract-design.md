# API & protocol design (system boundary)

## Contents
Protocol selection by boundary type · versioning at the system level · pointer to `best-practices`
for endpoint-level shape · examples.

This reference owns *which protocol crosses a given boundary and why* — the system-level contract
decision. Once REST is chosen for a boundary, `best-practices/api-design.md` owns the endpoint
shape (verb-free URLs, status codes, pagination, idempotency keys); this file doesn't restate that.

## Protocol by boundary type

| Boundary | Default | Why |
|---|---|---|
| Public/client-facing (web, mobile) | REST (or GraphQL if clients need to shape heterogeneous queries themselves) | Widest tooling support, cacheable, human-debuggable; GraphQL earns its place when clients genuinely need to compose varied queries against the same graph, not by default preference. |
| Internal, service-to-service (east-west) | gRPC/Protocol Buffers | Binary framing and codegen'd contracts outperform REST+JSON for internal traffic with no browser in the loop; the contract is enforced at compile time instead of by convention. |
| Real-time / streaming / bidirectional | WebSockets or Server-Sent Events | SSE for one-way server-push (simpler, works over plain HTTP); WebSockets when the client needs to push back too. Neither is the default — most APIs don't need either. |
| Decoupled, fire-and-forget, or spike-absorbing | A message queue/stream, not a synchronous protocol at all | See `reference/communication-patterns.md` — this is a sync-vs-async decision, not a protocol pick among synchronous options. |

State the choice per boundary in the diagram (see
`reference/high-level-architecture-diagramming.md`), not just once for "the API" — a system
routinely has a REST edge and a gRPC interior, and both deserve a stated reason.

## Versioning, at the system level

Whatever the protocol, state how a breaking change to this boundary's contract gets introduced
without breaking existing callers — a version segment in the URL/package, a new field that's
additive-only until the old one is deprecated, or a schema-registry-enforced compatibility mode for
event contracts (see `reference/communication-patterns.md`). The mechanism is `best-practices`'
territory once chosen (`api-design.md` for REST versioning); the decision that a versioning story
exists at all is made here.

## Checklist

- [ ] Each system boundary in the diagram has a stated protocol and a one-line reason, not a
      default assumed silently
- [ ] GraphQL, gRPC, or WebSockets/SSE are chosen because their specific case (client-composed
      queries, internal east-west, real-time push) actually holds — not by default preference
- [ ] A versioning/compatibility story is stated for every boundary that external or
      independently-deployed callers depend on
- [ ] Endpoint-level shape (once REST is chosen) is left to `best-practices/api-design.md`, not
      re-specified here
