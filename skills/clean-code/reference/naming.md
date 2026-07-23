# Naming

Names are the primary interface between the code and the reader's mind. A bad name costs every
person who reads it, forever; a good one carries meaning without a comment.

## Rules

- **Reveal intent.** A reader must know what a name is and why it exists without a comment.
  `activeUsers`, not `list2`; `retryBudget`, not `n`.
- **Functions are verb phrases** — `fetchOrder`, `calculate_total`, `PlaceOrder`. A function named
  like a noun hides what it does.
- **Booleans read as predicates** — `isReady`, `hasItems`, `should_retry`. Never a bare noun that
  forces the reader to guess the polarity.
- **No cryptic abbreviations or single letters**, outside tiny idiomatic scopes (a loop `i`, Go's
  `err`, a 2-line lambda). Ban `data`, `info`, `tmp`, `obj`, `mgr`, `doStuff`, `handle2`.
- **One term per concept.** If it's a `user`, it's a `user` everywhere — don't drift between `user`,
  `account`, and `customer` for the same thing. Conversely, one term must mean one concept — don't
  reuse `manager` for both a queue drainer and a config loader.
- **Name by role, not by type.** `recipients`, not `stringList`; `pendingOrders`, not `orderArr`.
- **Distinguishable, not just different.** `getUser`/`getUserInfo` reads as the same thing with a
  typo-sized difference; the reader can't tell which to call. Names in the same scope must differ in
  *meaning*, not just in a suffix.
- **Searchable over single-letter, for anything with a lifespan.** A constant used across a file
  deserves a name you can grep for (`MAX_RETRY_ATTEMPTS`, not `5` inline); a loop index scoped to
  three lines doesn't.
- **No encoded type or scope prefixes** (`strName`, `m_count`, `iTotal`). Modern type systems and
  IDEs make Hungarian notation and member prefixes pure noise — the type is a hover away.
- **Follow the language's idiom.** Go: `MixedCaps`, exported = capitalized, short receiver names.
  Python: `snake_case` for functions/vars, `PascalCase` for classes, no type prefixes.

## Rationalizations

| Excuse | Reality |
|---|---|
| "The name is obvious from context." | Obvious to you, right now, with the whole problem loaded in your head. Not obvious to the next reader six months from now with none of it. |
| "It's a small function, doesn't matter." | Small functions compose into big systems; a sloppy name at the leaf still costs every caller that reads it. |
| "Everyone on the team knows what this means." | Today's team. Not the next hire, not you after six other projects, not the reviewer of a change eight months from now. |
| "Renaming everywhere is too much churn." | An editor renames every reference in seconds; a wrong name misleads every reader for the file's whole life. |

## Red flags

- A name that needs a comment to explain what it actually means.
- A variable named after its type or shape, not its role: `data`, `temp`, `obj`, `list1`, `arr`.
- Two names in the same scope that differ only by a number or a thin suffix (`user`, `user2`,
  `userInfo`).
- A boolean parameter or field with no predicate name, so every call site is ambiguous
  (`create(true)` — true what?).

## Checklist

- [ ] Every name reveals intent without needing a comment
- [ ] Functions are verb phrases; booleans are predicates
- [ ] No cryptic abbreviations, encoded prefixes, or type-named variables, outside tiny scopes
- [ ] One consistent term per concept; no concept borrows another's term
- [ ] Names in the same scope are distinguishable by meaning, not just by a suffix

## Examples

### Go

**Bad** — cryptic, type-named, no predicate:

```go
func proc(d []*U, f bool) []*U {
    var r []*U
    for _, u := range d {
        if f && !u.Active {
            continue
        }
        r = append(r, u)
    }
    return r
}
```

**Good** — intention-revealing names throughout:

```go
// filterActiveUsers returns only active users unless includeInactive is set.
func filterActiveUsers(users []*User, includeInactive bool) []*User {
    filtered := make([]*User, 0, len(users))
    for _, u := range users {
        if !includeInactive && !u.Active {
            continue
        }
        filtered = append(filtered, u)
    }
    return filtered
}
```

### Python

**Bad** — a type-named variable and a non-predicate flag:

```python
def get(lst, flag):
    obj = [x for x in lst if x.active or flag]
    return obj
```

**Good**:

```python
def filter_active_orders(orders: list[Order], include_cancelled: bool) -> list[Order]:
    return [o for o in orders if o.active or include_cancelled]
```
