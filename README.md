# revai — a clean-code harness for Claude Code

**revai** is a Claude Code plugin carrying exactly one thing: a language-agnostic clean-code
standard, plus the machinery that makes an AI actually follow it.

The standard is canonical to *Clean Code* (Robert C. Martin) — 56 rules across names, functions,
comments, formatting, objects and data structures, error handling, classes, and the four rules of
simple design, with the Ch17 smells catalog as a review scan list.

## Why it's built this way

A skill that merely *exists* changes nothing. The common failure is a skill whose top level is
exhortation ("this standard is absolute") with the real rules one hop away in reference files that
nothing ever opens — so what lands in context is a mood, not a standard.

revai fixes that with three layers over a single source of truth. The rules are authored **once**, in
`skills/clean-code/SKILL.md`, inside an `HARD-RULES` comment fence. Everything else reads that file.

| Layer | Mechanism | Fires when | Needs |
| --- | --- | --- | --- |
| **1 — always on** | `SessionStart` hook extracts the fenced rules and injects them as context | every session, every repo, plain chat included | nothing |
| **2 — depth** | the `clean-code` skill: worked bad/good examples and the smells catalog | you're writing or reviewing code | skill invocation |
| **3 — the gate** | `Stop` hook blocks the turn until `clean-code-review` has passed over the diff | the agent tries to finish after changing source files | nothing |

Layer 1 means the rules are present without a slash command. Layer 3 means ignoring them can't end
the turn. The card is *generated* from `SKILL.md` by `sed`, never maintained beside it, so the three
layers cannot drift.

## Install

```bash
/plugin marketplace add AymanKastali/revai
/plugin install revai@revai
```

Then enable it in whatever repo you want the standard applied to. There is no per-repo setup step, no
config file to write, and nothing to add to that project's `CLAUDE.md`.

Pull improvements with `/plugin update revai@revai`, then `/reload-plugins` or start a fresh session.

## The gate, concretely

On `Stop`, `hooks/clean-code-gate.sh`:

1. Collects changed files, filtering out docs, config, lockfiles, vendored and generated paths.
2. Exits silently if no source files changed — zero cost on conversation and docs-only turns.
3. Otherwise blocks with `exit 2`, instructing the agent to dispatch `clean-code-review`, fix every
   HIGH finding, and record the diff hash in `.revai/reviewed`.
4. Clears once that hash is recorded. Any further edit changes the hash and re-arms the gate.
5. Relents after 3 attempts on one diff, so a genuine disagreement can't trap you in a loop.

Add `.revai/` to a project's `.gitignore` — it holds only gate bookkeeping.

**Known limits, stated plainly.** The agent records its own `reviewed` marker, so the gate compels
the review but does not prove it happened; the unfakeable alternative (the hook shelling out to
`claude -p`) costs tokens on every code turn and is deferred. And Layer 1's card arrives as an early
conversation turn, so a very long session can compact it away — Layer 3 is the backstop for exactly
that, since a shell script cannot be compacted.

## Severity

Only **HIGH** findings block: a misleading name, a unit with more than one responsibility, a leaked
abstraction, a Law of Demeter violation, a returned or passed null, duplication at the third
occurrence, and dead or commented-out code. MEDIUM and LOW are reported, never blocking.

## Layout

```text
revai/
├── .claude-plugin/
│   ├── plugin.json                 declares the plugin
│   └── marketplace.json            lists revai as installable (source ".")
├── skills/clean-code/SKILL.md      the single source of truth
├── agents/clean-code-review.md     read-only reviewer
├── hooks/
│   ├── hooks.json
│   ├── inject-hard-rules.sh        Layer 1
│   └── clean-code-gate.sh          Layer 3
├── CLAUDE.md                       conventions for developing revai itself
└── README.md
```

Four content files. No `commands/`, no `templates/`, and deliberately no `reference/` directory.

## Scope

Deliberately out, each its own future iteration: language-specific idioms and shipped linter configs
(which would restore a machine-checkable half to the gate), testing practice (*Clean Code* Ch9),
and the architecture and correctness material of Ch8, Ch11 and Ch13.

## License

MIT — see [LICENSE](LICENSE).
