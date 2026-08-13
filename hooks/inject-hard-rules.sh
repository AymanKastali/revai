#!/usr/bin/env bash
#
# Layer 1 of the revai harness: put every standard's rules in context at the start of every session.
#
# Each card is extracted from its own SKILL.md at runtime rather than duplicated here, so every
# SKILL.md stays the single source of truth for its standard and the two can never drift apart.
#
# A broken hook must never cost the user a session: every failure path warns on stderr and exits 0.

set -uo pipefail

readonly FENCE_START='<!-- HARD-RULES:START -->'
readonly FENCE_END='<!-- HARD-RULES:END -->'

# Standards to inject, in order, as "skill-directory:xml-tag".
readonly STANDARDS=(
  'clean-code:clean-code'
  'best-practices:best-practices'
  'domain-driven-design:domain-driven-design'
  'modular-monolith:modular-monolith'
)

plugin_root() {
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    printf '%s' "$CLAUDE_PLUGIN_ROOT"
    return
  fi
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

# Prints the fenced rules of one skill, or nothing if they cannot be read.
extract_card() {
  local skill="$1" file="$2" card

  if [[ ! -r "$file" ]]; then
    echo "revai: cannot read ${file} — ${skill} rules not injected" >&2
    return 1
  fi

  # sed picks the fenced block, then drops the two fence lines themselves.
  card="$(sed -n "\|${FENCE_START}|,\|${FENCE_END}|p" "$file" | sed '1d;$d')"

  if [[ -z "${card//[[:space:]]/}" ]]; then
    echo "revai: HARD-RULES fence missing or empty in ${file}" >&2
    return 1
  fi

  printf '%s\n' "$card"
}

root="$(plugin_root)"
cards=''
skill_names=''

for standard in "${STANDARDS[@]}"; do
  skill="${standard%%:*}"
  tag="${standard##*:}"
  card="$(extract_card "$skill" "${root}/skills/${skill}/SKILL.md")" || continue
  cards+="<${tag}>"$'\n'"${card}"$'\n'"</${tag}>"$'\n\n'
  skill_names+="${skill_names:+, }\`revai:${skill}\`"
done

if [[ -z "$cards" ]]; then
  echo 'revai: no standards could be injected' >&2
  exit 0
fi

cat <<EOF
<revai-standards>
The standards below are in force for every piece of code you write or change in this session, in any
language. They are not suggestions. Before you finish a turn that touched source files, a gate will
require that the review agents have passed over your diff.

Each standard states its own scope. \`clean-code\` applies to every line you write.
\`best-practices\` gates each of its groups on a named concern, so only the groups your change
actually touches are in play. \`domain-driven-design\` applies only where its own first rules say it
does — read them before using any pattern from it, and say so when it does not apply.
\`modular-monolith\` applies when the system is one deployable holding more than one business
capability, and governs only what crosses a module boundary.

For depth on any rule — worked examples, decision tables and the anti-pattern catalogues — invoke
${skill_names}.

${cards}</revai-standards>
EOF
