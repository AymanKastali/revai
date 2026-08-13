---
name: system-design
description: Applies the system design standard — turn an idea into a documented high-level design: the problem and its non-goals, functional and non-functional requirements as testable capabilities and measurable scenarios, capacity estimated from stated numbers, the simplest shape that meets them, data ownership and access patterns, concrete API contracts, a deep dive on the hardest mechanisms, enumerated failure and overload behaviour, trust boundaries, operability and cost, every consequential decision recorded with its alternatives, and a delivery path validated against the requirements before anything is built. Use when designing a new system, service or major capability, sizing for load or growth, choosing a datastore or architecture, designing an API or event contract, specifying the algorithm behind a hard component, setting SLOs, planning a migration or rollout, writing or reviewing a design document, or recording an architecture decision.
---

# System design

A design is not a diagram. It is the written answer to five questions — what problem is this, what
must be true for it to work, what shape meets that, how does it actually work where it's hard, and
what did we decide against — with enough numbers in it that someone can disagree with an input
instead of a conclusion.

The failure mode is a design that cannot be wrong. "Scalable, reliable, secure" survives any
outcome: when the system falls over at a tenth of the load someone assumed, no line in the document
was contradicted. Every rule below exists to make the design falsifiable before it is built —
requirements with measures, load with arithmetic, interfaces with contracts, the hard parts with a
mechanism, decisions with consequences. The second failure mode is the opposite: a design document
for a change whose answer was never in doubt. Rule 109 is that limit.

Scope: this standard owns **the design-time question** — what is being built, whether the shape meets
requirements someone can check, and what was decided instead. It does not own where boundaries fall
(`domain-driven-design`), what crosses them or how many deployables there are (`modular-monolith`),
or which library, protocol or resilience pattern implements a choice (`best-practices`). Where those
settle something, cite them rather than deciding it again here.

## Contents

- **System design rules** — 123 rules in fifteen groups: applicability, the problem before the
  solution, requirements (functional and non-functional), capacity estimation, choosing the shape,
  data, API and interface design, detailed design, failure, security and privacy, operability and
  cost, model-backed capability, recording the decision, validating the design, and delivery and
  evolution. Rules 1–3 gate the standard on the change deciding a system's shape, and rule 2 gates
  each group on the concern in its heading. Not injected — invoked directly as a skill.
- **The design document** — the section-by-section outline the rules produce, and what each section
  has to contain to count.
- **Procedure** — how to run the standard end to end: the warrant check, tagging the idea narrow or
  complex, gathering context, bounded question rounds, the defaults applied without asking, writing
  the document, the self-check before showing it, and the report.
- **What forces the shape** — the dominant requirement and the shape it implies, read before choosing
  an architecture.
- **The estimate and what it decides** — the arithmetic behind rules 25–35, with the decision each
  number settles.
- **The shortcut and what it costs** — 12 design shortcuts that each look reasonable in the moment,
  with the price and the alternative.
- **Depth** — one worked scenario, run end to end, through a requirement you can check, sizing before
  shape, a real interface contract, a mechanism walked to the edge case that breaks the naive
  version, and the failure table and decision record it forces.
- **Anti-pattern scan list** — 97 rows, coded by group (`P` problem, `R` requirements, `Z` capacity,
  `A` shape, `D` data, `I` interface, `X` detailed design, `F` failure, `S` security and privacy,
  `O` operability, `M` model, `C` decisions, `V` validation, `L` delivery), to work down while
  reviewing a design.

<!-- HARD-RULES:START -->
## System design rules

These are not aspirations. A design that violates one is a document, not a design. Rules 1–3 decide
whether the rest apply and where their edges are.

Rule 1 gates the standard on the change deciding or changing a system's shape. Rule 2 gates each
group on the concern named in its heading. Rule 3 draws the edges against the standards that own
boundaries, module interaction and implementation choice — cite them instead of restating them.

### Rules 1-3 — what applies

1. This standard applies to any change that decides or changes the shape of a system: a new application, service or major capability, a change to how data is owned or how the system scales, a new component or store, or any decision that will be expensive to reverse. A well-understood change inside an existing shape answers to the other standards only.
2. Each group applies when the concern named in its heading is in play — a design that stores nothing answers to no data rule, one that exposes no interface answers to no API rule, one with no probabilistic component answers to no model rule. A heading marked "always applies" is not conditional on anything else.
3. This standard owns what is being built, whether the shape meets requirements someone can check, and what was decided instead. It does not own where a boundary falls (`domain-driven-design`), what crosses it or how many deployables exist (`modular-monolith`), or which library, protocol or resilience pattern implements a choice, or how a chosen mechanism gets coded (`best-practices`, and the stack skill for that language).

### The problem before the solution — always applies

4. Write the problem first: who has it, what they do today, and what that costs them. A design that opens with a component diagram is a solution looking for a problem.
5. State goals as outcomes an observer outside the system could confirm, not as features or components.
6. State non-goals explicitly — things that could reasonably be goals and are deliberately not. A design with no non-goals has no scope, and every reviewer will assume a different one.
7. Name the success measure and its value today. "Faster", "more scalable" and "cleaner" are directions, not measures, and nothing can be compared against them later.
8. Consider doing nothing, and buying it, before designing it. Record why each was rejected — `best-practices` owns the search order for what already exists.
9. Record the constraints you do not control: deadline, budget, team size and skills, systems that already exist, regulation, and commitments already made. A design that ignores them is fiction with a diagram.
10. Name who the design is for, who reviews it and who decides. A design nobody is accountable for does not get built or maintained.
11. State the expected lifetime and rate of change. A one-quarter experiment and a system that must run for ten years are not designed the same way, and pretending otherwise over-builds one and under-builds the other.

### Requirements — functional and non-functional — always applies

12. Split every requirement into two documented groups: **Functional Requirements** — the discrete capabilities the system must perform — and **Non-Functional Requirements** — quality attributes with a number attached. Anything else is a preference, and it will lose to whatever is convenient during implementation.
13. Write each functional requirement as one testable capability: the actor who needs it, the trigger, and the acceptance criterion that decides whether it was met. A requirement with no actor is nobody's requirement and gets interpreted differently by every reader.
14. Prioritise functional requirements so a reader can tell what ships first without asking — P0 breaks the system's reason to exist, P1 is expected at launch, P2 can slip to a later increment.
15. Write each non-functional requirement as a scenario: what triggers it and from where, the state the system is in, the part affected, the response, and the measure of that response. The measure is the requirement; without it the scenario cannot be checked.
16. Define an indicator before a target: the proportion of good events out of all valid events, counted where the user experiences it, not where it is easy to instrument.
17. Pick the indicator from what the thing actually is — availability and latency for request paths, freshness, correctness and coverage for pipelines, durability for stores. They fail differently and one menu does not cover them.
18. State targets as percentiles over a stated window. An average hides the tail that every unhappy user is in, and a target with no window cannot be evaluated.
19. Keep to five or fewer non-functional objectives, covering the journeys that matter most. Thirty targets are nobody's target and will be ignored together.
20. 100% is not a target. State the level users actually need and treat the remainder as the budget you intend to spend on change; a system with no budget for failure has no budget for improvement either.
21. Say what the system may lose and what it must never lose. Those are different requirements, they lead to different designs, and conflating them buys durability where it was not needed and skips it where it was.
22. State what you are deliberately not optimising for. A design that optimises everything has no priority, so the priority will be set by whoever implements it first.
23. Every number carries its source and its date — who said it, from what evidence. An unattributed figure gets defended by nobody and revised by everybody.
24. A requirement nobody will measure after launch is deleted, not designed for.

### Capacity estimation — applies when load, data volume, growth or cost are in play

25. Put numbers on the system before drawing it: users, requests, payload sizes, data volume, growth rate. A shape chosen without them is chosen by taste and discovered to be wrong in production.
26. Derive load, do not assert it: from users, to actions per user per period, to the average per second, to a peak with a stated peak factor. Design for the peak; the average never happens.
27. Size the read and the write path separately. Their ratio decides caching, replication and the store far more than either total does.
28. Size storage as write rate × retention × replication, projected over the horizon the design claims to serve, and add the indexes, the copies and the backups.
29. Size bandwidth per hop and check the largest response against the narrowest link, including the client's network rather than only the data centre's.
30. Distinguish the working set from the total. Memory and cache sizing follow the working set; cost and store choice follow the total.
31. Concurrency is throughput × latency. Derive pool, worker and connection counts from it instead of picking a number that looks generous.
32. Give each user-visible operation a latency budget and divide it across its hops — network, each dependency's tail, and your own code. What remains after the dependencies is what you have to work with, and it is usually less than expected.
33. Every estimate shows its assumptions and its arithmetic, so a reader can disagree with an input rather than with the conclusion.
34. Estimates are order-of-magnitude. Three significant figures are a false claim about a future nobody knows.
35. State what saturates first and at what multiple of today's load. A design that cannot name its next bottleneck has not been sized, and the bottleneck will be named by an incident.

### Choosing the shape — applies when the architecture or a technology is being chosen

36. Choose the simplest shape that meets the stated requirements, and name the requirement that forces each departure from it.
37. Let the dominant non-functional requirement pick the shape. Design for the one or two that decide whether the system is worth having and accept the rest.
38. Default to one deployable with modules inside it — `modular-monolith` rules 4–6 own when that stops being the answer, and "we might need to scale" is not that moment.
39. Prefer the boring option: technology with known failure modes, in-house experience and someone who has operated it. Novelty is a small fixed budget, spent on the thing that differentiates the product and nowhere else.
40. Prefer a managed service to self-hosting and either to building it, and name who operates every component you keep. `best-practices` owns the order in which to search for what exists.
41. No tier, queue, cache, gateway, replica or abstraction enters the design without the requirement that demands it named beside it.
42. Synchronous request/response is the default. Asynchrony is chosen for a stated reason — decoupling, absorbing bursts, work longer than a request — and its cost in ordering, duplication and observability is stated with it.
43. Keep compute stateless and put state in something built to hold it. Session or scratch state on the instance turns every deploy, every scale-in and every crash into data loss.
44. The system fits on one page at component level: every box named with its responsibility and its technology, every line labelled with what flows and by what mechanism. An unlabelled arrow is a decision nobody made.
45. Name every external system the design depends on, what it promises, what it costs, and what the design does when the promise is not kept.
46. Design the seam between what you own and what you rent, so replacing a vendor is a contained change — `domain-driven-design` owns the anticorruption layer that keeps their model out of yours.
47. Match the shape to the team that will run it. A design that needs more independently operated parts than there are people to operate them will be operated by nobody.

### Data — applies when the design stores or moves data

48. Design the data before the interface. What is stored and what must be read decide the contract; the reverse produces a contract that cannot answer the questions the product asks.
49. Every fact has exactly one source of truth, named. Everything else is a derived copy, marked as one, and rebuildable from the source.
50. State the consistency each operation needs, operation by operation. A single global answer is too weak somewhere or too expensive everywhere.
51. Choose the store from the access patterns, written down: the queries, their frequency, their selectivity and their latency need. A store chosen before the queries gets worked around for the rest of its life.
52. List the dominant access patterns and show how each is served, naming the index, key or view that serves it.
53. Choose the partition or sharding key from the dominant access pattern, then check it for skew: the largest tenant, the newest time bucket, the most popular row.
54. State the replication and failover model with the recovery point and recovery time being promised, how failover is triggered, and how it is reversed.
55. Classify the data at design time — public, internal, personal, secret, regulated — and record for each class where it may live, how long, and who may read it.
56. State retention and deletion per class, including every copy: caches, replicas, backups, logs, exports, analytics stores and third parties you send it to.
57. Name which entities will change shape and what that will cost before the first row exists. `best-practices` owns expand/contract; the design owns knowing where it will be needed.
58. Design the migration and backfill of data that already exists in the same pass as the new model. A design that only serves new data is half a design and the other half is an emergency.

### API and interface design — applies when the design exposes or consumes an interface across a trust or process boundary

59. Give every interface that crosses a boundary a concrete contract: the method, endpoint or event name, the request, response or payload shape with types, and what each field means — not a name and a promise to define it later.
60. State an error taxonomy per interface: what each failure mode returns to the caller, and how a caller tells a retryable failure from one that is not.
61. State whether each interface is synchronous or asynchronous, and what the caller may assume about ordering and delivery — at-most-once, at-least-once or exactly-once — wherever it is not plain request/response.
62. State the versioning and backward-compatibility stance before the first caller exists: what changes are additive, what breaks a consumer, and how a breaking change ships. `best-practices` owns expand/contract mechanics.
63. Name every operation that must not run twice with the same effect, and where its idempotency key lives at the boundary, not only inside the implementation. `best-practices` owns the mechanics.

### Detailed design — the hardest parts — applies when a component's correctness or a stated non-functional target depends on a specific algorithm, protocol or state machine rather than off-the-shelf composition

64. Name the one to three sub-problems in the design that are actually hard — not every component, only the ones a reviewer would ask "how, exactly?" about.
65. For each, walk the mechanism step by step: the inputs, what it does with them, the output, and the edge case that breaks the obvious version of it.
66. Show the naive approach and why it fails before presenting the one chosen. A deep dive with no rejected alternative is a description, not a decision.
67. State the mechanism's cost where it matters — time, space, network round trips — at the scale sized earlier, not in the abstract.
68. Tie each deep dive back to the requirement or failure scenario that made it hard; a mechanism walk connected to nothing is trivia.

### Failure — always applies

69. Enumerate the failures: for each component and each dependency, what happens when it is slow, when it is down, when it returns something wrong, and when it comes back.
70. For each, state detection, blast radius, degraded behaviour and recovery. A failure with no designed degraded behaviour degrades into an outage.
71. Name every single point of failure. Accepting one is a decision with a stated cost; discovering one during an incident is not a decision.
72. Availability composes: a path through dependencies in series cannot beat their product, and nothing is more available than the least available thing on its critical path. Check the target against that arithmetic before promising it.
73. Keep the critical path short and name what is on it. Anything not required for the core outcome should be able to fail without the user noticing.
74. Bound the blast radius by design — partition users, tenants or regions into units that fail independently — and state which unit a given failure is confined to.
75. Decide overload behaviour in advance: what is shed, what is queued, what is refused, and in what order. Under load that choice is made either by the design or by the collapse.
76. State the trade between losing data and being unavailable. Both are legitimate answers; not choosing means the answer is whatever the code happens to do.
77. Every retry, replay and reprocess path in the design is safe to run twice — `best-practices` owns idempotency keys, dead-letter paths and retry budgets.
78. Recovery is designed and exercised, not assumed. Restoring a backup, rebuilding a derived store, replaying a stream and draining a queue each have a procedure and an expected duration.
79. State how the system behaves during its own deployment. Two versions running at once is a designed state with a defined contract between them, not an accident that resolves itself.

### Security and privacy — applies to any system with users, data or an external interface

80. Draw the trust boundaries on the same diagram as the components: where data changes hands, where trust changes level, and where your control ends.
81. Walk every element and every flow that crosses a boundary for spoofing, tampering, repudiation, disclosure, denial of service and elevation of privilege, and record what mitigates each or why it is accepted.
82. State the authorization model once, as a model: who the subjects are, what the resources are, who may do what, and the single layer that enforces it. `best-practices` owns the implementation defaults.
83. State the isolation model between tenants or customers, and what a single bug would have to do to cross it.
84. Name the secrets and keys the design needs, where they live, who can read them, and how they are rotated without downtime.
85. State which actions are audited, what each record contains, and who can read it and who cannot change it.
86. Treat everything arriving from outside a trust boundary as hostile, including another team's system, a vendor's callback and anything a model generated.
87. Name the regulatory, contractual and residency constraints as constraints, each with its design consequence. A residency requirement discovered after the data design redesigns the data layer.

### Operability and cost — always applies

88. State how you will know it works: which signal, measured where, and how it maps to each objective. A target with no measurement point is not yet a target.
89. Every component has a named operator and a stated way to be diagnosed, restarted, scaled and rolled back.
90. State the scaling signal and the headroom kept above normal load, and what a human does when the signal is misleading.
91. Design the deploy and the rollback together. A change that cannot be rolled back is split into steps that can be, or its irreversibility is stated as an accepted consequence.
92. State the cost model: cost per unit of work, what dominates it, and what it becomes at ten times the load. A design with no cost shape is hiding its tightest constraint.
93. Describe the worst day — traffic spike, dependency outage, bad deploy, corrupted data — as a path a person on call can follow, not as an aspiration.
94. Name what must be answerable in production and by which signal. `best-practices` owns telemetry, log and alerting mechanics; the design owns the questions they have to answer.

### Model-backed capability — applies when a model or other probabilistic component is in the design

95. State what the model is for and what a deterministic implementation would cost. A probabilistic component competing with a rule that would work needs a reason beyond novelty.
96. Treat every model call as a remote dependency that is slow, metered, sometimes wrong and sometimes unavailable, and design its timeout, its fallback and its cost ceiling with it.
97. State the accuracy requirement as a measure over a named evaluation set, held in version control and run in the build. Without one, quality is an anecdote and every change is a gamble.
98. Design what happens when the output is wrong: what is validated, what is reversible, and where a human decides. A consequential action is never taken on an unchecked generation.
99. Model input and output cross a trust boundary in both directions — retrieved content can carry instructions, and generated content can carry mistakes into your data.
100. State the cost per request, its ceiling, and what degrades when the ceiling is reached. Per-call pricing turns a traffic spike into an invoice.
101. Pin the model, prompt and parameters, and treat a change to any of them as a deployment with an evaluation gate and a rollback.

### Recording the decision — always applies

102. Every consequential decision is recorded beside the code: the context and the drivers, the options considered, the outcome, and the consequences accepted.
103. A record with one option is a rationalisation. List the real alternatives, including doing nothing, and state each one's strongest case before rejecting it.
104. Record the consequence accepted, not only the benefit wanted. A decision with no stated cost was not a decision.
105. Each record carries a date, an owner and a status. A superseded record is marked and kept, never edited or deleted: what was known at the time is the point of it.
106. Flag the decisions that are expensive to reverse and spend proportionally more on those. A store, a data model, a published contract and a boundary are one-way doors next to a library choice.
107. State what would make you revisit the decision — a number, a date or an event. A decision with no revisit trigger becomes a permanent constraint nobody chose.
108. The design document is the artifact, versioned with the code: problem, goals and non-goals, constraints, functional and non-functional requirements, capacity estimation, architecture, data, API and interface contracts, detailed design, integration, failure, security and privacy, operability and cost, decisions, validation, delivery, open questions. A section with nothing in it says "not applicable" and why.
109. Scale the document to the stakes. Several credible options behind a one-way door earn the full treatment; a change whose answer was never in doubt earns a paragraph, and writing more is a cost with no return.

### Validating the design — always applies

110. Walk the primary journeys end to end through the design, naming every component and store touched. A journey that cannot be traced is a gap in the design, not in the walk.
111. Walk each non-functional requirement's scenario against the design and show the measure is met, with the arithmetic. A design never checked against its own requirements has not been designed.
112. Walk the top failure scenarios and the busiest hour the same way.
113. Turn the properties that must keep holding into checks that run — a test, a metric, a query or an alert — so erosion appears in the build or the dashboard rather than in an incident.
114. Identify the riskiest assumption and reduce it first, with a spike, a load test or a prototype, before the design is committed to.
115. Have the design reviewed by whoever will operate it and by someone outside the work. A design reviewed only by its author is a plan.
116. Record the open questions with an owner and a date needed by. Unknowns are part of a design; claiming there are none is not.
117. Walk every API contract and every detailed-design mechanism against the requirement or failure scenario that motivated it. A contract or a mechanism nobody checked against its reason for existing is unvalidated by definition.

### Delivery and evolution — always applies

118. Slice the work into increments that each ship and each deliver something. A design that delivers nothing until everything is finished is a bet.
119. Build the thinnest end-to-end path first — one journey through every layer, in production — then broaden it. Depth before breadth finds the wrong assumptions while they are still cheap.
120. Say what is deliberately deferred and what would trigger building it, so a later reader can tell a decision from an omission.
121. For a system that already exists, design the transition as well as the destination: what runs in parallel, how traffic moves, how it moves back, and when the old path is deleted.
122. Keep each step reversible. A step that changes shape and moves data at the same time can only be rolled forward.
123. A design is finished when the system matches it. At the first divergence, correct the system or correct the document, and say which.
<!-- HARD-RULES:END -->

## The design document

One document per system or capability, versioned beside the code. Sections in this order, each
carrying what the rules require of it; nothing invented to fill a gap and nothing silently dropped.

```text
# <system or capability>          status · owner · date · reviewers
 1  Problem                who has it, what happens today, what it costs                    4, 7
 2  Goals / Non-goals      outcomes observable from outside; what is deliberately out       5, 6
 3  Constraints            deadline, budget, team, existing systems, regulation, commitments 9-11
 4  Functional Reqs        actor → capability → acceptance criterion, each prioritised       12-14
 5  Non-Functional Reqs    scenario, indicator, target and window per objective; error
                           budget; what may be lost; what is not optimised                   12, 15-24
 6  Capacity Estimation    users → load → peak; storage; bandwidth; concurrency; latency
                           budget per hop; what saturates first and at what multiple         25-35
 7  Architecture           one component diagram; per box: responsibility, technology,
                           operator; per line: what flows and how; the simplest shape and
                           the requirement forcing each departure                            36-47
 8  Data                   source of truth per fact; access patterns and what serves them;
                           store choice; partition key and skew; replication, RPO, RTO;
                           classification, retention, residency; migration and backfill      48-58
 9  API & Interface Design contract per interface: shape, errors, sync/async and delivery
                           semantics, versioning and compatibility, idempotency              59-63
10  Detailed Design        the 1-3 hardest mechanisms, walked step by step, naive approach
                           and why it fails, cost, tied back to the requirement it serves    64-68
11  Model-backed capability what the model is for, its fallback and cost ceiling, its
                           evaluation set, human checkpoints — omit if not applicable        95-101
12  Integration            what crosses each boundary and by which mechanism, external
                           systems and their promises                    modular-monolith, 45
13  Failure & Resilience   per component and dependency: detection, blast radius, degraded
                           behaviour, recovery; SPOFs; overload behaviour; availability
                           arithmetic against the target                                     69-79
14  Security & Privacy     trust boundaries on the diagram; threats per crossing flow and
                           their mitigations; authorization model; isolation; secrets;
                           audit; regulatory and residency constraints                       80-87
15  Operability & Cost     signal and measurement point per objective; scaling signal and
                           headroom; deploy and rollback; cost per unit of work and at 10×;
                           the worst day as a path                                           88-94
16  Decisions              per decision: drivers, options with their strongest case, outcome,
                           consequence accepted, reversibility, revisit trigger             102-109
17  Validation             journeys walked; requirement scenarios checked with arithmetic;
                           failure walk; API and mechanism walks; checks that catch erosion;
                           riskiest assumption and how it is reduced first                  110-117
18  Delivery & Rollout     increments; the thinnest end-to-end path; transition and rollback
                           for what exists; what is deferred and what triggers it          118-122
19  Open Questions         question → owner → needed by                                     116
```

## Procedure

Running this standard end to end, from an idea to a written, self-checked document on disk.

Terminal state: a design document on disk and a short summary in chat. Write no implementation
code, scaffold nothing, install nothing.

### 1. Is a design warranted?

Apply rules 1 and 109. A well-understood change inside a shape that already exists gets one
paragraph — the answer, and why it needed no document — and nothing else. Otherwise continue.

### 2. Classify the complexity, out loud

State in one line: how many distinct actor journeys the idea implies, how many integrations and
stores, and whether multi-region, regulated data or a genuinely hard mechanism is in play. Tag it:

- **Narrow** — one or two journeys, a well-trodden shape, no hard sub-problem. The question round
  (step 4) can close as soon as the shape, store and loss tolerance are settled. Detailed Design
  may be "not applicable" if nothing in the design is actually hard (rule 64's own gate).
- **Complex** — several journeys, more than one integration or store, or a mechanism that isn't
  off-the-shelf composition. The question round does not close on a fixed number of calls — it
  closes when doubt runs out (step 4). Detailed Design covers 2–3 mechanisms, not fewer, unless the
  design genuinely doesn't need one.

### 3. Context before questions

Do not ask what you can find. Establish from the repository: whether one exists, its language and
frameworks, its datastore, its deployment shape, its existing modules, and any design docs, ADRs or
`CLAUDE.md` already present. No repository: the design is greenfield — say so and move on.

### 4. Question rounds — keep going as long as there is doubt

Ask only what changes the design. Use `AskUserQuestion`, up to four questions per call, no cap on
the number of calls. Every question carries a concrete recommended option first.

A decision-critical unknown is any of: the shape, the store, the consistency model, what may be
lost versus what must never be lost, the contract each interface needs, and — for a complex design
— which sub-problem earns the Detailed Design deep dive. Keep issuing rounds until every one of
these is answered or explicitly defaulted with a recorded rationale (step 5). Stop early only once
the user has actually skipped a round or answered "you decide" — not before a first real attempt.

When an answer is vague, numberless, or contradicts an earlier one, the next call's first question
is a clarifying follow-up on that same point — do not carry an unresolved one into a new category.

Ask in this order of value, adding a round rather than dropping a category while doubt remains:

1. What it must do — journeys as functional requirements, actor + "done", and what's explicitly out.
2. Scale and shape of load — users or events, growth, burstiness. Derive the rate (25–26); never ask for one.
3. What must never fail or be lost, and what may (21).
4. Consistency and freshness — where a stale read is unacceptable (50).
5. Who consumes each interface, and what they expect from it (59–62).
6. Hard constraints — deadline, team, budget, regulation, residency, existing systems (9, 87).
7. Where it runs and what it may depend on (40).
8. For a complex design, what's actually hard — the sub-problem(s) needing a mechanism walk (64).

### 5. Defaults you apply without asking

Each is the standard's own answer, overridden only by a stated requirement and recorded as a
decision when it is: one deployable with modules inside it (38; `modular-monolith` 4–6), and a
design with several deployables names the driver in the document; the boring option, managed before
self-hosting before building (39, 40), and where the repository already has a stack, that stack is
the boring option; single region, synchronous request/response, one relational source of truth
until forced otherwise (36, 42); no tier without its requirement named beside it (41). Every
requirement the user skipped or waved off becomes an assumption in the document and an open
question with an owner and a "needed by" date (116) — never a silent guess.

### 6. Write the document

Path: `docs/design/<kebab-slug>.md`, created if needed, unless the user names another. Follow the
outline above exactly, in order, all nineteen sections — a section with nothing in it says "not
applicable" and why (108).

- Do the arithmetic visibly, with its assumptions (33, 34) — not in your head.
- Split Requirements into Functional (actor, priority, acceptance criterion — 13, 14) and
  Non-Functional (a scenario with a measure — 15–24).
- Give every boundary-crossing interface a real contract — types, error taxonomy, sync/async and
  delivery semantics, versioning (59–63) — not a named endpoint with no shape.
- Walk the 1–3 hardest mechanisms in Detailed Design: the naive approach and why it fails, the
  chosen one step by step, its cost, the requirement it serves (64–68). Narrow and nothing hard:
  "not applicable" and why.
- One component-level `mermaid` diagram: every box its responsibility and technology, every edge
  what flows and by what mechanism (44).
- Mark every assumption inline as `Assumption:`, mirrored in Open Questions with an owner and date (116).
- Cite the sibling standard instead of re-deciding what it owns: boundaries and the domain model to
  `domain-driven-design`, what crosses a boundary to `modular-monolith`, libraries, protocols,
  resilience and migration mechanics to `best-practices`; `golang`/`postgres` for that technology's
  form of these.
- Decisions carries a record per consequential decision: alternatives, consequence accepted,
  reversibility, revisit trigger (102–107).
- Before writing a sentence in Architecture, API & Interface Design or Detailed Design: would it be
  equally true of a different system? If yes, delete it and write the version only true of this one.

### 7. Check it before showing it

Work the scan list and the validation group over the draft, and fix what fails rather than
reporting it. It doesn't leave this step until: every functional requirement has an actor,
priority and acceptance criterion (13, 14); every non-functional requirement has a measure, window
and measurement point (15, 18, 88); every number shows its source and ties to this system's stated
scale (23, 33); every boundary-crossing interface has a concrete contract (59); the hardest
mechanisms are walked to the edge case that breaks the naive version (64–66); every dependency has
a failure-table row and the availability target survives the arithmetic (72); every component
traces to a requirement (41) and every primary journey traces through the components (110); trust
boundaries are on the diagram and every crossing flow is walked (80, 81); there is a cost model
(92), a transition plan if a system already exists (121), and a first increment that ships alone
(118, 119); non-goals, what's not optimised for, and open questions are all non-empty (6, 22, 116).
Then one final genericness pass over Architecture, API & Interface Design and Detailed Design: any
sentence that would survive word-for-word in a design for a different system gets rewritten or cut.

### 8. Report

In chat, briefly — the document holds the detail: the complexity tag and why; the shape; the
sizing headline and what saturates first; the hardest mechanism covered and the naive approach it
beat; the three decisions that matter most, each with the alternative rejected; the open questions
and the riskiest assumption made on the user's behalf; the path to the document. Then stop — do
not start building, and do not plan the implementation; that is `implementation-planning`'s job,
run separately once this design is approved.

## What forces the shape

Read the dominant requirement, not the preference. Nothing on the right enters a design without the
requirement on its left written beside it (rule 41).

| The requirement that dominates | What it forces | Settled by |
| --- | --- | --- |
| Two facts must be consistent in one transaction | One store, one owner, one module | `modular-monolith` 16, 63 |
| Reads vastly outnumber writes, and the read shape differs | A derived read model or replica, and a stated staleness window | 27, 50; `domain-driven-design` 71 |
| Arrival rate is bursty and the work outlives the request | A queue with a stated depth, backlog behaviour and duplicate handling | 42, 75, 77 |
| One workload must scale on a different resource | A separate deployable, and only for that workload | `modular-monolith` 4 |
| A tight tail-latency target | Fewer hops, no synchronous fan-out, a budget per hop | 32, 72, 73 |
| Data must survive the loss of a machine or a region | Replication with a stated RPO and RTO, and a tested restore | 54, 78 |
| Records must stay in a jurisdiction | Partition by region; no global write path; no cross-region copy | 55, 87 |
| An external caller you cannot coordinate a release with | A versioned contract and a compatibility policy before it ships | 62 |
| Base load is low and spikes are unpredictable | Managed or on-demand compute, with a cost ceiling | 40, 92 |
| One tenant must never see another's data | A stated isolation model and the bug that would defeat it | 83 |
| Availability higher than a dependency's | Remove it from the critical path, or lower the target | 72, 73 |
| Nothing above is dominant | The simplest shape, one deployable, boring technology | 36, 38, 39 |

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
| "Fast and highly available" as the requirement | Nothing can fail the design, so nothing constrains it | A scenario with a measure, and a target with a window (15, 18) |
| Drawing the components before doing the arithmetic | The shape is chosen by taste and disproved by traffic | Numbers first, then boxes (25, 26) |
| An average latency target, or a 100% availability target | Ships the tail every unhappy user sits in; no budget for change | A percentile over a window; a level with a stated error budget (18, 20) |
| Microservices with no driver, or a new datastore for one feature | The distributed premium refunded by nothing, or a second thing to operate | One deployable and the boring option until a driver appears (38, 39) |
| Choosing the store before writing the queries | Every future query becomes a workaround | Access patterns first, then the store (51, 52) |
| An interface with a name and no contract | Every caller guesses the shape and guesses differently | A typed request/response and an error taxonomy before the first caller (59, 60) |
| No failure enumeration, or retries as the whole resilience plan | Degraded behaviour invented mid-incident; amplified load at the worst moment | A row per dependency; overload behaviour decided in advance (69, 70, 75) |
| A component diagram standing in for the hard part | The one thing a reviewer would ask "how, exactly?" is never answered | Name it, and walk the mechanism (64, 65) |
| No cost model | The tightest constraint on the design is the one nobody sized | Cost per unit of work, and at 10× (92) |
| An alternatives section with one option | The decision cannot be reviewed, only ratified | Real options, each with its strongest case (103) |
| A model call with no fallback or evaluation set | Silent quality regressions and an unbounded bill | Timeout, fallback, cost ceiling, evaluation in the build (96, 97, 100) |
| Designing the destination only | The system that exists has no way to become the one described | A transition with reversible steps (121, 122) |

## Depth

### One running example — a signed-in customer's order

"The service must be fast, highly available and able to scale" is unfalsifiable. Split it:

```text
Functional   FR-14 (P0) — customer submits an order from the mobile app. Accepted when
             the order is durably stored and the confirmation screen renders within the
             non-functional target below.
Non-func     Scenario   Same trigger, Monday 09:00-11:00 peak, against the order service.
             Measure    p99 < 400 ms, p50 < 120 ms, at the mobile client.
             Indicator  orders accepted and stored / orders submitted, at the API edge.
             Objective  99.9% over a rolling 28 days · budget 0.1% ≈ 43 min/month.
             May lose   Draft carts, recommendation state, analytics events.
             Must not   An accepted order, a payment record, an audit entry.
             Not for    Cross-region survival — single region until EU launch.
```

Capacity, derived rather than asserted:

```text
Assumption   200k DAU, 12 actions each, 10% writes, 2 KB/write, 90-day retention, 3 replicas.
             Source: this quarter's analytics, 2026-08-10.
Average      200k × 12 ÷ 86,400 ≈ 28 req/s
Peak         × 5 (Monday factor) ≈ 140 req/s, of which ~14 writes/s
Storage      14/s × 86,400 × 2 KB ≈ 2.4 GB/day → 90 days ≈ 220 GB × 3 ≈ 650 GB + indexes ≈ 1 TB
Latency      400 ms budget = 60 ms network + 120 ms payment tail + 40 ms DB + 30 ms queue
             → 150 ms left for our own code
Saturates    The payment provider's 20-connection limit, at roughly 3× today's peak
```

The interface FR-14 needs — a contract, not a name:

```text
POST /v1/orders                                        (synchronous, at-most-once)
  → 201 {order_id, status: "accepted"|"pending_payment", confirmed_at}
  → 402 {error: "payment_declined", retryable: false}
  → 503 {error: "payment_provider_unavailable", retryable: true, retry_after_s}
Idempotency-Key header required; a replayed key returns the original response.
```

Failure, the mechanism the pending-order path needs, and the decision that forced it:

```text
Payments down (69)   Queue as pending, notify, no charge. Blast radius: checkout only.
Order store down     Read-only from replica. Failover 90 s, RPO 10 s.

Mechanism (65)   Reconcile a pending order once the provider recovers.
Naive (66)       Poll every order every minute — cost grows with backlog, and a
                 thundering herd hits the provider the moment it recovers.
Chosen           Dedupe key = order_id; drain a FIFO queue at a capped rate (10/s, below
                 the provider's 20-connection limit), settling each order exactly once.
Cost (67)        O(1) per order; bounded by the rate limit, not by backlog size.

Decision   Accept pending orders when the payment provider is down.
Drivers    Order acceptance is 99.9%; the provider publishes 99.5% (rules 72, 21).
Options    1. Fail checkout while down — simplest; caps our availability at the provider's.
           2. Accept as pending, settle via the queue above — chosen.
           3. Second provider behind an abstraction — best availability, not justified
              at this volume.
Outcome    Option 2. Consequence: a pending state customers can see. Reversible cheaply
           until pending orders appear in the API (rule 106). Revisit at 0.5% monthly
           unavailability, or at EU launch.
```

## Anti-pattern scan list

Codes: `P` problem, `R` requirements, `Z` capacity, `A` shape, `D` data, `I` interface,
`X` detailed design, `F` failure, `S` security and privacy, `O` operability and cost, `M` model,
`C` decisions, `V` validation, `L` delivery.

| Code | Anti-pattern | Settled by |
| --- | --- | --- |
| P1 | Opens with a diagram or a technology, no non-goals, or success stated as a direction with no baseline | 4, 6, 7 |
| P2 | Doing nothing and buying it were never considered | 8 |
| P3 | Deadline, budget, team or regulation absent from the design | 9 |
| P4 | No named owner, reviewer or decision-maker | 10 |
| P5 | An experiment and a decade-long system designed alike | 11 |
| R1 | Functional and non-functional requirements not separated, or a quality attribute with no number | 12 |
| R2 | A functional requirement with no actor, no acceptance criterion, or no priority | 13, 14 |
| R3 | A scenario with no response measure | 15 |
| R4 | A target with no indicator, or an indicator measured where it is convenient | 16 |
| R5 | Availability used as the only indicator for a pipeline or a store | 17 |
| R6 | An average or a mean as the target | 18 |
| R7 | More than five objectives not tied to a journey, or a 100% target with no error budget | 19, 20 |
| R8 | What may be lost and what must never be lost not separated | 21 |
| R9 | Nothing named as deliberately not optimised for, or a number with no source or date | 22, 23 |
| R10 | A requirement nobody will measure after launch | 24 |
| Z1 | Components drawn before any number exists, or load asserted rather than derived | 25, 26 |
| Z2 | One load figure covering reads and writes | 27 |
| Z3 | Storage sized without retention, replication, indexes or growth | 28 |
| Z4 | Payload and bandwidth never computed, or only for the data centre | 29 |
| Z5 | Cache sized against the total data rather than the working set | 30 |
| Z6 | Pool, worker or connection counts chosen by feel | 31 |
| Z7 | A latency target never divided across hops | 32 |
| Z8 | An estimate with no visible assumption or arithmetic, or carried to three significant figures | 33, 34 |
| Z9 | No statement of what saturates first, or at what multiple | 35 |
| A1 | A departure from the simplest shape with no requirement named, or a shape satisfying every requirement at once | 36, 37 |
| A2 | Several deployables with no driver from `modular-monolith` 4 | 38 |
| A3 | A new language, framework or datastore adopted for one feature, or something a managed service already provides | 39, 40 |
| A4 | A queue, cache, gateway or tier with no requirement beside it | 41 |
| A5 | Asynchrony by default, its cost in ordering and duplication unstated | 42 |
| A6 | Session or scratch state held on the compute instance | 43 |
| A7 | An unlabelled arrow, or a box with no technology or responsibility | 44 |
| A8 | An external dependency with no stated promise or failure behaviour | 45 |
| A9 | A vendor's model reaching into the domain, or more independently operated parts than there are operators | 46, 47 |
| D1 | Endpoints or a contract designed before the data, or two components able to write the same fact | 48, 49 |
| D2 | One global consistency answer for every operation | 50 |
| D3 | A store chosen before the access patterns were written down | 51 |
| D4 | A dominant access pattern with nothing named that serves it | 52 |
| D5 | A partition key never checked for skew or a hot tenant | 53 |
| D6 | No RPO, RTO, failover trigger or way back | 54 |
| D7 | Personal, secret or regulated data left unclassified | 55 |
| D8 | Retention stated for the primary store but not for the copies | 56 |
| D9 | No idea which entities will change shape, or existing data's migration left out | 57, 58 |
| I1 | An interface with a name and no contract for its request, response or payload | 59 |
| I2 | No error taxonomy, or sync/async, ordering and delivery semantics left unstated | 60, 61 |
| I3 | No versioning or compatibility stance before the first caller exists | 62 |
| I4 | An operation that must not run twice with no idempotency key at the boundary | 63 |
| X1 | Every component treated as equally simple; the hard sub-problem never named | 64 |
| X2 | A deep dive that names a mechanism but never walks it, or shows no rejected naive alternative | 65, 66 |
| X3 | A mechanism with no stated cost at the sized scale | 67 |
| X4 | A deep dive connected to no requirement or failure scenario | 68 |
| F1 | No enumeration of slow, down, wrong and recovering per dependency, or no designed degraded behaviour | 69, 70 |
| F2 | An unacknowledged single point of failure | 71 |
| F3 | A target higher than the product of its critical-path dependencies | 72 |
| F4 | Non-essential work on the critical path | 73 |
| F5 | Blast radius unbounded — one failure reaches every user | 74 |
| F6 | Overload behaviour left to be discovered under load | 75 |
| F7 | The data-loss versus unavailability trade never made, or a replay path not safe to run twice | 76, 77 |
| F8 | Recovery assumed rather than described and timed | 78 |
| F9 | Two versions running at once treated as an accident | 79 |
| S1 | No trust boundaries on the diagram, or no threat walk over the flows that cross them | 80, 81 |
| S2 | Authorization described per endpoint instead of as one enforced model | 82 |
| S3 | Tenant or customer isolation unstated | 83 |
| S4 | Secrets, key custody and rotation unaddressed | 84 |
| S5 | Privileged actions with no audit record, or a mutable one | 85 |
| S6 | Another team's system, a vendor callback or model output trusted | 86 |
| S7 | A residency or regulatory constraint discovered after the data design | 87 |
| O1 | No signal named for an objective, or no measurement point | 88 |
| O2 | A component with no named operator or no way to be diagnosed | 89 |
| O3 | Autoscaling with no stated signal or headroom, or a change with no rollback path | 90, 91 |
| O4 | No cost per unit of work, and no idea what dominates it | 92 |
| O5 | The worst day described as an aspiration rather than a path | 93 |
| O6 | Production questions nobody has mapped to a signal | 94 |
| M1 | A probabilistic component where a deterministic one would do | 95 |
| M2 | A model call with no timeout, fallback or cost ceiling | 96 |
| M3 | Accuracy claimed with no evaluation set in version control | 97 |
| M4 | A consequential action taken on an unchecked generation | 98 |
| M5 | Retrieved or generated content treated as trusted | 99 |
| M6 | Per-call pricing with no ceiling, or model, prompt or parameters changed with no evaluation gate | 100, 101 |
| C1 | A consequential decision with no record | 102 |
| C2 | One option written as a strawman, or a decision recording its benefit and not its cost | 103, 104 |
| C3 | No date, owner or status; a superseded record edited in place | 105 |
| C4 | A one-way door decided as casually as a library choice | 106 |
| C5 | No revisit trigger, so the decision becomes a permanent constraint | 107 |
| C6 | A document with sections silently missing | 108 |
| C7 | A full design for an obvious change, or a paragraph for a one-way door | 109 |
| V1 | A primary journey that cannot be traced through the design | 110 |
| V2 | A non-functional scenario never checked against the design, or checked without arithmetic | 111 |
| V3 | Failure scenarios and the busiest hour never walked | 112 |
| V4 | A property that must hold with no check that would catch its erosion | 113 |
| V5 | The riskiest assumption left untested | 114 |
| V6 | Reviewed only by its author, or never by an operator, or open questions with no owner | 115, 116 |
| V7 | An API contract or a detailed-design mechanism never checked against why it exists | 117 |
| L1 | Nothing delivered until everything is finished, or breadth before the first end-to-end path exists | 118, 119 |
| L2 | Deferred work indistinguishable from forgotten work | 120 |
| L3 | A destination with no transition for the system that exists | 121 |
| L4 | One step that changes shape and moves data at once | 122 |
| L5 | Document and system diverged, with neither corrected | 123 |
