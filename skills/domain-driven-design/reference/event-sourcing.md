# Event sourcing (event-sourced aggregates)

## Contents
What it is · the trigger condition · event store, snapshots, upcasting · interaction with CQRS ·
interaction with domain vs. integration events · example (state-stored → event-sourced).

`reference/architecture-and-layering.md`'s default is a state-stored aggregate: the current fields,
loaded and saved as a row. Event sourcing is the alternative storage strategy for one specific
situation — an aggregate's *history* is itself something the business needs, not just its current
state. This reference owns that one pattern; everything else about the aggregate (invariants, small
boundary, one-per-transaction, reference-by-id) is unchanged and still governed by
`reference/tactical-patterns.md`.

## Rules

- **The trigger, precisely: the aggregate's history is a business requirement**, not an
  infrastructure preference — an audit trail that must be provable, "what did this look like as of
  last Tuesday" queries, or debugging that depends on replaying exactly what happened. If nobody will
  ever ask "how did we get here," a state-stored aggregate is simpler and correct — event sourcing
  applied without this trigger is ceremony, not rigor.
- **State is a fold over committed events, never stored directly.** The aggregate's current state is
  rebuilt by replaying its events in order through the same state-transition logic that produced them
  — there is no separate "current state" column to fall out of sync with the history.
- **The event store is the single source of truth**, append-only, keyed by aggregate id and sequence
  number. Optimistic concurrency (check the expected sequence number on append) replaces a row-level
  lock as the mechanism that catches concurrent writers.
- **Snapshot for replay performance, never for correctness.** Once an aggregate has enough events that
  replay is slow, persist a periodic snapshot of the folded state — but always alongside the full
  event log, and always able to fall back to full replay. A snapshot is a cache, not the record.
- **Version and upcast events as they evolve.** A stored event is a historical fact and can't be
  edited in place; when its shape needs to change, add an upcaster that transforms the old shape into
  the new one on read, the same versioning discipline
  `reference/strategic-design.md` applies to integration events, applied here to the store itself.
- **Event-sourced aggregates commonly pair with dedicated read-model projections** — a separate
  process consumes the event stream and maintains purpose-built query tables. This is **physical**
  CQRS (a real second store), a step up from the **logical** CQRS that's the default elsewhere in
  this skill (see `reference/architecture-and-layering.md`) — reach for it because this aggregate is
  event-sourced, not as a general performance move.
- **The stored event is still internal to the aggregate.** Nothing changes about the domain vs.
  integration event rule in `reference/strategic-design.md`: another bounded context is told what
  happened through a versioned integration event, never by subscribing to this aggregate's raw event
  store.
- **Migrating an existing state-stored aggregate to event-sourced is a deliberate, scoped change** —
  it changes the write path, the concurrency mechanism, and requires backfilling a plausible event
  history (or accepting a "migrated" starting event) for existing rows. Don't do it opportunistically
  alongside an unrelated feature.

## Checklist

- [ ] The trigger is named explicitly (audit/temporal query/replay-driven debugging) — not "we're
      doing DDD so let's event-source"
- [ ] Current state is always derived by folding events, never stored and read independently
- [ ] The event store is append-only, keyed by aggregate id + sequence number, with optimistic
      concurrency on append
- [ ] Snapshots exist only as a replay-performance optimization and can always be regenerated from
      the full event log
- [ ] Events are versioned; a shape change is handled with an upcaster, never an in-place edit
- [ ] Read models are projections consumed from the event stream, not queries against the write model
- [ ] Cross-context notifications are still versioned integration events, not the raw stored events
- [ ] Migrating an aggregate to event sourcing is its own scoped change, not bundled into a feature

## Examples

### State-stored aggregate → event-sourced aggregate

**Before** — state-stored: current balance is the row; history isn't kept, so "what was the balance
last Tuesday" isn't answerable, and this account type has an audit requirement that means it should
be:

```python
class Account:
    def __init__(self, id: AccountId, balance: Money) -> None:
        self.id = id
        self._balance = balance

    def deposit(self, amount: Money) -> None:
        self._balance = self._balance.add(amount)   # overwrites the only record of prior state
```

**After** — event-sourced: state is a fold over committed events; the event log is the only thing
persisted, and any past balance is answerable by replaying up to that point:

```python
class Account:
    def __init__(self, id: AccountId) -> None:
        self.id = id
        self._balance = Money.zero()
        self._uncommitted: list[DomainEvent] = []

    @staticmethod
    def rebuild(id: AccountId, history: list[DomainEvent]) -> "Account":
        account = Account(id)
        for event in history:
            account._apply(event)            # same fold used for replay and for new events
        return account

    def deposit(self, amount: Money) -> None:
        self._raise(Deposited(account_id=self.id, amount=amount))

    def _raise(self, event: DomainEvent) -> None:
        self._apply(event)
        self._uncommitted.append(event)

    def _apply(self, event: DomainEvent) -> None:
        match event:
            case Deposited(amount=amount):
                self._balance = self._balance.add(amount)

# repository: append-only store, optimistic concurrency on the expected sequence number.
class EventSourcedAccountRepository:
    def load(self, id: AccountId) -> Account:
        history = self._store.read(id)               # or: snapshot + events since the snapshot
        return Account.rebuild(id, history)

    def save(self, account: Account, expected_version: int) -> None:
        self._store.append(account.id, account._uncommitted, expected_version)  # raises on conflict
        account._uncommitted.clear()
```

```go
// Account: state is derived by folding events; nothing else is stored.
type Account struct {
    id          AccountID
    balance     Money
    uncommitted []DomainEvent
}

func RebuildAccount(id AccountID, history []DomainEvent) *Account {
    a := &Account{id: id}
    for _, e := range history {
        a.apply(e) // same fold used for replay and for new events
    }
    return a
}

func (a *Account) Deposit(amount Money) { a.raise(Deposited{AccountID: a.id, Amount: amount}) }

func (a *Account) raise(e DomainEvent) {
    a.apply(e)
    a.uncommitted = append(a.uncommitted, e)
}

func (a *Account) apply(e DomainEvent) {
    switch ev := e.(type) {
    case Deposited:
        a.balance, _ = a.balance.Add(ev.Amount)
    }
}

// repository: append-only, optimistic concurrency on expectedVersion.
func (r *EventSourcedAccountRepository) Save(ctx context.Context, a *Account, expectedVersion int) error {
    return r.store.Append(ctx, a.id, a.uncommitted, expectedVersion) // errors on version conflict
}
```
