# revai — developing the harness itself

This repo IS a Claude Code plugin (and its own marketplace). It carries exactly one thing: a
language-agnostic clean-code standard, plus the machinery that makes an AI follow it. See
`README.md` for the user-facing overview.

## The one rule that matters here

`skills/clean-code/SKILL.md` is the **single source of truth** for the standard. The rules live
inside the `HARD-RULES` comment fence, and `hooks/inject-hard-rules.sh` extracts that fence at
runtime with `sed`.

Never copy rules out of the fence into another file. If you find yourself restating a rule anywhere
else, you have introduced drift — read it out of `SKILL.md` instead.

Editing the fence changes what every session sees. Keep the fence markers intact and in order:

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

## Conventions

- `SKILL.md` has a hard budget of **500 lines**. Past that, cut examples — never move rules out.
- Pseudocode examples stay language-neutral. Concrete-language idioms belong in a future
  language-specific skill, not here.
- Every rule in the fence is one line. Depth and examples go below the fence.
- No rationalization tables and no "this standard is absolute" preamble. That was the old plugin's
  entire top level and it changed nothing; the `Stop` gate is the enforcement mechanism now.
- Markdown: table delimiter rows are spaced (`| --- | --- |`) and every fenced block declares a
  language. The repo lints clean under `markdownlint`.
- Hook scripts are `bash`, `set -uo pipefail`, executable, and **never fail a session** — every
  error path warns on stderr and exits 0. The one exception is the gate's deliberate `exit 2`.
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
| Fence intact | `grep -n 'HARD-RULES:\(START\|END\)' skills/clean-code/SKILL.md` |
| Card extracts | `./hooks/inject-hard-rules.sh` — prints all 56 rules, exit 0 |
| Rule count | `./hooks/inject-hard-rules.sh \| grep -cE '^[0-9]+\. '` — must be 56 |
| Budget held | `wc -l skills/clean-code/SKILL.md` — must be ≤ 500 |
| Hooks parse | `bash -n hooks/*.sh` |
| Gate is quiet | run `hooks/clean-code-gate.sh` with only `*.md` changed — exit 0, no output |
| Gate blocks | touch any source file, run it — exit 2 with the demand text |
| Components load | `/reload-plugins`, then confirm `clean-code` and `clean-code-review` appear |

CI (`.github/workflows/ci.yml`) runs the non-interactive subset of the above on every PR and push to
`main`. Because the repo is its own marketplace, merging to `main` publishes instantly — CI's job is
to guard what gets published.
