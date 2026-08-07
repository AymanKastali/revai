# In-process communication

## Contents
The core principle · the published-interface facade · domain-event dispatch: in-transaction vs.
after-commit · escalating to async · outbox/inbox for reliability.

**Modules never communicate over the network inside one modular monolith.** Everything below is
in-process — a published-interface facade call or a domain-event dispatch — never HTTP, never gRPC,
never any socket between two modules in the same deployable. That's the entire point of the pattern:
reaching for a network call here is building a distributed system by accident, with none of a real
service boundary's benefits (independent deployability, independent scaling) and all of the cost
(latency, a new failure mode). `system-design/reference/communication-patterns.md` answers this same
sync-vs-async question for calls that *do* cross a network boundary between services — a genuinely
different question from this one.

## The published-interface facade

One facade per module, with three method shapes: a command that returns a result, a command that
doesn't, and a query. Injected at the composition root, per
`domain-driven-design/reference/architecture-and-layering.md` — the calling module depends on the
facade's interface/protocol, never the providing module's internals.

**Go:**

```go
// billing/app/facade.go — billing's published interface; orders depends on this, never billing/domain.
type Facade interface {
    ChargeCustomer(ctx context.Context, cmd ChargeCustomerCommand) (ChargeResult, error) // command, with result
    CancelSubscription(ctx context.Context, cmd CancelSubscriptionCommand) error         // command, no result
    GetInvoice(ctx context.Context, id InvoiceID) (InvoiceView, error)                   // query
}
```

**Python:**

```python
# billing/app/facade.py — billing's published interface; orders depends on this Protocol.
class Facade(Protocol):
    def charge_customer(self, cmd: ChargeCustomerCommand) -> ChargeResult: ...   # command, with result
    def cancel_subscription(self, cmd: CancelSubscriptionCommand) -> None: ...   # command, no result
    def get_invoice(self, invoice_id: InvoiceId) -> InvoiceView: ...             # query
```

## Domain-event dispatch: in-transaction vs. after-commit

Two shapes, chosen by whether the reaction must stay atomic with its trigger — this is Grzybek's actual
distinction, confirmed against his repo and blog: consistency-critical domain events run in-transaction;
"after commit" is reserved for decoupled notifications. Merging the two into one "sync, dispatched
after commit" mode (an earlier draft of this file did this) is inaccurate to that source and unsafe — a
post-commit handler failure can no longer roll back a write that's already durable.

- **In-transaction (default when multiple aggregates in *one module* must move together).** The
  handler runs inside the same unit of work as the code that raised the event, before commit. If it
  fails, the whole transaction rolls back. Always synchronous by construction — there's no such thing
  as an in-transaction async handler.
- **After-commit (default for a reaction in a *different* module).** The event is dispatched only once
  the triggering transaction has already committed, so a handler failure can no longer roll back the
  primary change — this deliberately trades atomicity for decoupling one module's write from another
  module's reaction.

The same `Dispatcher` type serves both — what differs is *where in the code* `Publish`/`publish` is
called (inside vs. after the enclosing transaction), not the dispatcher's shape. State plainly that
this dispatcher shape is **synthesized from the Grzybek/Spring-Modulith reference architectures applied
to Go/Python**, not lifted from an existing named Go/Python library — a recommended shape, not a
claimed industry standard.

**Go:**

```go
// events/dispatcher.go
type Handler func(ctx context.Context, evt Event) error

type Dispatcher struct {
    handlers map[EventType][]Handler
}

func (d *Dispatcher) Subscribe(t EventType, h Handler) {
    d.handlers[t] = append(d.handlers[t], h)
}

func (d *Dispatcher) Publish(ctx context.Context, evt Event) error {
    for _, h := range d.handlers[evt.Type()] {
        if err := h(ctx, evt); err != nil {
            return err // in-transaction: the caller rolls back its transaction on this error
        }
    }
    return nil
}
```

**Python:**

```python
# events/dispatcher.py
class Dispatcher:
    def __init__(self) -> None:
        self._handlers: dict[type, list[Callable]] = {}

    def subscribe(self, event_type: type, handler: Callable) -> None:
        self._handlers.setdefault(event_type, []).append(handler)

    def publish(self, event: object) -> None:
        for handler in self._handlers.get(type(event), []):
            handler(event)  # raises propagate into the caller's transaction if called in-transaction
```

## Escalating an after-commit handler to async

Once an after-commit handler's own work would blow the request's latency budget, move it off the
request path — a goroutine in Go, `asyncio.create_task`/a worker queue in Python — check that budget
against `system-design/reference/capacity-estimation.md` rather than reaching for async by default.
Most after-commit handlers are cheap enough to stay synchronous (still in the same request, right after
commit).

## Outbox/inbox for after-commit reliability

Required for **every** after-commit dispatch, sync or async — not just the async case: write the event
transactionally alongside the state change (the outbox), then relay it, so a crash between "state
committed" and "event dispatched" can't silently drop it. The risk it closes exists the moment dispatch
happens after commit, regardless of whether the handler then runs sync or async. This is the same
mechanism `domain-driven-design/reference/process-managers-and-integration.md` already requires for
cross-context integration events; applying it to an in-process, after-commit handler is the same rule
one level more concrete, not a second outbox rule to learn.

## Checklist

- [ ] No module calls another module over HTTP/gRPC/any socket — every cross-module call is in-process
- [ ] A module depends on another's facade interface/protocol, never its concrete implementation or
      internals
- [ ] A reaction that must stay atomic with its trigger runs in-transaction; a reaction in a different
      module runs after commit
- [ ] Every after-commit dispatch — sync or async — is backed by an outbox, not a fire-and-forget call
- [ ] Async is a stated escalation off an after-commit handler, tied to a real latency budget, not the
      default
