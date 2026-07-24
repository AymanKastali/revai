# Discovery & modeling techniques (EventStorming, domain storytelling, example mapping)

## Contents
EventStorming (big-picture, process-level, design-level) · domain storytelling · example mapping ·
how each feeds strategic and tactical modeling · a worked example.

Strategic and tactical modeling both assume the boundaries, events, and rules are already known.
They rarely are at the start — they're discovered, with the people who actually run the process, not
guessed at from an org chart or a hunch. This reference is the feeder: it produces the raw material
(`reference/strategic-design.md` turns it into bounded contexts and ubiquitous language;
`reference/tactical-patterns.md` turns it into aggregates, value objects, and domain events). It
doesn't compete with either — running it is how you earn the right to skip guessing.

## Rules

- **Run discovery before committing to a boundary.** A bounded context or aggregate drawn without
  ever talking to a domain expert is a guess wearing a diagram. Discovery is cheap; a wrong boundary
  discovered after code exists is not.
- **EventStorming — big-picture.** Put every domain event (past tense, orange sticky) that happens
  in the process on a timeline, contributed by whoever knows a piece of it, with no filtering for
  "is this in scope." Mark **hotspots** — points of confusion, disagreement, or known pain — instead
  of resolving them on the spot. This pass finds candidate bounded-context boundaries: clusters of
  events that cohere, and the seams between clusters where vocabulary or ownership visibly shifts.
- **EventStorming — process level.** Take one cluster from the big picture and add **commands**
  (blue, the trigger), **actors** (who/what issues the command), and **policies** (yellow, "whenever
  X happens, do Y" — the reactive rules that turn one event into the next command). This pass
  surfaces the process as command → event → policy → command chains, which is the shape a Saga/
  process manager formalizes later (see `reference/process-managers-and-integration.md`) when a
  chain crosses aggregates or contexts.
- **EventStorming — design level.** Group the events for one cluster into candidate **aggregates**
  (the boundary that must be consistent to produce that sequence of events) and **read models** (what
  a user needs to see to issue the next command). This pass's output maps directly onto
  `reference/tactical-patterns.md` — don't skip straight here from the big picture; process level is
  what makes the aggregate boundaries defensible instead of guessed.
- **Domain storytelling** when the process is more narrative than event-driven — a domain expert
  walks through a concrete scenario as **actor → activity → work object → actor**, recorded as a
  simple pictographic sentence, not a diagram tool's formalism. Good for onboarding a new context or
  when the events themselves aren't yet agreed on. The nouns and verbs that recur across stories are
  the first draft of the ubiquitous language.
- **Example mapping** to pin down a specific rule before modeling it. For one **rule**, elicit
  concrete **examples** (including edge cases) and **questions** (open issues, parked, not resolved
  in the room). A rule with no example is not understood yet — don't model it as an invariant until
  it has one; a question that can't be answered in the room becomes an explicit open item, not a
  silent assumption.
- **Don't over-formalize a small, well-understood rule.** These techniques earn their cost on
  processes that are genuinely unclear or cross several people's knowledge. A single, already-agreed
  rule doesn't need an EventStorming session — write the example down and move on.
- **Capture hotspots and open questions as artifacts, not memory.** A hotspot or an example-mapping
  question that isn't written down gets silently resolved by whoever codes it first, often wrong.

## Checklist

- [ ] Every bounded-context boundary in the design traces back to a discovery session, not a guess
- [ ] Big-picture EventStorming produced a full event timeline before any aggregate was drawn
- [ ] Hotspots and open questions from discovery are recorded, not silently resolved in code
- [ ] Every proposed aggregate maps to a design-level EventStorming cluster or an example-mapped rule
- [ ] Recurring nouns/verbs from domain storytelling became the ubiquitous language, not synonyms left
      to coexist
- [ ] A rule went into the model only once it had a concrete example, not just a description

## Examples

### From a big-picture EventStorming timeline to a bounded context and an aggregate

A retailer's fulfillment process, timelined in one big-picture session:

```
OrderPlaced → PaymentAuthorized → StockReserved → PaymentCaptured → OrderShipped → InvoiceIssued
                                        ▲ hotspot: "what if stock isn't available at authorize time?"
```

Reading the timeline for where vocabulary and ownership shift: `OrderPlaced`/`OrderShipped` belong to
**Ordering**, `PaymentAuthorized`/`PaymentCaptured` to **Payments**, `StockReserved` to
**Inventory**, `InvoiceIssued` to **Billing** — four candidate bounded contexts, not one. The hotspot
on `StockReserved` becomes an explicit open question for `reference/strategic-design.md`'s
integration choice between Ordering and Inventory (resolved there as a policy: `PaymentAuthorized` →
command `ReserveStock`, handled by Inventory) — it is not resolved by guessing during the session.

Design-level pass on the Ordering cluster alone: `OrderPlaced`/`OrderShipped` cohere around one
consistency boundary (an order's state transitions) → one aggregate, `Order`. The read model "order
status for the customer" doesn't need to load that aggregate — a candidate query-side read model per
`reference/architecture-and-layering.md`.
