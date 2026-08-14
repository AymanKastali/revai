# revai — a code-standard harness for Claude Code

**revai** is a Claude Code plugin carrying engineering standards, plus the machinery that makes an AI
actually follow them.

Four are stack-agnostic and always in context:

| Standard | Rules | Scan list | Canonical to |
| --- | --- | --- | --- |
| `clean-code` | 56 | 52 | *Clean Code* (Robert C. Martin) — names, functions, comments, formatting, objects and data structures, error handling, classes, the four rules of simple design |
| `best-practices` | 99 | 85 | The published canon — API guidelines (Zalando, Microsoft, Google), RFC 9457 and 3339, twelve-factor config, *Release It!* stability patterns, expand/contract migrations, OWASP defaults, SRE golden signals, at-least-once messaging, the test pyramid |
| `domain-driven-design` | 74 | 51 | Modern DDD (Evans, Vernon, Khononov) — subdomains, bounded contexts, ubiquitous language, context mapping, aggregates, value objects, services, domain and integration events, hexagonal layering, sagas |
| `modular-monolith` | 95 | 82 | The modular-monolith canon — Grzybek's primer, integration-styles and architecture-enforcement series, Simon Brown's package-by-component, Fowler's *MonolithFirst* and the microservice premium, Martin's package-coupling principles, Shopify's Packwerk componentisation, GitLab's bounded contexts, Spring Modulith's module model, and the strangler-fig extraction path |

Two are design-time standards, each a procedure carried entirely inside its own skill:

| Standard | Rules | Scan list | Canonical to |
| --- | --- | --- | --- |
| `system-design` | 123 | 97 | The design canon — Google's design-doc practice (goals, non-goals, alternatives considered, cross-cutting concerns), the SRE workbook on SLIs, SLOs and error budgets, SEI quality-attribute scenarios, Little's law and back-of-envelope sizing, the C4 model's labelled container view, AWS's reliability design principles and blast-radius containment, STRIDE threat modelling over trust boundaries, *Designing Data-Intensive Applications* on consistency, replication and partitioning, McKinley's innovation tokens, Ford and Parsons' fitness functions, MADR decision records, Conway's law and cognitive load, and the strangler-fig transition |
| `implementation-planning` | 27 | 26 | The seam between `system-design`'s own delivery-slicing rules (118–122) and `superpowers:writing-plans`' scope-check and file-structure discipline — this repo's own answer to keeping a plan's boundaries consistent with the design it implements, not an external canon |

Three are stack-specific, and are invoked rather than injected:

| Standard | Rules | Scan list | Canonical to |
| --- | --- | --- | --- |
| `golang` | 125 | 85 | What the Go team publishes — `gofmt`, `go vet`, the Go Code Review Comments, Google's Go Style Guide, the `log/slog`, `iter`, `errors` and `testing/synctest` package docs, and the release notes from Go 1.18 through 1.26 that retired the idioms most Go code still carries |
| `go-project-layout` | 66 | 69 | The Go form of `domain-driven-design`'s hexagonal layering and `modular-monolith`'s public surface and storage ownership — a flat context tree, the official module layout, and `depguard` as the boundary itself rather than a note about one, since Go's `internal/` is positional and stops nothing between two contexts. This repo's adopted structure, not a survey of options |
| `postgres` | 123 | 79 | What the PostgreSQL project publishes — the manual on locking, isolation, indexes and `SECURITY DEFINER`, the wiki's *Don't Do This* page, and the release notes from Postgres 10 through 18 that retired the workarounds most SQL still carries |

The `Scan list` column is each standard's anti-pattern list, with citable codes — `clean-code`'s is
the Ch17 smells and heuristics, and every other standard's is coded by group. Several ship more than
that. `best-practices` adds the table of answers you are not allowed to reinvent — 22 recurring
concerns, each with its established solution named; `modular-monolith` adds 21 coupling shortcuts with
what each one costs and what to do instead; `system-design` adds the design-document outline
(functional and non-functional requirements, capacity estimation, API and interface contracts, a
detailed-design deep dive, and the rest), a table mapping the dominant requirement to the shape it
forces, the arithmetic behind every estimate and what each number decides, and 12 design shortcuts
with their price; `implementation-planning` adds a worked module-boundary split and the exact shape of
a one-slice handoff; `golang` and `postgres` each add a legacy-to-modern table: 30 forms that were
correct once, each with the current answer and the release that introduced it; and
`go-project-layout` adds the annotated reference tree itself, with every directory keyed to the rule
that puts it there.

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

`golang`, `go-project-layout` and `postgres` are deliberately **Layer 2 only**. Layer 1 costs tokens
in every session and every repo, which is the right trade for a standard that governs any line of code
in any stack and the wrong one for Go rules landing in a Python repo or Postgres rules in a repo with
no database. They are reached the way any skill is reached — by their descriptions — and they keep
their fences, so injecting one later is a one-line change.

`system-design` and `implementation-planning` are Layer 2 for a different reason: their rules govern
a design act and the document or plan it produces, not the code being typed, so injecting them into a
session that is fixing a typo would be the same waste. Each carries its own `## Procedure` section
inside its `SKILL.md`, below the fence — running the standard as a procedure, which a card cannot do
— so invoking the skill directly is the entry point, no separate command needed.

## Scope: the standards behave differently on purpose

They divide by question, not by topic: `clean-code` governs **how the code reads**, `best-practices`
governs **what you build it with**, `domain-driven-design` governs **how the domain is modelled**,
`modular-monolith` governs **how one deployable is partitioned**, `system-design` governs **what is
being built and whether its shape meets requirements someone can check**, `golang` governs **how Go
itself is written**, `go-project-layout` governs **where a Go file goes**, and `postgres` governs
**how Postgres itself is used**. A finding belongs to exactly one of them.

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

## `system-design`

```text
Design a service that lets our couriers claim delivery slots.
```

No command — the skill itself runs the procedure. Say what you want designed (or invoke the skill by
name, e.g. `/revai:system-design a service that lets our couriers claim delivery slots`) and it reads
the `system-design` standard, then:

1. **Decides whether a design is warranted at all.** A well-understood change inside an existing shape
   gets one paragraph and no document — that is rule 109, and it is the difference between a standard
   and a ritual.
2. **Tags the idea narrow or complex**, out loud — how many journeys, integrations and stores, and
   whether a genuinely hard mechanism is in play — which governs how hard the question round and the
   detailed-design deep dive push.
3. **Reads the repository before asking you anything** — language, datastore, deployment shape,
   existing modules, existing decision records. It will not ask what it can find.
4. **Keeps asking as long as there is doubt**, not a fixed number of rounds: the journeys that define
   the system, users and growth (never "what's your QPS" — it derives the rate), what must never be
   lost, where staleness is unacceptable, who consumes each interface, the constraints you don't
   control, where it runs, and — for a complex design — what's actually hard. Every question carries a
   recommended default, so accepting it is one click. Skip a round and it proceeds anyway, recording
   the gap as an assumption and an open question.
5. **Writes `docs/design/<slug>.md`** — nineteen sections: problem, goals and non-goals, constraints,
   functional and non-functional requirements (each an actor, priority and acceptance criterion, or a
   measurable scenario with an SLO), capacity estimation with the arithmetic shown, a labelled
   component diagram, data ownership and access patterns, concrete API and interface contracts, a
   detailed-design deep dive on the 1-3 hardest mechanisms, integration, a failure table per
   dependency, trust boundaries and threats, operability and cost, decision records with real
   alternatives and reversibility, validation, delivery, open questions.
6. **Checks its own output** against the standard's scan list and fixes what fails before showing you
   anything — every requirement measurable, every number sourced, every interface under contract, the
   hardest mechanisms walked to their edge case, every dependency in the failure table, the
   availability target surviving the arithmetic, every component traceable to a requirement.
7. **Stops.** It reports the complexity tag, the shape, the sizing headline, the hardest mechanism
   covered, the three decisions that matter and the riskiest assumption it made for you. It does not
   start building — turning a chosen slice into an implementation plan is `implementation-planning`'s
   job, run separately.

Defaults it applies unless a requirement overrides them, each recorded as a decision when overridden:
one deployable with modules inside it, boring technology, a managed service before self-hosting before
building, a single region, and no queue, cache or tier without the requirement that demands it.

## `implementation-planning`

```text
Plan the next slice from docs/design/courier-delivery-slots.md.
```

No command here either — one approved design document in, one right-sized implementation plan out,
for exactly one slice at a time. It reads the `implementation-planning` standard, then:

1. **Loads the design.** No path, or nothing readable there: it says so and stops. There is nothing
   to slice without an approved design.
2. **Reads the design's own delivery slices** — section 18 (Delivery & Rollout) — and its module
   and data-ownership boundaries — sections 7 (Architecture) and 8 (Data) — before inventing
   anything, then **right-sizes** whatever still spans more than one module or bundles more than one
   independently-shippable capability, splitting along the module boundary rather than down the
   middle of one.
3. **Orders the sequence** by dependency first, the thinnest end-to-end path where dependency order
   leaves a choice, and records the reason for each slice's position.
4. **Detects what's already planned or built** by searching `docs/superpowers/plans/` for a plan
   citing this design document as its spec, and recommends the next undone slice — always confirmed,
   never assumed.
5. **Hands off exactly one slice** to `superpowers:writing-plans`, stating that slice's module and
   data ownership verbatim from the design so the plan's own file structure inherits those boundaries
   instead of guessing at new ones, and naming the stack skill (`golang`, `postgres`) if the design
   named one for that module.
6. **Validates the breakdown** — every slice traceable to a requirement, every requirement covered,
   no cycle in the sequence — before showing anything.
7. **Stops.** It reports the full ordered sequence, which slice it just planned, and the plan's path.
   It does not touch code, and it never hands more than one slice to `writing-plans` in a single run
   — invoke it again once that slice has shipped.

## The gate, concretely

On `Stop`, `hooks/review-gate.sh`:

1. Collects changed files, filtering out docs, config, lockfiles, vendored and generated paths.
2. Exits silently if no source files changed — zero cost on conversation and docs-only turns.
3. Otherwise blocks with `exit 2`, demanding `clean-code-review`, `best-practices-review` and
   `modular-monolith-review` always, and `ddd-review` too. When a changed path looks like domain
   modelling (`domain/`, `infra/`, `port/`, `*repositor*`, `*aggregate*` and friends) the gate names
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
│   ├── system-design/SKILL.md              123 rules + its own procedure — source of truth, invoked
│   ├── implementation-planning/SKILL.md     27 rules + its own procedure — source of truth, invoked
│   ├── golang/SKILL.md                     125 rules — source of truth, invoked
│   ├── go-project-layout/SKILL.md           66 rules + the adopted tree — source of truth, invoked
│   └── postgres/SKILL.md                   123 rules — source of truth, invoked
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

No `commands/`, no `templates/`, and deliberately no `reference/` directory. A procedure standard
lives entirely inside its own `SKILL.md` — the fence for the rules, a `## Procedure` section below it
for how to run them — so there is exactly one file per standard and CI has one thing to check per
standard, not two.

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
docs only
