#!/usr/bin/env bash
# revai SessionStart hook: record the repo's HEAD as this session's baseline, so verify-on-stop.sh
# can tell "code changed this turn" apart from "the working tree happens to be dirty right now" —
# a turn that edits AND commits code before stopping would otherwise look clean at Stop time and
# silently skip verification. No-op outside a git repo.
set -euo pipefail

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null || true)"
  session_id="$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null || true)"
else
  cwd=""
  session_id=""
fi
[ -z "$cwd" ] && cwd="$PWD"
[ -z "$session_id" ] && session_id="nosession"

git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

head_sha="$(git -C "$cwd" rev-parse HEAD 2>/dev/null || echo "unborn")"
echo "$head_sha" > "${TMPDIR:-/tmp}/revai-verify-head-${session_id//[^A-Za-z0-9_-]/_}"
exit 0
