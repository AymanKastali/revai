#!/usr/bin/env bash
#
# Layer 3 of the clean-code harness: refuse to end a turn that changed source files until the
# clean-code-review agent has passed over the diff.
#
# A shell hook cannot dispatch a subagent, so this gate DEMANDS the review rather than running it:
# it blocks with instructions, and clears once the reviewed diff hash is recorded.
#
# Exit codes: 0 = let the turn finish, 2 = block and feed stderr back to the agent.

set -uo pipefail

readonly STATE_DIR='.revai'
readonly REVIEWED_FILE="${STATE_DIR}/reviewed"
readonly ATTEMPTS_FILE="${STATE_DIR}/gate-attempts"
readonly MAX_ATTEMPTS=3

# Outside a git repo there is no diff to gate on.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Docs, config, lockfiles, vendored trees and generated output are not source we judge.
changed_source_files() {
  {
    git diff --name-only HEAD
    git diff --cached --name-only
    git ls-files --others --exclude-standard
  } 2>/dev/null |
    sort -u |
    grep -vE '\.(md|markdown|txt|json|ya?ml|toml|ini|cfg|lock|sum|svg|png|jpg)$' |
    grep -vE '(^|/)(vendor|node_modules|third_party|dist|build|target|\.git|\.revai)/' |
    grep -vE '(_pb2?\.py|\.pb\.go|_generated\.|\.gen\.|\.min\.)'
}

# Hash the names and contents of exactly the files being gated, so any further edit to them
# invalidates a recorded review — and so the gate's own bookkeeping never shifts the hash.
source_diff_hash() {
  local file_list="$1" file
  {
    printf '%s\n' "$file_list"
    while IFS= read -r file; do
      [[ -f "$file" ]] && cat -- "$file"
    done <<< "$file_list"
  } 2>/dev/null | sha1sum | cut -d' ' -f1
}

recorded_attempts() {
  local hash="$1"
  [[ -f "$ATTEMPTS_FILE" ]] || { printf '0'; return; }
  awk -v h="$hash" '$1 == h { print $2; found = 1 } END { if (!found) print 0 }' "$ATTEMPTS_FILE"
}

files="$(changed_source_files || true)"
[[ -z "$files" ]] && exit 0

diff_hash="$(source_diff_hash "$files")"
[[ -z "$diff_hash" ]] && exit 0

if [[ -f "$REVIEWED_FILE" ]] && grep -qxF "$diff_hash" "$REVIEWED_FILE"; then
  exit 0
fi

attempts="$(recorded_attempts "$diff_hash")"
if (( attempts >= MAX_ATTEMPTS )); then
  echo "revai: clean-code gate relented after ${MAX_ATTEMPTS} attempts on this diff" >&2
  exit 0
fi

mkdir -p "$STATE_DIR"
# Only this diff's counter is kept, so the file cannot grow without bound.
printf '%s %s\n' "$diff_hash" "$(( attempts + 1 ))" > "$ATTEMPTS_FILE"

cat >&2 <<EOF
Clean-code gate: you changed source files and have not reviewed this diff.

Before finishing:
  1. Dispatch the \`clean-code-review\` agent on the current diff.
  2. Fix every HIGH finding. MEDIUM and LOW are advisory — report them, don't ignore them silently.
  3. Record the reviewed diff so this gate clears:
       mkdir -p ${STATE_DIR} && echo ${diff_hash} >> ${REVIEWED_FILE}

Changed source files:
${files}
EOF
exit 2
