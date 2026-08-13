#!/usr/bin/env bash
#
# Layer 1 of the clean-code harness: put the rules in context at the start of every session.
#
# The card is extracted from SKILL.md at runtime rather than duplicated here, so SKILL.md stays the
# single source of truth and the two can never drift apart.
#
# A broken hook must never cost the user a session: every failure path warns on stderr and exits 0.

set -uo pipefail

readonly FENCE_START='<!-- HARD-RULES:START -->'
readonly FENCE_END='<!-- HARD-RULES:END -->'

plugin_root() {
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    printf '%s' "$CLAUDE_PLUGIN_ROOT"
    return
  fi
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

skill_file="$(plugin_root)/skills/clean-code/SKILL.md"

if [[ ! -r "$skill_file" ]]; then
  echo "revai: cannot read ${skill_file} — clean-code rules not injected" >&2
  exit 0
fi

# sed picks the fenced block, then drops the two fence lines themselves.
card="$(sed -n "\|${FENCE_START}|,\|${FENCE_END}|p" "$skill_file" | sed '1d;$d')"

if [[ -z "${card//[[:space:]]/}" ]]; then
  echo "revai: HARD-RULES fence missing or empty in ${skill_file}" >&2
  exit 0
fi

cat <<EOF
<clean-code-standard>
The rules below are in force for every piece of code you write or change in this session, in any
language. They are not suggestions. Before you finish a turn that touched source files, a gate will
require that the clean-code-review agent has passed over your diff.

For depth on any rule — worked bad/good examples and the Ch17 smells catalog — invoke the
\`revai:clean-code\` skill.

${card}
</clean-code-standard>
EOF
