---
name: tdd
description: Use when implementing a feature or bugfix — how to drive it with TDD and what to test at each layer of the architecture. Complements superpowers:test-driven-development (the red-green-refactor method) and backend-testing (what a test runs against). This skill owns the sequencing across a feature and the per-layer "what to assert".
---

# TDD: how to apply it and what to test

Three skills, three jobs. Don't restate the others:

- **The method** — red → green → refactor, the iron law (no production code without a failing test
  first), why order matters → `superpowers:test-driven-development`. Follow that loop; this skill
  only tells you *where to point it*.
- **What a test runs against** — real DB over mocks, ephemeral infra, factories, determinism, and
  **where test files live** (Go co-located, Python `tests/` tree, unit split from integration) →
  `backend-testing`.
- **This skill** — how to *sequence* TDD across a feature, and *what behavior to assert at each
  layer*.

## Where to start the failing test

- **Logic-rich feature → start in the domain (inside-out).** Write the first failing test against
  the aggregate or value object that owns the rule, get it green, then work outward to the handler
  and the endpoint. The hardest thinking gets pinned by tests first.
- **Thin CRUD / pass-through endpoint → start at the boundary (outside-in).** Drive from a failing
  handler test inward; there's little domain logic to protect.

Guidance, not dogma — pick the direction that puts the risky behavior under test earliest. See
`hexagonal-architecture` for the layers referenced below.

## What to test, by layer

| Layer | Test style | Assert on |
|---|---|---|
| **domain** — aggregates, value objects, domain services | pure unit, **no mocks** | invariants hold, valid state transitions, invalid input is rejected, domain events raised (see `domain-modeling`) |
| **application** — command/query handlers | unit with **fake ports** (in-memory repo) | the orchestration outcome, that ports were called with the right intent, each designed error path |
| **infra** — repositories, adapters | integration | mapping and round-trips, constraint violations — **for the how (real ephemeral DB, factories, isolation) use `backend-testing`** |
| **interface** — HTTP handlers | table-driven request→response | status code + body shape, validation/error responses (see `api-design`, `error-handling-and-logging`) |

## What NOT to test

- Getters/setters and data holders with no logic.
- Framework glue and third-party libraries — test *your* behavior, not theirs.
- Private internals or call counts — assert observable behavior, so a refactor that preserves
  behavior doesn't break the test.

If a test forces you to reach into internals, the design is too coupled — that's a signal to fix
the seam (dependency injection, a port), not to test the internals.

## Test-craft rules

What a good test looks like in general — behavior over implementation, one behavior per test, real
code over mocks — is owned by `superpowers:test-driven-development` and `backend-testing`. The slant
specific to this skill:

- **In domain/app, prefer fakes to mocks** — an in-memory port implementation reads as real usage of
  the seam, not ceremony.
- **Follow the language grain.** Go: table-driven cases with `t.Run` subtests, `testify/require`.
  Python: `pytest` with `@pytest.mark.parametrize` and fixtures; arrange-act-assert; no
  `unittest.TestCase` boilerplate.

## Checklist

- [ ] Started each behavior from a **failing test**, at the right layer for where the risk lives
- [ ] Domain logic covered by **pure unit tests**, no mocks
- [ ] Application handlers tested against **fake ports**, including error paths
- [ ] Infra/integration testing follows `backend-testing` (real ephemeral deps, not mocks)
- [ ] Assertions check **observable behavior**, not internals or call counts
- [ ] Nothing tested that shouldn't be (getters, framework, third-party)
- [ ] One behavior per test; names describe the behavior

## Examples

A domain rule — an `Order` must have at least one line — driven red → green → refactor. Domain
layer, so pure unit tests, no infrastructure.

### Go

**RED** — write the behavior first; it fails because the guard doesn't exist yet:
```go
func TestOrder_RejectsSubmissionWithNoLines(t *testing.T) {
    order := NewOrder(customerID)

    err := order.Submit()

    require.ErrorIs(t, err, ErrOrderEmpty) // fails: Submit has no guard yet
}
```

**GREEN** — minimal code to pass, nothing more:
```go
func (o *Order) Submit() error {
    if len(o.lines) == 0 {
        return ErrOrderEmpty
    }
    o.status = StatusSubmitted
    return nil
}
```

**REFACTOR** — once green, fold the guard into an invariant check reused by other mutators; keep
tests green, add no behavior. Then the next failing test (e.g. "submitted order can't be edited").

### Python

**RED**:
```python
def test_order_rejects_submission_with_no_lines():
    order = Order(customer_id)

    with pytest.raises(OrderEmpty):   # fails: submit() has no guard yet
        order.submit()
```

**GREEN**:
```python
def submit(self) -> None:
    if not self._lines:
        raise OrderEmpty
    self._status = OrderStatus.SUBMITTED
```

**REFACTOR** — extract the invariant if a second mutator needs it; tests stay green.
