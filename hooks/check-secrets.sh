#!/usr/bin/env bash
# revai PreToolUse guard: block a `git commit` that would introduce a secret.
# Scans only the ADDED lines of the staged diff for high-confidence secret patterns.
# Exit 2 blocks the tool call and shows the message to the agent; exit 0 allows it.
set -euo pipefail

input="$(cat)"

# Only act on git commits — every other Bash call passes straight through.
grep -Eq 'git[[:space:]]+commit' <<<"$input" || exit 0

# Need to be inside a git repo.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Only the newly added lines (drop the +++ file header).
added="$(git diff --cached 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' || true)"
[ -z "$added" ] && exit 0

# High-confidence patterns — curated to minimize false positives.
# Note: this is precision-over-recall, named-pattern matching, not a general secrets scanner —
# it won't catch an arbitrary high-entropy token (a random-looking Stripe/JWT/GCP-JSON secret)
# that doesn't match one of these shapes. That's an accepted, documented gap, not an oversight.
patterns=(
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'                                              # private keys
  'AKIA[0-9A-Z]{16}'                                                                # AWS access key id
  'ghp_[0-9A-Za-z]{36}'                                                             # GitHub PAT
  'xox[baprs]-[0-9A-Za-z-]{10,}'                                                    # Slack token
  'AIza[0-9A-Za-z_-]{35}'                                                           # Google API key
  '[A-Za-z0-9_-]*(password|passwd|secret|api[_-]?key|access[_-]?token)[A-Za-z0-9_-]*[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}["'"'"']'  # quoted inline credential
)

matched=""
for p in "${patterns[@]}"; do
  if grep -Eiq -e "$p" <<<"$added"; then
    matched+=$'\n'"  • $p"
  fi
done

# Unquoted KEY=VALUE / KEY: VALUE credential assignment — the .env / shell-export / unquoted-YAML
# shape the quoted pattern above can't see. The credential keyword can be a substring of a longer
# identifier (AWS_SECRET_ACCESS_KEY, DB_PASSWORD — the common real-world naming shape), not just a
# bare word. Require a long, space-free value and exclude obvious placeholders (changeme, example,
# <...>, ${...}) to keep this from flagging fixture/template values.
unquoted_re='[A-Za-z0-9_-]*(password|passwd|secret|api[_-]?key|access[_-]?token)[A-Za-z0-9_-]*[[:space:]]*[:=][[:space:]]*[^[:space:]"'"'"']{16,}'
placeholder_re='(changeme|change_me|your[_-]|example|placeholder|xxx|redacted|todo|<.*>|\$\{)'
unquoted_hits="$(grep -Ei -e "$unquoted_re" <<<"$added" | grep -Eiv -e "$placeholder_re" || true)"
[ -n "$unquoted_hits" ] && matched+=$'\n'"  • unquoted credential assignment"

[ -z "$matched" ] && exit 0

{
  echo "revai: potential secret in staged changes — commit blocked."
  echo "Matched pattern(s):$matched"
  echo "Remove or redact the value (use env/config — see the config-and-secrets skill),"
  echo "or, if this is a confirmed false positive, tell the user and re-stage without the flagged line."
} >&2
exit 2
