---
description: Broadly review the code you generated — bugs, security, backend design, quality — report ranked findings, auto-fix what's confident, re-verify, and show the diff.
argument-hint: [optional path, file, or commit range — defaults to your uncommitted changes]
---

# /revai:review

Review the code you just generated across every dimension, then **fix it**: report ranked findings,
auto-apply the fixes you're confident about, re-verify, and show what changed. You **orchestrate**;
the real judgement comes from the skills you invoke — don't reinvent review or verification.

The argument (`$ARGUMENTS`) is an optional target (a file, directory, or commit range).

## 1. Determine the target

- **Argument given** → review exactly that (path, directory, or `git` range).
- **No argument, working tree dirty** → review uncommitted changes vs `HEAD` (staged + unstaged) —
  this is "the code I just generated", the common case.
- **No argument, working tree clean** → review the current branch vs `main`
  (`git merge-base HEAD origin/main` → `git diff <base>...HEAD`).
- State plainly what you're about to review before you start.

## 2. Review (broad, skill-driven)

Dispatch a broad-review subagent over the target so the findings are gathered off your main context.
It reviews across all of these, using only the ones the diff actually touches:

- **`superpowers:systematic-debugging`** — real bugs and correctness defects.
- The **revai backend skills** — `api-design`, `data-access-patterns`, `error-handling-and-logging`,
  `resilience-and-timeouts`, `config-and-secrets`, `safe-schema-changes`, `naming-and-structure`,
  `domain-modeling`, `hexagonal-architecture`. (For a backend-heavy diff, the `revai:backend-review`
  agent already encodes these — use it for that pass.)
- **`security-review`** — security issues.
- **`simplify`** — clarity and quality cleanups.

Require the report back as **ranked findings**, most severe first, each as:
`severity · file:line · what's wrong · the fix`.

## 3. Report

Show the ranked findings to the user before touching anything. Group by severity.

## 4. Auto-fix (confident only)

- **Apply every fix you're confident about** — an unambiguous defect with a clear, local fix.
- **Do not force** low-confidence, ambiguous, or design-level findings. List those under
  **"Needs your call"** with the tradeoff, and leave the code alone.
- Fix the actual issue, not the symptom. Don't expand scope beyond the findings.

## 5. Re-verify

- Run the project's verify command. The repo's `verify-on-Stop` hook backstops this — don't claim
  success without green output.
- If a fix breaks verification, revert that fix and move it to "Needs your call" rather than leaving
  the tree broken.

## 6. Summarize

Report: what was **fixed** (with file:line), what was **skipped** and why, and the resulting `git
diff --stat`. End with a one-line verdict.
