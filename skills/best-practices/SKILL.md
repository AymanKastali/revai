---
name: best-practices
description: Use whenever writing code or choosing an implementation approach — anywhere in Build/Refine of feature/bugfix/refactor, or when weighing options at a Decide gate. Owns the habit of preferring a standard, well-known solution (stdlib, an established library, a recognized protocol/format, or a documented design pattern/algorithm) over inventing a bespoke one, and the order to search in. Does not restate any one domain's concrete best practice — that's api-design, data-access-patterns, safe-schema-changes, error-handling-and-logging, resilience-and-timeouts, hexagonal-architecture, domain-modeling, naming-and-structure, tdd, and the rest; this is the meta-habit that sends you to them, or beyond them, instead of inventing from scratch. Not architecture-level fit — designing-architecture and divide-and-conquer own that layer, one level up.
---

# Best practices (prefer the standard solution over inventing one)

Most problems that feel novel in the moment aren't. Someone has already solved retry logic,
pagination, idempotency keys, rate limiting, cache eviction, password hashing, date/time handling,
ID generation, config parsing, and auth flows — and the solution is well-known, widely used, and
already sitting in a standard library or a dominant package. Reinventing it costs time now and
correctness later (the standard solution has already had its edge cases found by everyone else).
This skill owns the habit of checking before you build, and where to look. It doesn't own the
concrete answer for any one domain — the backend skills already encode those; this is what sends
you to them, or past them, instead of freestyling.

## The habit

Before writing bespoke code, or designing a bespoke shape for a problem, ask: **has this already
been solved, and by what standard?** Treat that question as a required step, not an afterthought —
ask it *before* the first line of a new function or type, not during self-review after the fact.

## The search order

Work down this list. Only drop to the next tier when the current one is checked and doesn't fit —
not skipped out of habit or unfamiliarity.

1. **Standard library, or something already a dependency in this repo.** The cheapest, safest
   option — no new dependency, already vetted by the ecosystem and (if already used here) by this
   codebase.
2. **The ecosystem's dominant, well-maintained library for exactly this problem.** Check it against
   real project constraints — license, dependency weight, maintenance status, whether it's already
   in the lockfile under a different name — before adopting it.
3. **An established protocol, format, or convention**, even when you implement it by hand — RFC
   3339 timestamps, semver, JSON:API/OpenAPI shapes, OAuth2/OIDC flows, HTTP status codes used as
   intended. No library required; the standard is the shape, not a package.
4. **A recognized design pattern or algorithm from the literature** — exponential backoff with
   jitter, token-bucket rate limiting, LRU/LFU eviction, circuit breaker, the outbox pattern,
   expand-contract migration. Known, named, and documented elsewhere.

Only after exhausting 1–3 does bespoke enter — and even then, shape it like the recognized pattern
in tier 4 rather than inventing structure freestyle.

## When bespoke is right anyway

- The behaviour is genuinely domain-specific and nothing standard covers it.
- A real project constraint rules the standard option out — license, dependency weight, platform,
  a measured performance need the standard option can't meet.
- The standard option is a poor fit, and you can say exactly why.

Name the reason wherever the decision is recorded (plan, diagnosis, PR summary) — "didn't think to
check" is never a reason. And keep this proportional: a one-off, low-stakes internal helper doesn't
need a formal tier-by-tier comparison. The habit is a quick check for anything that recurs across
projects, not ceremony for every line of code.

## Where this fires

This is an **always-on** bar, held throughout Build and Refine alongside `naming-and-structure` —
every implementation choice gets this lens, not just the big architectural ones. It also biases
option-generation at Decide time: when `superpowers:brainstorming` surfaces candidate approaches,
lead with the standard/established one and require a stated reason for a bespoke option to win.

## What this hands off

Once the answer is "yes, use the established thing," the concrete "what's standard here" for a
backend problem lives in the relevant revai skill — `api-design`'s REST conventions,
`resilience-and-timeouts`'s backoff/circuit-breaker, `safe-schema-changes`'s expand-contract,
`data-access-patterns`'s one-aggregate-per-transaction, `naming-and-structure`'s naming and shape.
This skill doesn't re-derive their content — it's the nudge that sends you looking. And
"should this be built at all, and how" at the system level stays `designing-architecture`'s and
`divide-and-conquer`'s job; this operates one level down, at the individual implementation choice.

## The rules

- Ask the question before building bespoke, every time something might already be solved
  elsewhere — not only when it's convenient to ask.
- Search in order: stdlib/existing dependency → dominant library → established protocol/pattern →
  bespoke. Only skip a tier with a real, stated reason.
- Bespoke always needs a stated reason. Unfamiliarity or preference isn't one.
- Don't gold-plate. Reaching for a heavyweight library or a "proper" protocol on a one-off,
  low-stakes throwaway is its own violation of this same principle — proportional judgement, not
  reflexive ceremony.
- When several standards are equally dominant, name the trade-off and pick one — don't stall in
  comparison-shopping.
