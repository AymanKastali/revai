# Boundary enforcement & fitness functions

## Contents
Go/Python tooling with real config · CI wiring · the fitness-function framing · shared kernel in the
enforcement config · module-scoped integration tests · contract tests for a published interface.

A module boundary that's only a convention erodes under deadline pressure. This reference turns "don't
reach into another module's internals" into something CI actually catches — a **fitness function**: an
automated, repeatable check that a stated architectural rule still holds, run on every change the same
way a test suite is.

## Tooling, with real config

**Go — `go-arch-lint`.** Maps directory globs to named components, then declares which components may
depend on which. Requires top-level `version` and `workdir` keys — a config missing them won't run:

```yaml
# .go-arch-lint.yml
version: 3
workdir: .
components:
  orders:  { in: internal/orders/** }
  billing: { in: internal/billing/** }
  shared:  { in: internal/shared/** }
deps:
  orders:  { mayDependOn: [shared] }   # orders may use shared, never billing directly
  billing: { mayDependOn: [shared] }   # billing may use shared, never orders directly
  shared:  { mayDependOn: [] }         # shared depends on nothing — keeps the graph acyclic
```

Run `go-arch-lint check --project-path .` — non-zero exit on any violation. Pair it with **`depguard`**
when a *layer within* a module needs a specific import banned outright (e.g. no `database/sql` inside
`domain/`) — the two tools are complementary: `go-arch-lint` polices cross-module edges, `depguard`
polices what a given package is allowed to import at all.

**Python — `import-linter`.** For flat "these modules must never import each other, even
transitively" rules with no actual layer hierarchy, `independence` is the purpose-built contract type
— not `layers` (which models an actual high/low layering and only incidentally supports independent
siblings within one layer):

```toml
[[tool.importlinter.contracts]]
name = "Modules stay independent"
type = "independence"
modules = [
    "myapp.orders",
    "myapp.billing",
]
```

Run `lint-imports` — non-zero exit on violation.

**Honest trade-off.** Neither tool infers module boundaries automatically from folder structure the
way some JVM tooling does — both need this hand-maintained config kept in sync with the real module
layout. State that plainly rather than claiming parity with tooling this ecosystem doesn't have.

## CI wiring

Wire the check as a **required** CI step (or a pre-commit hook) — a boundary violation fails the build
the same way a failing test does, never just an advisory warning that's easy to ignore under deadline
pressure.

## The fitness-function framing

The tool above *is* this system's fitness function for two rules, both explicit, neither left implied
by an example config:

- **"Module A never imports module B's internals"** — the per-edge `mayDependOn` / `independence`
  rule above.
- **"The module dependency graph has no cycles."** Spring Modulith's `ApplicationModules.verify()`
  treats this as its own first-class check (`orders → billing → orders` fails verification even if
  each edge looks reasonable in isolation) — state it the same way here, not just as a side effect of
  writing symmetric `mayDependOn: []` entries.

The same idea extends to any other architectural rule worth automating rather than trusting to review:
a rule stated once, checked on every change, failing loudly the moment it's violated.

## Shared kernel in the enforcement config

Once `domain-driven-design/reference/strategic-design.md`'s Shared Kernel decision has been made for a
small, stable, jointly-owned type (e.g. `Money`) — that file owns *whether* to share it, not this one —
give it its own named leaf component, as in the `shared` component above: every module may depend on
it, it depends on nothing, and that asymmetry is what keeps the graph acyclic. Keep it small on
purpose: DDD's own caveat applies unchanged here — every extra field in it is a standing coordination
cost, and a "shared" module that keeps growing is how a second Big Ball of Mud forms with a
respectable-sounding name.

## Module-scoped integration tests

Bootstrap only the module under test and its own dependencies — wire just that module's composition
root (per `domain-driven-design/reference/architecture-and-layering.md`), not the whole application.
This keeps a module's integration test suite fast and honest about what it actually depends on; a test
that needs the whole app wired up to test one module is itself a boundary smell.

## Contract tests for a published interface

When module A depends on module B's facade, write a test against a **fake implementing that facade's
contract** — not B's internals. This catches a breaking change to the interface itself, independent of
either module's internal test suite, and is the same discipline as testing against a port in hexagonal
architecture, applied at the module boundary instead of the infra boundary.

## Checklist

- [ ] A boundary-enforcement tool (`go-arch-lint`/`depguard` or `import-linter`) has real config
      matching the actual module layout, not a stale copy from an earlier structure
- [ ] The check runs as a required CI step or pre-commit hook, not an advisory lint
- [ ] The module dependency graph has no cycles — checked and named as its own rule, not just implied
      by symmetric per-edge config
- [ ] Any shared kernel is its own named leaf component (everything may depend on it, it depends on
      nothing) and stays small — not a grab-bag
- [ ] Each module's integration tests wire only that module's own composition root
- [ ] A module depending on another's facade has a contract test against a fake of that facade, not
      against the real implementation's internals
