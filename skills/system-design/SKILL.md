---
name: system-design
description: Applies the system design standard — turn an idea into a documented high-level design: the problem and its non-goals, requirements written as measurable scenarios and objectives, capacity derived from stated numbers, the simplest shape that meets them, data ownership and access patterns, enumerated failure and overload behaviour, trust boundaries, operability and cost, every consequential decision recorded with its alternatives and its reversibility, and a delivery path validated against the requirements before anything is built. Use when designing a new system, service or major capability, running /revai:design, sizing for load or growth, choosing a datastore, an architecture shape or a technology, setting SLOs, planning a migration or a rollout, writing or reviewing a design document, or recording an architecture decision.
---

# System design

A design is not a diagram. It is the written answer to four questions — what problem is this, what
must be true for it to work, what shape meets that, and what did we decide against — with enough
numbers in it that someone can disagree with an input instead of a conclusion.

The failure mode is a design that cannot be wrong. "Scalable, reliable, secure" survives any
outcome: when the system falls over at a tenth of the load someone assumed, no line in the document
was contradicted. Every rule below exists to make the design falsifiable before it is built —
requirements with measures, load with arithmetic, failures with behaviours, decisions with
consequences. The second failure mode is the opposite: a design document for a change whose answer
was never in doubt. Rule 97 is that limit.

Scope: this standard owns **the design-time question** — what is being built, whether the shape meets
requirements someone can check, and what was decided instead. It does not own where boundaries fall
(`domain-driven-design`), what crosses them or how many deployables there are (`modular-monolith`),
or which library, protocol or resilience pattern implements a choice (`best-practices`). Where those
settle something, cite them rather than deciding it again here.

## Contents

- **System design rules** — 110 rules in thirteen groups: applicability, the problem before the
  solution, requirements that can be checked, sizing, choosing the shape, data, failure, security and
  privacy, operability and cost, model-backed capability, recording the decision, validating the
  design, and delivery and evolution. Rules 1–3 gate the standard on the change deciding a system's
  shape, and rule 2 gates each group on the concern in its heading. Not injected — invoked, or
  reached through `/revai:design`.
- **The design document** — the section-by-section outline the rules produce, and what each section
  has to contain to count.
- **What forces the shape** — the dominant requirement and the shape it implies, read before choosing
  an architecture.
- **The estimate and what it decides** — the arithmetic behind rules 23–33, with the decision each
  number settles.
- **The shortcut and what it costs** — 16 design shortcuts that each look reasonable in the moment,
  with the price and the alternative.
- **Depth** — worked bad/good pairs for the three things most often skipped: a requirement you can
  check, sizing before shape, and the failure table with the decision record.
- **Anti-pattern scan list** — 106 rows, coded by group (`P` problem, `R` requirements, `Z` sizing,
  `A` shape, `D` data, `F` failure, `S` security and privacy, `O` operability, `M` model,
  `C` decisions, `V` validation, `L` delivery), to work down while reviewing a design.

<!-- HARD-RULES:START -->
## System design rules

These are not aspirations. A design that violates one is a document, not a design. Rules 1–3 decide
whether the rest apply and where their edges are.

Rule 1 gates the standard on the change deciding or changing a system's shape. Rule 2 gates each
group on the concern named in its heading. Rule 3 draws the edges against the standards that own
boundaries, module interaction and implementation choice — cite them instead of restating them.

### Rules 1-3 — what applies

1. This standard applies to any change that decides or changes the shape of a system: a new application, service or major capability, a change to how data is owned or how the system scales, a new component or store, or any decision that will be expensive to reverse. A well-understood change inside an existing shape answers to the other standards only.
2. Each group applies when the concern in its heading is in play — a design that stores nothing answers to no data rule, one with no probabilistic component answers to no model rule. Three groups always apply: the problem before the solution, recording the decision, and validating the design.
3. This standard owns what is being built, whether the shape meets requirements someone can check, and what was decided instead. It does not own where a boundary falls (`domain-driven-design`), what crosses it or how many deployables exist (`modular-monolith`), or which library, protocol or resilience pattern implements a choice (`best-practices`).

### The problem before the solution — always applies

4. Write the problem first: who has it, what they do today, and what that costs them. A design that opens with a component diagram is a solution looking for a problem.
5. State goals as outcomes an observer outside the system could confirm, not as features or components.
6. State non-goals explicitly — things that could reasonably be goals and are deliberately not. A design with no non-goals has no scope, and every reviewer will assume a different one.
7. Name the success measure and its value today. "Faster", "more scalable" and "cleaner" are directions, not measures, and nothing can be compared against them later.
8. Consider doing nothing, and buying it, before designing it. Record why each was rejected — `best-practices` owns the search order for what already exists.
9. Record the constraints you do not control: deadline, budget, team size and skills, systems that already exist, regulation, and commitments already made. A design that ignores them is fiction with a diagram.
10. Name who the design is for, who reviews it and who decides. A design nobody is accountable for does not get built or maintained.
11. State the expected lifetime and rate of change. A one-quarter experiment and a system that must run for ten years are not designed the same way, and pretending otherwise over-builds one and under-builds the other.

### Requirements that can be checked — always applies

12. Every requirement is functional — what the system must do — or a quality attribute with a number attached. Anything else is a preference, and it will lose to whatever is convenient during implementation.
13. Write each quality attribute as a scenario: what triggers it and from where, the state the system is in, the part affected, the response, and the measure of that response. The measure is the requirement; without it the scenario cannot be checked.
14. Define an indicator before a target: the proportion of good events out of all valid events, counted where the user experiences it, not where it is easy to instrument.
15. Pick the indicator from what the thing actually is — availability and latency for request paths, freshness, correctness and coverage for pipelines, durability for stores. They fail differently and one menu does not cover them.
16. State targets as percentiles over a stated window. An average hides the tail that every unhappy user is in, and a target with no window cannot be evaluated.
17. Keep to five or fewer objectives, covering the journeys that matter most. Thirty targets are nobody's target and will be ignored together.
18. 100% is not a target. State the level users actually need and treat the remainder as the budget you intend to spend on change; a system with no budget for failure has no budget for improvement either.
19. Say what the system may lose and what it must never lose. Those are different requirements, they lead to different designs, and conflating them buys durability where it was not needed and skips it where it was.
20. State what you are deliberately not optimising for. A design that optimises everything has no priority, so the priority will be set by whoever implements it first.
21. Every number carries its source and its date — who said it, from what evidence. An unattributed figure gets defended by nobody and revised by everybody.
22. A requirement nobody will measure after launch is deleted, not designed for.

### Sizing — applies when load, data volume, growth or cost are in play

23. Put numbers on the system before drawing it: users, requests, payload sizes, data volume, growth rate. A shape chosen without them is chosen by taste and discovered to be wrong in production.
24. Derive load, do not assert it: from users, to actions per user per period, to the average per second, to a peak with a stated peak factor. Design for the peak; the average never happens.
25. Size the read and the write path separately. Their ratio decides caching, replication and the store far more than either total does.
26. Size storage as write rate × retention × replication, projected over the horizon the design claims to serve, and add the indexes, the copies and the backups.
27. Size bandwidth per hop and check the largest response against the narrowest link, including the client's network rather than only the data centre's.
28. Distinguish the working set from the total. Memory and cache sizing follow the working set; cost and store choice follow the total.
29. Concurrency is throughput × latency. Derive pool, worker and connection counts from it instead of picking a number that looks generous.
30. Give each user-visible operation a latency budget and divide it across its hops — network, each dependency's tail, and your own code. What remains after the dependencies is what you have to work with, and it is usually less than expected.
31. Every estimate shows its assumptions and its arithmetic, so a reader can disagree with an input rather than with the conclusion.
32. Estimates are order-of-magnitude. Three significant figures are a false claim about a future nobody knows.
33. State what saturates first and at what multiple of today's load. A design that cannot name its next bottleneck has not been sized, and the bottleneck will be named by an incident.

### Choosing the shape — applies when the architecture or a technology is being chosen

34. Choose the simplest shape that meets the stated requirements, and name the requirement that forces each departure from it.
35. Let the dominant quality attribute pick the shape. Design for the one or two that decide whether the system is worth having and accept the rest.
36. Default to one deployable with modules inside it — `modular-monolith` rules 4–6 own when that stops being the answer, and "we might need to scale" is not that moment.
37. Prefer the boring option: technology with known failure modes, in-house experience and someone who has operated it. Novelty is a small fixed budget, spent on the thing that differentiates the product and nowhere else.
38. Prefer a managed service to self-hosting and either to building it, and name who operates every component you keep. `best-practices` owns the order in which to search for what exists.
39. No tier, queue, cache, gateway, replica or abstraction enters the design without the requirement that demands it named beside it.
40. Synchronous request/response is the default. Asynchrony is chosen for a stated reason — decoupling, absorbing bursts, work longer than a request — and its cost in ordering, duplication and observability is stated with it.
41. Keep compute stateless and put state in something built to hold it. Session or scratch state on the instance turns every deploy, every scale-in and every crash into data loss.
42. The system fits on one page at component level: every box named with its responsibility and its technology, every line labelled with what flows and by what mechanism. An unlabelled arrow is a decision nobody made.
43. Name every external system the design depends on, what it promises, what it costs, and what the design does when the promise is not kept.
44. Design the seam between what you own and what you rent, so replacing a vendor is a contained change — `domain-driven-design` owns the anticorruption layer that keeps their model out of yours.
45. Match the shape to the team that will run it. A design that needs more independently operated parts than there are people to operate them will be operated by nobody.

### Data — applies when the design stores or moves data

46. Design the data before the interface. Endpoints follow from what is stored and what must be read; the reverse produces a schema that cannot answer the questions the product asks.
47. Every fact has exactly one source of truth, named. Everything else is a derived copy, marked as one, and rebuildable from the source.
48. State the consistency each operation needs, operation by operation. A single global answer is too weak somewhere or too expensive everywhere.
49. Choose the store from the access patterns, written down: the queries, their frequency, their selectivity and their latency need. A store chosen before the queries gets worked around for the rest of its life.
50. List the dominant access patterns and show how each is served, naming the index, key or view that serves it.
51. Choose the partition or sharding key from the dominant access pattern, then check it for skew: the largest tenant, the newest time bucket, the most popular row.
52. State the replication and failover model with the recovery point and recovery time being promised, how failover is triggered, and how it is reversed.
53. Classify the data at design time — public, internal, personal, secret, regulated — and record for each class where it may live, how long, and who may read it.
54. State retention and deletion per class, including every copy: caches, replicas, backups, logs, exports, analytics stores and third parties you send it to.
55. Name which entities will change shape and what that will cost before the first row exists. `best-practices` owns expand/contract; the design owns knowing where it will be needed.
56. Design the migration and backfill of data that already exists in the same pass as the new model. A design that only serves new data is half a design and the other half is an emergency.

### Failure — always applies

57. Enumerate the failures: for each component and each dependency, what happens when it is slow, when it is down, when it returns something wrong, and when it comes back.
58. For each, state detection, blast radius, degraded behaviour and recovery. A failure with no designed degraded behaviour degrades into an outage.
59. Name every single point of failure. Accepting one is a decision with a stated cost; discovering one during an incident is not a decision.
60. Availability composes: a path through dependencies in series cannot beat their product, and nothing is more available than the least available thing on its critical path. Check the target against that arithmetic before promising it.
61. Keep the critical path short and name what is on it. Anything not required for the core outcome should be able to fail without the user noticing.
62. Bound the blast radius by design — partition users, tenants or regions into units that fail independently — and state which unit a given failure is confined to.
63. Decide overload behaviour in advance: what is shed, what is queued, what is refused, and in what order. Under load that choice is made either by the design or by the collapse.
64. State the trade between losing data and being unavailable. Both are legitimate answers; not choosing means the answer is whatever the code happens to do.
65. Every retry, replay and reprocess path in the design is safe to run twice — `best-practices` owns idempotency keys, dead-letter paths and retry budgets.
66. Recovery is designed and exercised, not assumed. Restoring a backup, rebuilding a derived store, replaying a stream and draining a queue each have a procedure and an expected duration.
67. State how the system behaves during its own deployment. Two versions running at once is a designed state with a defined contract between them, not an accident that resolves itself.

### Security and privacy — applies to any system with users, data or an external interface

68. Draw the trust boundaries on the same diagram as the components: where data changes hands, where trust changes level, and where your control ends.
69. Walk every element and every flow that crosses a boundary for spoofing, tampering, repudiation, disclosure, denial of service and elevation of privilege, and record what mitigates each or why it is accepted.
70. State the authorization model once, as a model: who the subjects are, what the resources are, who may do what, and the single layer that enforces it. `best-practices` owns the implementation defaults.
71. State the isolation model between tenants or customers, and what a single bug would have to do to cross it.
72. Name the secrets and keys the design needs, where they live, who can read them, and how they are rotated without downtime.
73. State which actions are audited, what each record contains, and who can read it and who cannot change it.
74. Treat everything arriving from outside a trust boundary as hostile, including another team's system, a vendor's callback and anything a model generated.
75. Name the regulatory, contractual and residency constraints as constraints, each with its design consequence. A residency requirement discovered after the data design redesigns the data layer.

### Operability and cost — always applies

76. State how you will know it works: which signal, measured where, and how it maps to each objective. A target with no measurement point is not yet a target.
77. Every component has a named operator and a stated way to be diagnosed, restarted, scaled and rolled back.
78. State the scaling signal and the headroom kept above normal load, and what a human does when the signal is misleading.
79. Design the deploy and the rollback together. A change that cannot be rolled back is split into steps that can be, or its irreversibility is stated as an accepted consequence.
80. State the cost model: cost per unit of work, what dominates it, and what it becomes at ten times the load. A design with no cost shape is hiding its tightest constraint.
81. Describe the worst day — traffic spike, dependency outage, bad deploy, corrupted data — as a path a person on call can follow, not as an aspiration.
82. Name what must be answerable in production and by which signal. `best-practices` owns telemetry, log and alerting mechanics; the design owns the questions they have to answer.

### Model-backed capability — applies when a model or other probabilistic component is in the design

83. State what the model is for and what a deterministic implementation would cost. A probabilistic component competing with a rule that would work needs a reason beyond novelty.
84. Treat every model call as a remote dependency that is slow, metered, sometimes wrong and sometimes unavailable, and design its timeout, its fallback and its cost ceiling with it.
85. State the accuracy requirement as a measure over a named evaluation set, held in version control and run in the build. Without one, quality is an anecdote and every change is a gamble.
86. Design what happens when the output is wrong: what is validated, what is reversible, and where a human decides. A consequential action is never taken on an unchecked generation.
87. Model input and output cross a trust boundary in both directions — retrieved content can carry instructions, and generated content can carry mistakes into your data.
88. State the cost per request, its ceiling, and what degrades when the ceiling is reached. Per-call pricing turns a traffic spike into an invoice.
89. Pin the model, prompt and parameters, and treat a change to any of them as a deployment with an evaluation gate and a rollback.

### Recording the decision — always applies

90. Every consequential decision is recorded beside the code: the context and the drivers, the options considered, the outcome, and the consequences accepted.
91. A record with one option is a rationalisation. List the real alternatives, including doing nothing, and state each one's strongest case before rejecting it.
92. Record the consequence accepted, not only the benefit wanted. A decision with no stated cost was not a decision.
93. Each record carries a date, an owner and a status. A superseded record is marked and kept, never edited or deleted: what was known at the time is the point of it.
94. Flag the decisions that are expensive to reverse and spend proportionally more on those. A store, a data model, a published contract and a boundary are one-way doors next to a library choice.
95. State what would make you revisit the decision — a number, a date or an event. A decision with no revisit trigger becomes a permanent constraint nobody chose.
96. The design document is the artifact, versioned with the code: problem, goals and non-goals, constraints, requirements, sizing, architecture, data, integration, failure, security and privacy, operability and cost, decisions, validation, delivery, open questions. A section with nothing in it says "not applicable" and why.
97. Scale the document to the stakes. Several credible options behind a one-way door earn the full treatment; a change whose answer was never in doubt earns a paragraph, and writing more is a cost with no return.

### Validating the design — always applies

98. Walk the primary journeys end to end through the design, naming every component and store touched. A journey that cannot be traced is a gap in the design, not in the walk.
99. Walk each quality attribute scenario against the design and show the measure is met, with the arithmetic. A design never checked against its own requirements has not been designed.
100. Walk the top failure scenarios and the busiest hour the same way.
101. Turn the properties that must keep holding into checks that run — a test, a metric, a query or an alert — so erosion appears in the build or the dashboard rather than in an incident.
102. Identify the riskiest assumption and reduce it first, with a spike, a load test or a prototype, before the design is committed to.
103. Have the design reviewed by whoever will operate it and by someone outside the work. A design reviewed only by its author is a plan.
104. Record the open questions with an owner and a date needed by. Unknowns are part of a design; claiming there are none is not.

### Delivery and evolution — always applies

105. Slice the work into increments that each ship and each deliver something. A design that delivers nothing until everything is finished is a bet.
106. Build the thinnest end-to-end path first — one journey through every layer, in production — then broaden it. Depth before breadth finds the wrong assumptions while they are still cheap.
107. Say what is deliberately deferred and what would trigger building it, so a later reader can tell a decision from an omission.
108. For a system that already exists, design the transition as well as the destination: what runs in parallel, how traffic moves, how it moves back, and when the old path is deleted.
109. Keep each step reversible. A step that changes shape and moves data at the same time can only be rolled forward.
110. A design is finished when the system matches it. At the first divergence, correct the system or correct the document, and say which.
<!-- HARD-RULES:END -->

## The design document

One document per system or capability, versioned beside the code. Sections in this order, each
carrying what the rules require of it; nothing invented to fill a gap and nothing silently dropped.

```text
# <system or capability>          status · owner · date · reviewers
 1  Problem              who has it, what happens today, what it costs                    4, 7
 2  Goals / Non-goals    outcomes observable from outside; what is deliberately out        5, 6
 3  Constraints          deadline, budget, team, existing systems, regulation, commitments 9, 10, 11
 4  Requirements         capabilities; quality-attribute scenarios with measures; SLIs,
                         SLOs and error budget; what may be lost; what is not optimised    12-22
 5  Sizing               users → load → peak; storage; bandwidth; concurrency; latency
                         budget per hop; what saturates first and at what multiple         23-33
 6  Architecture         one component diagram; per box: responsibility, technology,
                         operator; per line: what flows and how; the simplest shape and
                         the requirement forcing each departure                            34-45
 7  Data                 source of truth per fact; access patterns and what serves them;
                         store choice; partition key and skew; replication, RPO, RTO;
                         classification, retention, residency; migration and backfill      46-56
 8  Integration          what crosses each boundary and by which mechanism, external
                         systems and their promises                     modular-monolith, 43
 9  Failure              per component and dependency: detection, blast radius, degraded
                         behaviour, recovery; SPOFs; overload behaviour; availability
                         arithmetic against the target                                     57-67
10  Security & privacy   trust boundaries on the diagram; threats per crossing flow and
                         their mitigations; authorization model; isolation; secrets;
                         audit; regulatory and residency constraints                       68-75
11  Operability & cost   signal and measurement point per objective; scaling signal and
                         headroom; deploy and rollback; cost per unit of work and at 10×;
                         the worst day as a path                                           76-82
12  Decisions            per decision: drivers, options with their strongest case, outcome,
                         consequence accepted, reversibility, revisit trigger              90-97
13  Validation           journeys walked; scenarios checked with arithmetic; failure walk;
                         checks that catch erosion; riskiest assumption and how it is
                         reduced first                                                     98-103
14  Delivery             increments; the thinnest end-to-end path; transition and rollback
                         for what exists; what is deferred and what triggers it            105-109
15  Open questions       question → owner → needed by                                      104
```

## What forces the shape

Read the dominant requirement, not the preference. Nothing on the right enters a design without the
requirement on its left written beside it (rule 39).

| The requirement that dominates | What it forces | Settled by |
| --- | --- | --- |
| Two facts must be consistent in one transaction | One store, one owner, one module | `modular-monolith` 16, 63 |
| Reads vastly outnumber writes, and the read shape differs | A derived read model or replica, and a stated staleness window | 25, 48; `domain-driven-design` 71 |
| Arrival rate is bursty and the work outlives the request | A queue with a stated depth, backlog behaviour and duplicate handling | 40, 63, 65 |
| One workload must scale on a different resource | A separate deployable, and only for that workload | `modular-monolith` 4 |
| A tight tail-latency target | Fewer hops, no synchronous fan-out, a budget per hop | 30, 60, 61 |
| Data must survive the loss of a machine or a region | Replication with a stated RPO and RTO, and a tested restore | 52, 66 |
| Records must stay in a jurisdiction | Partition by region; no global write path; no cross-region copy | 53, 75 |
| Base load is low and spikes are unpredictable | Managed or on-demand compute, with a cost ceiling | 38, 80 |
| One tenant must never see another's data | A stated isolation model and the bug that would defeat it | 71 |
| Availability higher than a dependency's | Remove it from the critical path, or lower the target | 60, 61 |
| Nothing above is dominant | The simplest shape, one deployable, boring technology | 34, 36, 37 |

## The estimate and what it decides

| Quantity | From | What it decides |
| --- | --- | --- |
| Average load | users × actions per user per period ÷ seconds in it | Whether the system is small; everything below |
| Peak load | average × peak factor, stated | Instance count, pool sizes, rate limits |
| Write load | peak × write share | Store choice, replication cost, contention |
| Storage | write rate × payload × retention × replication, + indexes and copies | Store, cost, retention policy, archive path |
| Growth | storage per period × horizon | When the shape stops working |
| Bandwidth | payload × load, per hop | Link capacity, CDN, pagination, payload trimming |
| Working set | active records × size | Cache size and expected hit rate |
| Concurrency | throughput × latency | Workers, connections, thread and pool limits |
| Latency budget | target percentile − each dependency's tail − network | What your own code may spend, and how many hops fit |
| Availability | product of the critical path's dependencies | Whether the objective is achievable as designed |
| Cost per request | infrastructure + per-call vendor charges ÷ requests | Whether the design is affordable at 10× |

## The shortcut and what it costs

| Shortcut | What it costs | Instead |
| --- | --- | --- |
| "Fast and highly available" as the requirement | Nothing can fail the design, so nothing constrains it | A scenario with a measure, and a target with a window (13, 16) |
| Drawing the components before doing the arithmetic | The shape is chosen by taste and disproved by traffic | Numbers first, then boxes (23, 24) |
| An average latency target | Ships the tail every unhappy user sits in | A percentile over a stated window (16) |
| A 100% or unstated availability target | No budget for change; every release becomes a risk nobody sized | The level users need, with the remainder as budget (18) |
| Microservices with no driver | The distributed premium from day one, refunded by nothing | One deployable until a named driver appears (36) |
| A new datastore or framework for one feature | A second thing to operate, learn, back up, patch and staff | The boring option; spend novelty on the differentiator (37) |
| One global consistency answer | Too weak on the path that matters, too expensive on the rest | Per operation, stated (48) |
| Choosing the store before writing the queries | Every future query becomes a workaround | Access patterns first, then the store (49, 50) |
| Partitioning by tenant with one enormous tenant | One shard saturates while the rest idle | Check the key for skew before adopting it (51) |
| "We'll add a cache later" | A cache hiding a store that was wrong for the access pattern | Size the working set, then choose (28, 49) |
| No failure enumeration | Degraded behaviour gets invented during the incident | A row per component and dependency (57, 58) |
| Retries as the resilience plan | Amplified load at exactly the wrong moment | Overload behaviour decided in advance (63); `best-practices` for mechanics |
| No cost model | The tightest constraint on the design is the one nobody sized | Cost per unit of work, and at 10× (80) |
| An alternatives section with one option | The decision cannot be reviewed, only ratified | Real options, each with its strongest case (91) |
| A model call with no fallback or evaluation set | Silent quality regressions and an unbounded bill | Timeout, fallback, cost ceiling, evaluation in the build (84, 85, 88) |
| Designing the destination only | The system that exists has no way to become the one described | A transition with reversible steps (108, 109) |

## Depth

### Rules 12-22 — a requirement you can check

Bad — nothing here can be contradicted by any outcome:

```text
The service must be fast, highly available and able to scale.
```

Good — a scenario with a measure, then the objective derived from it:

```text
Scenario   A signed-in customer submits an order from the mobile app,
           during the Monday 09:00-11:00 peak, against the order service.
Response   The order is accepted and durably stored, and the confirmation
           screen renders.
Measure    p99 under 400 ms, p50 under 120 ms, measured at the mobile client.

Indicator  orders accepted and stored / orders submitted (valid = authenticated,
           schema-valid submissions), measured at the API edge.
Objective  99.9% over a rolling 28 days · budget 0.1% ≈ 43 min/month of failed
           submissions, spent deliberately on releases and migrations.
May lose   Draft carts, recommendation state, non-billing analytics events.
Must not   An accepted order, a payment record, an audit entry.
Not optimising for: cross-region survival (single region accepted until EU launch),
           sub-second analytics freshness (15 minutes is enough).
```

### Rules 23-33 — sizing before shape

```text
Assumption   200k daily active customers, 12 actions each, 10% of them writes,
             2 KB average stored per write, 90-day hot retention, 3 replicas.
             Source: this quarter's analytics, 2026-08-10.
Average      200k × 12 ÷ 86,400 ≈ 28 req/s
Peak         × 5 (observed Monday-morning factor) ≈ 140 req/s, of which ~14 writes/s
Storage hot  14/s × 86,400 × 2 KB ≈ 2.4 GB/day → 90 days ≈ 220 GB × 3 ≈ 650 GB,
             plus indexes ≈ 1 TB. One ordinary managed instance, not a cluster.
Bandwidth    140/s × 30 KB response ≈ 4.2 MB/s ≈ 34 Mbps — fine on the link,
             not fine on a phone: paginate and trim the payload.
Concurrency  140/s × 0.25 s ≈ 35 in flight → pool of 50, not 500.
Latency      400 ms p99 budget = 60 ms client/network + 120 ms payment provider
             tail + 40 ms database + 30 ms queue publish → 150 ms for our code.
Saturates    The payment provider's 20-connection limit, at roughly 3× today's
             peak. That is the next thing to change, not the database.
```

Two orders of magnitude below "needs a distributed system", and the first bottleneck is somebody
else's connection limit. Both facts change the shape, and neither is visible without the arithmetic.

### Rules 57-67, 90-97 — the failure table and the decision record

Bad: *"The service is resilient: it retries failed calls and runs multiple instances."*

Good — one row per dependency, then the decision that row forced:

```text
| Dependency  | Slow            | Down                 | Blast radius   | Recovery        |
| Payments    | Shed after 2 s  | Queue as pending,    | Checkout only, | Drain queue;    |
|             | at the edge     | notify, no charge    | one region     | 15 min drain    |
| Order store | Reject writes,  | Read-only mode from  | All writes     | Failover 90 s,  |
|             | serve reads     | replica              |                | RPO 10 s        |
| Search      | Serve stale     | Fall back to keyword | Discovery only | Reindex 40 min  |
|             | index           | search on the store  | — no checkout  |                 |

Decision  Accept pending orders when the payment provider is down
Drivers   Order acceptance is 99.9%; the provider publishes 99.5% (rules 60, 19)
Options   1. Fail checkout while the provider is down — provider's availability
             becomes ours; simplest; strongest case: no pending state to reconcile.
          2. Accept as pending and settle asynchronously — chosen.
          3. Second provider behind an abstraction — best availability; two
             integrations, two reconciliations, cost not justified at this volume.
Outcome   Option 2.
Consequence  A pending state customers can see, a reconciliation job, and a rule
          for orders that never settle. Accepted.
Reversible   Yes, cheaply, until pending orders are exposed in the API (rule 94).
Revisit   If provider unavailability exceeds 0.5% in a month, or at EU launch.
```

## Anti-pattern scan list

Codes: `P` problem, `R` requirements, `Z` sizing, `A` shape, `D` data, `F` failure, `S` security and
privacy, `O` operability and cost, `M` model, `C` decisions, `V` validation, `L` delivery.

| Code | Anti-pattern | Settled by |
| --- | --- | --- |
| P1 | Opens with a diagram or a technology; no problem statement | 4 |
| P2 | No non-goals, so every reader assumes a different scope | 6 |
| P3 | Success stated as a direction, with no measure and no baseline | 7 |
| P4 | Doing nothing and buying it were never considered | 8 |
| P5 | Deadline, budget, team or regulation absent from the design | 9 |
| P6 | No named owner, reviewer or decision-maker | 10 |
| P7 | An experiment and a decade-long system designed alike | 11 |
| R1 | A quality attribute with no number attached | 12 |
| R2 | A scenario with no response measure | 13 |
| R3 | A target with no indicator, or an indicator measured where it is convenient | 14 |
| R4 | Availability used as the only indicator for a pipeline or a store | 15 |
| R5 | An average or a mean as the target | 16 |
| R6 | More than five objectives, or none tied to a journey | 17 |
| R7 | A 100% target, or an objective with no error budget | 18 |
| R8 | What may be lost and what must never be lost not separated | 19 |
| R9 | Nothing named as deliberately not optimised for | 20 |
| R10 | A number with no source or date | 21 |
| R11 | A requirement nobody will measure after launch | 22 |
| Z1 | Components drawn before any number exists | 23 |
| Z2 | Load asserted rather than derived, or only the average sized | 24 |
| Z3 | One load figure covering reads and writes | 25 |
| Z4 | Storage sized without retention, replication, indexes or growth | 26 |
| Z5 | Payload and bandwidth never computed, or only for the data centre | 27 |
| Z6 | Cache sized against the total data rather than the working set | 28 |
| Z7 | Pool, worker or connection counts chosen by feel | 29 |
| Z8 | A latency target never divided across hops | 30 |
| Z9 | An estimate with no visible assumption or arithmetic | 31 |
| Z10 | Estimates carried to three significant figures | 32 |
| Z11 | No statement of what saturates first, or at what multiple | 33 |
| A1 | A departure from the simplest shape with no requirement named | 34 |
| A2 | A shape chosen to satisfy every quality attribute at once | 35 |
| A3 | Several deployables with no driver from `modular-monolith` 4 | 36 |
| A4 | A new language, framework or datastore adopted for one feature | 37 |
| A5 | Something built that a managed service already provides | 38 |
| A6 | A queue, cache, gateway or tier with no requirement beside it | 39 |
| A7 | Asynchrony by default, its cost in ordering and duplication unstated | 40 |
| A8 | Session or scratch state held on the compute instance | 41 |
| A9 | An unlabelled arrow, or a box with no technology or responsibility | 42 |
| A10 | An external dependency with no stated promise or failure behaviour | 43 |
| A11 | A vendor's model reaching into the domain | 44 |
| A12 | More independently operated parts than there are operators | 45 |
| D1 | Endpoints designed before the data | 46 |
| D2 | Two components able to write the same fact | 47 |
| D3 | One global consistency answer for every operation | 48 |
| D4 | A store chosen before the access patterns were written down | 49 |
| D5 | A dominant access pattern with nothing named that serves it | 50 |
| D6 | A partition key never checked for skew or a hot tenant | 51 |
| D7 | No RPO, RTO, failover trigger or way back | 52 |
| D8 | Personal, secret or regulated data left unclassified | 53 |
| D9 | Retention stated for the primary store but not for the copies | 54 |
| D10 | No idea which entities will change shape, or what that costs | 55 |
| D11 | Existing data's migration and backfill left out of the design | 56 |
| F1 | No enumeration of slow, down, wrong and recovering per dependency | 57 |
| F2 | A failure with no designed degraded behaviour | 58 |
| F3 | An unacknowledged single point of failure | 59 |
| F4 | A target higher than the product of its critical-path dependencies | 60 |
| F5 | Non-essential work on the critical path | 61 |
| F6 | Blast radius unbounded — one failure reaches every user | 62 |
| F7 | Overload behaviour left to be discovered under load | 63 |
| F8 | The data-loss versus unavailability trade never made | 64 |
| F9 | A replay or reprocess path that is not safe to run twice | 65 |
| F10 | Recovery assumed rather than described and timed | 66 |
| F11 | Two versions running at once treated as an accident | 67 |
| S1 | No trust boundaries on the diagram | 68 |
| S2 | No threat walk over the flows that cross them | 69 |
| S3 | Authorization described per endpoint instead of as one enforced model | 70 |
| S4 | Tenant or customer isolation unstated | 71 |
| S5 | Secrets, key custody and rotation unaddressed | 72 |
| S6 | Privileged actions with no audit record, or a mutable one | 73 |
| S7 | Another team's system, a vendor callback or model output trusted | 74 |
| S8 | A residency or regulatory constraint discovered after the data design | 75 |
| O1 | No signal named for an objective, or no measurement point | 76 |
| O2 | A component with no named operator or no way to be diagnosed | 77 |
| O3 | Autoscaling with no stated signal or headroom | 78 |
| O4 | A change with no rollback path, and no statement that it has none | 79 |
| O5 | No cost per unit of work, and no idea what dominates it | 80 |
| O6 | The worst day described as an aspiration rather than a path | 81 |
| O7 | Production questions nobody has mapped to a signal | 82 |
| M1 | A probabilistic component where a deterministic one would do | 83 |
| M2 | A model call with no timeout, fallback or cost ceiling | 84 |
| M3 | Accuracy claimed with no evaluation set in version control | 85 |
| M4 | A consequential action taken on an unchecked generation | 86 |
| M5 | Retrieved or generated content treated as trusted | 87 |
| M6 | Per-call pricing with no ceiling and no degraded mode | 88 |
| M7 | Model, prompt or parameters changed with no evaluation gate | 89 |
| C1 | A consequential decision with no record | 90 |
| C2 | One option, or alternatives written as strawmen | 91 |
| C3 | A decision recording its benefit and not its cost | 92 |
| C4 | No date, owner or status; a superseded record edited in place | 93 |
| C5 | A one-way door decided as casually as a library choice | 94 |
| C6 | No revisit trigger, so the decision becomes a permanent constraint | 95 |
| C7 | A document with sections silently missing | 96 |
| C8 | A full design for an obvious change, or a paragraph for a one-way door | 97 |
| V1 | A primary journey that cannot be traced through the design | 98 |
| V2 | A scenario never checked against the design, or checked without arithmetic | 99 |
| V3 | Failure scenarios and the busiest hour never walked | 100 |
| V4 | A property that must hold with no check that would catch its erosion | 101 |
| V5 | The riskiest assumption left untested | 102 |
| V6 | Reviewed only by its author, or never by an operator | 103 |
| V7 | No open questions, or open questions with no owner | 104 |
| L1 | Nothing delivered until everything is finished | 105 |
| L2 | Breadth before the first end-to-end path exists | 106 |
| L3 | Deferred work indistinguishable from forgotten work | 107 |
| L4 | A destination with no transition for the system that exists | 108 |
| L5 | One step that changes shape and moves data at once | 109 |
| L6 | Document and system diverged, with neither corrected | 110 |
