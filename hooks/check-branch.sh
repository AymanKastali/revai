#!/usr/bin/env bash
# revai PreToolUse guard: block a `git commit` or `git push` made directly on the default branch.
# /revai:implement is expected to create a feature branch before any commit — this is the
# deterministic backstop for when that step gets skipped or forgotten.
# Exit 2 blocks the tool call and shows the message to the agent; exit 0 allows it.
set -euo pipefail

input="$(cat)"

# Only act on commits/pushes — every other Bash call passes straight through.
grep -Eq 'git[[:space:]]+(commit|push)' <<<"$input" || exit 0

# Need to be inside a git repo.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch="$(git branch --show-current 2>/dev/null || true)"
[ -z "$branch" ] && exit 0  # detached HEAD or no commits yet — nothing to protect

case "$branch" in
  main|master)
    {
      echo "revai: blocked a git commit/push directly on '$branch'."
      echo "Create a feature branch first — /revai:implement's Approve & branch gate does this"
      echo "automatically (feat/, fix/, or refactor/ prefix) once you approve what's being built."
    } >&2
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
