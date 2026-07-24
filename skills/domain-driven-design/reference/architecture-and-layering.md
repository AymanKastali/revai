# Architecture & layering (hexagonal, modular monolith)

## Contents
Modules as bounded contexts · the inward dependency rule · the three layers (domain/app/infra) ·
CQRS as an optional escalation, not a default · examples (module layout, dependency inversion,
cross-module boundary).

The house architecture. One deployable, partitioned into **modules — one per bounded context**.
Each module is internally **hexagonal**: three layers (`domain` / `app` / `infra`) with
dependencies pointing **inward**. The application layer holds **one set of use-case handlers per
module** by default — the same path serves commands and queries alike. CQRS (splitting into a
command side and a query side), physical CQRS, and event sourcing are each available where their
own trigger condition holds (see `## CQRS — when queries outgrow the aggregate` below and
`reference/event-sourcing.md`) — none of them is the default starting shape.

This reference owns *the layout and the dependency direction*. It sits alongside the others in this
skill: `reference/strategic-design.md` draws where a module's boundary is;
`reference/tactical-patterns.md` fills each `domain/`; `reference/event-sourcing.md` and
`reference/process-managers-and-integration.md` extend the write side and the app layer respectively
where their trigger applies; `clean-code`'s "layers don't leak" is made concrete here as an import
rule; `best-practices` covers what goes in the infra adapters (data access patterns).

## Modules — the modular monolith

- **A module realises one bounded context.** It owns its three layers and **its own data** (its
  tables/schema). No other module reads those tables.
- **Modules are isolated.** A module **never imports another module's `domain` or `infra`**. Reaching
  into another module's internals couples them and destroys the boundary.
- **Cross-module contact goes through a narrow seam:** the other module's **published interface**
  (an app-layer port/facade) for synchronous calls, or a **domain event** for reactions. Translate
  the other module's concepts at that seam (anti-corruption layer — see `reference/strategic-design.md`).
- **One deployable, real seams.** Because modules only touch through published interfaces/events, any
  module can later be extracted into its own service without a rewrite. Keep it a monolith until a
  module genuinely needs to be a service — don't pay distributed-systems cost early.

## The dependency rule (inward, always)

- `domain` imports **nothing** (no framework, no DB, no HTTP).
- `app` imports **`domain`** only.
- `infra` imports **`app` and `domain`**.
- **Nothing inner ever imports `infra`.** Inner layers declare **ports** (interfaces); `infra`
  provides **adapters** (implementations). Concrete adapters are wired to ports by dependency
  injection at the **composition root** (`main`) — the only place that knows the concrete types.

## The three layers

- **`domain/`** — aggregates, value objects, domain services, domain events, and the
  **repository ports** (interfaces) they need. Pure and framework-free — no DB, clock, or HTTP
  inside it (this is the layer rule that keeps the domain a functional core).
- **`app/`** — one set of use-case handlers per module, by default. A handler loads the aggregate
  through its repository port, invokes the domain to enforce invariants, persists, and emits
  events; the **same handler shape serves a simple query too** — load the aggregate through the
  same repository, read what's needed off it. There is no command/query split here unless CQRS's
  own trigger holds (see below) — most modules never need one.
- **`infra/`** — adapters. **Driven:** repository implementations (see `best-practices`), external
  clients, event publishers. **Driving:** HTTP/CLI/gRPC controllers that dispatch to the use-case
  handlers. Plus the composition root that wires it all.

## CQRS — when queries outgrow the aggregate

CQRS is an escalation, not a starting shape. Reaching for it without the trigger below is the same
mistake as skipping a mandatory building block — ceremony that outruns the problem.

- **The trigger:** a query's read shape has genuinely diverged from the write model — a screen or
  report needs data joined/shaped in a way no single aggregate maps to cleanly, or loading a whole
  aggregate just to read a handful of fields is a measured, real cost. Neither "we're doing DDD" nor
  "it might scale someday" is the trigger.
- **Logical CQRS, once the trigger holds:** split the module's use cases into a **command side**
  (loads the aggregate through its repository, invokes the domain, persists, emits events) and a
  **query side** (uses a **read port** to return **read DTOs directly, bypassing the domain and the
  aggregate** entirely — never hydrate an aggregate just to read it). One datastore; the split is in
  code paths and models, not infrastructure. Read ports and read DTOs live in `app/` — a read shape
  is an application concern, not a domain concept. Queries may use optimised/raw SQL returning DTOs;
  commands still go through the aggregate so invariants always hold.
- **Physical CQRS, a further escalation — driven by event sourcing, not by a general performance
  itch.** If an aggregate is event-sourced (see `reference/event-sourcing.md` for that trigger), its
  read models are typically real projections maintained by a separate process consuming the event
  stream — a second, purpose-built store, not just a second code path over the same tables. Reach
  for this because the write side is already event-sourced, not as a standalone scaling move.

## Composition root: wiring a saga

A process manager/saga (see `reference/process-managers-and-integration.md`) is wired at the
composition root exactly like any use-case handler: its dependencies (repositories, the outbox, a
command dispatcher) are injected there, and it's registered as the handler for the events that drive
it forward. It lives in `app/` alongside the module's other use-case handlers, not in `infra/` — the
coordination logic is application logic, even though its triggers arrive as events from `infra/`.

## Checklist

- [ ] Top level is partitioned by module (bounded context), not by technical layer
- [ ] Each module has its own `domain`/`app`/`infra` and owns its own tables
- [ ] No module imports another module's `domain` or `infra`; cross-module via published port or event
- [ ] Dependencies point inward; nothing inner imports `infra`
- [ ] Ports declared in `domain`/`app`; adapters in `infra`; wired only at the composition root
- [ ] `app` holds one set of use-case handlers by default; a command/query split exists only where
      the read shape has actually diverged from the write model, stated explicitly why
- [ ] One datastore by default; a second store/event sourcing is present only where its own trigger
      condition (see `reference/event-sourcing.md`) actually holds
- [ ] Any saga/process manager is wired at the composition root and lives in `app/`, not `infra/`

## Examples

### Module layout — the default, no CQRS

**Go** — partition by module; hexagon recurses inside each; one set of handlers per module:

```
internal/
  order/                         # module = bounded context
    domain/
      order.go                   # Order aggregate, invariants
      money.go                   # value objects
      events.go                  # OrderPlaced, …
      repository.go              # OrderRepository port (load + save the aggregate)
    app/
      place_order.go             # PlaceOrderHandler: load → invoke domain → save → emit
      list_orders.go             # ListOrdersHandler: same repository, reads off the aggregate
    infra/
      persistence/order_repo_pg.go  # implements domain.OrderRepository
      http/order_handler.go         # driving adapter → handlers
      events/publisher.go
  billing/                       # another module, same internal shape
    domain/ app/ infra/
  cmd/server/main.go             # composition root: build adapters, inject into handlers
```

**Python** — same partitioning:

```
src/
  orders/                        # module = bounded context
    domain/
      order.py                   # Order aggregate, value objects, events
      repository.py              # OrderRepository Protocol (load + save the aggregate)
    app/
      place_order.py             # PlaceOrderHandler
      list_orders.py             # ListOrdersHandler: same repository, reads off the aggregate
    infra/
      persistence/order_repo_pg.py  # implements OrderRepository
      http/routes.py                # driving adapter → handlers
      events/publisher.py
  billing/                       # another module, same internal shape
    domain/ app/ infra/
  main.py                        # composition root (wiring / DI)
```

### Module layout — once CQRS's trigger holds

A reporting screen needs orders shaped and joined in a way the `Order` aggregate never will, and
loading the whole aggregate to serve it is a measured, real cost — the trigger is met, so `orders`
(only this module, not every module) splits into command and query sides:

```
internal/
  order/
    domain/
      order.go repository.go     # OrderRepository — now specifically the WRITE port
    app/
      command/place_order.go     # PlaceOrderHandler: load → invoke domain → save → emit
      query/list_orders.go       # ListOrdersHandler: OrderReadPort → []OrderView
      query/ports.go             # OrderReadPort + OrderView DTO (read model, bypasses the domain)
    infra/
      persistence/order_repo_pg.go  # implements domain.OrderRepository (write)
      persistence/order_read_pg.go  # implements app/query.OrderReadPort (raw SQL → OrderView)
      http/order_handler.go         # driving adapter → command/query handlers
  billing/                       # unaffected — still the default, no split
    domain/ app/ infra/
```

### The dependency rule, inverted

**Good** — the port is declared inward; the adapter depends on it, never the reverse:

```go
// domain/order/repository.go — the domain owns the contract it needs.
type OrderRepository interface {
    Load(ctx context.Context, id OrderID) (*Order, error)
    Save(ctx context.Context, o *Order) error
}

// infra/persistence/order_repo_pg.go — the adapter implements the domain's port.
type PgOrderRepository struct{ db *sql.DB }
func (r *PgOrderRepository) Load(ctx context.Context, id OrderID) (*Order, error) { /* SQL */ }

// cmd/server/main.go — composition root: the only place that names the concrete type.
repo := &persistence.PgOrderRepository{db: db}
placeOrder := command.NewPlaceOrderHandler(repo) // inject port impl into the use case
```

### Cross-module boundary

**Bad** — `orders` reaches into `billing`'s internals; the two are now welded together:

```python
from billing.domain.account import Account          # importing another module's DOMAIN
from billing.infra.persistence import charge_card    # …and its INFRA

def place_order(cmd):
    charge_card(Account(cmd.customer_id), cmd.total)  # boundary destroyed
```

**Good** — `orders` depends only on `billing`'s published interface; `billing` owns its own model:

```python
# orders/app/ports.py — what orders needs FROM billing, in orders' own terms.
class PaymentGateway(Protocol):
    def charge(self, customer_id: CustomerId, amount: Money) -> PaymentRef: ...

# orders/app/place_order.py — depends on the seam, not on billing's internals.
class PlaceOrderHandler:
    def __init__(self, orders: OrderRepository, payments: PaymentGateway) -> None:
        self._orders, self._payments = orders, payments

# infra (composition root) wires billing's published adapter into orders' PaymentGateway port.
```

```go
// orders/app/ports.go — orders declares the seam it needs, in its own language.
type PaymentGateway interface {
    Charge(ctx context.Context, customerID CustomerID, amount Money) (PaymentRef, error)
}
// An adapter over billing's PUBLISHED interface implements this; orders never imports billing/domain.
```
