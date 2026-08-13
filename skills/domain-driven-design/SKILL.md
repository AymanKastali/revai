---
name: domain-driven-design
description: The modern domain-driven design standard — subdomain classification, bounded contexts, ubiquitous language, context mapping, aggregates and Vernon's four rules, value objects, domain vs application services, domain vs integration events, hexagonal layering, sagas. Use whenever modelling a business domain, naming or shaping an aggregate, entity, value object, repository, service, event or bounded context, deciding where a business rule lives, or structuring a backend around business capabilities.
---

# Modern domain-driven design

DDD is not a pattern catalogue. It is the practice of letting a *boundary* and a *language* — both
discovered from the business, not invented at the keyboard — decide the shape of the code. The
patterns below only pay off inside a boundary you can name.

So the first rules are about whether to apply the rest at all. Bolting aggregates and repositories
onto a domain nobody analysed produces pattern-driven design: all the ceremony, none of the benefit,
and it is the single most common way DDD fails.

<!-- HARD-RULES:START -->
## Domain-driven design rules

These are not aspirations. Code that violates one is not finished. Rules 1–3 decide whether the
remaining rules apply — check them before you use a single pattern below.

### Applicability — is this DDD work at all?

1. Classify the subdomain before writing code and say which it is: **core** (competitive advantage, complex, changes constantly), **supporting** (necessary, simple, stable), **generic** (a solved problem someone already sells).
2. Match the pattern to the subdomain. Core → a full domain model with aggregates and value objects. Supporting → transaction script or active record. Generic → adopt an existing product or library; do not model it.
3. Never introduce aggregates, repositories, value objects or domain events into a supporting or generic subdomain, a script, glue code, or CRUD with no rules. If asked to "use DDD" where it does not fit, say why and propose the simpler shape.
4. Patterns are not DDD — boundaries and language are. Types named `*Aggregate` and `*Repository` with no analysed boundary behind them are pattern-driven design.
5. Model incrementally. A small model you can name and refine beats a speculative one built for requirements nobody has stated.

### Ubiquitous language

6. Every identifier in a domain layer comes from the domain expert's vocabulary. If a domain expert would not recognise the word, it does not belong there.
7. Technical nouns are banned from the domain model: `Manager`, `Data`, `Info`, `DTO`, `Helper`, `Util`, `Entity`, `Model`, `Object`, `Item`, and bare `Service`.
8. One term, one meaning, within one bounded context. The same word in two contexts may mean two different things — never unify them into a shared type to "remove duplication".
9. The code *is* the model. If the code says something a domain expert would not say, the model is wrong; change the code, not the conversation.
10. When a domain expert corrects a word, rename it in code immediately. A stale name is a stale model.
11. No abbreviations in domain terms: `policyholderAddress`, never `phAddr`.
12. Record a context's terms beside that context's code, not in one company-wide dictionary.

### Bounded contexts

13. A bounded context is a boundary of *meaning* — the widest scope in which every term has exactly one definition. It is not a layer, a namespace, a database, or automatically a service.
14. One team owns a context. Two teams inside one context means the boundary is in the wrong place.
15. A context owns its data exclusively. No other context reads its tables, its schema, or its persistence types — ever. No cross-context join.
16. A context exposes a deliberately designed contract, never its internal model. If a consumer's change forces an aggregate to change, the contract has leaked.
17. A bounded context is not a microservice. A module inside a monolith is often the correct first answer; split for independent deployment, scaling or team autonomy, never for tidiness.
18. Structure follows contexts: one top-level module per context, layers *inside* it. No global `models/`, `entities/`, `services/` or `repositories/` folder spanning contexts.
19. A model is valid only inside its context. Never reuse a domain type across a context boundary — translate at the edge.

### Context mapping and integration

20. Name the relationship between two integrating contexts explicitly and record it: partnership, shared kernel, customer/supplier, conformist, anticorruption layer, open host service, published language, or separate ways.
21. Choose it on two facts: how well the two teams communicate, and how much control you have over the other system.
22. Consuming a model you do not control requires an anticorruption layer that translates into your language at the boundary. No foreign type crosses inward.
23. A shared kernel is the smallest possible overlap, co-owned by every context using it, changed only by agreement. Never put a whole entity in one for convenience.
24. Serve more than one consumer through an open host service with a published language. Version it — changing it breaks somebody.
25. Conformist means deliberately accepting an upstream model as-is, with the cost stated. It is a decision, never a default.
26. Separate ways is legitimate: duplicating a small model often costs less than integrating. Say so out loud instead of integrating by reflex.

### Value objects

27. Any domain concept that is *described* rather than *identified* is a value object: money, quantity, date range, email address, postal address, percentage, identifier.
28. Immutable. Any change returns a new instance.
29. Equality by value, never by reference or identity.
30. Self-validating at construction. A value object that exists is valid — no half-built state, no `validate()` the caller must remember to call.
31. Make illegal states unrepresentable: encode the constraint in the type so an invalid value cannot be constructed at all.
32. No primitive obsession. A `string` email, a floating-point amount, or a bare `uuid` in a domain signature is a defect.
33. Behavior belongs on the value object — `price.add(tax)`, never `addTax(price, tax)`. Arithmetic on a domain quantity performed outside its type is a leak.

### Entities and aggregates

34. An entity has identity and a lifecycle. Its identity is assigned at creation and never changes.
35. An aggregate is a consistency boundary — the objects that must be transactionally consistent with each other, and nothing more.
36. Model **true invariants** inside that boundary: rules the business requires to hold at every instant. A rule allowed to lag belongs outside.
37. Only the aggregate root is reachable from outside. Nothing external holds, queries or mutates an internal member.
38. One aggregate per transaction. If a use case must change two, one of them is eventually consistent — or the boundary is wrong.
39. Design small aggregates. Prefer a single root entity plus value objects; two or three entities is already unusual. A large aggregate is a contention and performance defect.
40. Reference other aggregates **by identity only** — no object reference, no navigation property, no lazy-loaded collection across the boundary.
41. Reach consistency outside the boundary with domain events and eventual consistency, never with a bigger transaction.
42. No public setters. State changes go through methods named for the business intent: `confirm()`, `cancel(reason)` — never `setStatus(value)`.
43. An invariant lives in the aggregate that owns the rule. Enforcing it only in a controller, a service, or a database constraint is a misplaced invariant.
44. An aggregate depends on no persistence, framework, HTTP, ORM, serialization or clock machinery. Pass time and generated identity in as arguments.
45. Never shape an aggregate to serve a query. Build a read model instead.
46. An anemic model — data with accessors, rules living in services — is a defect in a core subdomain. In a supporting subdomain it is the right answer; see rule 2.

### Services, factories, repositories

47. Put behavior on the entity or value object that owns the data. Reach for a service only when the behavior belongs to no single one of them.
48. A domain service is stateless, takes and returns domain objects, and holds domain logic. It **never** touches a repository, database, message bus, or any other IO.
49. An application service orchestrates only: load the aggregate, call one domain method, persist, dispatch events. It holds no business rule and no business conditional.
50. A service that calls a repository is an application service by definition. Domain rules found inside one belong in the model.
51. One repository per aggregate root, and none for anything else.
52. A repository speaks the domain's language, returns whole aggregates, and hides storage completely — no ORM query type, no SQL, no query-builder handle, and no paging or sort parameter shaped by a UI.
53. A repository is a collection abstraction, not a data-access layer: `save`, `findById`, `findOverdueInvoices`. Never `updateStatusById`.
54. Use a factory when construction is complex enough to obscure the model, or when one invariant spans several objects. Construction performs no IO.
55. Reconstituting a stored aggregate is not creating one. It deliberately skips creation-time rules, so keep it separate and explicit.

### Domain events

56. Name a domain event as a past-tense fact in the ubiquitous language: `OrderConfirmed`, `PaymentDeclined`. Never `OrderUpdated` or `OrderChanged`.
57. The aggregate records its own events as part of the state change that caused them. Nothing else invents them.
58. Dispatch events after the transaction commits. A handler never runs inside the transaction that produced the event.
59. An event carries identifiers and the facts that happened — never an entity reference, and never a whole aggregate.
60. Domain events are internal to a context; integration events are its public contract. Translate explicitly — the right integration event is not always the nearest domain event.
61. Publish integration events through a transactional outbox written in the same transaction as the state change. Delivery is at-least-once, so every consumer is idempotent.
62. An event already happened and is immutable. A handler may fail, retry or compensate — it may never veto.

### Architecture and layering

63. Dependency rule: source dependencies point inward only — adapters depend on application, application depends on domain, domain depends on nothing.
64. The domain layer contains no framework, ORM, HTTP, serialization, DI-container or logging-library type. Language primitives and domain types only.
65. Ports are interfaces declared by the inner layers in the domain's own vocabulary. Adapters live outside and implement them.
66. The persistence model may differ from the domain model. Map at the boundary rather than deforming an aggregate to fit a table.
67. Inside a context: `domain/` (aggregates, entities, value objects, events, ports, domain services), `application/` (use cases), `adapters/` (inbound and outbound). Nothing in `domain/` imports from `application/` or `adapters/`.
68. Enforce boundaries mechanically wherever the language allows — package visibility, module exports, import lint rules. A boundary nobody checks is a boundary nobody keeps.

### Consistency and long-running processes

69. Give a cross-aggregate or cross-context workflow an explicit owner: a saga (owns data and business meaning) or a process manager (pure routing). Never an implicit chain of event handlers.
70. Every saga step has a named compensating action. Eventual consistency without compensation is data loss with extra steps.
71. Apply CQRS only where read and write models genuinely diverge. Two shapes for one need is cost with no return.
72. Apply event sourcing only when the business needs history itself as a fact. It is a serious commitment, not a default.
73. A reusable domain predicate belongs in one named specification, not duplicated in a query and again in memory.
74. State the trade-off whenever you choose eventual consistency: what may be stale, for how long, and what the business does about it.
<!-- HARD-RULES:END -->

## Choosing by subdomain — rules 1, 2, 3

The classification is the decision. Getting it wrong is more expensive than any tactical mistake.

| Subdomain | Test | Build it as |
| --- | --- | --- |
| Core | Competitors can't copy it; rules are complex and change often | Full domain model — aggregates, value objects, domain events |
| Supporting | The business needs it, but nobody wins on it; rules are few | Transaction script, or active record over the table |
| Generic | Someone sells this already — auth, billing rails, notifications | Adopt the product or library; write an adapter, not a model |

A pricing engine at an airline is core. The same pricing engine at a hospital is supporting. The
classification belongs to the *business*, not the code.

## Integration patterns — rules 20, 21

Pick along two axes: control over the other system, and quality of communication between the teams.

| Pattern | Use when |
| --- | --- |
| Partnership | Two teams succeed or fail together and coordinate changes continuously |
| Shared kernel | A genuinely shared, tiny model both contexts co-own and change by agreement |
| Customer/supplier | Upstream can accommodate downstream's needs on a schedule |
| Conformist | You have no leverage and accept the upstream model deliberately |
| Anticorruption layer | You do not control the model and it does not fit yours — translate at the edge |
| Open host service | Several consumers need you; publish a stable, versioned contract |
| Published language | The contract itself is the shared artefact — a schema, not your internals |
| Separate ways | Integration costs more than duplication; stay independent on purpose |

## Depth

### Rules 37, 40 — the aggregate boundary, and reference by identity

Bad — `Order` reaches into `Customer` and `Product`, so saving an order can mutate three aggregates,
and loading one drags a graph:

```text
class Order:
    customer      # a whole Customer aggregate
    lines         # each line holds a whole Product aggregate

    function applyDiscount():
        if self.customer.loyaltyTier == "gold":
            self.customer.creditUsed += 1        # mutating another aggregate
            self.total = self.total * 0.9
```

Good — identity across the boundary, and the rule takes what it needs as an argument:

```text
class Order:
    customerId                                   # identity only
    lines                                        # each holds productId + Money + Quantity

    function applyDiscount(discountPolicy):
        self.total = discountPolicy.apply(self.total)
```

The loyalty rule moved to whoever owns loyalty. `Order` now loads, saves and locks alone.

### Rule 38 — one aggregate per transaction

Bad — one transaction, three aggregates, and a lock ordering nobody chose deliberately:

```text
function confirmOrder(orderId):
    transaction:
        order = orderRepository.findById(orderId)
        order.confirm()
        inventory = inventoryRepository.findBySku(order.sku)
        inventory.reserve(order.quantity)
        customer = customerRepository.findById(order.customerId)
        customer.recordPurchase(order.total)
```

Good — one aggregate commits, and the rest follow the fact it published:

```text
function confirmOrder(orderId):
    transaction:
        order = orderRepository.findById(orderId)
        order.confirm()                  # records OrderConfirmed internally
        orderRepository.save(order)
    # after commit: OrderConfirmed reaches inventory and loyalty, each in its own transaction
```

Rule 74 applies: stock may be unreserved for a moment, and the business must have an answer for an
order it cannot fulfil. Say that out loud rather than reaching for a bigger transaction.

### Rules 30, 31, 32 — value objects that cannot be wrong

Bad — primitives, so every caller re-checks, and one of them will forget:

```text
function transfer(fromIban, toIban, amountCents, currency):
    if amountCents <= 0: throw
    if currency not in SUPPORTED: throw
```

Good — the type carries the rule, so the signature is the specification:

```text
class Money:
    private amount, currency
    constructor(amount, currency):
        require(amount > 0, "amount must be positive")
        require(currency in SUPPORTED, "unsupported currency")
    function add(other):
        require(other.currency == self.currency, "currency mismatch")
        return Money(self.amount + other.amount, self.currency)

function transfer(from: Iban, to: Iban, amount: Money)
```

`transfer` has no validation left to do. Everything it receives is already valid.

### Rule 42 — intention-revealing state changes

Bad — the caller drives the state machine, so the rule lives everywhere and nowhere:

```text
order.setStatus("CANCELLED")
order.setCancelledAt(now)
order.setRefundDue(order.total)
```

Good — one business act, guarded by the invariant that governs it:

```text
class Order:
    function cancel(reason, at):
        require(self.status == CONFIRMED, "only a confirmed order can be cancelled")
        self.status = CANCELLED
        self.cancellation = Cancellation(reason, at)
        self.record(OrderCancelled(self.id, reason, at))
```

### Rules 48, 49, 50 — domain service vs application service

Bad — one class that loads, decides and saves, so the business rule is fused to the database:

```text
class PricingService:
    function priceOrder(orderId):
        order = self.orderRepository.findById(orderId)          # IO
        rates = self.taxRepository.findRatesFor(order.region)   # IO
        if order.total > 1000: discount = 0.05                  # domain rule
        else:                  discount = 0
        order.total = order.total * (1 - discount) + rates.vat(order.total)
        self.orderRepository.save(order)                        # IO
```

Good — the rule is a domain service with no IO, and orchestration is the use case's only job:

```text
class PricingPolicy:                       # domain service: pure, domain types in and out
    function priceFor(order, taxRates):
        discount = VolumeDiscount.forTotal(order.total)
        return order.total.minus(discount).plus(taxRates.vatOn(order.total))

class PriceOrder:                          # application service: orchestration only
    function execute(command):
        order = self.orders.findById(command.orderId)
        rates = self.taxRates.forRegion(order.region)
        order.applyPrice(self.pricingPolicy.priceFor(order, rates))
        self.orders.save(order)
```

`PricingPolicy` is testable with no database and readable by a domain expert. `PriceOrder` holds no
rule you could get wrong.

### Rules 52, 53 — the repository that leaks

Bad — storage and a UI's paging leak through the abstraction, so the domain now depends on both:

```text
interface OrderRepository:
    function query() -> QueryBuilder                  # storage language escapes
    function findAll(page, pageSize, sortColumn)      # a screen's concern
    function updateStatusById(id, status)             # bypasses the aggregate
```

Good — the domain's own vocabulary, whole aggregates, storage invisible:

```text
interface OrderRepository:
    function findById(orderId) -> Order
    function findOverdueAsOf(date) -> [Order]
    function save(order)
```

Paging a list of orders for a screen is a read-model query, not a repository method (rule 45).

### Rules 60, 61 — domain event, integration event, outbox

Bad — the internal event *is* the contract, so every consumer is now coupled to your model, and a
crash between commit and publish loses the message:

```text
order.confirm()
transaction: orderRepository.save(order)
messageBus.publish(OrderConfirmed(order))     # internal event, whole aggregate, outside the tx
```

Good — translate at the boundary, and commit the intent to publish with the state change:

```text
transaction:
    order.confirm()                                    # records the domain event internally
    orderRepository.save(order)
    outbox.add(OrderConfirmedV1(order.id, order.customerId, order.total, order.confirmedAt))
# a separate publisher drains the outbox; consumers are idempotent on order.id
```

`OrderConfirmedV1` is a published language (rule 24) — versioned, flat, and free of your internals.

### Rules 18, 67 — structure follows the boundary

Bad — layers on top, contexts nowhere, so every feature is spread across four folders and no
boundary can be enforced:

```text
src/
  models/          Order, Invoice, Shipment, Customer, User
  services/        OrderService, InvoiceService, ShipmentService
  repositories/
  controllers/
```

Good — contexts on top, layers inside, so a boundary violation is an import you can lint:

```text
src/
  ordering/
    domain/          Order, OrderLine, Money, OrderConfirmed, OrderRepository (port)
    application/     ConfirmOrder, CancelOrder
    adapters/        http/, persistence/, messaging/
  shipping/
    domain/          Shipment, TrackingNumber, ShipmentDelivered
    application/     DispatchShipment
    adapters/
  billing/
    ...
```

`Order` in `ordering` and `Order` in `shipping` are allowed to be different types with different
fields. That is rule 8 working, not duplication.

## Anti-pattern scan list

A review scan list, not rules. Work down it when auditing a domain model.

| Code | Anti-pattern |
| --- | --- |
| S1 | Tactical patterns applied with no subdomain classification stated |
| S2 | Full domain model built for a supporting or generic subdomain |
| S3 | Bounded context split to mirror a database, a layer, or an org chart |
| S4 | Two contexts sharing a database, a schema, or a persistence type |
| S5 | A domain type reused verbatim across a context boundary |
| S6 | Foreign model consumed with no anticorruption layer |
| S7 | Internal aggregate exposed directly as an API or event contract |
| S8 | Integration relationship never named or recorded |
| L1 | Domain identifier no domain expert would recognise |
| L2 | Technical noun in the domain model — `Manager`, `Data`, `DTO`, `Helper` |
| L3 | One word meaning two things inside a single context |
| L4 | Two words for one concept inside a single context |
| L5 | Abbreviated domain term |
| V1 | Primitive where a value object belongs — money, email, quantity, id |
| V2 | Mutable value object, or one with identity |
| V3 | Value object constructible in an invalid state |
| V4 | Equality by reference where value equality is meant |
| V5 | Domain arithmetic performed outside the type that owns it |
| A1 | Anemic aggregate — accessors only, rules living elsewhere |
| A2 | Public setter, or a `setStatus`-style state change |
| A3 | Object reference or navigation property across an aggregate boundary |
| A4 | More than one aggregate mutated in one transaction |
| A5 | Aggregate large enough to be a contention point |
| A6 | Invariant enforced outside the aggregate that owns it |
| A7 | Framework, ORM, clock or IO dependency inside an aggregate |
| A8 | Aggregate shaped to satisfy a query |
| A9 | Mutable identity, or identity assigned after creation |
| R1 | Repository for something that is not an aggregate root |
| R2 | Storage language leaking through a repository interface |
| R3 | UI paging or sorting in a repository signature |
| R4 | Repository method that mutates state field-by-field |
| R5 | Domain service performing IO or calling a repository |
| R6 | Business rule inside an application service |
| R7 | Factory performing IO, or construction logic hidden in a constructor |
| E1 | Event not named as a past-tense fact, or named `*Updated` |
| E2 | Event carrying an entity reference or a whole aggregate |
| E3 | Handler running inside the producing transaction |
| E4 | Domain event published as the public contract |
| E5 | Integration event published without an outbox |
| E6 | Non-idempotent consumer of an at-least-once event |
| E7 | Handler that vetoes or rejects an event that already happened |
| H1 | Inward dependency violated — domain importing application or adapters |
| H2 | Framework, ORM or HTTP type in the domain layer |
| H3 | Port declared outside the layer that needs it |
| H4 | Global `models/` or `services/` folder spanning contexts |
| H5 | Aggregate deformed to match a table instead of mapped at the boundary |
| P1 | Multi-step workflow with no explicit saga or process manager |
| P2 | Saga step with no compensating action |
| P3 | CQRS or event sourcing adopted without a stated need |
| P4 | Duplicated domain predicate that should be one specification |
| P5 | Eventual consistency chosen without stating the staleness trade-off |
