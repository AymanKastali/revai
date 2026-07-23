# Functions

## Contents
Rules · Rationalizations · Checklist · Examples

A function is the smallest unit a reader has to hold in their head at once. Every extra thing it
does, every extra argument it takes, and every extra level of nesting it carries is something the
next reader — often you, months later — has to keep loaded in working memory just to trust that a
one-line change is safe. These rules keep that cost small and constant instead of growing with the
codebase.

## Rules

- **Small, and does one thing.** A function should fit in view without scrolling. If a chunk of its
  body can be extracted into a well-named function that isn't just restating what the chunk does,
  the original function was doing more than one thing.
- **One level of abstraction per function.** Never mix high-level orchestration ("validate, then
  save, then notify") with low-level detail (SQL strings, loop arithmetic, string formatting) in the
  same body. Mixed abstraction levels are the signal to extract — pull the low-level step into its
  own named function.
- **Guard clauses over deep nesting.** Return or raise on the exceptional or invalid case first, at
  the top of the function, and keep the main logic unindented after it. This supersedes the old
  "single entry, single exit" dogma — modern style prefers early returns because they remove
  nesting, not because a function must have exactly one `return`.
- **Few arguments — 0 to 2 ideal, 3 is the ceiling.** A parameter list past three means the function
  is coordinating too much, or the arguments belong together as one thing. When several values
  always travel together (a customer's id, email, and tier, say), that's a type waiting to be
  named — refactor the list into a struct or dataclass instead of adding a fourth parameter.
- **No flag/boolean parameters that branch the function's behavior in two.** A boolean argument that
  changes *what* the function does — not just a value it computes with — means two different
  functions are welded together behind one name. Split it into two named functions instead of adding
  a flag.
- **No hidden side effects.** A function's name is a promise to the caller. If `checkPassword()`
  also starts a session, the name lied — the caller had no way to know calling it would mutate
  session state. Either name the function for everything it does, or extract the side effect into
  its own call that the caller invokes explicitly.
- **Command-query separation.** A function either *does* something (a command — causes a side
  effect, returns nothing meaningful) or *answers* something (a query — returns a value, causes no
  observable side effect). Never both. A `pop()` that removes an item and returns it is the classic
  violation; where the distinction matters, prefer separate `peek()` (query) and `remove()`
  (command).
- **Errors over encoded status.** Signal failure through an error return (Go) or an exception
  (Python and most other languages) — never a sentinel value (`-1`, `null`, empty string) mixed in
  with legitimate return values that a caller can forget to check. This rule only covers the
  channel failure travels on; the operational handling — wrapping, logging, retrying — belongs to
  `reference/error-handling.md`.
- **DRY targets duplicated *knowledge*, not duplicated *shape*.** Two blocks that happen to look
  similar but encode unrelated business rules are not a DRY violation — forcing them into one shared
  function couples two things that need to change independently, and the next change to either rule
  ends up threading a flag through the merged function just to keep them apart. Extract only when
  it's the same rule, stated twice, that would have to change in both places together if the rule
  ever changed.

## Rationalizations

| Excuse | Reality |
|---|---|
| "It's just one more parameter." | Every parameter is one more thing every caller must get right, in order; the fourth one is where callers start passing arguments into the wrong slot. |
| "I'll split it later once it's stable." | It never becomes more stable, only more depended-on — splitting it later means splitting it with every caller already watching. |
| "The flag just skips one small step." | A skipped step is a second code path with no name of its own; the reader has to hold both branches in their head to know what the function actually does here. |
| "It's only 40 lines, that's not that long." | If it needs a scroll to read start to finish, it's already asking to be more than one thing. |

## Checklist

- [ ] Every function fits in view and does one thing; no extractable chunk left inline
- [ ] No function mixes high-level orchestration with low-level detail
- [ ] Exceptional/invalid cases return or raise early as guard clauses; the main path is unindented
- [ ] No function takes more than 3 arguments; related values are grouped into a struct/dataclass
- [ ] No boolean parameter branches a function's behavior — split into two named functions instead
- [ ] No function does something its name doesn't say
- [ ] No function is both a command and a query
- [ ] Failure is signaled through an error/exception, never a sentinel value in the return type
- [ ] Duplication removed is the same rule stated twice, not just similar-looking shape

## Examples

### Go

**Bad** — does several things, mixes abstraction levels, nests instead of guarding, and a `notify`
flag hides an email side effect the name never promised:

```go
func ProcessOrder(o Order, notify bool) error {
    if o.CustomerID != "" {
        if len(o.Items) > 0 {
            var total float64
            for _, item := range o.Items { // low-level arithmetic mixed with orchestration
                total += item.Price * float64(item.Qty)
                db.Exec(reserveInventorySQL, item.Qty, item.SKU) // low-level SQL inline
            }
            o.Total = total
            if err := db.Exec(insertOrderSQL, o.ID, o.Total); err != nil {
                return err
            }
            if notify { // boolean flag branches the function's behavior in two
                msg := fmt.Sprintf("Hi %s, your total is $%.2f", o.CustomerName, o.Total)
                smtp.Send(o.CustomerEmail, msg) // hidden side effect ProcessOrder never promised
            }
            return nil
        }
        return errors.New("no items")
    }
    return errors.New("no customer")
}
```

**Good** — guard clauses up front, one abstraction level per function, no flag argument; sending a
confirmation is a separate, honestly named call the caller opts into:

```go
func PlaceOrder(o Order) error {
    if err := validateOrder(o); err != nil { // guard clause: fail fast, main path stays unindented
        return err
    }
    o.Total = calculateTotal(o.Items)
    if err := reserveInventory(o.Items); err != nil {
        return err
    }
    return saveOrder(o) // orchestration only — one level of abstraction
}

func validateOrder(o Order) error {
    if o.CustomerID == "" {
        return errors.New("order: missing customer")
    }
    if len(o.Items) == 0 {
        return errors.New("order: no items")
    }
    return nil
}

func calculateTotal(items []Item) float64 {
    var total float64
    for _, item := range items {
        total += item.Price * float64(item.Qty)
    }
    return total
}

func reserveInventory(items []Item) error {
    for _, item := range items {
        if _, err := db.Exec(reserveInventorySQL, item.Qty, item.SKU); err != nil {
            return err
        }
    }
    return nil
}

func saveOrder(o Order) error {
    _, err := db.Exec(insertOrderSQL, o.ID, o.Total)
    return err
}

// SendOrderConfirmation is its own function — callers opt in explicitly instead of
// PlaceOrder silently branching on a notify flag.
func SendOrderConfirmation(o Order) error {
    return smtp.Send(o.CustomerEmail, formatConfirmation(o))
}

func formatConfirmation(o Order) string {
    return fmt.Sprintf("Hi %s, your total is $%.2f", o.CustomerName, o.Total)
}
```

### Python

**Bad** — same shape: nested conditionals instead of guard clauses, arithmetic and SQL and string
formatting all in one body, and a `notify` flag hiding an email side effect:

```python
def process_order(order, notify=False):
    if order.customer_id:
        if order.items:
            total = 0
            for item in order.items:  # low-level arithmetic mixed with orchestration
                total += item.price * item.qty
                db.execute(reserve_inventory_sql, item.qty, item.sku)  # low-level SQL inline
            order.total = total
            db.execute(insert_order_sql, order.id, order.total)
            if notify:  # boolean flag branches the function's behavior in two
                msg = f"Hi {order.customer_name}, your total is ${order.total:.2f}"
                smtp.send(order.customer_email, msg)  # hidden side effect, not in the name
        else:
            raise ValueError("no items")
    else:
        raise ValueError("no customer")
```

**Good** — guard clauses raise early, each function holds one abstraction level, and confirmation is
a separate call instead of a flag:

```python
def place_order(order: Order) -> None:
    validate_order(order)  # guard clause raises early; main path stays unindented
    order.total = calculate_total(order.items)
    reserve_inventory(order.items)
    save_order(order)  # orchestration only — one level of abstraction


def validate_order(order: Order) -> None:
    if not order.customer_id:
        raise ValueError("order: missing customer")
    if not order.items:
        raise ValueError("order: no items")


def calculate_total(items: list[Item]) -> float:
    return sum(item.price * item.qty for item in items)


def reserve_inventory(items: list[Item]) -> None:
    for item in items:
        db.execute(reserve_inventory_sql, item.qty, item.sku)


def save_order(order: Order) -> None:
    db.execute(insert_order_sql, order.id, order.total)


def send_order_confirmation(order: Order) -> None:
    """Separate, honestly named — callers opt in instead of a notify flag."""
    smtp.send(order.customer_email, format_confirmation(order))


def format_confirmation(order: Order) -> str:
    return f"Hi {order.customer_name}, your total is ${order.total:.2f}"
```
