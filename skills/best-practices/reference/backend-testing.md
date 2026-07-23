# Backend testing

## Contents

- Test at the boundary, against real dependencies
- Keep tests deterministic and isolated
- Where tests live
- What to cover
- Checklist
- Examples

This is about *what a backend test runs against*, not *when to write it* — for the red-green-refactor
method, use `superpowers:test-driven-development`. These rules make backend tests catch the bugs
that actually happen in production instead of passing against a fantasy.

## Test at the boundary, against real dependencies

- **Exercise the real entry point.** Test through the HTTP handler or the service's public method —
  the surface a caller actually uses — not private internals. A test coupled to internals breaks on
  every refactor and proves nothing about the contract.
- **Use a real database, don't mock it.** The database is where most backend bugs live: wrong query,
  bad migration, missing constraint, N+1, transaction boundary. A mocked DB tests your mock. Run
  against an ephemeral real instance (e.g. testcontainers, or a disposable local DB), migrate it,
  and tear it down. Same for queues/caches you own.
- **Mock only what you don't own and can't run** — third-party network APIs, payment providers,
  email/SMS senders. Wrap them behind an interface and stub that. Everything inside your system
  boundary should be real.

## Keep tests deterministic and isolated

- **No shared mutable state.** Each test sets up its own data and cleans up (transaction rollback per
  test, or truncate between tests). A test must pass alone and in any order.
- **Build data with factories/builders**, not hand-maintained fixtures or copy-pasted inserts. A
  factory creates a valid object with sensible defaults and lets the test override only the field
  under test — so the intent of each test is visible.
- **Control time and randomness.** Inject the clock and any random/ID source so tests aren't flaky
  around midnight or on a rare seed. Never `sleep()` to wait — poll a condition or use a controllable
  clock.
- **Assert on behavior and observable effects** (response, persisted row, emitted event), not on how
  many times an internal method was called.

## Where tests live

Mirror the source structure so a test is findable from the code it covers, and **split fast unit
tests from slow integration/e2e** so each runs on its own cadence. Follow the language grain for
where the file physically sits.

- **Go — co-locate.** Tests live in the **same directory** as the code, in `_test.go` files
  (compiled only for tests). Default to the **external test package** `package foo_test` (same dir)
  so you exercise the public API as a caller does; drop to internal `package foo` only when a unit
  test genuinely needs unexported access. A separate `tests/` tree fights the toolchain — don't.
- **Python — a separate `tests/` tree mirroring the package** (with `src/` layout):
  `src/orders/domain/order.py` → `tests/orders/domain/test_order.py`. It keeps test-only
  deps/helpers out of the shipped package and forces imports through the public path, exactly as
  callers use it. Co-locating inside the package is fine for a small app; the separate tree is the
  modern default for anything distributed.
- **Depends on the test *type* — split by speed/dependency, regardless of language.** Pure unit
  tests (domain/app) run on every save; slow tests (real DB, network, e2e) run separately in CI or
  on demand — keep them selectable:
  - Go: a build tag `//go:build integration` (or a dedicated `test/`/`e2e/` package) so
    `go test ./...` stays fast.
  - Python: a `tests/integration/` dir and/or markers (`@pytest.mark.integration`), so
    `pytest -m "not integration"` is the fast inner loop.
- **The file name mirrors the source file** — `order.go` → `order_test.go`, `order.py` → `test_order.py`.

This lines up with the per-layer table in `reference/tdd.md`: domain/app tests (pure, fast) live in
the unit path; infra/interface tests (real ephemeral deps, slow) live in the integration suite.

## What to cover

- The happy path through the real stack.
- Each **error path** you designed (validation, not-found, conflict, auth) — see
  `error-handling-and-logging`.
- **Boundary/edge data**: empty, max size, unicode, concurrent writes, duplicate/idempotent retries.
- Integration seams: the migration applies cleanly; the query returns what the constraint allows.

## Checklist

- [ ] Test drives the public boundary (endpoint/service method), not internals
- [ ] Database and owned infra are real (ephemeral), not mocked
- [ ] Only third-party externals are stubbed, behind an interface
- [ ] Each test is self-contained; passes alone and in any order
- [ ] Data comes from factories; only the relevant field is set explicitly
- [ ] Time/randomness injected; no `sleep`-based waits
- [ ] Assertions check observable behavior, not call counts
- [ ] Error paths and edge/boundary inputs are covered, not just the happy path
- [ ] Test files mirror the source layout (Go: co-located `_test.go`; Python: `tests/` tree); slow integration tests are separated from fast unit tests

## Examples

### Go

**Bad** — mocks the DB, so it tests the mock and would pass even if the query or schema were wrong:

```go
func TestGetUser(t *testing.T) {
    db := new(MockDB) // mocked DB → tests the mock
    db.On("FindUser", 1).Return(&User{ID: 1, Name: "A"})
    got, _ := NewService(db).GetUser(1)
    require.Equal(t, "A", got.Name) // proves nothing about real SQL/migrations
}
```

**Good** — real ephemeral DB, factory data, asserts the persisted effect:

```go
func TestGetUser(t *testing.T) {
    db := startEphemeralDatabase(t) // real instance, migrated, torn down via t.Cleanup
    user := UserFactory(t, db, func(u *User) { u.Name = "A" }) // factory: valid row, one field set

    res := testClient(t, db).Get("/users/" + user.ID) // through the real endpoint

    require.Equal(t, 200, res.StatusCode)
    require.Equal(t, "A", res.Body.Data.Name)
}
```

### Python

**Bad** — mocks the DB, so the test only exercises the mock:

```python
def test_get_user(mocker):
    db = mocker.Mock()
    db.find_user.return_value = User(id=1, name="A")  # mocked DB → tests the mock
    assert Service(db).get_user(1).name == "A"        # proves nothing about real SQL/migrations
```

**Good** — real ephemeral DB via fixture, factory data, asserts the persisted effect:

```python
def test_get_user(db, client):             # db fixture: real ephemeral instance, migrated, torn down
    user = UserFactory(db, name="A")        # factory: valid row, one field set

    res = client.get(f"/users/{user.id}")   # through the real endpoint

    assert res.status_code == 200
    assert res.json()["data"]["name"] == "A"
```
