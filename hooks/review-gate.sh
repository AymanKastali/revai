#!/usr/bin/env bash
#
# Layer 3 of the revai harness: refuse to end a turn that changed source files until the review
# agents have passed over the diff.
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
#
# The dotfile rule carries its weight: a repo's configuration lives in files like .gitignore and
# .markdownlint-cli2.jsonc, which no extension list catches (.gitignore has none, .jsonc is not
# .json). Without it, editing either one demands four code reviews of a file holding no code. A
# real source file is essentially never a dotfile, and a dotfile *directory* is unaffected — the
# basename is what is tested, so .github/scripts/deploy.py is still gated.
changed_source_files() {
  {
    git diff --name-only HEAD
    git diff --cached --name-only
    git ls-files --others --exclude-standard
  } 2>/dev/null |
    sort -u |
    grep -vE '\.(md|markdown|txt|jsonc?|json5|ya?ml|toml|ini|cfg|lock|sum|svg|png|jpg)$' |
    grep -vE '(^|/)\.[^/]*$' |
    grep -vE '(^|/)(vendor|node_modules|third_party|dist|build|target|\.git|\.revai)/' |
    grep -vE '(_pb2?\.py|\.pb\.go|_generated\.|\.gen\.|\.min\.)'
}

# Paths that sit inside a DDD-layered context, so the demand can name them instead of leaving the
# agent to guess whether ddd-review applies. A heuristic on purpose: ddd-review decides applicability
# itself, and half of what matches here — infra/, adapters/, ports/ — is by definition NOT the domain
# layer. It is dispatched on them because DDD rules 63-67 govern the layering those directories are.
#
# `app` is deliberately absent. It is the use-case layer under domain-driven-design rule 67, but a
# bare `app/` segment is also every Next.js route and every Rails tree, and the false positive costs
# a full review pass on each. Under the adopted layout (go-project-layout rule 6) `context/` already
# matches the whole subtree, so nothing is lost there; only a flat hexagonal tree slips through, and
# it slips through to the softer "use judgment" demand rather than to nothing.
readonly DDD_LAYER_DIRS='domain|aggregates?|entit(y|ies)|value[-_]?objects?|application|use[-_]?cases?|adapters?|infra(structure)?|ports?|contexts?'
readonly DDD_NAME_TOKENS='aggregate|repositor|value[-_]object|domain[-_]event|invariant|specification'

ddd_layered_files() {
  printf '%s\n' "$1" | grep -iE "(^|/)(${DDD_LAYER_DIRS})/|(${DDD_NAME_TOKENS})"
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
  echo "revai: review gate relented after ${MAX_ATTEMPTS} attempts on this diff" >&2
  exit 0
fi

mkdir -p "$STATE_DIR"
# Only this diff's counter is kept, so the file cannot grow without bound.
printf '%s %s\n' "$diff_hash" "$(( attempts + 1 ))" > "$ATTEMPTS_FILE"

layered_files="$(ddd_layered_files "$files" || true)"
if [[ -n "$layered_files" ]]; then
  ddd_demand="Required — these changed paths sit inside a DDD-layered context:
${layered_files}"
else
  ddd_demand='Required unless the diff plainly models no business rules — a script, config or pure
     glue. When in doubt dispatch it: its first step is a one-line "not applicable" verdict.'
fi

cat >&2 <<EOF
Review gate: you changed source files and have not reviewed this diff.

Before finishing:
  1. Dispatch the \`clean-code-review\` agent on the current diff. Always required.
  2. Dispatch the \`best-practices-review\` agent on the current diff. Always required.
  3. Dispatch the \`modular-monolith-review\` agent on the current diff. Always required — its own
     rule 1 decides whether the standard applies at all, and reports "not applicable" when it doesn't.
  4. Dispatch the \`ddd-review\` agent. ${ddd_demand}
     Steps 1-4 are independent: dispatch them in a single message so they run concurrently.
  5. Fix every HIGH finding from all four. MEDIUM and LOW are advisory — report them, don't ignore
     them silently.
  6. Record the reviewed diff so this gate clears:
       mkdir -p ${STATE_DIR} && echo ${diff_hash} >> ${REVIEWED_FILE}

Changed source files:
${files}
EOF
exit 2
