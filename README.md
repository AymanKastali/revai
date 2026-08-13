# revai — a code-standard harness for Claude Code

**revai** is a Claude Code plugin carrying engineering standards, plus the machinery that makes an AI
actually follow them.

Four are stack-agnostic and always in context:

| Standard | Rules | Canonical to |
| --- | --- | --- |
| `clean-code` | 56 | *Clean Code* (Robert C. Martin) — names, functions, comments, formatting, objects and data structures, error handling, classes, the four rules of simple design |
| `best-practices` | 99 | The published canon — API guidelines (Zalando, Microsoft, Google), RFC 9457 and 3339, twelve-factor config, *Release It!* stability patterns, expand/contract migrations, OWASP defaults, SRE golden signals, at-least-once messaging, the test pyramid |
| `domain-driven-design` | 74 | Modern DDD (Evans, Vernon, Khononov) — subdomains, bounded contexts, ubiquitous language, context mapping, aggregates, value objects, services, domain and integration events, hexagonal layering, sagas |
| `modular-monolith` | 95 | The modular-monolith canon — Grzybek's primer, integration-styles and architecture-enforcement series, Simon Brown's package-by-component, Fowler's *MonolithFirst* and the microservice premium, Martin's package-coupling principles, Shopify's Packwerk componentisation, GitLab's bounded contexts, Spring Modulith's module model, and the strangler-fig extraction path |

One is a design-time standard with its own command, `/revai:design`:

| Standard | Rules | Canonical to |
| --- | --- | --- |
| `system-design` | 110 | The design canon — Google's design-doc practice (goals, non-goals, alternatives considered, cross-cutting concerns), the SRE workbook on SLIs, SLOs and error budgets, SEI quality-attribute scenarios, Little's law and back-of-envelope sizing, the C4 model's labelled container view, AWS's reliability design principles and blast-radius containment, STRIDE threat modelling over trust boundaries, *Designing Data-Intensive Applications* on consistency, replication and partitioning, McKinley's innovation tokens, Ford and Parsons' fitness functions, MADR decision records, Conway's law and cognitive load, and the strangler-fig transition |

Two are stack-specific, and are invoked rather than injected:

| Standard | Rules | Canonical to |
| --- | --- | --- |
| `golang` | 125 | What the Go team publishes — `gofmt`, `go vet`, the Go Code Review Comments, Google's Go Style Guide, the `log/slog`, `iter`, `errors` and `testing/synctest` package docs, and the release notes from Go 1.18 through 1.26 that retired the idioms most Go code still carries |
| `postgres` | 123 | What the PostgreSQL project publishes — the manual on locking, isolation, indexes and `SECURITY DEFINER`, the wiki's *Don't Do This* page, and the release notes from Postgres 10 through 18 that retired the workarounds most SQL still carries |

Each ships an anti-pattern scan list too, with citable codes: the Ch17 smells and heuristics (55
rows), a 90-row best-practice list, a 45-row DDD list, an 82-row modular-monolith list, a 106-row
system-design list, an 85-row Go list and a 79-row Postgres list. `best-practices` also ships the table
of answers you are not allowed to reinvent — 22 recurring concerns, each with its established solution
named; `modular-monolith` ships 21 coupling shortcuts with what each one costs and what to do instead;
`system-design` ships the design-document outline, a table mapping the dominant requirement to the
shape it forces, the arithmetic behind every estimate and what each number decides, and 16 design
shortcuts with their price; and `golang` and `postgres` each ship a legacy-to-modern table: 30 forms
that were correct once, each with the current answer and the release that introduced it.

Every `SKILL.md` stays inside the six frontmatter fields of the [Agent Skills](https://agentskills.io)
spec, so the skills load unchanged in Claude Code, on claude.ai, and through the API. CI enforces that,
along with the name and description limits and a `## Contents` section on every file long enough to be
read in parts.

## Why it's built this way

A skill that merely *exists* changes nothing. The common failure is a skill whose top level is
exhortation ("this standard is absolute") with the real rules one hop away in reference files that
nothing ever opens — so what lands in context is a mood, not a standard.

revai fixes that with three layers over a single source of truth. Each standard's rules are authored
**once**, in its own `skills/<name>/SKILL.md`, inside a `HARD-RULES` comment fence. Everything else
reads those files.

| Layer | Mechanism | Fires when | Needs |
| --- | --- | --- | --- |
| **1 — always on** | `SessionStart` hook extracts the fenced rules of every *agnostic* standard and injects them as context | every session, every repo, plain chat included | nothing |
| **2 — depth** | the skills themselves: worked examples, decision tables, scan lists | you're writing or reviewing code | skill invocation |
| **3 — the gate** | `Stop` hook blocks the turn until the review agents have passed over the diff | the agent tries to finish after changing source files | nothing |

Layer 1 means the rules are present without a slash command. Layer 3 means ignoring them can't end
the turn. The cards are *generated* from each `SKILL.md` by `sed`, never maintained beside them, so
the three layers cannot drift.

`golang` and `postgres` are deliberately **Layer 2 only**. Layer 1 costs tokens in every session and
every repo, which is the right trade for a standard that governs any line of code in any stack and the
wrong one for Go rules landing in a Python repo or Postgres rules in a repo with no database. They are
reached the way any skill is reached — by their descriptions — and they keep their fences, so injecting
one later is a one-line change.

`system-design` is Layer 2 for a different reason: its rules govern a design act and the document it
produces, not the code being typed, so injecting them into a session that is fixing a typo would be the
same waste. Instead it has an exact entry point — `/revai:design` — which is both a stronger trigger
than a description match and able to do what a card cannot: run the standard as a procedure.

## Scope: the standards behave differently on purpose

They divide by question, not by topic: `clean-code` governs **how the code reads**, `best-practices`
governs **what you build it with**, `domain-driven-design` governs **how the domain is modelled**,
`modular-monolith` governs **how one deployable is partitioned**, `system-design` governs **what is
being built and whether its shape meets requirements someone can check**, `golang` governs **how Go
itself is written**, and `postgres` governs **how Postgres itself is used**. A finding belongs to
exactly one of them.

That split is what keeps the stack skills from becoming a second copy of everything.
`best-practices` rule 46 requires a timeout on every outbound call; `golang` rule 61 says the Go form
is a `context.Context` first parameter, and `postgres` rule 77 says the Postgres form is
`statement_timeout` and `lock_timeout` set on the role. The property is stated once, in the agnostic
fence; the stack skill only names its shape — which release introduced it, what the platform calls it,
and what the toolchain will and won't catch for you.

`clean-code` applies to every line of code in any language. `best-practices` gates each of its ten
groups on a named concern — a change with no HTTP interface answers to no interface rule, a pure
refactor answers to no migration rule — while two groups always apply: choosing the solution, and how
the change is tested and delivered. Its first ten rules are the spine: search the standard library,
then the ecosystem's dominant library, then an established protocol, then a named pattern, and only
then write something bespoke, with the reason recorded.

`domain-driven-design` does not apply everywhere — and
applying it everywhere is its single most common failure mode. Bolting aggregates and repositories
onto a domain nobody analysed produces pattern-driven design: all the ceremony, none of the benefit.

So the DDD standard is **self-gating**. Its first three rules require classifying the subdomain
(core / supporting / generic) and choosing accordingly — a full domain model for a core subdomain, a
transaction script for a supporting one, an off-the-shelf product for a generic one. Applying the
tactical patterns where they don't belong is itself a HIGH finding, and `ddd-review` opens by deciding
whether DDD applies at all, reporting `Not applicable` in one line when it doesn't.

`modular-monolith` self-gates the same way, on shape rather than on subdomain: its first rule applies
the standard only to a system built as one deployable holding more than one business capability, so a
library, a CLI or a single-purpose service says so in one line and skips the rest. Its edge against
DDD is drawn deliberately — DDD owns how a boundary is found and what lives inside it, this standard
owns what crosses it: the module graph, the public surface, storage ownership, in-process integration,
wiring, and the seam a later extraction would use. `modular-monolith-review` enforces it, deciding
rule 1's applicability first — exactly as `ddd-review` does for DDD.

## Install

```bash
/plugin marketplace add AymanKastali/revai
/plugin install revai@revai
```

Then enable it in whatever repo you want the standards applied to. There is no per-repo setup step, no
config file to write, and nothing to add to that project's `CLAUDE.md`.

Pull improvements with `/plugin update revai@revai`, then `/reload-plugins` or start a fresh session.

## `/revai:design`

```text
/revai:design a service that lets our couriers claim delivery slots
```

One command, one idea in one sentence, one design document out. It reads the `system-design` standard,
then:

1. **Decides whether a design is warranted at all.** A well-understood change inside an existing shape
   gets one paragraph and no document — that is rule 97, and it is the difference between a standard
   and a ritual.
2. **Reads the repository before asking you anything** — language, datastore, deployment shape,
   existing modules, existing decision records. It will not ask what it can find.
3. **Asks one bounded round of questions**, at most three batches, and only where the answer changes
   the design: the journeys that define the system, users and growth (never "what's your QPS" — it
   derives the rate), what must never be lost, where staleness is unacceptable, the constraints you
   don't control, and where it runs. Every question carries a recommended default, so accepting the
   defaults is one click. Skip them and it proceeds anyway, recording each gap as an assumption and an
   open question.
4. **Writes `docs/design/<slug>.md`** — fifteen sections: problem, goals and non-goals, constraints,
   requirements as measurable scenarios with SLOs, sizing with the arithmetic shown, a labelled
   component diagram, data ownership and access patterns, integration, a failure table per dependency,
   trust boundaries and threats, operability and cost, decision records with real alternatives and
   reversibility, validation, delivery, open questions.
5. **Checks its own output** against the standard's scan list and fixes what fails before showing you
   anything — every quality attribute measurable, every number sourced, every dependency in the failure
   table, the availability target surviving the arithmetic, every component traceable to a requirement.
6. **Stops.** It reports the shape, the sizing headline, the three decisions that matter and the
   riskiest assumption it made for you, then offers to turn a chosen delivery slice into an
   implementation plan via `superpowers:writing-plans` — still no code, just a plan document. It
   does not start building.

Defaults it applies unless a requirement overrides them, each recorded as a decision when overridden:
one deployable with modules inside it, boring technology, a managed service before self-hosting before
building, a single region, and no queue, cache or tier without the requirement that demands it.

## The gate, concretely

On `Stop`, `hooks/review-gate.sh`:

1. Collects changed files, filtering out docs, config, lockfiles, vendored and generated paths.
2. Exits silently if no source files changed — zero cost on conversation and docs-only turns.
3. Otherwise blocks with `exit 2`, demanding `clean-code-review`, `best-practices-review` and
   `modular-monolith-review` always, and `ddd-review` too. When a changed path looks like domain
   modelling (`domain/`, `application/`, `*repositor*`, `*aggregate*` and friends) the gate names
   those paths and hard-requires the fourth; otherwise it says to use judgment. All four are
   independent, so it asks for them in one message.
4. Requires every HIGH finding from all four reviews fixed, then clears once the diff hash is recorded
   in `.revai/reviewed`. Any further edit changes the hash and re-arms the gate.
5. Relents after 3 attempts on one diff, so a genuine disagreement can't trap you in a loop.

Add `.revai/` to a project's `.gitignore` — it holds only gate bookkeeping.

**Known limits, stated plainly.** The agent records its own `reviewed` marker, so the gate compels
the review but does not prove it happened; the unfakeable alternative (the hook shelling out to
`claude -p`) costs tokens on every code turn and is deferred. The domain-path heuristic is a
convenience, not a boundary — `ddd-review` is the thing that decides applicability. And Layer 1's card
arrives as an early conversation turn, so a very long session can compact it away — Layer 3 is the
backstop for exactly that, since a shell script cannot be compacted.

## What blocks a turn

Only **HIGH** findings block. MEDIUM and LOW are reported, never blocking.

`clean-code-review` blocks on: a misleading name, a unit with more than one responsibility, a leaked
abstraction, a Law of Demeter violation, a returned or passed null, duplication at the third
occurrence, and dead or commented-out code.

`best-practices-review` blocks on: anything reinvented that has an established answer, an incompatible
change to a shipped contract or message schema, a concatenated query or any interpreted string built
from untrusted input, authorization taken from the client or never checked at the resource, hand-rolled
crypto or a password behind a fast digest, a secret in source or a log, disabled certificate
verification, a known-vulnerable dependency, a call with no timeout, retry with no jitter or budget or
a retriable write with no idempotency key, anything unbounded a caller can grow, IO or a publish inside
a transaction, a dual write treated as atomic, read-then-write with no version check, a migration the
running version can't survive, a task with no owner or cancellation, unguarded shared mutable state,
sleep as synchronization, a consumer that breaks on duplicates or has no dead-letter path, a behaviour
change with no test, and a new test that depends on real time or the real network.

`modular-monolith-review` blocks on: a missing or disabled boundary check, two modules sharing a
database or schema, a query or join reading across a module boundary, a foreign key across a
boundary, a domain or framework type on a module's public surface, an import reaching past an entry
point or a back door into internals, an undeclared or cyclic module dependency, one transaction
writing two modules' storage, a multi-module workflow with no named process or compensation, a
handler running inside the publisher's transaction unannounced, an integration event with no outbox,
ambient user or tenant state crossing a boundary, business logic in the host, a migration touching two
modules' objects, and a `common`/`shared`/`util` module holding a business rule.

`ddd-review` blocks on: tactical patterns with no subdomain classification (or a full domain model in
a supporting subdomain), two contexts sharing a database or persistence type, a domain type reused
across a context boundary, a foreign model with no anticorruption layer, an internal aggregate exposed
as a contract, an object reference across an aggregate boundary, two aggregates mutated in one
transaction, an invariant enforced outside its aggregate, an anemic aggregate in a core subdomain, a
public setter on an aggregate, framework or IO machinery in the domain layer, a violated inward
dependency, a domain service doing IO, a business rule in an application service, storage leaking
through a repository, an integration event without an outbox, and a saga step with no compensation.

## Layout

```text
revai/
├── .claude-plugin/
│   ├── plugin.json                          declares the plugin
│   └── marketplace.json                     lists revai as installable (source ".")
├── skills/
│   ├── clean-code/SKILL.md                  56 rules — source of truth, injected
│   ├── best-practices/SKILL.md              99 rules — source of truth, injected
│   ├── domain-driven-design/SKILL.md        74 rules — source of truth, injected
│   ├── modular-monolith/SKILL.md            95 rules — source of truth, injected
│   ├── system-design/SKILL.md              110 rules — source of truth, run by /revai:design
│   ├── golang/SKILL.md                     125 rules — source of truth, invoked
│   └── postgres/SKILL.md                   123 rules — source of truth, invoked
├── commands/
│   └── design.md                            /revai:design — sequences system-design, states no rule
├── agents/
│   ├── clean-code-review.md                 read-only reviewer
│   ├── best-practices-review.md             read-only reviewer, reinvention check first
│   ├── modular-monolith-review.md           read-only reviewer, decides applicability first
│   └── ddd-review.md                        read-only reviewer, decides applicability first
├── hooks/
│   ├── hooks.json
│   ├── inject-hard-rules.sh                 Layer 1 — extracts every skill's fence
│   └── review-gate.sh                       Layer 3
├── CLAUDE.md                                conventions for developing revai itself
└── README.md
```

One command and no more, no `templates/`, and deliberately no `reference/` directory. A command exists
only where a standard is a procedure someone starts on purpose; it sequences a `SKILL.md` and states no
rule of its own, which CI checks.

## Deferred

Each its own future iteration: a `design-review` agent that reads an existing design document against
`system-design` and reports what it cannot answer; review agents and Layer 3 demands for the stack
standards, gated on `*.go` and `*.sql`/migration paths; shipped configs for the checks the standards
require (which would restore a machine-checkable half to the gate — `golangci-lint`, a migration
linter, and the module-graph linter
`modular-monolith` rules 75–82 insist on); and stack skills beyond Go and Postgres. System-design
material and testing are no longer deferred — `system-design` carries the former, and
`best-practices` rules 88–99, `modular-monolith` rules 83–85 and `golang` rules 112–125 the latter.

## License

MIT — see [LICENSE](LICENSE).
