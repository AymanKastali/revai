# Process managers, sagas & reliable integration

## Contents
Process manager/saga (orchestration vs. choreography) · compensating actions · transactional outbox
· idempotent consumers · worked example (order → payment → inventory).

`reference/tactical-patterns.md`'s "reconcile through an event" rule handles the simple case: one
aggregate's event, one other aggregate reacting. This reference is for what's left: a workflow with
more than one hop, one that must undo an earlier step when a later one fails, and the plumbing that
makes "publish after commit" actually safe when the process crashes mid-way. All three below are
pattern-level tools with their own trigger — reach for them because the workflow in front of you
needs multi-step coordination, compensation, or crash-safe delivery, not by default.

## Rules

- **A process manager (saga) coordinates a workflow that spans more than one aggregate or bounded
  context**, tracking which steps have completed and what to do next — or what to undo. Trigger: the
  workflow has more than one hop, or a later step can fail in a way that must undo an earlier one.
  A single command → single reaction is not a saga; don't build the coordinator for that case.
- **Orchestration vs. choreography — pick deliberately, per workflow:**
  - **Orchestration** — a dedicated process-manager aggregate/service holds the workflow's state
    explicitly, issues the next command, and reacts to the result. Prefer this when the workflow has
    several steps, needs visible state ("where is this order in fulfillment"), or needs compensation
    logic — the coordination is easier to find, test, and debug in one place.
    - **Choreography** — no central coordinator; each participant reacts to the previous participant's
    event and emits its own. Prefer this for a short chain (two or three hops) where no single step
    needs to see the whole picture — adding a coordinator for a two-hop reaction is unearned
    ceremony. As a workflow grows past a few hops, or gains branching/compensation, migrate it to
    orchestration rather than adding a fourth participant to the choreography chain.
- **Compensating actions undo a prior step's effect — there is no distributed transaction to roll
  back.** For every step with a real-world or cross-aggregate side effect, design its compensation
  up front (release the reserved stock, refund the captured payment) as part of the workflow, not as
  an afterthought once a failure is observed in production.
- **The transactional outbox makes "publish after commit" crash-safe.** Write the domain event to an
  outbox table in the *same database transaction* as the aggregate's state change; a separate relay
  process reads the outbox and publishes to the broker, marking each row published only after a
  confirmed send. This closes the gap where a bare "commit, then publish" can commit and crash before
  publishing — the event would otherwise be silently lost.
- **Consumers must be idempotent.** At-least-once delivery is the default assumption for any event
  transport — the same event can arrive twice. A handler that isn't safe to run twice (double-charging
  a payment, double-decrementing stock) needs a dedup key (event id, or the aggregate's expected
  version) checked before applying the effect.
- **A process manager's own state is itself an aggregate** — it has identity, a lifecycle (started →
  steps completed → finished/compensated), and its invariants (no step runs twice, compensation runs
  in reverse order) are enforced the same way any aggregate's are (see `reference/tactical-patterns.md`).
- **This is where `best-practices`' event-driven-messaging reference and this skill meet** — the
  outbox/broker mechanics and delivery guarantees are governed there; which events represent a saga
  step, and what compensates what, is governed here.

## Checklist

- [ ] A coordinator exists only for workflows with more than one hop or a real compensation need
- [ ] Orchestration vs. choreography was a deliberate choice for this workflow, not a default
- [ ] Every step with a side effect has a designed compensating action, decided up front
- [ ] Domain events that must survive a crash are written via a transactional outbox, not published
      directly after commit with no safety net
- [ ] Every event consumer is idempotent against redelivery of the same event
- [ ] The process manager's own state is modeled as an aggregate with its own invariants
- [ ] Choreography chains that grew past a few hops or gained branching were migrated to orchestration

## Examples

### Orchestrated saga with compensation and a transactional outbox

Workflow: placing an order must authorize payment, then reserve stock; if stock can't be reserved,
the payment authorization must be voided.

```python
class OrderFulfillmentSaga:                      # the process manager — itself an aggregate
    def __init__(self, order_id: OrderId) -> None:
        self.order_id = order_id
        self.state = SagaState.STARTED

    def on_order_placed(self, event: OrderPlaced) -> Command:
        self.state = SagaState.AWAITING_PAYMENT
        return AuthorizePayment(self.order_id, event.total)

    def on_payment_authorized(self, event: PaymentAuthorized) -> Command:
        self.state = SagaState.AWAITING_STOCK
        return ReserveStock(self.order_id, event.items)

    def on_stock_reservation_failed(self, event: StockReservationFailed) -> Command:
        self.state = SagaState.COMPENSATING
        return VoidPaymentAuthorization(self.order_id)   # compensate the prior step

    def on_stock_reserved(self, event: StockReserved) -> Command:
        self.state = SagaState.COMPLETED
        return CapturePayment(self.order_id)

# transactional outbox: event row written in the SAME transaction as the state change.
def place_order(order: Order) -> None:
    with uow.transaction():
        event = order.place()
        uow.orders.save(order)
        uow.outbox.append(event)             # same transaction — no publish-after-crash gap
    # a separate relay process reads uow.outbox and publishes to the broker, then marks it sent

# idempotent consumer: checked against a dedup key before applying the effect.
def on_authorize_payment(cmd: AuthorizePayment, seen: SeenCommands) -> None:
    if seen.already_handled(cmd.id):         # at-least-once delivery — this may be a redelivery
        return
    gateway.authorize(cmd.order_id, cmd.amount)
    seen.mark_handled(cmd.id)
```

```go
// OrderFulfillmentSaga: the process manager, modeled as its own aggregate.
type OrderFulfillmentSaga struct {
    orderID OrderID
    state   SagaState
}

func (s *OrderFulfillmentSaga) OnOrderPlaced(e OrderPlaced) Command {
    s.state = SagaAwaitingPayment
    return AuthorizePayment{OrderID: s.orderID, Amount: e.Total}
}

func (s *OrderFulfillmentSaga) OnStockReservationFailed(e StockReservationFailed) Command {
    s.state = SagaCompensating
    return VoidPaymentAuthorization{OrderID: s.orderID} // compensate the prior step
}

// transactional outbox: event persisted in the same DB transaction as the state change.
func (h *OrderHandler) PlaceOrder(ctx context.Context, id OrderID) error {
    return h.uow.WithinTx(ctx, func(tx Tx) error {
        order, err := h.orders.Load(ctx, tx, id)
        if err != nil { return err }
        event, err := order.Place(h.clock.Now())
        if err != nil { return err }
        if err := h.orders.Save(ctx, tx, order); err != nil { return err }
        return h.outbox.Append(ctx, tx, event) // same transaction — a relay publishes it later
    })
}

// idempotent consumer: dedup key checked before applying an at-least-once-delivered command.
func (h *PaymentHandler) OnAuthorizePayment(ctx context.Context, cmd AuthorizePayment) error {
    if h.seen.AlreadyHandled(ctx, cmd.ID) {
        return nil
    }
    if err := h.gateway.Authorize(ctx, cmd.OrderID, cmd.Amount); err != nil { return err }
    return h.seen.MarkHandled(ctx, cmd.ID)
}
```
