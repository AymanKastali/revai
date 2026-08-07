# Extraction to microservice

## Contents
The three extraction-readiness preconditions · strangler-fig mechanics · named anti-patterns · closing
note.

Most modules stay in the monolith indefinitely. This file exists to make extraction **safe when it's
genuinely warranted** — not to encourage treating every module as an eventual microservice.

## The three extraction-readiness preconditions

The same hygiene the other four references in this skill already enforce day-to-day — not new
criteria invented specifically for extraction day:

1. **The module owns its schema outright, zero cross-module joins.** Already required at the
   schema-per-module tier — see `reference/data-isolation-and-persistence.md`.
2. **Every inbound/outbound contact already goes through its published interface or events, never an
   internal type reached into directly.** Already required by
   `reference/in-process-communication.md` and enforced in CI by
   `reference/boundary-enforcement-and-fitness-functions.md`'s fitness function.
3. **Its dependencies are injected at the composition root rather than statically wired.** Already
   `domain-driven-design/reference/architecture-and-layering.md`'s existing rule.

If any of these three isn't already true and proven out in practice — not just true on paper the week
before extraction — fix it and let it hold for a while under real load first. Extraction on top of a
boundary that's never actually been tested is extraction on faith.

## Strangler-fig mechanics

1. Stand up the new service, implementing the same published interface the module already exposes
   in-process.
2. Add a routing layer that can send the module's traffic to *either* the in-process module or the new
   service — behind a flag.
3. Cut over gradually: shadow traffic first (compare outputs, don't act on the new service's result
   yet), then a small percentage, then ramp — never an instant, all-at-once switch.
4. Once the new service is the sole source of truth, delete the monolith's copy of that module. Never
   leave both writing the same table "just in case."

## Named anti-patterns (Sam Newman)

- **Extracting before observability, CI/CD, and routing are solid.** A poorly-operated microservice is
  worse than the monolith it replaced.
- **A table written to by both the monolith and the new service** — a distributed monolith: all of the
  operational cost of a service boundary, none of the consistency guarantees of either a monolith or a
  properly decoupled service.
- **Keeping the old in-monolith code "just in case," instead of deleting it once the new service is
  live.** Dead code that could silently start receiving traffic again is a bug waiting to happen.

## Closing note

Extraction is the exception this skill exists to make safe, not its goal. A module that never gets
extracted and stays a clean, well-bounded part of the monolith for its entire life is this pattern
working exactly as intended.

## Checklist

- [ ] All three extraction-readiness preconditions are verified true in practice, not just asserted
- [ ] The cutover plan includes shadow/canary traffic before a full switch, gated behind a flag
- [ ] The monolith's copy of the module is deleted once the new service is the sole source of truth —
      no dual-write left behind
- [ ] Extraction is justified by a real, stated need — not applied by default to every module
