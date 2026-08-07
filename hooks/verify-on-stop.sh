#!/usr/bin/env bash
# revai Stop guard: before the agent finishes, run the project's recorded verify
# commands and block completion if a BLOCKING one fails. Turns "evidence before
# assertions" into enforcement.
#
# Source of truth: .revai/verify.json in the project root (written by /revai:attach):
#   { "commands": [ { "name": "test", "cmd": "go test ./...", "blocking": true }, ... ] }
# blocking=true  → failure blocks the stop and feeds the agent the output (exit 2).
# blocking=false → advisory: reported, never blocks.
#
# No config → no-op. Runs when code changed this turn — either it's still uncommitted, or it was
# committed since the session started (tracked by session-start.sh, since a turn that edits AND
# commits leaves a clean tree by Stop time and `git status` alone can't see that). Gives up
# blocking after MAX_ATTEMPTS so a genuinely stuck build can't loop forever.
set -euo pipefail

MAX_ATTEMPTS=3
EMPTY_TREE_SHA="4b825dc642cb6eb9a060e54bf8d69288fbee4904"  # git's well-known empty-tree object

input="$(cat)"

# jq is required to read the payload and config; degrade to a no-op if it's absent
# (never break someone's workflow because a tool is missing — fail open on tooling).
if ! command -v jq >/dev/null 2>&1; then
  echo "revai verify-on-stop: jq not found — skipping the verify gate. Install jq to enable it." >&2
  exit 0
fi

cwd="$(jq -r '.cwd // empty' <<<"$input")"
[ -z "$cwd" ] && cwd="$PWD"
session_id="$(jq -r '.session_id // "nosession"' <<<"$input")"

config="$cwd/.revai/verify.json"
[ -f "$config" ] || exit 0                      # not attached / no verify config → nothing to do

if ! jq -e . "$config" >/dev/null 2>&1; then    # malformed config → warn, don't block
  echo "revai verify-on-stop: $config is not valid JSON — skipping." >&2
  exit 0
fi

# Scope: only verify when code actually changed. A docs-only or Q&A turn shouldn't
# pay for the test suite. If it isn't a git repo we can't tell, so we proceed.
is_code_file() {
  case "$1" in
    *.md|*.txt|*.rst|docs/*|*/docs/*) return 1 ;;   # docs — ignore for scope
    *) return 0 ;;
  esac
}

if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  code_changed=false

  # Currently uncommitted (working-tree or staged) changes.
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    is_code_file "$f" && code_changed=true
  done < <(git -C "$cwd" status --porcelain 2>/dev/null | sed 's/^...//; s/.* -> //')

  # Commits made since this session started (session-start.sh's baseline) — catches a turn that
  # edits AND commits before stopping, which the dirty-tree check above can't see.
  baseline_file="${TMPDIR:-/tmp}/revai-verify-head-${session_id//[^A-Za-z0-9_-]/_}"
  baseline_head="$(cat "$baseline_file" 2>/dev/null || true)"
  current_head="$(git -C "$cwd" rev-parse HEAD 2>/dev/null || echo "unborn")"
  if [ -n "$baseline_head" ] && [ "$baseline_head" != "$current_head" ]; then
    from="$baseline_head"
    [ "$from" = "unborn" ] && from="$EMPTY_TREE_SHA"
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      is_code_file "$f" && code_changed=true
    done < <(git -C "$cwd" diff --name-only "$from" "$current_head" 2>/dev/null || true)
  fi

  $code_changed || exit 0
fi

# Run a command from the project root, with a timeout when one is available.
run_cmd() {
  if command -v timeout >/dev/null 2>&1; then
    (cd "$cwd" && timeout 300 bash -c "$1" 2>&1)
  else
    (cd "$cwd" && bash -c "$1" 2>&1)
  fi
}

# Keep only the tail of noisy output so the agent gets the failure, not a flood.
tail_output() { tail -n 40; }

blocking_report=""
advisory_report=""

while IFS=$'\t' read -r blocking name cmd; do
  [ -z "${cmd:-}" ] && continue
  case "$cmd" in *TODO*|*"{{"*) continue ;; esac   # skip unfilled placeholders
  if out="$(run_cmd "$cmd")"; then
    continue                                       # passed
  fi
  entry=$'\n'"  ✗ $name  (\`$cmd\`)"$'\n'"$(printf '%s' "$out" | tail_output | sed 's/^/    /')"
  if [ "$blocking" = "true" ]; then
    blocking_report+="$entry"
  else
    advisory_report+="$entry"
  fi
done < <(jq -r '.commands[]? | [(.blocking // false | tostring), (.name // "check"), (.cmd // "")] | @tsv' "$config")

counter_file="${TMPDIR:-/tmp}/revai-verify-${session_id//[^A-Za-z0-9_-]/_}.count"

# All blocking checks passed.
if [ -z "$blocking_report" ]; then
  rm -f "$counter_file"
  if [ -n "$advisory_report" ]; then
    echo "revai verify-on-stop: blocking checks passed. Advisory checks reporting issues:$advisory_report" >&2
  fi
  exit 0
fi

# A blocking check failed — block the stop up to MAX_ATTEMPTS, then relent so a
# genuinely stuck check can't trap the agent in a loop.
attempts=0
[ -f "$counter_file" ] && attempts="$(cat "$counter_file" 2>/dev/null || echo 0)"
attempts=$((attempts + 1))

if [ "$attempts" -ge "$MAX_ATTEMPTS" ]; then
  rm -f "$counter_file"
  {
    echo "revai verify-on-stop: blocking checks still failing after $MAX_ATTEMPTS attempts — allowing stop."
    echo "These need a human's attention:$blocking_report"
  } >&2
  exit 0
fi

echo "$attempts" > "$counter_file"
{
  echo "revai verify-on-stop: do not stop yet — blocking verify checks failed (attempt $attempts/$MAX_ATTEMPTS)."
  echo "Fix these, then finish:$blocking_report"
  [ -n "$advisory_report" ] && echo "Advisory (not blocking):$advisory_report"
} >&2
exit 2
