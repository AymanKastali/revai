# Error handling

## Contents
Rules · Checklist · Rationalizations · Examples

Defensive code rots the same way duplication does: once a caller has to null-check one return value
"just in case," every caller of everything starts doing it, and the real signal — this specific
call can fail, here's how — gets buried in reflexive guards. These rules keep the failure signal
explicit and the happy path readable. For what happens operationally once an error occurs —
retries, structured log fields, alerting, what gets logged vs swallowed — see `best-practices`'
error-handling-and-logging reference; this file covers only how error handling is shaped in the
code itself.

## Rules

- **Signal failure through the language's error mechanism, never an encoded sentinel.** In Go,
  return `error` as the last value and check it immediately at the call site — never a magic `-1`
  or empty string mixed in with valid results. In Python and similar languages, raise a real
  exception — never return `None` or a status code a caller can silently ignore.
- **Never return null to signal "nothing here."** Return an empty collection, a zero value, or an
  explicit optional/`Maybe` type instead. A caller that has to `if x != nil` before every use of a
  return value will eventually forget once, and that's a crash or a silent bug.
- **Never pass null as an argument meaning "skip this."** It forces every implementation to
  defensively null-check every parameter. Prefer an explicit optional type, a separate
  overload/named parameter, or a sentinel *value* documented as part of the type — not the absence
  of one.
- **Give every error context at the point it's handled, not just re-thrown bare.** Wrap with what
  operation was being attempted (`fmt.Errorf("fetch order %d: %w", id, err)`) so the failure is
  diagnosable from the message alone, without a debugger session to reconstruct the call chain.
- **Define error/exception types by what the caller needs to do in response, not by where they
  originate.** A caller should be able to branch on "is this retryable" or "is this a not-found,"
  not have to know which internal function happened to raise it. Group errors by response category,
  not by call site.
- **Wrap third-party APIs at a single boundary.** An external library's error conventions (its own
  status codes, its own exception hierarchy) get translated into this codebase's own error types in
  exactly one adapter — so a library swap or version bump touches one file, not every call site.
- **Extract the error-handling path into its own block/function when it gets non-trivial**, so the
  happy path stays readable and isn't buried in defensive branches.

## Checklist

- [ ] Failures are signaled via `error`/exceptions, never an encoded sentinel value
- [ ] No return value uses null/`None` to mean "nothing here" — empty/zero/optional instead
- [ ] No parameter accepts null to mean "skip this" — an explicit type or overload instead
- [ ] Every wrapped error adds what operation was being attempted
- [ ] Error/exception types are grouped by caller response, not by origin
- [ ] Third-party error conventions are translated at exactly one boundary
- [ ] Non-trivial error handling is extracted out of the happy path

## Rationalizations

| Excuse | Reality |
|---|---|
| "Returning null here is fine, I'll remember to check it." | You will, until the one call site that doesn't, and that's the crash report. The type system can't remind you to check something it doesn't know is checkable. |
| "It's faster to just return -1 than define a proper error type." | It's faster once. Every caller then has to know -1 is special, forever, with nothing enforcing it — that cost repeats at every call site. |
| "This library's exceptions are fine, callers can catch them directly." | Until the library's next major version renames them, and now the exception type is scattered across every file that called it instead of one adapter. |
| "The happy path has one extra `if err != nil`, that's not worth extracting." | One is fine. The third one nested inside the second is the actual problem — extract before you're there, not after. |

## Examples

### Go

**Bad** — ambiguous sentinel, no context, caller can't tell "empty" from "failed":

```go
func FindDiscount(order Order) float64 {
    d, ok := discounts[order.Code]
    if !ok {
        return -1 // sentinel: caller must remember -1 means "not found"
    }
    return d
}

func total(order Order) float64 {
    d := FindDiscount(order) // no error to check — easy to forget the -1 case
    return order.Subtotal - d
}
```

**Good** — real error, context at the point it's handled, caller decides once:

```go
var ErrDiscountNotFound = errors.New("discount code not found")

func FindDiscount(order Order) (float64, error) {
    d, ok := discounts[order.Code]
    if !ok {
        return 0, fmt.Errorf("discount for order %d: %w", order.ID, ErrDiscountNotFound)
    }
    return d, nil
}

func total(order Order) (float64, error) {
    d, err := FindDiscount(order)
    if errors.Is(err, ErrDiscountNotFound) {
        d = 0 // no discount is a valid, explicit business outcome
    } else if err != nil {
        return 0, err // any other failure propagates, unmasked
    }
    return order.Subtotal - d, nil
}
```

### Python

**Bad** — `None` mixed with real values, no context, caller must remember to check:

```python
def find_discount(order):
    entry = discounts.get(order.code)
    if entry is None:
        return None  # caller must remember None means "not found"
    return entry.amount

def total(order):
    d = find_discount(order)  # nothing forces a check here
    return order.subtotal - d  # crashes later if d is None
```

**Good** — real exception with context, caught once at a clear boundary:

```python
class DiscountNotFoundError(Exception):
    def __init__(self, order_id):
        super().__init__(f"discount for order {order_id}")

def find_discount(order):
    entry = discounts.get(order.code)
    if entry is None:
        raise DiscountNotFoundError(order.id)
    return entry.amount

def total(order):
    try:
        d = find_discount(order)
    except DiscountNotFoundError:
        d = 0  # no discount is a valid, explicit business outcome
    return order.subtotal - d
```
