---
name: modular-monolith
description: Applies the modular monolith standard — partition one deployable into modules named for business capabilities, each owning its storage, exposing one entry point, and depending on the others only through declared contracts, with every boundary enforced by a build check rather than by intention. Use when starting an application or service, adding or naming a module, deciding where a feature's code and tables belong, wiring modules into a host, choosing between a direct call and an event across a boundary, sharing data or code between modules, enforcing boundaries in CI, or deciding whether to merge, split or extract a module into a separate deployable.
---

# Modular monolith

One deployable, many modules, boundaries that a machine enforces. It is the default because the
alternative charges its premium — network calls, partial failure, distributed transactions, versioned
wire contracts, per-service operations — from the first commit, and refunds it only for a driver you
can name. And because the design work is the same either way: if you cannot draw the boundaries
inside one process, drawing them across a network will not help.

The failure mode is not choosing this architecture. It is claiming it. A codebase with modules in the
directory names, a join across two of them in the reporting query, and a shared `common` package
holding half the business rules is a monolith with extra folders. Every rule below exists because that
outcome arrives by accident, one convenient import at a time, unless something fails the build.

Scope: this standard governs **how one deployable is partitioned and how the parts interact** — the
module graph, the public surface, storage ownership, in-process integration, wiring, enforcement, and
the seam that a later extraction would use. What is *inside* a module belongs elsewhere:
`domain-driven-design` owns the boundary's discovery, the domain model and the layering;
`clean-code` owns how the code reads; `best-practices` owns what it is built with. Where those mandate
a property, the rules here name its module-level form.

## Contents

- **Modular monolith rules** — 95 rules in twelve groups: applicability, choosing the shape, modules,
  the module graph, the public surface, storage ownership, integration between modules, transactions
  and consistency, composition and configuration, enforcement, operating and testing, and evolution
  and extraction. Rules 1–3 gate the standard on the system being one deployable with more than one
  capability, and rule 2 gates each group on the concern in its heading. Injected every session, so
  they may already be in your context.
- **One module, two modules, or two deployables** — the signal-to-answer table behind rules 4–6 and
  14–16. Read it before drawing or moving a boundary.
- **Integration styles across a boundary** — the four ways one module can reach another's data or
  behaviour, and what each costs.
- **The coupling shortcut and the modular answer** — 21 shortcuts that each look local and harmless,
  with what they cost and what to do instead. Read this before taking one.
- **Depth** — worked bad/good pairs for the rules that get misread without one: a layout that hides
  internals, one module reading another's data, a write that touches two modules, and the check that
  makes the boundary real.
- **Anti-pattern scan list** — 82 rows, coded by group (`A` architecture choice, `B` boundaries,
  `G` graph, `S` surface, `D` data, `I` integration, `T` transactions, `W` wiring, `E` enforcement,
  `O` operating and testing, `X` evolution), to work down while reviewing.

<!-- HARD-RULES:START -->
## Modular monolith rules

These are not aspirations. A system that violates one is not modular, whatever its directories are
called. Rules 1–3 decide whether the rest apply and where their edges are.

Rule 1 gates the standard on the system being one deployable holding more than one business
capability. Rule 2 gates each group on the concern named in its heading. Rule 3 draws the edge
against `domain-driven-design`, which states several of these properties for a bounded context; the
rules below are the module's physical form of them and the mechanism that enforces it.

### Rules 1-3 — what applies

1. This standard governs a system built as **one deployable unit that holds more than one business capability**. On a single-purpose service, a library, a CLI or a script, say so in one line and skip the rest.
2. Each group below names its concern in its heading; only groups whose concern the change touches are in play. The module, surface and storage-ownership rules always apply to a change that adds a file, a table or a dependency.
3. This standard owns what crosses a module boundary. What is inside one — its layering, aggregates and domain model — belongs to `domain-driven-design`, which also owns how the boundary is discovered in the first place.

### Choosing the shape — applies when the system is being started, split or merged

4. Default to one deployable. A separate one is justified only by a driver the monolith cannot answer: a workload that must scale on a different resource, a different runtime or language, a hard isolation, tenancy or compliance boundary, or a release cadence the organisation genuinely forces. Name the driver in writing.
5. "We might need to scale one day", "microservices are the standard" and team preference are not drivers. The premium is paid from the first day and only one of rule 4's drivers refunds it.
6. Services that must be deployed together, share storage, or call each other synchronously to serve one request are a distributed monolith — the whole premium, none of the benefit. If a split would produce that, do not split.
7. Modularity is the deliverable; the single deployable is only the consequence. A monolith with no internal boundaries is not this architecture, it is the thing this architecture exists to prevent.
8. Draw every boundary as though the module were going to be extracted, and extract none of them until rule 4 applies.
9. Record each module's boundary and the reason for it in a decision record beside the code, so the next person moves it deliberately instead of discovering it.

### Modules — always applies

10. A module is a **business capability**, named in the domain's own language — `billing`, `shipping`, `catalogue`. Never a technical layer, never a bare entity, never a team's name or a project code.
11. A module's root holds everything the module needs — its interface, application, domain and persistence code, its migrations, its configuration and its tests. `domain-driven-design` puts the layers inside the module; this standard makes that root the unit of ownership, enforcement and deletion.
12. A module maps to exactly one bounded context where one has been identified, and where no context analysis exists it is still a capability rather than a layer. Two modules that turned out to share a context were never two capabilities.
13. Every file belongs to exactly one module. There is no `misc`, `common`, `core`, `shared` or `util` module holding whatever did not fit — generic technical infrastructure earns a module only on the terms of rules 27 and 28.
14. Two modules that always change together are one module. Merge them instead of maintaining a contract between them.
15. Two parts of one module that never change together, answer to different consistency needs, or have different owners are two modules. Split them.
16. If two things must be consistent within one transaction, they belong in the same module. That requirement decides the boundary and nothing else overrides it.
17. Every module has exactly one owning person or team, recorded in the repository's ownership file. A module nobody owns rots, and the number of modules is bounded by the number of owners.
18. Start with fewer, coarser modules and split when a seam proves itself. A boundary drawn in the wrong place costs far more to move than one drawn late.
19. A module is deletable: removing its directory and its registration must break only the modules that declared a dependency on it, and nothing else.

### The module graph — applies to any change that adds or removes a dependency

20. Dependencies between modules are declared in a manifest checked into the repository, and a module may depend only on what it declares there.
21. The graph is acyclic. There is no temporary exception, and no cycle laundered through an interface, a callback, a service locator or a dependency-injection container.
22. Break a cycle by extracting the shared concept into its own module, moving the responsibility entirely to one side, or inverting the direction with an event — never by widening a public surface until the import compiles.
23. Depend in the direction of stability: a module that changes often may depend on one that changes rarely, never the reverse.
24. A module that every other module depends on is either genuinely generic infrastructure with no domain knowledge, or a boundary mistake. Establish which before adding the next dependency on it.
25. Keep fan-out small. A module that calls five others to do its work is orchestrating, and that orchestration is its own module or an explicit process, not a method buried in one of the five.
26. The graph is generated from the code and published with it. A dependency diagram maintained by hand is a diagram that is already wrong.
27. Code is shared between modules only if you would still want a single copy after extracting its consumers into separate deployables. If you would copy it then, copy it now.
28. Shared code that survives rule 27 is generic technical infrastructure or a published contract, never a business rule. A business rule has exactly one owning module.
29. No module depends on another module's tests, fixtures, factories or test doubles.

### The public surface — always applies

30. Every module exposes exactly one entry point — one package, namespace or facade naming everything a caller may use. Everything else in the module is internal.
31. Internals are unreachable, not merely undocumented. Use the strongest mechanism the language offers — visibility modifiers, an internal-directory convention, a separate build unit — before relying on a check to catch violations.
32. A caller reaches a module only through that entry point. Importing anything beneath it is a violation whether or not the compiler allows it.
33. The surface speaks in types the module owns: the commands, queries and results of its own contract. Never a domain entity, a persistence or ORM type, a database row, or a framework request or response object.
34. The surface exposes use cases, not data. A getter per field is an invitation for the caller to reimplement the module's rules, and it becomes the caller's dependency on the module's internal shape.
35. Each consumer reaches a module through its own thin gateway, so a change in that surface lands in one place per consumer instead of at every call site.
36. The surface is a contract even inside one repository. Changing it incompatibly is a breaking change for every consumer: make it deliberately, in one change that updates them, or in two steps that keep both shapes working.
37. There is no back door. Reflection, a string-keyed registry, a generated accessor or a test-only hook that reaches internals is the same violation with more steps.
38. A module's published events are part of its surface and are designed with the same care as its methods: named for a fact the module owns, in the past tense, carrying what that fact is rather than what a consumer happens to need.
39. A module never knows who consumes it. No consumer named in its code, no branch per consumer, no method that exists for exactly one caller's convenience.

### Storage ownership — always applies to a change that touches storage

40. Every table, collection, stream, index and bucket has exactly one owning module, and the ownership is visible physically: a schema per module, or one documented name prefix per module.
41. Ownership is enforced, not merely intended: the owning module is the only code path that reads or writes its storage, and another module's need is served through the owner's surface. `domain-driven-design` states that exclusivity for a bounded context; rule 82 is what makes it true of the module.
42. No foreign key crosses a module boundary. A reference to another module's data is an opaque identifier that module issued, with no database-level constraint behind it.
43. No query, view or stored routine reads across a module boundary. That read is a dependency the module graph cannot see, and it is the single most common reason a boundary turns out to be fictional.
44. Data from two modules is composed by the caller, by an explicit process, or from a copy the caller owns — never by one statement that reads two owners' storage.
45. When a module reads another's data often enough that per-call composition hurts, it keeps its own copy, fed by the owner's published events and shaped for its own use, and treats that copy as stale by definition.
46. A copy is never authoritative. Only the owning module changes the data; every copy is read-only to its holder and rebuildable from the owner.
47. Cross-module reporting, search and analytics read a store fed from each module, never the operational storage of several modules at once.
48. A schema migration belongs to the owning module and changes only that module's objects. A migration that touches two modules' tables is two migrations.
49. No persistence session, transaction handle, ORM mapping or connection identity is shared in a way that lets one module navigate into another module's records.
50. Caches, queues, object-storage prefixes, scheduled jobs and external-system credentials are owned per module too, with keys namespaced by module so one module cannot read, evict or exhaust another's.

### Integration between modules — applies to any cross-module interaction

51. Choose between a direct call and an event on the semantics required, not on habit: a direct call when the caller cannot proceed without the result, an event when the publisher must not care whether anyone is listening.
52. A direct call goes through the target's entry point, in process. Two modules in one deployable never speak over HTTP, a socket or a broker — that pays the network premium while keeping none of the benefit.
53. Nor does an in-process call get dressed as a remote one. No retries, timeouts, circuit breakers or bulkheads around a function call in the same process; those answer failure modes that do not exist there.
54. A module publishes an event only about something it owns, and only once that something is committed.
55. Handlers run outside the publisher's transaction and after it commits. A consumer's failure must never roll back the publisher's work, and a consumer must never be able to veto it.
56. Where a handler is deliberately synchronous and inside the publisher's transaction, say so at the publication site and accept that the two modules are now strongly consistent — which by rule 16 usually means they should be one module.
57. Every handler is idempotent and tolerates redelivery, duplication and out-of-order arrival. Ordering is not guaranteed between events, and never between events of different modules.
58. Reliable delivery of an event that crosses a boundary uses the outbox that `domain-driven-design` mandates, over the dual-write hazard that `best-practices` names. Do not invent a second mechanism beside it.
59. An in-memory bus with no persistence loses every event it holds on restart or crash. Use it only where that loss is acceptable, and say where that is.
60. No module shares mutable in-memory state with another — no shared registry, static map, singleton cache, global or process-wide counter.
61. Nothing ambient crosses a boundary. A callee never reads the current user, tenant, request, locale or transaction from a thread local, a context object or a global; it receives what it needs as an argument.
62. Every published surface and every published event has a test that fails the owning module's build when a change would break a consumer.

### Transactions and consistency — applies to any change that writes state

63. One operation changes the state of one module. A single transaction never writes two modules' storage.
64. A workflow that must change several modules is an explicit named process driven by events and compensations — `domain-driven-design` owns the saga and process-manager rules it follows.
65. Eventual consistency across a boundary is a decision with a stated staleness window and a stated behaviour while stale, never a side effect of having chosen an event.
66. A module never holds a transaction open across a call into another module.
67. When an operation is refused because another module's state had moved on, that refusal is a modelled outcome the caller can act on, not an exception leaking out of a boundary.

### Composition and configuration — applies to wiring, config and flags

68. The host — the deployable's single entry point — is the only place that knows the set of modules. It wires them and does nothing else; no business logic lives there.
69. Each module exposes one registration entry point that constructs its own internals. No module constructs another's internals, and the host never reaches inside a module to wire it.
70. Adding a module is one line in the host plus one entry in the dependency manifest. If it takes more, the host has acquired knowledge that belongs inside a module.
71. Configuration keys, environment variables, feature flags, metric names, log fields and job names are namespaced by module. An unnamespaced flag is a boundary leak that outlives the flag.
72. A module reads only its own configuration. Coordination between modules through a shared setting is an undeclared dependency that no check can see.
73. Startup order is not a contract. A module that works only if another initialised first has a dependency it has not declared.
74. A module can be switched off at runtime, or excluded from the build, by configuration the host reads — never by editing another module.

### Enforcement — always applies

75. A boundary no machine checks is a boundary that is already broken. Every rule above that can be checked automatically, is.
76. Enforce in this order: the language's own visibility first, an automated boundary check in the build second, review last. Review is the final line of defence, never the first.
77. The check runs in CI on every change and fails the build. A warning nobody reads is not enforcement.
78. The check reads the declared dependency manifest, so adding a dependency is a reviewable edit to a file rather than an import nobody noticed.
79. Violations that predate the check live in an explicit baseline that only ever shrinks, each entry carrying an owner and a date. A baseline that grows records the moment the boundary was abandoned.
80. Suppressing a violation requires a reason at the suppression site and a named owner. No blanket disable, no directory-wide exclusion, no commented-out check.
81. Adding a module updates the dependency manifest, the ownership file and the check's module list in the same change as the code.
82. The check covers storage ownership too — no cross-module table reference in schema, migration or query text. A structure-only check misses the coupling that hurts most.

### Operating and testing — applies to tests and telemetry

83. Each module's tests run on their own, without another module's internals, database objects or fixtures.
84. A module's tests substitute other modules at their entry points. A test that inserts rows into another module's tables to arrange state has coupled the two test suites to each other's schemas.
85. The boundaries themselves are tested: acyclicity, the declared graph, visibility and storage ownership are assertions in the suite that must pass, not a document.
86. Every log line, metric and trace span carries the module that emitted it, so a runtime problem maps to an owner without reading code.
87. Cross-module calls and event flows are observable — which module called this, and which module consumed that event, is answerable from telemetry rather than from grep.
88. An error crossing a boundary is translated into the caller's terms. A stack trace from another module's internals is a leaked internal like any other.
89. Each module reports its own health and its own external dependencies separately, so one module's failing dependency is not reported as the whole system being down.

### Evolution and extraction — applies when a boundary or deployment shape changes

90. Merge before splitting. A boundary that produces constant cross-module chatter, shared changes and coordinated releases is in the wrong place, and merging costs almost nothing now against a great deal after extraction.
91. A module is ready to extract only when it owns its storage with no cross-boundary joins or keys, its surface is coarse enough to survive a network between caller and callee, and its consumers already tolerate its events arriving late.
92. Extract for a driver from rule 4, one module at a time, behind the surface that already exists: each consumer's gateway changes, its call sites do not.
93. Move traffic incrementally and keep the rollback path until the extracted service is proven, then delete the module's code. A capability living in two places is worse than either place alone.
94. Do not redesign a boundary and extract it in the same step. The extracted contract is the existing surface made explicit and versioned; changing both at once means neither can be rolled back.
95. Recombining is a legitimate outcome. A service folded back into the monolith because the driver did not materialise is a correction, not a failure.
<!-- HARD-RULES:END -->

## One module, two modules, or two deployables

Read the signal, not the preference. The first three rows outrank everything below them.

| Signal | Answer | Why |
| --- | --- | --- |
| Two things must be consistent inside one transaction | **One module** | Rule 16. No boundary survives a transaction crossing it |
| Every release touches both; they always change together | **One module** | Rule 14. A contract between them is pure overhead |
| They chat constantly to serve one request | **One module**, or move the responsibility | The boundary cuts a single decision in half |
| Different consistency needs, different change rhythm, different owner | **Two modules** | Rule 15. That is what a boundary is for |
| One capability is generic and someone sells it | **Two modules**, then buy it | `domain-driven-design` decides this by subdomain |
| One workload must scale on a different resource — CPU against memory, or a GPU | **Two deployables** | Rule 4. One process cannot be sized two ways |
| One capability needs a different runtime, language or hardware | **Two deployables** | Rule 4 |
| A hard isolation, tenancy, residency or compliance boundary | **Two deployables** | Rule 4. A process boundary is the only real one |
| The organisation genuinely forces independent release cadence | **Two deployables** | Rule 4, and only once the module already passes rule 91 |
| Traffic might grow one day | **One deployable** | Rule 5. Modularise now, split when the driver is real |
| The team wants microservices on the CV | **One deployable** | Rule 5 |
| The split would still require deploying both together | **One deployable** | Rule 6. That is a distributed monolith |

## Integration styles across a boundary

| Style | Use when | What it costs |
| --- | --- | --- |
| Direct call through the entry point | The caller cannot proceed without the result, or the outcome must be visible immediately | The caller's latency and availability are now the callee's too, and the dependency is permanent and visible |
| Event published after commit, handled asynchronously | The publisher must not care who listens, and the consumer can act later | Eventual consistency, redelivery, no ordering, an outbox to make delivery reliable |
| A copy the consumer owns, fed by the owner's events | The consumer reads the same data constantly and per-call composition hurts | Staleness, storage, a rebuild path, and a second place to reason about |
| Reading the owner's storage directly | Never | Invisible coupling, an owner that can no longer change its schema, and a boundary that only exists in the directory names |

## The coupling shortcut and the modular answer

Every one of these looks local, small and harmless at the moment it is taken. Each is how a modular
monolith becomes a monolith with folders.

| Shortcut | What it costs | The modular answer |
| --- | --- | --- |
| Join across two modules' tables | A dependency no check can see; extraction becomes a rewrite | Call the owner's surface, or hold a projection fed by its events (43, 45) |
| Foreign key across a boundary | The owner can no longer change its keys; deletes cascade between owners | An opaque identifier with no constraint; validate through the surface (42) |
| Importing another module's entity or ORM type | The owner cannot refactor its internals without breaking callers | A contract type owned by the boundary (33) |
| A `common` module holding business rules | Everything depends on it, so nothing can move | Return each rule to its owning module; keep only generic infrastructure (13, 28) |
| Breaking a cycle with an interface in a shared module | The cycle is still there, now invisible | Invert with an event, or extract the shared concept (21, 22) |
| Breaking a cycle through the DI container | Same cycle, resolved at runtime instead of compile time | As above; the container is not an architecture (21) |
| Reaching past an entry point because it compiles | The surface stops describing the module | Widen the surface deliberately, or move the code (32) |
| A direct read "just for this report" | The reporting query becomes a second, undeclared contract | A read store fed by every module (47) |
| One transaction writing two modules | Two modules now share a failure and a lock scope | One transaction per module, event after commit, an explicit process (63, 64) |
| A synchronous handler inside the publisher's transaction | A consumer can roll back the publisher's work | Handle after commit; if it truly cannot, they are one module (55, 56) |
| In-memory event bus with no persistence | Events vanish on every restart and crash | The outbox (58, 59) |
| A static or singleton cache two modules use | Invisible coupling plus a lifecycle bug | A cache per module with namespaced keys (50, 60) |
| Reading the current user or tenant from a thread local on the far side | The callee cannot be tested, called or extracted independently | Pass it as an argument (61) |
| An HTTP call between modules in one process | The network premium with none of the benefit | A direct call through the entry point (52) |
| Retries and a circuit breaker around an in-process call | Ceremony for a failure mode that does not exist here | Let it fail; model the outcome the caller must handle (53, 67) |
| An unnamespaced feature flag or config key | Collisions, and coordination between modules through a setting | Namespace every key by module (71, 72) |
| A migration touching two modules' tables | Ownership becomes untraceable at exactly the wrong moment | One migration per owning module (48) |
| A test seeding another module's tables | The suites are now coupled through a schema neither owns | Substitute the other module at its entry point (84) |
| A module named `user`, `order` or `services` | An entity or layer name attracts every feature that mentions it | Name the capability (10, 11) |
| A new module with no recorded owner | It rots, and no one is accountable for its boundary | One owner per module in the ownership file (17, 81) |
| A directory-wide suppression of the boundary check | The boundary is abandoned, silently and permanently | Per-site suppression with a reason and an owner; a baseline that only shrinks (79, 80) |

## Depth

### Rules 10-13, 30-33 — a layout that hides internals

```text
Bad — layers at the top level. Every feature is spread across four directories, every
directory is a dumping ground, and nothing is private to anything.

  src/
    controllers/    order_controller, invoice_controller, shipment_controller, ...
    services/       order_service, invoice_service, shipment_service, ...
    repositories/   order_repo, invoice_repo, shipment_repo, ...
    models/         order, invoice, shipment, customer, ...
    common/         pricing rules, tax rules, address validation, id generation

Good — capabilities at the top level, each with a surface and an unreachable inside.

  src/
    billing/
      api/            the only importable thing: commands, queries, results, events
      internal/       domain model, use cases, persistence — unreachable from outside
      migrations/     changes only billing's own objects
    shipping/
      api/
      internal/
      migrations/
    catalogue/
      api/
      internal/
      migrations/
    platform/         generic infrastructure only: clock, ids, logging, transport
    host/             wires the modules and nothing else
    modules.yml       the declared dependency graph
```

`platform/` earns its place only by rule 27: after extracting `billing` and `shipping` into separate
deployables, you would still want one copy of a clock and an id generator — and none of the pricing
rules, which belong to `billing` alone.

### Rules 41-45 — one module reading another's data

```text
Bad — the boundary exists in the directory names and nowhere else.

  -- in shipping/internal/queries
  SELECT s.id, s.status, b.invoice_number, b.amount_due
    FROM shipping.shipments s
    JOIN billing.invoices b ON b.order_id = s.order_id   -- billing's table, shipping's query
   WHERE s.status = 'pending';

  Now billing cannot rename a column, cannot change a type, and cannot be extracted.
  Nothing in the build fails. Nothing in the module graph records it.

Good — ask the owner, or hold your own copy.

  -- shipping/internal: the query reads only what shipping owns
  SELECT id, status, order_id FROM shipping.shipments WHERE status = 'pending';

  # then, in shipping's use case, through the gateway it owns:
  billing = self.billing        # a thin gateway over billing/api (35)
  invoices = billing.invoices_for_orders(order_ids)   # a use case, not a row reader (34)

  # or, when this read happens on every request and composition hurts (45):
  #   shipping subscribes to billing's InvoiceIssued / InvoiceSettled events and maintains
  #   shipping.invoice_snapshot — its own table, read-only to it, rebuildable from billing,
  #   and stale by definition. Every consumer of it is written to expect that.
```

### Rules 55, 63-64 — a write that touches two modules

```text
Bad — one transaction, two owners, and a consumer that can veto a publisher.

  begin()
    orders.insert(order)                    -- orders' table
    billing.invoices.insert(invoice)        -- billing's table, written by orders
    inventory.reserve(order.lines)          -- runs inside this transaction; may raise
  commit()

  Any failure in inventory rolls back a confirmed order. The lock scope now spans three
  modules, and no boundary here would survive an extraction.

Good — one module per transaction, then a fact.

  begin()
    orders.insert(order)                    -- only orders' storage (63)
    outbox.append(OrderPlaced{order_id, lines, total})   -- same transaction (58)
  commit()

  # after commit, the outbox delivers OrderPlaced. Each consumer acts in its own
  # transaction, idempotently, and cannot roll the publisher back (55, 57):
  billing   on OrderPlaced -> issue invoice        (key: order_id)
  inventory on OrderPlaced -> reserve stock        (key: order_id)

  # inventory cannot reserve? It publishes ReservationRejected, and the named process
  # that owns this workflow compensates — cancel the order, void the invoice. The process
  # is explicit and has a name; `domain-driven-design` owns its rules (64).
```

If that eventual consistency is genuinely unacceptable — the order must not exist unless stock is
reserved, in the same instant — then rule 16 has already answered the design question: orders and
inventory are one module, and the transaction above is legal because it has one owner.

### Rules 20, 75-82 — the check that makes the boundary real

```yaml
# modules.yml — the declared graph. An import outside it fails the build (20, 78).
modules:
  catalogue:
    owner: team-catalogue
    depends_on: [platform]
  billing:
    owner: team-billing
    depends_on: [platform, catalogue]
  shipping:
    owner: team-fulfilment
    depends_on: [platform, catalogue]   # billing is absent on purpose: shipping
                                        # learns about invoices from events (51)
  platform:
    owner: team-platform
    depends_on: []

baseline:            # only ever shrinks (79)
  - violation: shipping/internal/queries joins billing.invoices
    owner: team-fulfilment
    remove_by: 2026-09-30
```

```text
The assertions that run in CI on every change (77, 85):

  no module imports another module's internal/ ....................... (31, 32)
  every import between modules appears in modules.yml ............... (20)
  the graph has no cycle ............................................ (21)
  every table's name prefix or schema matches exactly one module .... (40)
  no migration file changes another module's objects ................ (48)
  no query text names a table another module owns ................... (43, 82)
  every module in modules.yml has an owner ......................... (17)
  the baseline has not grown ....................................... (79)
```

Such a checker exists for every major ecosystem — an import linter, a module-graph linter, or an
architecture-test library that reads the compiled result. Which one, and how it is configured,
belongs in that stack's standard rather than here; that a check runs at all is what this standard
requires.

## Anti-pattern scan list

Codes: `A` architecture choice, `B` boundaries, `G` graph, `S` surface, `D` data, `I` integration,
`T` transactions, `W` wiring, `E` enforcement, `O` operating and testing, `X` evolution.

| Code | Anti-pattern | Settled by |
| --- | --- | --- |
| A1 | Separate deployables with no named driver | 4 |
| A2 | A split justified by future scale, fashion or preference | 5 |
| A3 | Services that must deploy together or share storage | 6 |
| A4 | "Modular monolith" claimed with no internal boundary at all | 7 |
| A5 | Boundaries with no recorded reason | 9 |
| B1 | A module named for a layer, an entity, a team or a project | 10, 11 |
| B2 | Layers at the top level, capabilities beneath them | 11 |
| B3 | Two bounded contexts inside one module | 12 |
| B4 | A `common`, `core`, `shared` or `util` module holding domain logic | 13, 28 |
| B5 | Two modules that never change independently | 14 |
| B6 | One module holding two change rhythms or two owners | 15 |
| B7 | A transaction-scoped invariant split across two modules | 16 |
| B8 | A module with no recorded owner | 17 |
| B9 | Twenty modules on day one | 18 |
| B10 | A module that cannot be deleted without editing unrelated code | 19 |
| G1 | An undeclared dependency between modules | 20 |
| G2 | A cycle in the module graph | 21 |
| G3 | A cycle hidden behind an interface, a callback or the DI container | 21, 22 |
| G4 | A stable module depending on a volatile one | 23 |
| G5 | A module every other module depends on | 24 |
| G6 | One module calling five others to do its work | 25 |
| G7 | A hand-drawn dependency diagram | 26 |
| G8 | Code shared that would be copied after extraction | 27 |
| G9 | A dependency on another module's tests or fixtures | 29 |
| S1 | More than one importable entry point per module | 30 |
| S2 | Internals kept private by convention alone | 31 |
| S3 | An import that reaches past the entry point | 32 |
| S4 | A domain entity, ORM type or framework object on the surface | 33 |
| S5 | A surface of getters instead of use cases | 34 |
| S6 | Every consumer calling the surface directly from every call site | 35 |
| S7 | An incompatible surface change made silently | 36 |
| S8 | Reflection, a string registry or a test hook reaching internals | 37 |
| S9 | An event shaped for one consumer's needs | 38 |
| S10 | A module that names or branches on its consumers | 39 |
| D1 | A table with no owning module, or two claimed owners | 40 |
| D2 | A module querying another module's storage | 41 |
| D3 | A foreign key across a boundary | 42 |
| D4 | A join across a boundary | 43 |
| D5 | Composition done in SQL spanning two owners | 44 |
| D6 | A hot cross-module read done per call with no owned copy | 45 |
| D7 | Two modules writing the same data | 46 |
| D8 | Reporting reading several modules' operational tables | 47 |
| D9 | One migration changing two modules' objects | 48 |
| D10 | A shared session or mapping that navigates across owners | 49 |
| D11 | An unnamespaced cache key, queue or bucket prefix | 50 |
| I1 | An event chosen where the caller needs the result now, or the reverse | 51 |
| I2 | An HTTP, socket or broker hop between modules in one process | 52 |
| I3 | Retries, timeouts or a circuit breaker around an in-process call | 53 |
| I4 | An event published before its cause committed, or about data another module owns | 54 |
| I5 | A handler running inside the publisher's transaction unannounced | 55, 56 |
| I6 | A handler that breaks on redelivery or out-of-order arrival | 57 |
| I7 | A second delivery mechanism invented beside the outbox | 58 |
| I8 | An in-memory bus where event loss is not acceptable | 59 |
| I9 | Mutable state shared between modules in memory | 60 |
| I10 | Ambient user, tenant or request state read across a boundary | 61 |
| I11 | A published surface or event with no consumer-side test | 62 |
| T1 | One transaction writing two modules' storage | 63 |
| T2 | A multi-module workflow with no named process or compensation | 64 |
| T3 | Eventual consistency with no stated window or stale behaviour | 65 |
| T4 | A transaction held open across a call into another module | 66 |
| T5 | A staleness conflict surfacing as an exception rather than an outcome | 67 |
| W1 | Business logic in the host | 68 |
| W2 | One module constructing another's internals | 69 |
| W3 | A host that must be edited in many places to add a module | 70 |
| W4 | An unnamespaced config key, flag, metric or job name | 71 |
| W5 | Two modules coordinating through one shared setting | 72 |
| W6 | A module that only works if another initialised first | 73 |
| E1 | A boundary rule enforced by review or intention only | 75, 76 |
| E2 | A boundary check that warns instead of failing | 77 |
| E3 | A growing violation baseline, or entries with no owner or date | 79 |
| E4 | A blanket or directory-wide suppression | 80 |
| E5 | A new module missing from the manifest, ownership file or check | 81 |
| E6 | A check that verifies structure but not storage ownership | 82 |
| O1 | A module's tests requiring another module's internals or tables | 83, 84 |
| O2 | Boundary rules documented but not asserted | 85 |
| O3 | Telemetry with no module attribution | 86, 87 |
| O4 | Another module's internal error or stack trace leaking to a caller | 88 |
| X1 | Splitting before merging an obviously wrong boundary | 90 |
| X2 | Extracting a module that still shares storage or has a chatty surface | 91 |
| X3 | Extraction that rewrites every call site instead of the gateway | 92 |
| X4 | A capability left running in both places | 93 |
| X5 | Redesigning the boundary and extracting it in one step | 94 |
