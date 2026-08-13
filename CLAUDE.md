# revai — developing the harness itself

This repo IS a Claude Code plugin (and its own marketplace). It carries language-agnostic engineering
standards, plus the machinery that makes an AI follow them. See `README.md` for the user-facing
overview.

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
- There is deliberately no `commands/` and no `templates/`. The harness needs no per-repo setup step;
  if you think you need one, that is a signal the design slipped.
- Reference bundled files from a skill, agent, or hook with `${CLAUDE_PLUGIN_ROOT}`.

## Adding a standard

Three edits, in this order, or the layers fall out of sync:

1. `skills/<name>/SKILL.md` — frontmatter with a trigger-rich `description`, then the fence.
2. `hooks/inject-hard-rules.sh` — add `'<name>:<xml-tag>'` to the `STANDARDS` array. Nothing else in
   the hook needs to change; it loops.
3. `.github/workflows/ci.yml` — raise `EXPECTED_RULES` to the new total across all fences.

Then decide whether the standard needs its own review agent. If it does, the gate must demand it by
name in `hooks/review-gate.sh`, and CI asserts that every agent the gate names actually exists.

## Conventions

- Every `SKILL.md` has a hard budget of **500 lines**. Past that, cut examples — never move rules out.
- Rules inside a fence are numbered `1..N` with no gaps or duplicates; CI enforces it. Renumber the
  whole group rather than inserting `12a`.
- Every rule in the fence is one line. Depth, examples, decision tables and scan lists go below it.
- A standard that is not universally applicable must say so **inside its own fence**, as its first
  rules — not by being left out of Layer 1. `domain-driven-design` rules 1–3 are the pattern.
- Pseudocode examples stay language-neutral. Concrete-language idioms belong in a future
  language-specific skill, not here.
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
| Cards extract | `./hooks/inject-hard-rules.sh` — one tagged block per skill, exit 0 |
| Rule count | `./hooks/inject-hard-rules.sh \| grep -cE '^[0-9]+\. '` — must equal `EXPECTED_RULES` (130) |
| Numbering | rules in each fence run `1..N` — CI's awk check, or eyeball the tail of each group |
| Budgets held | `wc -l skills/*/SKILL.md` — each must be ≤ 500 |
| Hooks parse | `bash -n hooks/*.sh` |
| Hook paths resolve | `jq -r '.hooks[][].hooks[].command' hooks/hooks.json` — each file exists |
| Gate is quiet | run `hooks/review-gate.sh` with only `*.md` changed — exit 0, no output |
| Gate blocks | touch any source file, run it — exit 2, demand text names both review agents |
| Gate escalates | touch `x/domain/y.go`, run it — demand hard-requires `ddd-review` and lists the path |
| Components load | `/reload-plugins`, then confirm both skills and both review agents appear |

Run the gate only in a throwaway repo, or clean up after: it writes `.revai/` bookkeeping into
whatever tree it runs in.

CI (`.github/workflows/ci.yml`) runs the non-interactive subset of the above on every PR and push to
`main`. Because the repo is its own marketplace, merging to `main` publishes instantly — CI's job is
to guard what gets published.
