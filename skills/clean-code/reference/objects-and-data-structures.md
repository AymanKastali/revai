# Objects and data structures

Blurring objects and data structures produces types that are hard to change from both directions —
adding a new operation *and* adding a new field are both painful — and chains of getters that break
the moment any link in them changes shape. Picking one shape per type, and reaching only your
immediate collaborators, prevents that cost.

## Contents

Rules, rationalizations, checklist, then Go/Python examples of a train wreck and a clean split.

## Rules

- **Objects hide data behind behavior; data structures expose data with no meaningful behavior —
  pick one per type, never both.** An object exposes methods that express what it *does* and hides
  its internal representation, so the internals can change without touching a single caller. A data
  structure (a struct, a DTO, a record) exposes its fields plainly and carries little to no logic. A
  type that tries to be both — encapsulated fields plus a pile of getters/setters that expose
  everything anyway, with a few "real" methods bolted on — is the worst of both: as hard to extend
  with new behavior as a pure data structure, and as hard to add new data to as a pure object (see
  `reference/classes-and-cohesion.md` for what that split does to responsibility).
- **At a boundary — an API request/response body, a database row, a message payload — a plain data
  structure is correct and expected.** Don't force behavior onto a DTO; its job is to carry data
  across a seam, not to enforce rules. Rules belong to the domain type the DTO gets mapped into and
  out of, one layer in.
- **Obey the Law of Demeter: talk to your immediate collaborators, not strangers reached through
  them.** A method may call methods on itself, its own fields, an object it created, or a parameter
  passed to it — not an object returned by any of those. Reaching two or more levels deep
  (`a.getB().getC().doThing()`, a "train wreck") couples the caller to the entire chain's internal
  structure.
- **Ask the object to do the thing; don't ask it for its innards to do the thing yourself.** If
  you're pulling a value out of an object just to compute something with it, that computation
  belongs on the object (or a function next to it), not at the call site. This is "tell, don't ask."
- **Never expose a mutable internal collection or field directly.** Returning a live reference to
  internal state lets any caller mutate it behind the object's back, silently breaking whatever
  invariant the object was meant to hold. Return a copy, an immutable view, or a narrow accessor
  instead.

## Rationalizations

| Excuse | Reality |
|---|---|
| "It's just one more getter." | Each getter is a hole in the encapsulation. Enough of them and the type is a data structure wearing a class's clothes. |
| "Chaining three calls together is more concise." | Concise for the writer, but it couples the caller to every type in the chain — one shape change anywhere breaks every train-wreck call site. |
| "I'll add a setter so tests can set this up directly." | A setter that exists only for tests is a public mutation hole every other caller can use too. |
| "It's just a DTO, one method won't hurt." | One method invites the next. The DTO slowly grows into a hybrid nobody can classify as object or data. |

## Checklist

- [ ] Each type is clearly either a behavior-hiding object or a plain data structure, not both
- [ ] Boundary types (request/response, row, message) stay plain data; domain rules live one layer in
- [ ] No call site reaches past its immediate collaborator (no `a.getB().getC()` train wrecks)
- [ ] Call sites tell objects what to do, rather than pulling data out to compute it themselves
- [ ] No method returns a live reference to a mutable internal collection or field

## Examples

### Go

**Bad** — a Law-of-Demeter train wreck plus a hybrid type (encapsulated fields, but getters/setters
that expose everything anyway, with an unrelated behavior method bolted on):

```go
type Address struct {
    city string
}

func (a *Address) GetCity() string  { return a.city }
func (a *Address) SetCity(c string) { a.city = c }

type Customer struct {
    address *Address
}

func (c *Customer) GetAddress() *Address { return c.address }

type Order struct {
    customer *Customer
    total    float64
}

func (o *Order) GetCustomer() *Customer { return o.customer }
func (o *Order) GetTotal() float64      { return o.total }
func (o *Order) SetTotal(t float64)     { o.total = t }

// Unrelated behavior bolted onto an otherwise anemic, all-exposed type.
func (o *Order) SendConfirmationEmail() error { return nil }

func isLocalDelivery(o *Order) bool {
    // Train wreck: reaches through Order -> Customer -> Address.
    return o.GetCustomer().GetAddress().GetCity() == "Springfield"
}
```

**Good** — a plain DTO at the boundary, and a domain object that hides its internals behind
tell-don't-ask behavior:

```go
// OrderDTO is a boundary data structure: plain fields, no behavior.
type OrderDTO struct {
    CustomerCity string
    Total        float64
}

// Order is a domain object: internals hidden, behavior exposed instead.
type Order struct {
    customerCity string
    total        float64
}

func NewOrder(customerCity string, total float64) *Order {
    return &Order{customerCity: customerCity, total: total}
}

// IsLocalDelivery answers the question itself; callers never reach inside.
func (o *Order) IsLocalDelivery() bool {
    return o.customerCity == "Springfield"
}

// Caller: tell the object what it needs to know, don't ask for its guts.
if order.IsLocalDelivery() {
    scheduleLocalCourier(order)
}
```

### Python

**Bad** — the same train wreck and hybrid type:

```python
class Address:
    def __init__(self, city):
        self._city = city

    def get_city(self):
        return self._city

    def set_city(self, city):
        self._city = city


class Customer:
    def __init__(self, address):
        self._address = address

    def get_address(self):
        return self._address


class Order:
    def __init__(self, customer, total):
        self._customer = customer
        self._total = total

    def get_customer(self):
        return self._customer

    def get_total(self):
        return self._total

    def set_total(self, total):
        self._total = total

    def send_confirmation_email(self):  # unrelated behavior bolted on
        ...


def is_local_delivery(order):
    # Train wreck: reaches through Order -> Customer -> Address.
    return order.get_customer().get_address().get_city() == "Springfield"
```

**Good** — a plain DTO at the boundary, and a domain object hiding its internals:

```python
from dataclasses import dataclass


@dataclass
class OrderDTO:  # boundary data structure: plain fields, no behavior
    customer_city: str
    total: float


class Order:  # domain object: internals hidden, behavior exposed instead
    def __init__(self, customer_city: str, total: float):
        self._customer_city = customer_city
        self._total = total

    def is_local_delivery(self) -> bool:  # answers the question itself
        return self._customer_city == "Springfield"


# Caller: tell the object what it needs to know, don't ask for its guts.
if order.is_local_delivery():
    schedule_local_courier(order)
```
