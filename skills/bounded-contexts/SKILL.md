---
name: bounded-contexts
description: Use when drawing a domain boundary — naming a module/service/package, starting a new area of the system, or integrating two subsystems that use the same words differently. Applies strategic DDD: ubiquitous language, one model per bounded context, subdomain classification (core/supporting/generic), and context-mapping patterns (partnership, customer–supplier, conformist, anti-corruption layer, open-host/published language). Do this before tactical modelling — reach for domain-modeling once the boundary and language are set.
---

# Bounded contexts (strategic DDD)

Strategy comes before tactics. Before modelling types, decide **where the boundary is** and **what
the words mean inside it**. Teams that jump straight to aggregates and value objects are "building
without a map." This skill is the map; `domain-modeling` is what you build once it's drawn.

The central idea: there is no single correct model of the whole business. A model is only valid
*within a boundary*. "Modern" DDD treats this as the primary decision — align modules, packages,
services, and teams to these boundaries.

## Rules

- **One ubiquitous language per context.** Inside a boundary, one word means exactly one thing, and
  code uses that word (this is what `naming-and-structure` then enforces at the symbol level). The
  same word legitimately means different things in different contexts — that's not a bug to unify.
- **`Customer` in Billing ≠ `Customer` in Support.** Don't build one enterprise-wide `Customer`
  class to serve every context. A shared "god model" couples everything and pleases no one. Let each
  context keep the model it needs.
- **A bounded context is where one model and one language hold.** Make the boundary explicit — a
  package, module, or service. One team should own a context; one context shouldn't be split across
  teams that must coordinate on every change (Conway's law).
- **Classify subdomains, then spend effort accordingly:**
  - **Core** — your differentiator. Invest the best modelling here.
  - **Supporting** — needed but not special. Model it simply.
  - **Generic** — solved elsewhere (auth, payments, email). Buy/adopt; don't lovingly hand-model it.
- **Choose the integration (context map) deliberately** when two contexts meet:
  - **Partnership** — two teams succeed or fail together; coordinate closely.
  - **Customer–Supplier** — downstream's needs are on the upstream's backlog.
  - **Conformist** — you adopt the upstream's model as-is (no leverage to change it).
  - **Anti-corruption layer (ACL)** — you translate the other model into *your* language at the
    boundary so its concepts don't leak into your core. The default when integrating a legacy or
    third-party system you don't want to conform to.
  - **Open-host service / published language** — a stable, documented contract (often the API from
    `api-design`) for many consumers, so you don't build a bespoke integration per consumer.
- **Protect the core from foreign models.** Upstream concepts cross the boundary only through a
  translation layer, never raw into your aggregates.

## Checklist

- [ ] The boundary is explicit (a package/module/service), not implied
- [ ] One model and one language hold inside it; terms aren't overloaded within the context
- [ ] Shared terms across contexts are translated, not force-merged into one model
- [ ] Each subdomain is classified core/supporting/generic and effort matches
- [ ] The integration pattern with each neighbour is a deliberate choice, named
- [ ] Foreign/legacy models enter only through an anti-corruption layer
- [ ] One team owns each context

## Examples

### Same word, two contexts

`Account` in **Identity** is login credentials and MFA. `Account` in **Billing** is a balance and a
payment method. Forcing one `Account` type to serve both yields a class that's half-authentication,
half-ledger and coherent as neither. Keep two models; translate at the seam.

### Anti-corruption layer — translate a foreign model into your language

**Bad** — the vendor's shape leaks straight into the domain; every renamed field breaks your core:
```python
def price_order(order, vendor_resp):        # vendor_resp is a raw third-party dict
    order.total = vendor_resp["amt_due_usd_x100"] / 100   # vendor's vocabulary in the domain
    order.tax = vendor_resp["txn_tax_f"]                  # core now speaks "vendor"
```

**Good** — an ACL maps the foreign model to your value objects at the boundary; the core stays clean:
```python
# anti-corruption layer: the ONLY place that knows the vendor's vocabulary
def to_quote(vendor_resp: dict) -> Quote:
    return Quote(
        total=Money(cents=vendor_resp["amt_due_usd_x100"], currency=Currency.USD),
        tax=Money(cents=vendor_resp["txn_tax_f"], currency=Currency.USD),
    )

def price_order(order: Order, quote: Quote) -> None:  # core speaks only your language
    order.apply_quote(quote)
```
```go
// anti-corruption layer: isolates the vendor's vocabulary from the domain.
func toQuote(v vendorPriceResponse) (Quote, error) {
    total, err := NewMoney(v.AmtDueUSDx100, USD)
    if err != nil { return Quote{}, err }
    tax, err := NewMoney(v.TxnTaxF, USD)
    if err != nil { return Quote{}, err }
    return Quote{Total: total, Tax: tax}, nil // your language crosses the boundary, not theirs
}
```
