---
name: domain-modeling
description: Use when modelling a domain — defining a type, adding an invariant/business rule, or deciding where a rule lives. Applies modern, pragmatic tactical DDD: model the domain in types, make illegal states unrepresentable, value objects validated at construction, rich (not anemic) models, aggregates as consistency boundaries (one aggregate per transaction, eventual consistency between them via domain events), domain vs integration events, and a pure functional core with IO at the edges (Go/Python). Complements bounded-contexts (strategic) — reach for that when drawing boundaries rather than modelling within one.
---

# Domain modeling (tactical DDD)

Model the domain in the type system so the compiler/runtime enforces the rules, not scattered `if`
checks. "Modern" here means **pragmatic, not dogmatic**: apply the pattern that earns its place,
prefer type-driven modelling over ceremony, and keep the domain a **pure core** with IO at the edges.
Not every noun is an aggregate; not every value needs a wrapper. Model what has rules; leave the rest.

Strategy comes first — if you haven't named the concept and its boundary, do that with
`bounded-contexts` before reaching for these patterns.

## Rules

- **Make illegal states unrepresentable.** If a value can't be negative, don't use a bare `int` and
  guard everywhere — give it a type that *cannot* hold a bad value. Push validation to the boundary
  where the value is born, then trust it everywhere inside.
- **Value objects: immutable, self-validating, equal by value.** `Email`, `Money`, `Quantity` —
  validated once at construction, no identity, never mutated (return a new one). A construction that
  can fail returns an error, not a half-built object.
- **Entities have identity and a lifecycle.** Equality is by ID, not by fields. Two customers with
  the same name are different customers.
- **Rich, not anemic.** Behaviour and the invariant it protects live *together*. A struct of public
  fields mutated by a service is an anemic model — the rule ends up copy-pasted across call sites.
  The type should make the illegal transition impossible, not merely discouraged.
- **Aggregates are consistency boundaries.** An aggregate is the unit that must stay valid as a
  whole and is saved in **one transaction**. Keep them small. Reference *other* aggregates by ID,
  never by embedding — that keeps the transaction and the object graph bounded (see
  `data-access-patterns`).
- **Modify one aggregate per transaction.** A single transaction creates or changes exactly *one*
  aggregate instance. If handling a command must touch several aggregates, commit the first, then
  drive the rest through a domain event — don't widen the transaction to span them. Committing many
  aggregates at once dissolves the boundary and invites lock contention and deadlocks.
- **Between aggregates, consistency is eventual — inside one, it's immediate.** This is the decision
  the boundary encodes: an invariant that must *always* hold across two things means they belong in
  the *same* aggregate; one that may lag briefly means they're *separate* aggregates reconciled by an
  event. Choose deliberately — don't reach for a distributed or two-phase transaction to fake
  immediate consistency across aggregates. Design the reconciliation (and what a reader sees in the
  gap) on purpose.
- **Domain events name facts in the past tense** — `OrderPlaced`, `PaymentCaptured`. Published
  *after* the aggregate change commits, they carry IDs and values (never live object references) and
  let other aggregates, read models, and side effects catch up — the mechanism that *makes* eventual
  consistency work.
- **Domain events stay in this context; integration events cross out of it.** A domain event is an
  in-process fact handled *within* the same bounded context. To notify *another* context, publish a
  versioned **integration event** in your published language at the boundary — never leak the raw
  domain event across the seam (that couples the other context to your internals). See
  `bounded-contexts` for the cross-context side.
- **Functional core, imperative shell.** Domain decisions are pure functions/methods — no DB, no
  clock, no HTTP inside them. The shell (handlers, repositories) gathers inputs, calls the core, and
  performs the IO the core decided on. This is separation of concerns applied to the domain and
  makes the core trivial to test (see `backend-testing`).
- **Invalid domain input is a domain error, not a panic/500.** Return a typed domain error so the
  edge can map it correctly (see `error-handling-and-logging`).
- **Speak the ubiquitous language.** Types, methods, and events use the domain's exact words —
  the same terms `bounded-contexts` establishes and `naming-and-structure` enforces in code.

## Checklist

- [ ] Illegal states are unrepresentable, not just guarded against
- [ ] Value objects are immutable and validated at construction; equality is by value
- [ ] Entities are compared by identity; aggregates are small and saved in one transaction
- [ ] Exactly one aggregate is modified per transaction; cross-aggregate work goes through an event
- [ ] Consistency needs are classified: same-aggregate (immediate) vs cross-aggregate (eventual)
- [ ] Other aggregates are referenced by ID, not embedded
- [ ] Invariants live in the model (rich), not in a service mutating public fields (anemic)
- [ ] Domain logic is pure; DB/clock/HTTP stay in the shell
- [ ] Domain events are past-tense facts carrying values; cross-context uses an integration event
- [ ] Types and methods use the ubiquitous language; invalid input yields a domain error

## Examples

### Value object — illegal states unrepresentable

**Bad** — primitive obsession; the rule is re-checked (or forgotten) at every call site:
```go
func Charge(amountCents int, currency string) error {
    if amountCents < 0 { return errors.New("negative amount") } // repeated everywhere, easy to miss
    // currency could be "", "usd", "US$"… nothing guarantees it's valid
}
```
```python
def charge(amount_cents: int, currency: str) -> None:
    if amount_cents < 0:                    # repeated at every call site
        raise ValueError("negative amount")
    # currency could be "", "usd", "US$" — nothing guarantees validity
```

**Good** — a `Money` value object that cannot hold an invalid value; validated once, trusted after:
```go
type Money struct{ cents int64; currency Currency } // fields unexported → immutable from outside

func NewMoney(cents int64, c Currency) (Money, error) {
    if cents < 0 { return Money{}, ErrNegativeAmount } // domain error, not panic
    if !c.IsValid() { return Money{}, ErrUnknownCurrency }
    return Money{cents: cents, currency: c}, nil
}
func (m Money) Add(o Money) (Money, error) { /* same-currency check; returns a NEW Money */ }
```
```python
@dataclass(frozen=True)                     # frozen → immutable, equal by value
class Money:
    cents: int
    currency: Currency

    def __post_init__(self) -> None:
        if self.cents < 0:
            raise NegativeAmount()          # domain error
        if not self.currency.is_valid():
            raise UnknownCurrency()

    def add(self, other: "Money") -> "Money":  # returns a NEW Money, never mutates
        ...
```

### Rich aggregate vs anemic model

**Bad** — anemic: a service reaches in and mutates fields, so the invariant lives outside the model:
```python
def add_item(order, item):                  # nothing stops this on a shipped order
    order.items.append(item)
    order.total_cents += item.price_cents    # rule duplicated wherever items are added
```

**Good** — the aggregate owns its invariant; illegal transitions are impossible from outside:
```python
class Order:                                 # aggregate root
    def add_item(self, item: LineItem) -> None:
        if self.status is not OrderStatus.DRAFT:
            raise OrderAlreadyFinalized()    # invariant enforced in one place
        self._items.append(item)             # _items is private; no external mutation

    @property
    def total(self) -> Money:                # derived, always consistent
        return sum((i.subtotal for i in self._items), start=Money.zero(self.currency))
```
```go
// Order aggregate root: the only way to add an item goes through this method.
func (o *Order) AddItem(item LineItem) error {
    if o.status != StatusDraft { return ErrOrderAlreadyFinalized } // invariant in one place
    o.items = append(o.items, item)          // items unexported → no external mutation
    return nil
}
func (o *Order) Total() Money { /* derived from items, always consistent */ }
```

### Functional core, imperative shell

**Good** — the decision is pure; the shell performs the IO the core returned:
```go
// core: pure — given state + input, decide what happened. No DB, no clock, no HTTP.
func (o *Order) Place(now time.Time) (OrderPlaced, error) {
    if len(o.items) == 0 { return OrderPlaced{}, ErrEmptyOrder }
    o.status = StatusPlaced
    return OrderPlaced{OrderID: o.id, At: now, Total: o.Total()}, nil // past-tense fact
}

// shell: gather inputs, call the core, then do the IO it decided on.
func (h *OrderHandler) place(ctx context.Context, id OrderID) error {
    order, err := h.orders.Load(ctx, id)     // IO in
    if err != nil { return err }
    event, err := order.Place(h.clock.Now())  // pure decision
    if err != nil { return err }
    if err := h.orders.Save(ctx, order); err != nil { return err } // IO out
    return h.events.Publish(ctx, event)
}
```

### One aggregate per transaction → eventual consistency via a domain event

**Bad** — one transaction mutates two aggregates, so the consistency boundary means nothing and the
two now lock together:
```python
def place_order(order: Order, customer: Customer) -> None:
    with uow.transaction():                       # two aggregates in ONE commit
        order.place()
        customer.add_loyalty_points(order.total)  # different aggregate → boundary dissolved
```

**Good** — commit the one aggregate the command owns; let the other catch up on the event, in its
own transaction. Same-aggregate invariants stay immediate; across aggregates, consistency is eventual:
```python
def place_order(order: Order) -> None:
    with uow.transaction():                       # exactly ONE aggregate
        event = order.place()                     # OrderPlaced (past-tense fact)
        uow.orders.save(order)
    events.publish(event)                         # after commit

# handled separately — its own transaction, its own aggregate. Consistency is eventual.
def on_order_placed(event: OrderPlaced) -> None:
    with uow.transaction():
        customer = uow.customers.get(event.customer_id)
        customer.add_loyalty_points(event.total)
```
```go
func (h *OrderHandler) place(ctx context.Context, id OrderID) error {
    order, err := h.orders.Load(ctx, id)
    if err != nil { return err }
    event, err := order.Place(h.clock.Now())
    if err != nil { return err }
    if err := h.orders.Save(ctx, order); err != nil { return err } // one aggregate, one tx
    return h.events.Publish(ctx, event)                            // OrderPlaced, after commit
}

// separate handler, separate transaction — the Customer aggregate reconciles eventually.
func (h *LoyaltyHandler) OnOrderPlaced(ctx context.Context, e OrderPlaced) error {
    customer, err := h.customers.Load(ctx, e.CustomerID)
    if err != nil { return err }
    customer.AddLoyaltyPoints(e.Total)
    return h.customers.Save(ctx, customer)
}
```
