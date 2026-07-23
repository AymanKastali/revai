# Classes and cohesion

## Contents

Single responsibility for classes · cohesion (fields vs. methods) · small classes over god objects ·
open/closed · dependency inversion · minimal public surface · examples (a split-up god class in
Go and Python).

A class that mixes unrelated jobs, hoards fields most of its methods never touch, or reaches
straight into a concrete dependency costs you twice: every unrelated change risks breaking the
others hiding in the same file, and every test has to drag in dependencies it doesn't need. These
rules keep a class doing one job, needing only what it uses, and depending on what it needs rather
than how that need happens to be implemented today.

This is class-shape, at the general code level — it applies whether the class is a domain concept
or plain infrastructure. For function-level rules (size, arguments, side effects), see
`reference/functions.md`. For the split between objects and data structures and the Law of Demeter,
see `reference/objects-and-data-structures.md`.

## Rules

- **One reason to change, same as a function but one level up.** If describing a class's job needs
  "and," or two unrelated forces (a UI change vs. a business-rule change) would both require editing
  it, split it. A class name like `UserManager` or `OrderService` is usually the tell — "manager" and
  "service" are job titles for a class doing several jobs at once.
- **High cohesion: a class's methods should use most of its fields, most of the time.** A class where
  each method only touches a small, disjoint subset of the fields is really several classes sharing
  an address. Split along the fields each method actually uses — the boundary is usually obvious once
  you look at which fields cluster together.
- **Prefer many small, focused classes over a few large ones.** Total complexity doesn't shrink by
  hiding it inside one big class — it just becomes harder to find, name, and test. A codebase of
  small, well-named classes is easier to navigate than a handful of god-objects, exactly like small
  functions vs. one giant one.
- **Open for extension, closed for modification.** New behavior should be addable by adding new code
  — a new implementation behind an existing interface, a new case in an already-extensible seam —
  without editing and re-verifying code that already works and shipped.
- **Depend on abstractions, not on concrete details (Dependency Inversion).** A class that needs a
  capability (send an email, persist a record) should depend on an interface/port it defines or that
  already exists, not on a concrete, swappable implementation. Replacing the implementation should
  touch one binding, not every caller.
- **A class's public surface is a promise — keep it minimal.** Expose only what callers genuinely
  need; keep helper methods and internal state unexported/private. A wide public surface means more
  that can be depended on, and more that can never be safely changed later.

## Rationalizations

| Excuse | Reality |
|---|---|
| "It's easier to just add one more method to this class." | Easier to write, harder to read forever after — the next person has to hold the whole class's unrelated concerns in their head to change any one of them. |
| "Splitting this into two classes is over-engineering for now." | A class that already mixes two jobs isn't a future risk, it's a present one — the split is cheapest today, before more code depends on the tangled version. |
| "It's all `UserService` stuff, it belongs together." | Sharing a noun isn't sharing a responsibility. Validation, persistence, and notification all mention "user" and still change for different reasons. |
| "This interface is unnecessary ceremony for one implementation." | The interface isn't for today's one implementation — it's what keeps tomorrow's second implementation (or test double) from touching every caller. |

## Checklist

- [ ] The class's job can be described in one sentence, without "and"
- [ ] Most methods use most of the fields — no disjoint sub-clusters sharing one class
- [ ] No god-object doing what several small, named classes should each do
- [ ] New behavior can be added without editing and re-verifying existing, shipped code
- [ ] Dependencies on volatile details (network clients, drivers, SDKs) go through an interface/port
- [ ] Nothing is exported/public unless a caller genuinely needs it

## Examples

### Go

**Bad** — one class, three unrelated jobs; each method touches only its own field, and the
notification method is wired straight to a concrete client:

```go
type UserManager struct {
    minAge     int          // used only by the validation method
    db         *sql.DB      // used only by the persistence method
    smtpClient *smtp.Client // used only by the notification method — concrete, not an interface
}

func (m *UserManager) ValidateAge(age int) error {
    if age < m.minAge {
        return errors.New("user too young")
    }
    return nil
}

func (m *UserManager) SaveUser(u User) error {
    _, err := m.db.Exec("INSERT INTO users (name, email) VALUES ($1, $2)", u.Name, u.Email)
    return err
}

func (m *UserManager) SendWelcomeEmail(u User) error {
    return m.smtpClient.Send(u.Email, "Welcome!", "...") // swapping providers means editing this class
}
```

**Good** — split along the fields each method actually uses; the service depends on interfaces, not
concrete clients:

```go
type AgeValidator struct{ minAge int }

func (v AgeValidator) Validate(age int) error {
    if age < v.minAge {
        return errors.New("user too young")
    }
    return nil
}

type UserRepository interface { Save(u User) error } // port — persistence detail lives behind it

type sqlUserRepository struct{ db *sql.DB }

func (r *sqlUserRepository) Save(u User) error {
    _, err := r.db.Exec("INSERT INTO users (name, email) VALUES ($1, $2)", u.Name, u.Email)
    return err
}

type Notifier interface { SendWelcome(u User) error } // port — a new channel plugs in, no edits here

type smtpNotifier struct{ client *smtp.Client }

func (n *smtpNotifier) SendWelcome(u User) error {
    return n.client.Send(u.Email, "Welcome!", "...")
}

// UserService orchestrates the three collaborators through their ports — none of them concrete.
type UserService struct {
    validator AgeValidator
    repo      UserRepository
    notifier  Notifier
}

func (s *UserService) Register(u User) error {
    if err := s.validator.Validate(u.Age); err != nil {
        return err
    }
    if err := s.repo.Save(u); err != nil {
        return err
    }
    return s.notifier.SendWelcome(u)
}
```

### Python

**Bad** — validation, pricing, persistence, and notification bundled into one service, each method
reaching for only its own field:

```python
class OrderService:
    def __init__(self, db_connection, smtp_client, tax_rate):
        self.db_connection = db_connection  # used only by save()
        self.smtp_client = smtp_client      # used only by notify_customer() — concrete SMTP client
        self.tax_rate = tax_rate            # used only by calculate_total()

    def validate(self, order):
        if not order.items:
            raise ValueError("order has no items")

    def calculate_total(self, order):
        return sum(i.price for i in order.items) * (1 + self.tax_rate)

    def save(self, order):
        self.db_connection.execute("INSERT INTO orders (...) VALUES (...)", order.id)

    def notify_customer(self, order):
        self.smtp_client.send(order.customer_email, "Order placed", "...")  # locked to SMTP
```

**Good** — one job per class, wired through ports the `OrderService` depends on instead of concrete
clients:

```python
from typing import Protocol

class OrderValidator:
    def validate(self, order: Order) -> None:
        if not order.items:
            raise ValueError("order has no items")

class PriceCalculator:
    def __init__(self, tax_rate: float):
        self._tax_rate = tax_rate  # not exposed; only total() needs it

    def total(self, order: Order) -> float:
        return sum(i.price for i in order.items) * (1 + self._tax_rate)

class OrderRepository(Protocol):        # port — swap the implementation, callers don't change
    def save(self, order: Order) -> None: ...

class Notifier(Protocol):               # port — email today, SMS tomorrow, no edits to OrderService
    def send(self, to: str, subject: str, body: str) -> None: ...

class OrderService:
    def __init__(
        self,
        validator: OrderValidator,
        pricer: PriceCalculator,
        repo: OrderRepository,
        notifier: Notifier,
    ):
        self._validator = validator
        self._pricer = pricer
        self._repo = repo        # depends on the interface, not smtplib/psycopg2 directly
        self._notifier = notifier

    def place(self, order: Order) -> None:
        self._validator.validate(order)
        order.total = self._pricer.total(order)
        self._repo.save(order)
        self._notifier.send(order.customer_email, "Order placed", "...")
```

For a *domain* concept specifically — an entity carrying business invariants, not plain
infrastructure — this same cohesion judgment sharpens further: `domain-driven-design`'s
`reference/tactical-patterns.md` covers aggregates, consistency boundaries, and invariant placement.
The rules here are the general case underneath that: they apply to every class, whether or not it
models the domain.
