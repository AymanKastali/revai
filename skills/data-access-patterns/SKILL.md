---
name: data-access-patterns
description: Use when writing database queries, repositories, or transactions in application code (not migrations) — pass context to every query, use only parameterized queries, keep transaction boundaries explicit and short, avoid N+1 queries, bound the connection pool, and map "no rows" to a domain error.
---

# Data access patterns

This is the *runtime* database layer — the queries and transactions the service runs while serving
traffic. (For schema changes, see `safe-schema-changes`.) Most backend latency and corruption bugs
live here.

## Rules

- **Context on every query.** Every DB call takes the caller's `context.Context` so its deadline and
  cancellation propagate — a query with no deadline can pin a connection indefinitely.
  `resilience-and-timeouts` owns the deadline/propagation policy.
- **Parameterized queries only.** Never concatenate or interpolate client input into SQL — use bound
  placeholders. Any dynamic column or sort name must be allow-listed, not passed through (see
  `api-design`).
- **Explicit, short transactions.** Begin/commit/rollback at a clear boundary, one unit of work per
  transaction. Guarantee rollback on every error path (`defer`). Never do a network call, external
  API request, or user wait *inside* a transaction — it holds locks and connections hostage.
- **Avoid N+1.** Don't loop issuing one query per item; fetch the set in a single query (`IN` / `ANY`
  / join / batched load). N+1 loves to hide behind ORM lazy-loading of relations.
- **Bound the connection pool.** Set max open/idle connections and a max lifetime, sized to the
  database's own limits. An unbounded pool exhausts the DB under load.
- **Map "no rows" to a domain error.** A missing row is an expected outcome — translate it to a
  not-found domain error, not a generic failure (see `error-handling-and-logging`).
- **Keep persistence behind a boundary.** A repository / data-access layer, so queries aren't
  scattered through handlers — which also makes them testable against a real DB (see
  `backend-testing`).

## Checklist

- [ ] Every query receives a context carrying the caller's deadline
- [ ] All queries parameterized; dynamic identifiers allow-listed
- [ ] Transactions are short, one unit of work, with guaranteed rollback on error
- [ ] No network/external calls inside a transaction
- [ ] Collections fetched in one query, not a per-item loop (no N+1)
- [ ] Connection pool has max open/idle and max lifetime set
- [ ] "No rows" mapped to a not-found domain error
- [ ] Queries live in a data-access layer, not inline in handlers

## Examples

### Go

**Bad** — string-built SQL (injection), no context, one query per user (N+1):
```go
func ordersFor(userIDs []string) []Order {
    var out []Order
    for _, id := range userIDs { // N+1: a round-trip per user
        rows, _ := db.Query("SELECT * FROM orders WHERE user_id = '" + id + "'") // injection; no ctx
        out = append(out, scan(rows)...)
    }
    return out
}
```

**Good** — one parameterized query, context propagated, error wrapped:
```go
func (r *OrderRepo) ByUsers(ctx context.Context, userIDs []string) ([]Order, error) {
    rows, err := r.db.QueryContext(ctx, // caller's deadline propagates
        `SELECT id, user_id, total FROM orders WHERE user_id = ANY($1)`, // single, parameterized
        pq.Array(userIDs))
    if err != nil {
        return nil, fmt.Errorf("loading orders: %w", err)
    }
    defer rows.Close()
    return scanOrders(rows)
}
```

### Python

**Bad** — string-built SQL (injection), one query per user (N+1):
```python
def orders_for(user_ids):
    out = []
    for uid in user_ids:  # N+1: a round-trip per user
        rows = db.execute("SELECT * FROM orders WHERE user_id = '" + uid + "'")  # injection
        out += scan(rows)
    return out
```

**Good** — one parameterized query behind a data-access function:
```python
def orders_by_users(conn, user_ids: list[str]) -> list[Order]:
    rows = conn.execute(                                          # single, parameterized query
        "SELECT id, user_id, total FROM orders WHERE user_id = ANY(%s)",
        (user_ids,),
    )
    return [Order(**row) for row in rows]
```
