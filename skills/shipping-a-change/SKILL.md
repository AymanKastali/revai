---
name: shipping-a-change
description: Use inside a revai change workflow (/revai:feature, /revai:bugfix, /revai:refactor) for the stages they all share — preconditions and branch, the consistency bar held while working, and the verify → review → open-PR finish. Each command supplies only its distinct middle; this skill owns the shared spine so it stays identical across all three.
---

# Shipping a change (the shared workflow spine)

`/revai:feature`, `/revai:bugfix`, and `/revai:refactor` differ only in their **middle** — how the
change is arrived at. Everything around that middle is identical, and lives here so it can't drift.
A command runs **Before you begin** first, **holds the consistency bar** through its own middle,
then runs **Finish**. You **orchestrate**; the real work is done by the `superpowers` skills and
revai's guardrails — don't reimplement verification, review, or PR creation.

## Before you begin

- **Confirm revai is attached.** Check that both `CLAUDE.md` and `.revai/verify.json` exist in the
  repo root. If either is missing, tell the user to run `/revai:attach` first, and **stop**.
- **Read the project `CLAUDE.md`** into context — the stack, conventions, verify commands, and the
  **"Do not touch"** paths. These govern everything you do.
- **Get onto a branch.** If the current branch is the default (`main`/`master`), create
  `<prefix>/<slug>` off it — the calling command supplies the prefix (`feat/`, `fix/`, `refactor/`)
  and you derive `<slug>` from the change. If already on a non-default branch, stay on it.
  **Never work directly on the default branch.**

## Hold the consistency bar

Throughout the middle, the code you produce must look like it was written by the same hand as the
rest of the repo, and like the rest of itself:

- **With the codebase** — before writing a unit, read a neighbouring one and match its patterns,
  naming, file/layer layout, error handling, and test shape. Reuse existing helpers over adding
  near-duplicates. Don't introduce a second way to do something the repo already does one way.
- **Within the change** — one name per concept across every layer, the same pattern for the same
  problem, uniform ordering and structure. No drift between the files you touched in this run.
- When the existing code is itself inconsistent, follow the dominant convention and note the
  exception in the summary rather than adding a third variant.

## Finish

### Verify

- Run the check commands from `.revai/verify.json` and **read their output** — this is the
  `superpowers` **`verification-before-completion`** rule: evidence before assertions, never claim
  something passes without running it. (The verify-on-Stop hook is the backstop; run them here
  yourself and fix what fails.)
- `test` and `lint` are **blocking**; `build` and `format` are advisory.
- If a blocking check can't be made to pass after a few honest attempts, **STOP and report** — do
  not carry a broken build into review or a PR.

### Review

- Dispatch revai's **`backend-review`** agent on the change set to audit it against all the skills.
  For a change with no backend surface, use the `superpowers` **`requesting-code-review`** skill
  instead.
- Work the findings: fix every 🔴 High and 🟡 Medium, then **re-verify and re-review**, looping
  until the review is clean or only accepted Low/Questions remain.
- Treat any **consistency** finding (inconsistent naming/vocabulary, a duplicate way to do something
  the repo already does, or drift between the files you touched) as worth fixing regardless of its
  severity label — consistency is a hard requirement here, not a nicety.
- If a High finding can't be resolved, **STOP and surface it** rather than shipping around it.

### Open PR  ⏸ GATE

- Present a **completion summary**: what changed (by module and layer), the verify results, the
  review verdict, and a proposed **PR title and body**.
- **STOP.** Wait for the user's explicit approval to open the PR.
- On approval, use the `superpowers` **`finishing-a-development-branch`** skill to finish up:
  - commit any uncommitted work (the secrets hook runs on commit as usual);
  - `git push -u origin <branch>`;
  - open the PR with `gh pr create`.
- Footers:
  - commit message ends with
    `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`;
  - PR body ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Report the PR URL to the user.
