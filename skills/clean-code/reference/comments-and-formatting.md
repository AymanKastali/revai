# Comments and formatting

## Contents

Rules · Rationalizations · Checklist · Examples

A comment that restates the code costs the reader twice — once to read the noise, once to decide
whether it's safe to ignore — and a stale one costs more, because it actively lies. Inconsistent
formatting has the same effect at a smaller scale: every line that doesn't match its neighbors makes
the reader stop and ask whether the difference means something. These rules keep comments rare and
true, and formatting predictable enough that a diff shows only the change that matters.

## Rules

- **Comments are a last resort, not a first instinct.** Before writing one, ask whether renaming a
  variable or extracting a function would make it unnecessary — if so, do that instead of
  commenting around the problem.
- **Comments explain why, never what.** "Why" is a non-obvious constraint, a workaround for a
  specific bug, or a business rule the code can't say on its own. "What" the code does must be
  obvious from reading it, so restating it in prose is noise.
- **Delete commented-out code immediately — never keep it "just in case."** Git already remembers
  it; nobody comes back to uncomment it, and the next reader can't tell whether it's still relevant
  or abandoned.
- **No mumbling, mandated, or journal comments.** A comment too vague to help ("note: important"),
  one added only because a template requires one per function, or a changelog entry embedded in the
  code are all noise — git log owns history, so delete or replace these.
- **A comment that has drifted from the code is worse than no comment at all** — it actively misleads
  instead of merely failing to help. If you touch code with a stale comment, fix or delete it in the
  same change; never leave it for later.
- **TODOs are trackable, not permanent residents.** A `TODO:` must describe a real, current gap, not
  stand in for a decision nobody made. Where the project has issue tracking, put it there instead of
  leaving it inline indefinitely.
- **Follow the language's standard formatter without exception** — `gofmt`, `black`, or whatever the
  project has configured. Never hand-tune what a formatter would auto-apply, and never introduce a
  second style mid-file.
- **Vertical distance mirrors relationship.** Declare a variable right before its first use, keep
  tightly related lines adjacent with no blank line between them, and separate unrelated concerns
  with a single blank line, not a wall of whitespace.
- **Read top-to-bottom like an article** — high-level intent first, details below, so the reader can
  stop once they have what they need. A file that buries the entry point under helper details forces
  every reader to hunt for where to start.
- **Consistent ordering for structurally similar things.** If one file's imports, methods, or config
  keys follow a pattern — alphabetical, by lifecycle, by layer — every file in the codebase follows
  the same pattern; never let each file invent its own order.

## Rationalizations

| Excuse | Reality |
|---|---|
| "The comment took two seconds to write." | It costs every future reader more than two seconds to read, trust, and eventually discover it's wrong. |
| "I'll delete the commented-out code before merging." | It never happens — the dead block outlives the "later" that was supposed to remove it, and ships. |
| "The formatter's output looks worse here." | Hand-tuning restarts a style debate the formatter was adopted to end. If the rule is wrong, change the config, not this one file. |
| "This function needs a comment, our template says so." | A mandated comment that says nothing is worse than no comment — fix the template, don't pad the code to satisfy it. |

## Checklist

- [ ] Every comment explains why, not what — and a rename/extraction was considered first
- [ ] No commented-out code left in the diff
- [ ] No mumbling, template-mandated, or changelog-style comments
- [ ] No stale comments describing behavior the code no longer has
- [ ] Every `TODO` describes a real, current gap, or lives in the issue tracker instead
- [ ] Code run through the project's standard formatter, no manual overrides
- [ ] Variables declared close to first use; related lines adjacent, unrelated lines separated by one blank line
- [ ] File reads high-level-first, with detail below, not interleaved
- [ ] Structurally similar things (imports, methods, config keys) are ordered the same way throughout

## Examples

### Go

**Bad** — a comment restating the loop, a block of commented-out dead code, and `total` declared far
from where it's used:

```go
func ProcessOrder(o *Order) error {
    var total float64 // declared here but not needed until the loop far below

    log.Printf("processing order %s", o.ID)
    count++
    lastProcessedAt = time.Now()

    if o.Status == "cancelled" {
        return errors.New("order is cancelled")
    }

    // if o.Status == "pending" {
    //     return errors.New("cannot process a pending order")
    // }
    // total = total * 0.9 // old discount logic, replaced in v2

    // loop over the items and add price times quantity to total
    for _, item := range o.Items {
        total += item.Price * float64(item.Qty)
    }

    return charge(o.CustomerID, total)
}
```

**Good** — the dead code and obvious comment are gone; extracting `sumLineItems` both names the
intent and moves the declaration next to its use:

```go
func ProcessOrder(o *Order) error {
    log.Printf("processing order %s", o.ID)
    count++
    lastProcessedAt = time.Now()

    if o.Status == "cancelled" {
        return errors.New("order is cancelled")
    }

    total := sumLineItems(o.Items) // declared where it's used
    return charge(o.CustomerID, total)
}

func sumLineItems(items []Item) float64 {
    var total float64
    for _, item := range items {
        total += item.Price * float64(item.Qty)
    }
    return total
}
```

### Python

**Bad** — a comment restating the loop, a block of commented-out dead code, and `total` declared far
from where it's used:

```python
def process_order(order):
    total = 0.0  # declared here but not needed until the loop far below

    logger.info("processing order %s", order.id)
    increment_counter()
    last_processed_at = time.time()

    if order.status == "cancelled":
        raise ValueError("order is cancelled")

    # if order.status == "pending":
    #     raise ValueError("cannot process a pending order")
    # total = total * 0.9  # old discount logic, replaced in v2

    # loop over items and add price times quantity to total
    for item in order.items:
        total += item.price * item.qty

    return charge(order.customer_id, total)
```

**Good** — the dead code and obvious comment are gone; extracting `sum_line_items` both names the
intent and moves the declaration next to its use:

```python
def process_order(order):
    logger.info("processing order %s", order.id)
    increment_counter()
    last_processed_at = time.time()

    if order.status == "cancelled":
        raise ValueError("order is cancelled")

    total = sum_line_items(order.items)  # declared where it's used
    return charge(order.customer_id, total)


def sum_line_items(items):
    return sum(item.price * item.qty for item in items)
```
