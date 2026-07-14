---
name: naming-and-structure
description: Use when writing or naming any code — functions, variables, types, files, packages/modules (Go/Python primarily). Enforces intention-revealing descriptive names (verbs for functions, predicates for booleans, no cryptic abbreviations, one term per concept) and separation of concerns (one responsibility per unit, IO at the edges, layers that don't leak). Applied proactively as you write, not as a cleanup pass.
---

# Naming & structure

Code is read far more than it is written. A correct, descriptive name and a clear boundary remove
the need for a comment and make a change safe to reason about. Apply these *as you write* — this is
the proactive standard, distinct from `code-simplifier`, which cleans reactively.

## Naming

- **Reveal intent.** A reader should know what a name is and why it exists without a comment.
  `activeUsers`, not `list2`; `retryBudget`, not `n`.
- **Functions and methods are verb phrases** — `fetchOrder`, `calculate_total`, `PlaceOrder`. A
  function named like a noun hides what it does.
- **Booleans read as predicates** — `isReady`, `hasItems`, `should_retry`. Never a bare noun that
  forces the reader to guess the polarity.
- **No cryptic abbreviations or single letters** outside tiny, idiomatic scopes (a loop `i`, Go's
  `err`, a 2-line lambda). Ban `data`, `info`, `tmp`, `mgr`, `doStuff`, `handle2`.
- **One term per concept.** If it's a `user`, it's a `user` everywhere — don't drift between
  `user`, `account`, and `customer` for the same thing.
- **Name by role, not by type.** `recipients`, not `stringList`; `pendingOrders`, not `orderArr`.
- **Length scales with scope.** A wide-scope export earns a fuller name; a 3-line block can be terse.
- **Follow the language's idiom.** Go: `MixedCaps`, exported = capitalized, short receiver names.
  Python: `snake_case` for functions/vars, `PascalCase` for classes, no type prefixes.

## Separation of concerns

- **One reason to change per unit** (function, type, file, module). If you need "and" to describe
  what it does, split it.
- **IO at the edges, pure logic in the core.** Keep side effects at the boundary and business rules
  in pure functions that are trivial to test. `hexagonal-architecture` makes this concrete as the
  layer/import rule.
- **Don't leak layers.** Each layer talks to the next through a narrow interface and never reaches
  past it. `hexagonal-architecture` makes this concrete as the dependency/import rule.
- **One level of abstraction per function.** Don't mix high-level orchestration with low-level byte
  fiddling in the same body.
- **A large file or function is a symptom** — it's doing too much. Split by responsibility, never
  arbitrarily by line count.

## Checklist

- [ ] Every name reveals intent without needing a comment
- [ ] Functions are verb phrases; booleans are predicates
- [ ] No cryptic abbreviations or type-suffixed names outside tiny scopes
- [ ] One consistent term per concept across the codebase
- [ ] Each unit has a single responsibility (no "and" in its description)
- [ ] IO lives at the edges; core logic is pure; layers don't leak
- [ ] Names follow Go/Python idioms

## Examples

### Naming

**Bad** — nothing reveals intent:
```go
func proc(d []*U, f bool) []*U   // proc? d? f?
```
```python
def proc(d, f): ...              # proc? d? f?
```

**Good** — role-revealing names; function is a verb, flag is a predicate:
```go
func filterActiveUsers(users []*User, includeAdmins bool) []*User
```
```python
def filter_active_users(users: list[User], include_admins: bool) -> list[User]: ...
```

### Separation of concerns

**Bad** — one handler does transport, validation, a business rule, and persistence:
```go
func handler(w http.ResponseWriter, r *http.Request) {
    var body CreateOrder
    json.NewDecoder(r.Body).Decode(&body)             // transport
    if body.Total <= 0 { http.Error(w, "bad", 400); return } // validation
    total := body.Total * 1.2                          // business rule (tax)
    db.Exec("INSERT INTO orders (total) VALUES ($1)", total) // persistence
    w.WriteHeader(201)
}
```

**Good** — transport delegates to a service, which owns the rule; the repository owns SQL:
```go
// transport layer: HTTP in/out only
func (h *OrderHandler) Create(w http.ResponseWriter, r *http.Request) {
    body, err := decodeCreateOrder(r)
    if err != nil { writeError(w, err); return }
    order, err := h.orders.Place(r.Context(), body) // delegate to the service
    if err != nil { writeError(w, err); return }
    writeJSON(w, http.StatusCreated, order)
}
```
```python
# transport layer: HTTP in/out only; the service owns the rule, the repository owns SQL
@router.post("/orders", status_code=201)
def create_order(body: CreateOrder, orders: OrderService = Depends(order_service)):
    return orders.place(body)  # delegate; no validation/business/SQL logic inline here
```
