# revai — developing the harness itself

This repo IS a Claude Code plugin (and its own marketplace). It carries engineering standards — three
language-agnostic, plus one per language — and the machinery that makes an AI follow them. See
`README.md` for the user-facing overview.

## The one rule that matters here

Each standard's `skills/<name>/SKILL.md` is the **single source of truth** for that standard. The
rules live inside its `HARD-RULES` comment fence, and `hooks/inject-hard-rules.sh` extracts every
fence at runtime with `sed`.

Never copy rules out of a fence into another file. If you find yourself restating a rule anywhere
else — in a hook, an agent, the README — you have introduced drift. Read it out of `SKILL.md`
instead, or point at the skill.

Editing a fence changes what every session sees. Keep the markers intact and in order:

```text
<!-- HARD-RULES:START -->
<!-- HARD-RULES:END -->
```

## Structure rules

- `plugin.json` and `marketplace.json` live **only** inside `.claude-plugin/`. Nothing else goes
  there.
- Component dirs live at the repo **root**: `skills/`, `agents/`, `hooks/`.
- There is deliberately **no `reference/` directory**. Splitting rules into reference files that
  nothing opens is the exact failure this rewrite exists to remove — keep `SKILL.md` self-contained.
  This is a **considered deviation** from Anthropic's progressive-disclosure guidance, which says to
  split as a file approaches 500 lines. It holds here for two reasons: Layer 1 injects the rules
  regardless of whether any file is opened, and the depth below each fence is precisely what a caller
  invoked the skill to get, so putting it one hop further away buys nothing at the point of use. The
  `## Contents` section is the mitigation the same guidance prescribes for long files. Do not
  "fix" this by reintroducing reference files; if a `SKILL.md` genuinely cannot fit in 500 lines,
  raise it with the repo owner instead of splitting it.
- There is deliberately no `commands/` and no `templates/`. The harness needs no per-repo setup step;
  if you think you need one, that is a signal the design slipped.
- Reference bundled files from a skill, agent, or hook with `${CLAUDE_PLUGIN_ROOT}`.

## Adding a standard

First decide which layers it gets. A **language-agnostic** standard is injected by Layer 1, so it is
in context whether or not anything invokes it. A **language-specific** standard is not — see § Layers.

For a language-agnostic standard, three edits, in this order, or the layers fall out of sync:

1. `skills/<name>/SKILL.md` — spec-conformant frontmatter (see Conventions), a `## Contents` section,
   then the fence.
2. `hooks/inject-hard-rules.sh` — add `'<name>:<xml-tag>'` to the `STANDARDS` array. Nothing else in
   the hook needs to change; it loops.
3. `.github/workflows/ci.yml` — raise `EXPECTED_RULES` to the new total across all fences.

For a language-specific standard, step 1 only. `EXPECTED_RULES` counts the injected card, so it does
not move, and CI derives the list of skills that must appear in the card from the hook's `STANDARDS`
array rather than from `skills/*/` — which is what lets a skill exist without being injected.

Then decide whether the standard needs its own review agent. If it does, the gate must demand it by
name in `hooks/review-gate.sh`, and CI asserts that every agent the gate names actually exists.

## Layers

Layer 1 costs tokens in every session, in every repo, including plain chat. That is the right trade
for a standard that applies to every line of code in any language, and the wrong one for a standard
that applies to one language: Go rules injected into a Python repo are pure noise, and the card is
already ~7k tokens.

So **language-specific skills are Layer 2 only**. They carry no entry in `STANDARDS` and are reached
the way any skill is reached — by their `description`, which is why that description must name its
triggers concretely. Layer 3 can still demand a language reviewer, gated on the changed paths, the way
it already gates `ddd-review` on domain-looking paths.

They keep the fence anyway. It separates the hard rules from the depth below for a human reader, it is
what CI's numbering check keys off, and it means injecting one later is a one-line array edit rather
than a restructure.

This is **not** a licence to scope-limit a language-agnostic standard by leaving it out of Layer 1.
That was the old plugin's failure and the Conventions rule below still forbids it: an agnostic standard
that does not always apply says so inside its own fence, as its first rules.

## Conventions

- Frontmatter stays inside the **six fields of the Agent Skills spec** (`name`, `description`,
  `allowed-tools`, `compatibility`, `license`, `metadata`). We use only the first two. Claude Code
  extensions like `when_to_use` are rejected by CI: they would make these skills fail to load on
  claude.ai and through the API, and the description has room for what they would carry.
- `name` equals its directory, is `[a-z0-9-]` within 64 characters, and contains no reserved word.
  `description` is one line, ≤ 1024 characters, leads with a verb saying what the standard does, and
  ends with a `Use when …` clause naming concrete triggers — that clause is what drives discovery, and
  CI requires it.
- Every `SKILL.md` over 100 lines carries a `## Contents` section above the fence, so a partial read
  still shows the file's full scope. Keep it outside the fence: it must never enter the injected card.
- Section names are parallel across skills — `## Contents`, the rules group, decision tables,
  `## Depth`, then `## Anti-pattern scan list`. Same for the review agents.
- Every `SKILL.md` has a hard budget of **500 lines**. Past that, cut examples — never move rules out.
- Rules inside a fence are numbered `1..N` with no gaps or duplicates; CI enforces it. Renumber the
  whole group rather than inserting `12a`.
- Every rule in the fence is one line. Depth, examples, decision tables and scan lists go below it.
- A standard that is not universally applicable must say so **inside its own fence**, as its first
  rules — not by being left out of Layer 1. Two shapes exist: `domain-driven-design` rules 1–3 gate
  the whole standard on one up-front classification; `best-practices` rule 1 gates each group on the
  concern named in its heading. Pick whichever matches how the standard actually varies. A
  language-specific standard is the one exception to the "not by being left out" half (see § Layers),
  and it still gates itself in its own fence: `golang` rule 1 on the change containing Go, rule 2 on
  each group's concern.
- Standards divide by **question**, not by topic, so a finding belongs to exactly one of them:
  `clean-code` owns how the code reads, `best-practices` owns what it is built with,
  `domain-driven-design` owns how the domain is modelled, and a language standard owns how that
  language itself is written. Before adding a rule, check that no other fence already answers its
  question — the outbox, for example, is DDD rule 61, so `best-practices` rule 82 states the general
  dual-write hazard instead of restating it.
- A language standard names its language's **form** of a property another standard mandates; it never
  restates the property. `best-practices` rule 46 requires a timeout on every outbound call; `golang`
  rule 61 says the Go form is a `context.Context` first parameter. If a rule would read the same in
  another language, it belongs in an agnostic fence instead.
- Pseudocode in the agnostic standards stays language-neutral. Concrete idioms belong in that
  language's skill.
- A language standard cites the release that introduced each modern form — `any` (1.18),
  `wg.Go` (1.25) — so a reader can tell a rule they cannot yet apply from one they are ignoring.
- No rationalization tables and no "this standard is absolute" preamble. That was the old plugin's
  entire top level and it changed nothing; the `Stop` gate is the enforcement mechanism now.
- Markdown: table delimiter rows are spaced (`| --- | --- |`) and every fenced block declares a
  language. The repo lints clean under `npx markdownlint-cli2`, configured by
  `.markdownlint-cli2.jsonc` — which disables exactly two rules, each with the reason written down.
- Hook scripts are `bash`, `set -uo pipefail`, executable, and **never fail a session** — every
  error path warns on stderr and exits 0. The one exception is the gate's deliberate `exit 2`.
- A hook that reads several skills degrades per-skill: one unreadable fence warns and is skipped, the
  rest still inject.
- Validate JSON before committing: `jq . .claude-plugin/*.json hooks/hooks.json`.
- Design docs live under `docs/` and are **gitignored** — local only, never shipped with the plugin.

## Versioning

`plugin.json` carries no `version` field on purpose, so consumers track commits and
`/plugin update revai@revai` always fetches the tip of `main`. Add one only for a tagged release.

## How to verify your work

There is no build or test suite. Verification means:

| Purpose | Command |
| --- | --- |
| Manifests parse | `jq . .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json` |
| Fences intact | `grep -n 'HARD-RULES:\(START\|END\)' skills/*/SKILL.md` |
| Cards extract | `./hooks/inject-hard-rules.sh` — one tagged block per **injected** skill, exit 0 |
| Rule count | `./hooks/inject-hard-rules.sh \| grep -cE '^[0-9]+\. '` — must equal `EXPECTED_RULES` (229) |
| Layer 2 only | no `<golang>` block in the card, and `golang` absent from the hook's `STANDARDS` array |
| Numbering | rules in each fence run `1..N` — CI's awk check, or eyeball the tail of each group |
| Spec conformance | CI's "Skills conform to the Agent Skills spec" step — name/description limits, spec-only frontmatter, `## Contents` present, agent name equals filename |
| Card unaffected | `./hooks/inject-hard-rules.sh \| sha1sum` before and after editing anything outside a fence — it must not change |
| Budgets held | `wc -l skills/*/SKILL.md` — each must be ≤ 500 |
| Hooks parse | `bash -n hooks/*.sh` |
| Hook paths resolve | `jq -r '.hooks[][].hooks[].command' hooks/hooks.json` — each file exists |
| Gate is quiet | run `hooks/review-gate.sh` with only `*.md` changed — exit 0, no output |
| Gate blocks | touch any source file, run it — exit 2, demand text names all three review agents |
| Gate escalates | touch `x/domain/y.go`, run it — demand hard-requires `ddd-review` and lists the path |
| Components load | `/reload-plugins`, then confirm every skill and every review agent appears |

Run the gate only in a throwaway repo, or clean up after: it writes `.revai/` bookkeeping into
whatever tree it runs in.

CI (`.github/workflows/ci.yml`) runs the non-interactive subset of the above on every PR and push to
`main`. Because the repo is its own marketplace, merging to `main` publishes instantly — CI's job is
to guard what gets published.
