---
name: go-project-layout
description: Applies the Go project layout standard — the physical file and package structure of a Go modular monolith: one directory per bounded context under internal/context/, a surface package at its root with domain/ app/ infra/ sitting beside it, depguard holding the boundary the positional internal/ rule cannot, one Postgres schema and its own migrations per context, and internal/platform/ for generic infrastructure only. Use when starting a Go service or monolith, adding or naming a bounded context, deciding which directory or package a Go file belongs in, laying out aggregates, use cases, ports or adapters, placing migrations against a shared database, wiring a composition root in cmd/, sharing code between Go contexts, or enforcing the import graph with depguard.
---

# Go project layout

`domain-driven-design` says a bounded context owns its model and that dependencies point inward.
`modular-monolith` says every module exposes one entry point, that its internals are unreachable
rather than merely undocumented, and that it owns its storage. Both are properties. This standard is
their Go **form**: the directories, package names and filenames that make those properties true of a
Go binary, and the enforcement that keeps them true once the tree is flat enough to read.

Scope: this standard governs **where a Go file goes**. How Go itself is written belongs to `golang`;
how the domain is modelled belongs to `domain-driven-design`; how one deployable is partitioned
belongs to `modular-monolith`; how Postgres is used belongs to `postgres`. Where those mandate a
property, the rules here name its Go shape — `modular-monolith` rule 31 requires that a module's
internals be unreachable, and Go's `internal/` is positional, so one at the repository root stops
only code outside the module and nothing between contexts. Rules 60 and 61 are therefore load-bearing
rather than advisory: `depguard` is the mechanism, and a boundary with no rule behind it is a naming
convention.

## Contents

- **Layout rules** — 66 rules in eleven groups: the repository root, the context boundary, the three
  layers, the domain layer, the application layer, the infrastructure layer, storage and migrations,
  cross-context integration, shared code and the platform package, tests and enforcement, and growth.
  Rule 1 gates the standard on the codebase being a Go modular monolith, rule 2 gates each group on
  the concern in its heading, and rule 18 gates the whole domain layer on the context's subdomain.
- **The reference layout** — the annotated tree this standard describes, top to bottom. It is the
  adopted structure, not one option among several.
- **Depth** — worked bad/good pairs for the rules that get misread without one: the boundary
  `depguard` keeps and the config that is it, one context calling another and who writes the outbox,
  one Postgres instance with a schema per context, what survives the extraction test, and where a
  context starts.
- **Anti-pattern scan list** — 69 rows, coded by group (`R` root, `B` boundary, `L` layers, `D`
  domain, `A` application, `I` infrastructure, `S` storage, `X` integration, `P` platform, `T` tests,
  `G` growth), to work down while reviewing.

<!-- HARD-RULES:START -->
## Layout rules

These are not aspirations. A Go tree that violates one is not finished.

Rule 1 gates the standard on the codebase it applies to. Rule 2 gates each group on the concern named
in its heading — a change that adds no adapter answers to no adapter rule. Rule 18 gates the domain
layer a second time, on the subdomain, because a full aggregate model in a supporting context is the
most expensive mistake this layout can be used to make.

### Rules 1-2 — what applies

1. This standard governs the layout of a Go codebase that is one deployable holding more than one bounded context. A single-purpose service, a library, a CLI or a tool follows `golang` rules 23–24 and stops there.
2. Each group below applies only when the change touches the concern its heading names.

### The repository root — always applies

3. Two directories at the root carry Go: `cmd/` and `internal/`. No `pkg/`, no `api/`, no `src/` — `golang` rule 24.
4. `cmd/<binary>/main.go` is the composition root: it reads process configuration, builds the platform dependencies, calls each context's single constructor with that context's raw config, binds each declared port to the facade that satisfies it, and mounts what each constructor returns. One line per context — it never names a package beneath a context root, because rule 17 gives it exactly one constructor to call and rule 60 is what holds it to that.
5. `internal/` holds exactly two directories: `context/` and `platform/`. The level earns its place by separating what the business owns from what any binary would want, and every question about a file starts with which of the two it is.
6. One directory per bounded context sits under `internal/context/`, named for the capability in the ubiquitous language and singular — `internal/context/order/`, never `internal/context/orders/`. The container is `context/` and never `module/`: in Go a module is what `go.mod` declares, and reusing the word makes every sentence about either one ambiguous.
7. `internal/platform/` holds generic technical infrastructure and nothing else. `internal/shared/` does not exist.

### The context boundary — always applies

8. A context's surface is the package at the context's own root — `internal/context/order/`, `package order`. It names every command, query, result, integration event and error a caller may use.
9. Everything else in the context sits beside the surface as directories of `internal/context/order/` — the three layers of rule 15, and `migrations/`, which holds SQL rather than Go. No context imports any of them from another context, and because Go's `internal/` is positional that unreachability is rule 60's `depguard` config rather than the compiler's — `modular-monolith` rule 31 in the form Go actually supports.
10. The surface exposes use cases as methods on one facade type, not a package of loose functions and not a getter per field — `modular-monolith` rules 30 and 34.
11. Surface signatures speak in types the context owns. Never a domain aggregate, a persistence row, an ORM type, or an `http.Request` or `http.ResponseWriter` — `modular-monolith` rule 33.
12. A caller depends on an interface it declares in its own `app/port/`, satisfied by the other context's facade. The two are joined in `cmd/`, so neither names the other in its own package.
13. A context names another context in exactly two adapter packages — its own `infra/adapters/outbound/gateway/` for a call it makes, and its own `infra/adapters/inbound/event/` for an integration event it consumes — and nowhere else. `app/` names no context, rule 60's `depguard` config is what stops any reach beneath another surface, and both edges are listed in its allow-list, which is what makes the module graph reviewable instead of implicit.
14. Integration events are the application layer's published output, so they live in `app/events/`, one file per event named for it — `app/events/paid.go`, `package events`, importing the standard library only. That is a package inside a layer, not a fourth layer: rule 15's three are the only ones. The surface re-exports them as aliases — `type Paid = events.Paid` — so the consumer reads `order.Paid` with no stutter, and `app/command/` can construct one for its own transaction without importing the surface that imports it.

### The three layers inside a context — always applies

15. Three directories sit under `internal/context/<name>/`, beside the surface's own files: `domain/`, `app/`, `infra/`. These are the Go spellings of `domain-driven-design` rule 67's layers.
16. Imports run one way — `infra` to `app` to `domain`. `domain` imports neither of the others, and `depguard` is what makes that true rather than the diagram.
17. The surface's facade file imports `app/` and nothing below it, so changing an aggregate never changes what a caller compiles against. Its one companion is `new.go` at the context root — still `package order` — which imports `infra/` to build this context's adapters and returns the facade with its route registration. The context root is the only file set permitted to import `infra/`, which makes `new.go` the single assembly point, and rule 4 is what calls it. It is not named `wire.go`, which rule 36 already spends on a different job one directory down.

### The domain layer — when the change touches the model

18. This group applies to a context classified **core** under `domain-driven-design` rules 1–3, and the classification is stated before any package below is created. A supporting context keeps the script in `app/`, keeps only the row types and value objects that script needs in `domain/`, and has no aggregate package, no repository port and no events package. A generic subdomain is an adapter under `infra/adapters/outbound/`, not a directory under `internal/context/` at all.
19. One package per aggregate root, named for the root: `domain/order/`, `domain/shipment/`. Only the root, its identifier and its value objects are exported; child entities are unexported, or exported for reading with every mutator a method on the root — otherwise the package boundary is not the consistency boundary.
20. Inside an aggregate package, names drop the package prefix — `order.ID`, `order.Status`, `order.Line`, `order.Repository`, `order.ErrAlreadyPaid`. `order.Order` for the root is the one accepted stutter. When the context and its principal aggregate share a name, the surface keeps the bare name and the aggregate package is imported under an alias naming its layer: `orderdomain "…/context/order/domain/order"`.
21. One file per type for the root, its child entities and its value objects. The events, the port and the sentinels are grouped in `events.go`, `repository.go` and `errors.go`, and rebuilding an aggregate from stored state is an exported function in `reconstitute.go` that skips the creation rules — `domain-driven-design` rule 55.
22. One aggregate references another by its identifier value object only — `order.ID` held inside `shipment`, never `*order.Order`. A reference in both directions is an import cycle as well as a design smell: put it on the side that owns the relationship, or move the identifier under rule 27.
23. The repository port is declared in the aggregate's own package, in that aggregate's own types — `domain-driven-design` rule 65.
24. Domain events live in the aggregate package and stay inside the context, named so the qualified identifier reads as the past-tense fact — `order.Placed`, `order.Paid`. Rule 14's `app/events/` holds the integration events, and `domain-driven-design` rule 60 is the translation between them, written by hand in `app/`.
25. A domain package imports the standard library and other domain packages of the same context. Nothing else — no `database/sql`, no `net/http`, no `log/slog`, no third party. `time` and `crypto/rand` may be used for their types and never for `time.Now()` or identity generation: the instant and the id are arguments — `domain-driven-design` rule 44.
26. A rule spanning two aggregates imports both, so it sits in a package above them, named for the workflow and never for a layer — `domain/fulfillment/can_dispatch.go`. Only a decision that reads two aggregates and mutates neither belongs there: a rule one root owns stays on that root, and a rule that must hold across two roots at every instant means the boundary is wrong.
27. Value objects more than one aggregate shares are files in `domain/` itself, `package domain` — `domain.Money`, `domain.Quantity`. This is the deliberate exception to rule 26's ban on layer-named packages: the aggregate packages import it and it imports none of them, so it must sit below them, and the alternatives — a package per value object, or a `shared/` bucket — are a directory per file and an unnamed grab bag respectively.

### The application layer — when the change touches a use case

28. Four packages under `app/`: `command/`, `query/`, `port/` and rule 14's `events/`. No `inbound/` or `outbound/` level — the first two are inbound by construction and `port/` is outbound by construction, so the extra directory only lengthens the path.
29. One file per use case, named for it, holding both the request type and its handler: `app/command/place_order.go`. A handler receives its dependencies; it constructs none of them.
30. `app/port/` declares the outbound interfaces this context needs — a payment capability, a carrier, the outbox — in this context's vocabulary. No port names a vendor.
31. A use case is reached by a trigger, never written as one. An HTTP request, a queue message and a domain event are three triggers for the same `app/command/` handler, so none of them gets a package inside `app/` — rule 37 is where all three live.
32. The `command/` and `query/` split is where handlers live, not two models. A query handler loads the aggregate through its repository until read and write genuinely diverge; only then does it read a projection through a read port, and it never mutates — `domain-driven-design` rule 71.
33. The application layer opens the transaction and decides when it commits. The domain never sees one, and neither does a handler in `infra/adapters/inbound/`.
34. The use case writes its own integration events through an `app/port/Outbox` inside that same transaction. Nothing publishes after the commit returns — that is the dual write `domain-driven-design` rule 61 exists to prevent.

### The infrastructure layer — when the change touches an adapter

35. `infra/` holds `adapters/` and `config/`. `adapters/` splits into `inbound/` for driving adapters and `outbound/` for driven ones — the two fail differently, are tested differently and are wired differently, which is what earns them the split. `config/` sits beside `adapters/` rather than inside it because it implements no port.
36. `infra/adapters/inbound/http/` holds one file per resource plus `wire.go` for the request and response types. Not `dto.go` — "data transfer object" is two of `clean-code` rule 2's banned words in one filename.
37. `infra/adapters/inbound/event/` holds every trigger that is not a request — an external transport consumer (`kafka.go`) and an in-process domain-event subscription (`on_order_paid.go`) alike. Both translate something that happened into a call on `app/command/` and hold no business rule, which is the definition of an inbound adapter.
38. `infra/adapters/outbound/postgres/` holds the repository implementations, the outbox writer, the row types and the mapping in one package. A separate `mapper/` package exports functions that only its own neighbours ever call.
39. The persistence row type is separate from the aggregate and mapped at the boundary — `domain-driven-design` rule 66. No ORM tag, no `db:` tag and no embedded ORM type appears on a domain type.
40. `infra/adapters/outbound/gateway/` implements a port backed by another context in this binary; `infra/adapters/outbound/client/` implements one backed by a foreign system. The interface shape is the same and everything else about them is not.
41. An adapter package is named for the technology it speaks — `postgres/`, `stripe/`, `kafka/` — never for the layer it sits in.
42. `infra/config/` declares this context's configuration as one typed struct and validates it. Reading the environment is `cmd/`'s job under rule 4; owning the shape and the validity of what it reads is the context's. Every key it names is prefixed with the context — `ORDER_DB_URL`, never `DB_URL` — so one setting cannot be silently shared by two contexts that were never asked whether they agreed.

### Storage and migrations — when the change touches storage

43. Every context shares one Postgres instance and one database, and owns one schema inside it named for the context. The instance and the database are infrastructure; the schema and the role granted on it are the boundary — `modular-monolith` rule 40, and the reason `domain-driven-design`'s S4 is about a shared schema rather than a shared server.
44. `internal/context/<name>/migrations/` holds that context's own DDL and nothing else, embedded with `go:embed` from its surface package, so a context carries its own schema wherever it goes. Provisioning is not migration: `CREATE SCHEMA`, `CREATE ROLE`, `GRANT` and `CREATE EXTENSION` need privileges no context's role may hold, so they are applied once ahead of the binary and belong with the infrastructure, never in this directory.
45. Each context keeps its own migration history table inside its own schema. One shared history table across contexts is a single object every context writes, which is the coupling the schema split exists to remove.
46. No migration touches a schema its context does not own, and no foreign key crosses a schema — `modular-monolith` rules 41 and 42. This is what makes rule 44 safe on one shared database: with no cross-schema constraint, the contexts migrate in any order, and none of them blocks another's deploy.
47. `internal/platform/postgres/` provides the pool constructor, the transaction helper and the migration runner. It holds no DDL and knows no context's name. `cmd/` builds one pool per context under that context's own runtime role, granted only its own schema, so a cross-schema read fails at runtime as well as in CI, and the runner connects as that context's separate migration role — `postgres` rule 106, and rules 107–108 for how the grants are written.

### Cross-context integration — when the change crosses a boundary

48. A synchronous cross-context call goes through the caller's own `app/port/` interface, implemented in the caller's `infra/adapters/outbound/gateway/`, bound to the callee's facade in `cmd/` — `modular-monolith` rule 35's thin gateway per consumer.
49. An asynchronous one goes through an integration event the owner publishes via the transactional outbox of rule 34, consumed in the consumer's own `infra/adapters/inbound/event/`. Every consumer is idempotent because delivery is at-least-once, and its test decodes a checked-in payload fixture rather than a struct it shares with the publisher — the serialized form is the contract, so a field renamed on one side has to fail a build on the other.
50. The outbox table belongs to the publishing context's schema and is written by that context's own `postgres` adapter. `internal/platform/outbox/` holds only the generic relay that drains it.
51. An in-process bus dispatching domain events stays inside one context. A raw domain event crossing a boundary turns the publisher's internals into a contract nobody agreed to.

### Shared code and the platform package — when the change adds shared code

52. A package under `internal/platform/` must survive the extraction test: if one context became a separate deployable tomorrow, would both binaries still want their own copy? A clock, ids, logging, tracing, HTTP middleware and config parsing pass. Pricing, tax and address validation do not — `modular-monolith` rule 27.
53. No domain package is shared across contexts. `TenantID` and `Address` mean different things in two contexts, and one shared type is how a shared model starts.
54. An identifier issued by one context crosses as an opaque value and is held in the receiving context's own type — `domain-driven-design` rule 8 in its Go form.
55. `internal/platform/` imports no context. If a platform package needs a context's type, it is not platform code.

### Tests and enforcement — always applies

56. Unit tests sit beside the code they test as `_test.go`. A domain package's tests need no fixture, no container and no mock; if they do, the domain is not pure and rule 25 is being broken somewhere.
57. A context's surface carries a test in `package order_test` at the context root, exercising the facade exactly as a caller would and through nothing else.
58. Adapter tests run against the real technology rather than a mock of it, with fixtures in `testdata/`.
59. No context imports another context's fakes, fixtures or test helpers — `modular-monolith` rule 29.
60. `.golangci.yml` carries `depguard` rules encoding four things: no package may import anything beneath another context's root, the two seams of rule 13 are the allow-list of exceptions, imports inside a context run `infra` to `app` to `domain`, and `app/events/` may import the standard library only. CI additionally checks that every schema name appearing in a context's migrations and queries is that context's own — with one shared database, a cross-schema read otherwise compiles, passes lint and ships. A boundary the build does not check is a paragraph, not a boundary.
61. Rule 60 is the boundary, not a reminder of it. Go's `internal/` is positional, so the one at the repository root stops code outside the module and nothing between contexts; there is no compile error to fall back on, which makes a missing `depguard` rule a missing boundary. An architecture test asserting the import graph is the second line of defence behind it, and the review checks rule 60's config the way it checks any other source file.

### Growth — when the change adds a package or a directory

62. A context starts flat: the surface at `internal/context/order/`, and `internal/context/order/{domain,app,infra}/` with no sub-packages at all.
63. `domain/` splits into per-aggregate packages when the context holds its second aggregate, not before.
64. `app/` splits into `command/`, `query/` and `port/` when it holds more use cases than one file can hold clearly. `events/` is not part of that split — it arrives with the context's first integration event, whatever `app/` looks like at the time, because rule 14's cycle is there from the first one.
65. `infra/adapters/outbound/` splits by technology when it speaks to a second one.
66. An empty directory is not a boundary — `golang` rule 24. Create the package when the file that belongs in it exists.
<!-- HARD-RULES:END -->

## The reference layout

This is the adopted structure. `order` is shown in full; every other context has the same shape — a
surface package at its root, and `domain/`, `app/`, `infra/` and `migrations/` beside it.

```text
my-monolith/
├── cmd/
│   └── api/
│       └── main.go                 composition root: config, pools, wiring, routes (rule 4)
│
├── internal/
│   ├── context/                    everything the business owns (rule 5)
│   │   ├── order/                  BOUNDED CONTEXT — core subdomain (18)
│   │   │   ├── order.go            SURFACE — package order. The facade, and the only import (8, 10)
│   │   │   ├── new.go              package order — builds this context's adapters for cmd/ (17)
│   │   │   ├── events.go           integration events, re-exported as aliases (14)
│   │   │   ├── errors.go           the errors a caller may match on
│   │   │   ├── order_test.go       package order_test — the facade, exercised as a caller (57)
│   │   │   ├── migrations/         this context's schema, embedded from order.go (44)
│   │   │   │   └── 0001_order.sql
│   │   │   ├── domain/             package domain — the value objects the aggregates share (27)
│   │   │   │   ├── money.go        Money, Currency
│   │   │   │   ├── quantity.go     Quantity
│   │   │   │   ├── order/          AGGREGATE — package order, imports domain (19)
│   │   │   │   │   ├── order.go    root: Order
│   │   │   │   │   ├── line.go     child entity: line — unexported (19)
│   │   │   │   │   ├── id.go       value object: ID — not OrderID (20)
│   │   │   │   │   ├── status.go   value object: Status
│   │   │   │   │   ├── events.go   domain events: Placed, Paid — internal to this context (24)
│   │   │   │   │   ├── repository.go    port: Repository, in this aggregate's own types (23)
│   │   │   │   │   ├── reconstitute.go  rebuild from stored state, no creation rules (21)
│   │   │   │   │   └── errors.go   sentinels: ErrAlreadyPaid
│   │   │   │   ├── shipment/       AGGREGATE — same file set; holds order.ID, never *Order (22)
│   │   │   │   │   └── …
│   │   │   │   └── fulfillment/    reads both aggregates, mutates neither (26)
│   │   │   │       ├── can_dispatch.go
│   │   │   │       └── split_shipment.go
│   │   │   ├── app/
│   │   │   │   ├── events/         package events — one file per integration event (14)
│   │   │   │   │   ├── placed.go
│   │   │   │   │   └── paid.go
│   │   │   │   ├── command/        one file per write use case (29)
│   │   │   │   │   ├── place_order.go
│   │   │   │   │   └── dispatch_shipment.go
│   │   │   │   ├── query/          one file per read use case (32)
│   │   │   │   │   ├── get_order.go
│   │   │   │   │   └── track_shipment.go
│   │   │   │   └── port/           outbound interfaces, in this context's vocabulary (30)
│   │   │   │       ├── payment.go
│   │   │   │       ├── carrier.go
│   │   │   │       └── outbox.go   written inside the use case's transaction (34)
│   │   │   └── infra/              adapters, and this context's config beside them (35)
│   │   │       ├── adapters/
│   │   │       │   ├── inbound/
│   │   │       │   │   ├── http/
│   │   │       │   │   │   ├── order.go     handlers
│   │   │       │   │   │   ├── shipment.go
│   │   │       │   │   │   └── wire.go      request and response types — not dto.go (36)
│   │   │       │   │   └── event/           every trigger that is not a request (37)
│   │   │       │   │       ├── kafka.go             external transport consumer
│   │   │       │   │       └── on_order_paid.go     in-process subscription
│   │   │       │   └── outbound/
│   │   │       │       ├── postgres/   repositories, outbox, rows and mapping (38)
│   │   │       │       │   ├── order_repo.go
│   │   │       │       │   ├── shipment_repo.go
│   │   │       │       │   ├── outbox.go   writes order.outbox in the caller's tx (50)
│   │   │       │       │   ├── row.go      persistence types — not models.go (39)
│   │   │       │       │   └── mapper.go   row to aggregate and back, unexported
│   │   │       │       ├── gateway/    a port backed by another context's facade (40)
│   │   │       │       │   └── payment.go
│   │   │       │       └── client/     a port backed by a foreign system (40)
│   │   │       │           └── carrier.go
│   │   │       └── config/         this context's typed config, validated (42)
│   │   │           └── config.go
│   │   │
│   │   ├── payment/                same shape
│   │   │   ├── payment.go
│   │   │   ├── events.go
│   │   │   ├── migrations/
│   │   │   ├── domain/
│   │   │   ├── app/
│   │   │   └── infra/
│   │   │
│   │   └── inventory/
│   │       └── …
│   │
│   └── platform/                   generic technical infrastructure only (7, 52)
│       ├── postgres/               pool, transaction helper, migration runner (47)
│       ├── outbox/                 the generic relay; each table lives in its owner's schema (50)
│       ├── eventbus/               in-process dispatch, within one context (51)
│       ├── id/
│       └── clock/
│
├── .golangci.yml                   depguard: the whole boundary lives here (60, 61)
├── go.mod
└── go.sum
```

## Depth

### Rules 9, 60-61 — the boundary `depguard` keeps

Go's `internal/` rule is positional: a package under `a/b/internal/…` is importable only by packages
rooted at `a/b/`. The one at the repository root therefore stops code *outside* the module and
nothing else — between two contexts inside it, every import compiles.

```go
// Bad — and it compiles. Nothing in Go objects to this.
package gateway // internal/context/order/infra/adapters/outbound/gateway

import "my-monolith/internal/context/payment/domain/payment" // payment's aggregate, order's code

func (g *Gateway) Charge(ctx context.Context, id string, cents int64) error {
    p := payment.New(id, cents) // order now depends on payment's constructor, fields and invariants
    ...                         // payment cannot rename a field, and cannot be extracted
}
```

So the boundary is a lint rule, and the config is where it actually lives. Rule 60 is a deny on every
context's subtree with rule 13's two seams as the only exceptions:

```yaml
# .golangci.yml — the whole context boundary, and the only thing enforcing it
linters-settings:
  depguard:
    rules:
      order-internals:                                  # who may see order's insides
        files: ["!**/internal/context/order/**"]
        deny:
          - pkg: my-monolith/internal/context/order/domain
            desc: import the order surface, not its model — go-project-layout rule 9
          - pkg: my-monolith/internal/context/order/app
            desc: import the order surface — rule 9
          - pkg: my-monolith/internal/context/order/infra
            desc: order assembles itself in new.go — rule 17
      order-names-payment:                              # rule 13's two seams, and nothing else
        files:
          - "!**/internal/context/order/infra/adapters/outbound/gateway/**"
          - "!**/internal/context/order/infra/adapters/inbound/event/**"
        deny:
          - pkg: my-monolith/internal/context/payment
            desc: only the gateway calls payment, only inbound/event consumes it — rule 13
```

One block per context, generated or hand-written, reviewed like any other source file. That is the
cost of a flat tree: the rule is a paragraph of YAML someone has to keep true, rather than something
the compiler refuses to build. Rule 61 is why it is worth paying attention to — delete the block and
nothing fails until the day someone tries to extract `order` and finds `payment` inside it.

### Rules 14, 34, 48-50 — one context calling another, and who writes the outbox

The caller names a capability, not a context. Nothing in `order` mentions `payment`.

```go
// internal/context/order/app/port/payment.go — order's vocabulary, order's types
package port

type Payments interface {
    Authorize(ctx context.Context, of order.ID, amount domain.Money) (AuthorizationID, error)
}

// internal/context/order/infra/adapters/outbound/gateway/payment.go
// The one package in `order` allowed to name `payment` — rule 13, and the edge depguard lists.
package gateway

func (g *PaymentGateway) Authorize(ctx context.Context, of order.ID, amount domain.Money) (port.AuthorizationID, error) {
    res, err := g.payments.Authorize(ctx, payment.AuthorizeCommand{Reference: of.String(), Cents: amount.Cents()})
    ...
}

// cmd/api/main.go — one line per context, naming no package beneath either root (rules 4, 17)
orders, orderRoutes := order.New(orderPool, orderCfg, order.Deps{Payments: payments})
```

When the call does not need an answer now it is an event instead, and rule 14 is what makes that
compile. The integration event cannot be declared on the surface: the surface imports `app/`, so
`app/` importing the surface to construct one is a cycle — and `app/` is exactly where the open
transaction lives. It gets no directory of its own either; there are three layers. So it is declared
in `app/events/`, which `app/command/` and the surface can both import without either importing the
other, and the surface re-exports it:

```go
// internal/context/order/app/events/paid.go — package events, standard library only (14)
package events

type Paid struct { OrderID string; Cents int64; PaidAt time.Time }

// internal/context/order/events.go — the consumer writes order.Paid, with no stutter (rule 14)
package order

type Paid = events.Paid

// internal/context/order/app/command/pay_order.go — one transaction, both writes
func (h *PayOrder) Handle(ctx context.Context, cmd PayOrderCommand) error {
    return h.tx.Do(ctx, func(ctx context.Context) error {
        o, err := h.orders.Load(ctx, cmd.ID)
        ...
        if err := h.orders.Save(ctx, o); err != nil { return err }
        return h.outbox.Put(ctx, events.Paid{...}) // rule 34 — same tx, no dual write
    })
}
```

`payment` then receives it in `infra/adapters/inbound/event/on_order_paid.go`, which does nothing but
call an `app/command/` handler. Rule 31 is why that file is an adapter and not a layer: `PlaceOrder`
does not care whether an HTTP request, a Kafka message or `order.Paid` set it off, so a `subscriber/`
package inside `app/` would hold only the wire between a trigger and a handler that already exists.

That file is also the second of rule 13's two seams, exactly symmetric with the gateway: it is the
only package in `payment` allowed to name `order`, and the edge is listed in `depguard` like any
other. The delivery is serialized either way — the outbox relay drains rows and hands over bytes —
so rule 49 is what keeps the contract honest: `payment`'s adapter test unmarshals a payload fixture
checked into its own `testdata/`, never a struct the two contexts share, which is also why rule 59
holds when `order` becomes a separate binary and the import turns into a schema.

A reaction that carries **state** is not a subscriber at all. A saga has identity, persisted state
and a lifecycle, so it is an aggregate in its own right under rule 19 — its own package, with an ID,
a state machine, `repository.go` and events — and the app-layer handler loads it, calls one method
and saves it. A process manager holds no state and is pure routing, so it is an `app/command/`
handler. Neither belongs in rule 26's package, which is stateless by definition.

### Rules 43-47 — one Postgres instance, a schema per context

Sharing an instance is not sharing storage. The instance is infrastructure; the schema is the
boundary, and it is the schema that has to be exclusive.

```sql
-- Bad — one schema, one migration history, one lock everybody waits on.
CREATE TABLE public.orders (...);
CREATE TABLE public.invoices (...);
ALTER TABLE public.invoices ADD FOREIGN KEY (order_id) REFERENCES public.orders (id);
-- billing can no longer deploy without ordering, and neither can be extracted.

-- Provisioned once, ahead of the binary, by a role no context ever connects as — rule 44.
CREATE SCHEMA "order" AUTHORIZATION order_migrator;
GRANT USAGE ON SCHEMA "order" TO order_app;     -- rule 47: and only this role reaches it

-- Good — internal/context/order/migrations/0001_order.sql touches nothing but its own schema.
CREATE TABLE "order".orders (...);
CREATE TABLE "order".outbox (...);              -- rule 50: the publisher owns its outbox
CREATE TABLE "order".schema_migrations (...);   -- rule 45: its own history
```

The split above is a privilege boundary, not tidiness: `order_app` holds `USAGE` and nothing that
creates, so it *cannot* execute the two statements above it. Leaving them in the migration forces the
runner to connect as an owner or a superuser, and a runtime pool that inherits that connection erases
the runtime half of rule 46 — the grants stop enforcing anything. Two roles per context, applied by
`postgres` rule 106, is what keeps both halves real.

The payoff is rule 46. Because no foreign key crosses a schema, `order`'s migrations and `billing`'s
have no ordering relationship — the runner in `internal/platform/postgres/` applies each context's
embedded set against its own history table, in any order, and a context that is behind blocks nobody.
That is the whole reason migrations are per context rather than in one root directory, and it survives
the shared instance intact. What the shared instance does cost is shared *capacity* — one server, one
set of locks, one `work_mem` budget — which is a `postgres` concern rather than a layout one. It does
not cost a shared connection: rule 47 gives each context its own pool under its own role, which is
what keeps the grants enforcing rule 46 at runtime.

### Rules 52-54 — what survives the extraction test

The test is not "is this used twice". It is "after `order` and `payment` become separate binaries,
would each still want its own copy?"

| Candidate | Extract `order` tomorrow | Verdict |
| --- | --- | --- |
| `clock`, `id`, `slog` setup, tracing, HTTP middleware | both binaries want one | `internal/platform/` |
| Outbox relay, transaction helper, pool wiring | both binaries want one | `internal/platform/` |
| `Money` with rounding and currency rules | both want one — but they will disagree within a year | one per context, as `domain/money.go` (rule 27) |
| Pricing, tax, discount eligibility | exactly one owns it | that context's `domain/` |
| `TenantID`, `Address`, `Customer` | each context means something different | one per context |

The fourth row is `modular-monolith` rule 28. The fifth is the one that gets rationalised: a shared
`Customer` looks like removing duplication and is actually a shared model, which is the coupling both
standards exist to prevent.

### Rules 62-66 — where a context starts

A **core** context with one aggregate and two use cases is a handful of files, not forty — the full
tree above is what it grows into, not what it is scaffolded as. A supporting context never gets there
at all: rule 18 stops it at a script in `app/` over row types in `domain/`, with no aggregate package,
no repository port and no events.

```text
internal/context/notification/   core subdomain, not yet grown (18, 62)
├── notification.go              surface: the facade, its commands, its results
├── new.go                       builds this context's adapters for cmd/ (17)
├── events.go                    integration events, aliased from app/events/ (14)
├── migrations/0001_notification.sql
├── domain/                      package domain — one aggregate, no sub-package yet (63)
│   ├── notification.go
│   └── errors.go
├── app/                         package app — two use cases, no sub-package yet (64)
│   ├── events/paid.go           one file per integration event (14)
│   ├── send.go
│   └── port.go
└── infra/
    ├── adapters/inbound/http.go
    ├── adapters/outbound/postgres.go
    └── config/config.go
```

Every boundary that matters is already there: the surface, the three layers, the migrations, the
schema — and the `depguard` block naming this context, which is written when the directory is, not
when someone first violates it. What is absent is the sub-package nesting, and rule 66 is why: the
directories arrive with the second aggregate and the sixth use case, at which point the split is a
rename rather than a prediction.

## Anti-pattern scan list

A review scan list, not rules. Work down it when auditing a Go tree.

| Code | Anti-pattern |
| --- | --- |
| R1 | A `pkg/`, `api/` or `src/` directory at the repository root |
| R2 | A business rule, a handler body or a repository construction inside `cmd/` |
| R3 | Contexts loose under `internal/` beside `platform/`, or the container named `module/`, `modules/` or `contexts/` rather than `context/` |
| R4 | A context directory named for a layer or a technology rather than a capability |
| R5 | A root directory no context owns and `internal/platform/` does not cover |
| B1 | A context with no surface package, so callers import whatever they need |
| B2 | A context's `domain/`, `app/` or `infra/` imported from outside that context |
| B3 | A domain aggregate, a persistence row, an ORM type or an `http` type in a surface signature |
| B4 | One context naming another outside its own `outbound/gateway/` or `inbound/event/` |
| B5 | A surface exposing a getter per field rather than a use case |
| B6 | A caller depending on the callee's facade type directly instead of on its own port |
| B7 | An integration event declared on the surface, so the use case cannot construct one without a cycle |
| L1 | A layer directory inside a context other than `domain/`, `app/` and `infra/` |
| L2 | `domain/` importing `app/` or `infra/` |
| L3 | The surface package reaching past `app/` into `domain/` or `infra/` |
| L4 | The import direction drawn in a comment or a README and checked nowhere |
| D1 | An aggregate package created with no subdomain classification stated |
| D2 | A full aggregate model, repository port and domain events in a supporting context |
| D3 | A domain package importing `database/sql`, `net/http`, `log/slog` or a third party |
| D4 | A domain package calling `time.Now()`, `rand` or `uuid.New()` instead of taking them as arguments |
| D5 | An aggregate package named for a layer — `domain/service/`, `domain/model/`, `domain/entity/` |
| D6 | A child entity exported with a mutating method, so callers bypass the root |
| D7 | One aggregate holding a pointer to another instead of its identifier value object |
| D8 | Two aggregates referencing each other by identity, which is also an import cycle |
| D9 | A repository port declared outside the aggregate package it serves |
| D10 | Names stuttering inside their own package — `order.OrderID`, `order.OrderStatus` |
| D11 | No reconstitution path, so the mapper runs creation rules or the aggregate exports its fields |
| D12 | A package per shared value object — `domain/money/money.go` — rather than files in `domain/` itself, or a `shared/`, `common/` or `valueobject/` package standing in for it |
| D13 | A single-root invariant moved into the cross-aggregate package, or a rule there that mutates |
| D14 | A domain event leaving the context with no translation to an integration event |
| A1 | An `inbound/` or `outbound/` level under `app/` |
| A2 | A business rule in a command handler that belongs in the aggregate |
| A3 | An outbound port naming a vendor — `StripeClient`, `TwilioSender` |
| A4 | A query handler that mutates, or a command handler that exists to read |
| A5 | A projection and a read port adopted by layout rather than because the models diverged |
| A6 | A transaction opened in the domain or in an adapter rather than in `app/` |
| A7 | An integration event published after the commit returns instead of into the outbox inside it |
| A8 | A use case handler constructing its own dependencies instead of receiving them from `cmd/` |
| I1 | `dto.go`, `models.go` or any filename built from `clean-code` rule 2's banned words |
| I2 | A `mapper/` package whose only callers are its own neighbours |
| I3 | Inter-module gateways and foreign-system clients in one package |
| I4 | An adapter package named `persistence/` or `adapter/` rather than the technology it speaks |
| I5 | A persistence row used as the aggregate, or a domain type carrying ORM or `db:` tags |
| I6 | A domain-event subscription given its own package under `app/` instead of sitting with the other triggers in `infra/adapters/inbound/event/` |
| I7 | An HTTP handler carrying a business rule or building a query |
| I8 | Configuration parsed inside a use case, or a context reading the environment directly |
| S1 | A context with no schema of its own, or two contexts sharing one |
| S2 | Migrations in one root directory rather than one per context |
| S3 | One migration history table shared across contexts |
| S4 | A migration touching a schema its context does not own |
| S5 | A foreign key crossing a context's schema boundary |
| S6 | One database role reaching every schema, or one role used for both migrating and running |
| S7 | `CREATE SCHEMA`, `CREATE ROLE`, `GRANT` or `CREATE EXTENSION` inside a context's migrations |
| X1 | A synchronous cross-context call made without a port the caller declares |
| X2 | An outbox table in `internal/platform/` rather than in the publisher's schema |
| X3 | A raw domain event crossing a context boundary |
| X4 | An integration event consumed with no test against a checked-in payload fixture |
| P1 | An `internal/shared/` directory |
| P2 | A business rule in `internal/platform/` |
| P3 | A domain type shared across contexts — `TenantID`, `Address`, `Customer` |
| P4 | `internal/platform/` importing a context |
| T1 | A domain test needing a fixture, a container or a mock |
| T2 | A context surface with no test written as a caller |
| T3 | One context importing another's fakes, fixtures or test helpers |
| T4 | A boundary described in prose with no `depguard` rule behind it |
| G1 | A directory created before the file that belongs in it exists |
| G2 | A context with one aggregate already split into per-aggregate packages |
| G3 | Three `app/` sub-packages holding one file each |
| G4 | This layout copied wholesale into a single-purpose service, a library or a CLI |
