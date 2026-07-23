# Architecture & layering (hexagonal, modular monolith, logical CQRS)

## Contents
Modules as bounded contexts · the inward dependency rule · the three layers (domain/app/infra) ·
logical CQRS · examples (module layout, dependency inversion, cross-module boundary).

The house architecture. One deployable, partitioned into **modules — one per bounded context**.
Each module is internally **hexagonal**: three layers (`domain` / `app` / `infra`) with
dependencies pointing **inward**. The application layer is split **logically** into a command side
and a query side (CQRS), sharing one datastore — no event sourcing, no separate read store.

This reference owns *the layout and the dependency direction*. It sits alongside the others in this
skill: `reference/strategic-design.md` draws where a module's boundary is;
`reference/tactical-patterns.md` fills each `domain/`; `clean-code`'s "layers don't leak" is made
concrete here as an import rule; `best-practices` covers what goes in the infra adapters (data
access patterns).

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

- **`domain/`** — the write model: aggregates, value objects, domain services, domain events, and
  the **write-repository ports** (interfaces) it needs. Pure and framework-free — no DB, clock, or
  HTTP inside it (this is the layer rule that keeps the domain a functional core).
- **`app/`** — use cases, split by CQRS:
  - **command side** — a command handler loads an aggregate through a write-repository port, invokes
    the domain to enforce invariants, persists, and emits events.
  - **query side** — a query handler uses **read/query ports** to return **read DTOs directly,
    bypassing the domain** (never hydrate an aggregate just to read it). Read ports and read DTOs
    live here — a read shape is an application concern, not a domain concept.
- **`infra/`** — adapters. **Driven:** write-repository and read-model implementations (see
  `best-practices`), external clients, event publishers. **Driving:** HTTP/CLI/gRPC controllers
  that dispatch to command or query handlers. Plus the composition root that wires it all.

## Logical CQRS

- **Commands mutate through aggregates; queries read through read models and skip the domain.**
- **One datastore.** The split is in code paths and models, not infrastructure — read/write
  separation without the operational cost. No event sourcing, no separate read database.
- Queries may use optimised/raw SQL returning DTOs; commands go through the aggregate so invariants
  always hold.

## Checklist

- [ ] Top level is partitioned by module (bounded context), not by technical layer
- [ ] Each module has its own `domain`/`app`/`infra` and owns its own tables
- [ ] No module imports another module's `domain` or `infra`; cross-module via published port or event
- [ ] Dependencies point inward; nothing inner imports `infra`
- [ ] Ports declared in `domain`/`app`; adapters in `infra`; wired only at the composition root
- [ ] `app` is split into command and query sides; queries return DTOs and bypass the domain
- [ ] One datastore; no event sourcing / no separate read store

## Examples

### Module layout

**Go** — partition by module; hexagon recurses inside each:

```
internal/
  order/                         # module = bounded context
    domain/
      order.go                   # Order aggregate, invariants (write model)
      money.go                   # value objects
      events.go                  # OrderPlaced, …
      repository.go              # OrderRepository — WRITE port (interface)
    app/
      command/place_order.go     # PlaceOrderHandler: load → invoke domain → save → emit
      query/list_orders.go       # ListOrdersHandler: OrderReadPort → []OrderView
      query/ports.go             # OrderReadPort + OrderView DTO (read model)
    infra/
      persistence/order_repo_pg.go  # implements domain.OrderRepository (write)
      persistence/order_read_pg.go  # implements app/query.OrderReadPort (raw SQL → OrderView)
      http/order_handler.go         # driving adapter → command/query handlers
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
      repository.py              # OrderRepository Protocol — WRITE port
    app/
      command/place_order.py     # PlaceOrderHandler
      query/list_orders.py       # ListOrdersHandler
      query/ports.py             # OrderReadPort Protocol + OrderView dataclass (read DTO)
    infra/
      persistence/order_repo_pg.py  # implements OrderRepository
      persistence/order_read_pg.py  # implements OrderReadPort
      http/routes.py                # driving adapter → handlers
      events/publisher.py
  billing/                       # another module, same internal shape
    domain/ app/ infra/
  main.py                        # composition root (wiring / DI)
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

# orders/app/command/place_order.py — depends on the seam, not on billing's internals.
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
