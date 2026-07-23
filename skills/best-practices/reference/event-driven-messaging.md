# Event-driven & messaging

Publishing and consuming messages crosses a trust boundary a plain function call never does: the
publish can fail after the state change commits, the same message can arrive twice, and a consumer
you don't control can be slow, down, or running old code. These rules keep "state changed" and
"event published" atomic, and keep every consumer safe to run twice.

## Rules

- **Never publish as a bare side effect of a transaction.** Committing a DB write and then calling
  the broker in the next line loses the event if the process crashes between the two — the state
  change is durable, the event never happened. Use the **transactional outbox pattern**: write the
  event to an outbox table in the *same* transaction as the state change, and let a separate relay
  (polling the table, or reading its write-ahead log via CDC) publish it. Publish and state change
  succeed or fail together; the relay's job is exactly-once-triggered publish, retried until acked.
- **Every consumer is idempotent.** Delivery is at-least-once, never exactly-once, no matter what
  the broker claims. Dedupe by a stable message ID against a processed-messages table, or make the
  handler naturally idempotent (an upsert keyed on the domain ID, not an insert that fails on
  retry).
- **Version message schemas explicitly.** Stamp a version on every message. Consumers must tolerate
  unknown additive fields (ignore what you don't recognize) instead of failing closed on them. A
  breaking change ships as a new version published in parallel with the old one until every consumer
  has migrated — never rewrite a message shape in place.
- **Ordering only holds within a partition/key, never globally.** Design consumers to not depend on
  cross-key ordering; if two events about the same entity must be applied in order, they must share
  a partition key.
- **Dead-letter what you can't process — don't block or drop.** A poison message that fails every
  retry blocks every message behind it if left on the main queue, and silently discarding it hides a
  bug. Route it to a dead-letter queue after a bounded retry count, and alert on that queue's depth.
- **A consumer is an external dependency.** Calling out from a handler (another service, a DB) gets
  the same treatment as any outbound call — bounded retries with backoff on transient failures, then
  dead-letter (see `resilience-and-timeouts`).
- **Distinguish domain events from integration events.** A domain event is internal, in-process,
  and can change shape freely with its aggregate. An integration event is the explicit, versioned
  contract published across a bounded-context boundary — only integration events cross the
  outbox/broker boundary this file governs (see `domain-driven-design`'s strategic-design
  reference).

## Checklist

- [ ] No publish happens as a bare side effect after commit — outbox or an equivalent atomic path
- [ ] Every consumer handler is idempotent (dedupe table or a naturally idempotent write)
- [ ] Messages carry an explicit schema version; consumers ignore unknown additive fields
- [ ] Breaking schema changes ship as a new version running in parallel, not an in-place change
- [ ] Nothing in a consumer assumes ordering across partitions/keys
- [ ] Unprocessable messages go to a dead-letter queue after bounded retries, not dropped or blocking
- [ ] Calls a consumer makes to other dependencies are bounded/retried like any outbound call
- [ ] Domain events stay in-process; only integration events are published to the broker

## Examples

### Go

**Bad** — publishes after commit; a crash between the two loses the event, and the handler isn't
idempotent on redelivery:

```go
func (s *OrderService) PlaceOrder(ctx context.Context, o Order) error {
    if _, err := s.db.ExecContext(ctx, insertOrderSQL, o.ID, o.Total); err != nil {
        return err
    }
    // if the process dies here, the order exists but "OrderPlaced" is never published
    return s.broker.Publish(ctx, "OrderPlaced", o) // also re-runs fully on any redelivery
}
```

**Good** — event row written in the same transaction as the state change; a separate relay
publishes it, and the consumer dedupes by message ID:

```go
func (s *OrderService) PlaceOrder(ctx context.Context, o Order) error {
    tx, err := s.db.BeginTx(ctx, nil)
    if err != nil {
        return err
    }
    defer tx.Rollback() // no-op once committed

    if _, err := tx.ExecContext(ctx, insertOrderSQL, o.ID, o.Total); err != nil {
        return err
    }
    event := OrderPlaced{Version: 1, OrderID: o.ID, Total: o.Total}
    payload, _ := json.Marshal(event)
    // same transaction: the event row commits iff the order row commits
    if _, err := tx.ExecContext(ctx, insertOutboxSQL, uuid.New(), "OrderPlaced", payload); err != nil {
        return err
    }
    return tx.Commit() // a separate relay process polls the outbox table and publishes
}

// consumer side: dedupe by message ID before applying any effect
func (h *ReserveStockHandler) Handle(ctx context.Context, msg Message) error {
    seen, err := h.processed.MarkIfNew(ctx, msg.ID) // atomic insert-or-detect-duplicate
    if err != nil {
        return err
    }
    if seen {
        return nil // already handled this exact message; safe to ack and skip
    }
    return h.stock.Reserve(ctx, msg.OrderID) // upsert-style reserve, safe if retried anyway
}
```

### Python

**Bad** — publishes after commit with no outbox, and no schema version so consumers must guess the
shape:

```python
def place_order(db, broker, order: Order) -> None:
    db.execute(insert_order_sql, order.id, order.total)
    db.commit()
    # crash here: order exists, "order_placed" never published — no way to recover it
    broker.publish("order_placed", {"order_id": order.id, "total": order.total})
```

**Good** — outbox row written inside the same transaction; consumer dedupes via a processed-message
table and ignores unknown fields:

```python
def place_order(db, order: Order) -> None:
    with db.begin():  # single transaction: order row + outbox row commit together
        db.execute(insert_order_sql, order.id, order.total)
        event = {"version": 1, "order_id": order.id, "total": order.total}
        db.execute(insert_outbox_sql, str(uuid4()), "order_placed", json.dumps(event))
    # a separate relay process reads the outbox table and publishes to the broker

def handle_order_placed(db, msg: Message) -> None:
    with db.begin():
        inserted = db.execute(
            mark_processed_if_new_sql, msg.id  # unique constraint on message_id
        ).rowcount
        if not inserted:
            return  # duplicate delivery: already handled, ack and move on
        body = json.loads(msg.body)  # consumer reads only known fields; ignores extras
        reserve_stock(db, body["order_id"])  # upsert-style reserve, safe on retry
```
