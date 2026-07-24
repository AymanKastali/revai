# Tactical patterns (domain modeling)

## Contents
Value objects & illegal states · entities · rich vs anemic models · aggregates as consistency
boundaries (Vernon's four rules) · domain services · factories · specifications · repositories ·
domain events · examples (Money, Order aggregate, domain service, factory, cross-aggregate
reconciliation).

Model the domain in the type system so the compiler/runtime enforces the rules, not scattered `if`
checks. "Modern" here means **pragmatic, not dogmatic**: apply the pattern that earns its place,
prefer type-driven modelling over ceremony, and keep the domain a **pure core** with IO at the edges.
Not every noun is an aggregate; not every value needs a wrapper. Model what has rules; leave the rest.

Strategy comes first — if you haven't named the concept and its boundary, do that with
`reference/strategic-design.md` before reaching for these patterns.

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
- **An aggregate is a consistency boundary — Vernon's four rules, all mandatory:**
  1. **Protect true invariants inside the boundary.** Everything the aggregate must guarantee about
     itself, always, lives inside it — that's the only reason the boundary exists.
  2. **Design small aggregates.** Include only what must change together *atomically*; everything
     else is a separate aggregate reconciled by an event. Small aggregates mean less lock contention
     and less that can be invalid at once.
  3. **Reference other aggregates by identity only, never by embedding.** Hold an `OrderId`, not an
     `Order` — embedding another aggregate root inside yours dissolves both boundaries into one (see
     `best-practices`).
  4. **Use eventual consistency outside the boundary.** A transaction touches exactly **one**
     aggregate instance; anything that must also change is updated afterward, through a domain event,
     in its own transaction.
- **Across aggregates, reconcile through an event — never a wider transaction.** If a command must
  affect several aggregates, commit the one it owns, then drive the rest through a domain event in
  their own transaction. Don't widen the transaction to span them (lock contention, deadlocks), and
  don't reach for a distributed/two-phase transaction to fake immediate consistency across them. When
  reconciliation is more than one hop, or needs to compensate a prior step on failure, that's a
  process manager/saga — see `reference/process-managers-and-integration.md`.
- **Immediate inside, eventual between — choose deliberately.** This is the design decision the
  boundary encodes: an invariant that must *always* hold belongs *inside* one aggregate (immediate);
  one that may lag briefly belongs *between* separate aggregates, reconciled by an event (eventual).
  Design the reconciliation — and what a reader sees in the gap — on purpose.
- **Domain services hold behaviour that doesn't belong to one entity or value object.** When an
  operation genuinely needs two aggregates (or a domain concept and an aggregate) to compute something
  neither owns alone — e.g. pricing a transfer between two accounts — put it in a stateless domain
  service, not bolted onto one side arbitrarily or pushed up into an application handler. A domain
  service takes and returns domain types only; it is not a place to hold state, and it is not an
  escape hatch for behaviour that actually belongs to a single aggregate whose boundary is just
  unclear yet — fix the boundary first.
- **Factories encapsulate construction that has its own invariants.** When creating a valid aggregate
  or value object takes more than a constructor call — several parts assembled together, invariants
  that only make sense once the whole thing exists — put that assembly in a factory (a static method,
  or a small factory type for genuinely multi-step construction) so callers can't produce a
  half-valid instance. Skip this for anything a plain constructor already validates in one step.
- **Specifications encapsulate a reusable business rule as a predicate.** When the same business
  rule needs to be checked in more than one place — a query filter and a validation, say — express it
  once as a composable specification (`IsOverdue`, `IsEligibleForDiscount`) instead of copy-pasting
  the boolean expression. Compose with `and`/`or`/`not`; skip this for a one-off condition used once.
- **A repository is a collection-like abstraction over one aggregate root's storage.** One repository
  per aggregate root — never for a non-root entity, which is only ever reached through its root. The
  repository *interface* (port) lives in `domain/`; the implementation (adapter) lives in `infra/`
  (see `reference/architecture-and-layering.md`). The write-repository loads and saves the whole
  aggregate; the read side bypasses it entirely (see the CQRS split in
  `reference/architecture-and-layering.md`).
- **Domain events name facts in the past tense** — `OrderPlaced`, `PaymentCaptured`. Published
  *after* the aggregate change commits, they carry IDs and values (never live object references) and
  let other aggregates, read models, and side effects catch up — the mechanism that *makes* eventual
  consistency work. Publishing them reliably (so a crash between commit and publish can't lose one)
  is the transactional outbox — see `reference/process-managers-and-integration.md`. When an
  aggregate's own event history is itself a business requirement (audit, temporal query, replay), see
  `reference/event-sourcing.md` for storing the aggregate as that history instead of current state.
- The domain-vs-integration-event distinction and event versioning live in
  `reference/strategic-design.md`.
- The layer rule that keeps domain logic pure — no DB, clock, or HTTP inside it — lives in
  `reference/architecture-and-layering.md`; that purity is what keeps the core trivial to test (see
  `best-practices`).
- **Invalid domain input is a domain error, not a panic/500.** Return a typed domain error so the
  edge can map it correctly (see `best-practices`).
- **Speak the ubiquitous language.** Types, methods, and events use the domain's exact words —
  the same terms `reference/strategic-design.md` establishes and `clean-code` enforces in code.

## Checklist

- [ ] No bare primitive stands in for a value that has rules — it has its own type
- [ ] Value objects are immutable, self-validating, and equal by value
- [ ] Entities are compared by identity, not by field equality
- [ ] Every aggregate satisfies Vernon's four rules: true invariants inside, kept small, other
      aggregates referenced by ID only, eventual consistency outside the boundary
- [ ] No single transaction touches more than one aggregate instance
- [ ] Multi-hop or compensating reconciliation is a named saga/process manager, not an ad hoc chain
      of event handlers
- [ ] Invariants live inside the type, not in a service mutating public fields
- [ ] A domain service exists only for behaviour that genuinely spans more than one aggregate — not
      as a dumping ground for an unclear boundary
- [ ] A factory exists only where construction itself has multi-step invariants — not a wrapper
      around a constructor that already validates in one step
- [ ] A specification exists only for a rule checked in more than one place — not a one-off condition
- [ ] Each aggregate root has exactly one repository; non-root entities have none
- [ ] Domain logic never touches the DB, clock, or network directly
- [ ] Events are past-tense facts; none cross a context boundary raw (see `reference/strategic-design.md`)
- [ ] Names and events use the ubiquitous language; invalid input returns a domain error, not a panic

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

### Domain service — behaviour that spans two aggregates

**Bad** — the logic is bolted onto one side arbitrarily, and it has to reach into the other
aggregate's internals to do its job:

```python
class Account:
    def transfer_to(self, other: "Account", amount: Money) -> None:
        other._balance = other._balance.add(amount)   # reaching into another aggregate's internals
        self._balance = self._balance.subtract(amount)
```

**Good** — a domain service coordinates two aggregate roots through their own public methods; neither
aggregate reaches into the other:

```python
class TransferService:                       # stateless — takes and returns domain types only
    def transfer(self, source: Account, destination: Account, amount: Money) -> TransferResult:
        source.withdraw(amount)               # each aggregate enforces its own invariant
        destination.deposit(amount)
        return TransferResult(source.id, destination.id, amount)
```

```go
// TransferService: behaviour that belongs to neither Account alone.
type TransferService struct{}

func (TransferService) Transfer(source, destination *Account, amount Money) (TransferResult, error) {
    if err := source.Withdraw(amount); err != nil { return TransferResult{}, err }
    if err := destination.Deposit(amount); err != nil { return TransferResult{}, err }
    return TransferResult{SourceID: source.ID, DestinationID: destination.ID, Amount: amount}, nil
}
```

### Factory — construction with its own invariants

**Bad** — the caller assembles the aggregate piece by piece; nothing stops it from stopping halfway
in an invalid state:

```python
order = Order()
order.customer_id = customer_id
order.items = items                 # nothing checked the items are consistent with each other yet
order.currency = items[0].currency  # caller has to know this rule exists at all
```

**Good** — a factory owns the assembly rule; every `Order` that exists is valid from the moment it's
constructed:

```python
class OrderFactory:
    @staticmethod
    def start(customer_id: CustomerId, items: list[LineItem]) -> Order:
        if not items:
            raise EmptyOrder()
        currency = items[0].currency
        if any(i.currency != currency for i in items):
            raise MixedCurrencyOrder()       # invariant spans the whole set of items at birth
        return Order(customer_id=customer_id, items=items, currency=currency)
```

```go
// NewOrder is the factory: the only way to get an Order is one that's already valid.
func NewOrder(customerID CustomerID, items []LineItem) (*Order, error) {
    if len(items) == 0 { return nil, ErrEmptyOrder }
    currency := items[0].Currency
    for _, i := range items {
        if i.Currency != currency { return nil, ErrMixedCurrencyOrder }
    }
    return &Order{customerID: customerID, items: items, currency: currency}, nil
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
