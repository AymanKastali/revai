#!/usr/bin/env bash
# revai PreToolUse guard: block a `git commit` or `git push` that would land directly on the
# default branch — whether by being checked out on it, or (for push) by targeting it via an
# explicit refspec from a different branch, e.g. `git push origin feat/x:main`.
# /revai:implement is expected to create a feature branch before any commit — this is the
# deterministic backstop for when that step gets skipped or forgotten.
# Exit 2 blocks the tool call and shows the message to the agent; exit 0 allows it.
set -euo pipefail

input="$(cat)"

# Only act on commits/pushes — every other Bash call passes straight through.
grep -Eq 'git[[:space:]]+(commit|push)' <<<"$input" || exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

is_protected() {
  case "${1#refs/heads/}" in main|master) return 0 ;; *) return 1 ;; esac
}

block() {
  {
    echo "revai: blocked a git $1 that would land directly on '$2'."
    echo "Create a feature branch first — /revai:implement's Approve & branch gate does this"
    echo "automatically (feat/, fix/, or refactor/ prefix) once you approve what's being built."
  } >&2
  exit 2
}

current_branch="$(git branch --show-current 2>/dev/null || true)"

# `git commit` is blocked outright when checked out on the protected branch.
if grep -Eq 'git[[:space:]]+commit' <<<"$input" \
   && [ -n "$current_branch" ] \
   && is_protected "$current_branch"; then
  block "commit" "$current_branch"
fi

grep -Eq 'git[[:space:]]+push' <<<"$input" || exit 0

# `git push` needs the actual command text, not just the checked-out branch — a push can target
# the protected branch via an explicit refspec from anywhere (`git push origin feat/x:main`).
# Without jq we can't reliably pull that text out of the raw hook payload, so fall back to the
# checked-out-branch check above only — a known, accepted gap rather than a fragile text scrape.
command -v jq >/dev/null 2>&1 || exit 0
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

# Each `git push ...` invocation up to the next chain separator (&&, ;, |) or end of string.
while IFS= read -r invocation; do
  [ -z "$invocation" ] && continue

  args="$(sed -E 's/^.*git[[:space:]]+push[[:space:]]*//' <<<"$invocation")"
  read -r -a tokens <<<"$args"
  positional=()
  for t in "${tokens[@]}"; do
    [ "${t:0:1}" = "-" ] && continue   # drop flags like --force, --delete, -u
    positional+=("$t")
  done

  dest=""
  case "${#positional[@]}" in
    0)
      # `git push` alone — resolve the configured push destination (falls back to the current
      # branch if none is configured, e.g. push.default=current).
      dest="$(git rev-parse --abbrev-ref '@{push}' 2>/dev/null | sed -E 's#^[^/]+/##' || true)"
      [ -z "$dest" ] && dest="$current_branch"
      ;;
    1)
      # `git push <remote>` — pushes the current branch to a same-named ref on that remote.
      dest="$current_branch"
      ;;
    *)
      # `git push <remote> <refspec> ...` — the refspec's destination is what actually lands.
      refspec="${positional[1]#+}"   # drop a leading force marker on the refspec itself
      case "$refspec" in
        *:*) dest="${refspec#*:}" ;;   # explicit src:dst (incl. `:dst` delete form) — dst lands
        *)   dest="$refspec" ;;        # `<branch>` alone — same-named push
      esac
      ;;
  esac

  [ -n "$dest" ] && is_protected "$dest" && block "push" "$dest"
done < <(grep -oE 'git[[:space:]]+push[^&;|]*' <<<"$cmd")

exit 0
