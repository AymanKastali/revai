# revai — a code-standard harness for Claude Code

**revai** is a Claude Code plugin carrying language-agnostic engineering standards, plus the machinery
that makes an AI actually follow them.

| Standard | Rules | Canonical to |
| --- | --- | --- |
| `clean-code` | 56 | *Clean Code* (Robert C. Martin) — names, functions, comments, formatting, objects and data structures, error handling, classes, the four rules of simple design |
| `best-practices` | 99 | The published canon — API guidelines (Zalando, Microsoft, Google), RFC 9457 and 3339, twelve-factor config, *Release It!* stability patterns, expand/contract migrations, OWASP defaults, SRE golden signals, at-least-once messaging, the test pyramid |
| `domain-driven-design` | 74 | Modern DDD (Evans, Vernon, Khononov) — subdomains, bounded contexts, ubiquitous language, context mapping, aggregates, value objects, services, domain and integration events, hexagonal layering, sagas |

Each ships a review scan list too: the Ch17 smells catalog, a 90-entry best-practice anti-pattern
catalog, and a 45-entry DDD anti-pattern catalog. `best-practices` also ships the table of answers you
are not allowed to reinvent — 22 recurring concerns, each with its established solution named.

## Why it's built this way

A skill that merely *exists* changes nothing. The common failure is a skill whose top level is
exhortation ("this standard is absolute") with the real rules one hop away in reference files that
nothing ever opens — so what lands in context is a mood, not a standard.

revai fixes that with three layers over a single source of truth. Each standard's rules are authored
**once**, in its own `skills/<name>/SKILL.md`, inside a `HARD-RULES` comment fence. Everything else
reads those files.

| Layer | Mechanism | Fires when | Needs |
| --- | --- | --- | --- |
| **1 — always on** | `SessionStart` hook extracts every skill's fenced rules and injects them as context | every session, every repo, plain chat included | nothing |
| **2 — depth** | the skills themselves: worked examples, decision tables, scan lists | you're writing or reviewing code | skill invocation |
| **3 — the gate** | `Stop` hook blocks the turn until the review agents have passed over the diff | the agent tries to finish after changing source files | nothing |

Layer 1 means the rules are present without a slash command. Layer 3 means ignoring them can't end
the turn. The cards are *generated* from each `SKILL.md` by `sed`, never maintained beside them, so
the three layers cannot drift.

## Scope: the three standards behave differently on purpose

They divide by question, not by topic: `clean-code` governs **how the code reads**, `best-practices`
governs **what you build it with**, and `domain-driven-design` governs **how the domain is modelled**.
A finding belongs to exactly one of them.

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

## Install

```bash
/plugin marketplace add AymanKastali/revai
/plugin install revai@revai
```

Then enable it in whatever repo you want the standards applied to. There is no per-repo setup step, no
config file to write, and nothing to add to that project's `CLAUDE.md`.

Pull improvements with `/plugin update revai@revai`, then `/reload-plugins` or start a fresh session.

## The gate, concretely

On `Stop`, `hooks/review-gate.sh`:

1. Collects changed files, filtering out docs, config, lockfiles, vendored and generated paths.
2. Exits silently if no source files changed — zero cost on conversation and docs-only turns.
3. Otherwise blocks with `exit 2`, demanding `clean-code-review` and `best-practices-review` always,
   and `ddd-review` too. When a changed path looks like domain modelling (`domain/`, `application/`,
   `*repositor*`, `*aggregate*` and friends) the gate names those paths and hard-requires the third;
   otherwise it says to use judgment. All three are independent, so it asks for them in one message.
4. Requires every HIGH finding from all three reviews fixed, then clears once the diff hash is recorded
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
│   ├── clean-code/SKILL.md                  56 rules — source of truth
│   ├── best-practices/SKILL.md              99 rules — source of truth
│   └── domain-driven-design/SKILL.md        74 rules — source of truth
├── agents/
│   ├── clean-code-review.md                 read-only reviewer
│   ├── best-practices-review.md             read-only reviewer, reinvention check first
│   └── ddd-review.md                        read-only reviewer, decides applicability first
├── hooks/
│   ├── hooks.json
│   ├── inject-hard-rules.sh                 Layer 1 — extracts every skill's fence
│   └── review-gate.sh                       Layer 3
├── CLAUDE.md                                conventions for developing revai itself
└── README.md
```

No `commands/`, no `templates/`, and deliberately no `reference/` directory.

## Deferred

Each its own future iteration: language-specific idioms and shipped linter configs (which would
restore a machine-checkable half to the gate), modular-monolith boundary enforcement, and system-design
material. Testing is no longer deferred — `best-practices` rules 88–99 carry it.

## License

MIT — see [LICENSE](LICENSE).
