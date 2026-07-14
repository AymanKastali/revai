---
description: Audit the revai plugin itself — structure, dead references, docs drift, and skill content quality — then offer to fix the safe issues.
---

# /revai:doctor

Check the health of **this plugin repo**. Run concrete shell probes for everything mechanical,
read the skills for the judgment calls, emit **one** grouped, severity-ranked report, then offer
to fix the safe/mechanical issues behind a single gate.

**Core rule: never claim a check passed without running it.** For every mechanical check below,
run the shown probe and read its real output. Only content quality (§4) relies on your judgment,
because no deterministic probe exists for it.

Run from the repo root. All checks operate on the working tree — treat `${CLAUDE_PLUGIN_ROOT}`
references in files as pointing at the repo root (`.`).

## 1. Structural integrity  (severity: error)

- **Manifests parse** — both must be valid JSON:
  ```bash
  jq . .claude-plugin/plugin.json .claude-plugin/marketplace.json >/dev/null
  ```
- **Manifests live only in `.claude-plugin/`** — nothing else belongs there, and no stray
  `plugin.json`/`marketplace.json` elsewhere:
  ```bash
  ls .claude-plugin/
  find . -path ./.git -prune -o -name 'plugin.json' -print -o -name 'marketplace.json' -print
  ```
- **Component dirs are at the repo root** — `commands/ skills/ agents/ hooks/ templates/`.
- **Each skill is well-formed** — for every `skills/*/` directory, confirm:
  - `SKILL.md` exists;
  - its frontmatter has non-empty `name` and `description`;
  - the frontmatter `name` equals the folder name;
  - the folder name is kebab-case (`^[a-z0-9]+(-[a-z0-9]+)*$`).
  ```bash
  for d in skills/*/; do
    name=$(basename "$d")
    [ -f "$d/SKILL.md" ] || echo "MISSING SKILL.md: $name"
    fm=$(awk '/^---$/{n++;next} n==1' "$d/SKILL.md" 2>/dev/null)
    echo "$fm" | grep -q '^name:' || echo "NO name: frontmatter: $name"
    echo "$fm" | grep -q '^description:' || echo "NO description: frontmatter: $name"
    fmname=$(echo "$fm" | sed -n 's/^name:[[:space:]]*//p')
    [ "$fmname" = "$name" ] || echo "name mismatch: folder=$name frontmatter=$fmname"
    echo "$name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' || echo "not kebab-case: $name"
  done
  ```
- **Each command has frontmatter** — every `commands/*.md` starts with a `---` block containing
  at least a `description`.

## 2. Dead references  (severity: error)

- **`${CLAUDE_PLUGIN_ROOT}` targets exist** — extract every referenced path in `commands/` and
  `skills/`, resolve the variable to `.`, and confirm the file exists:
  ```bash
  grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}[^ ")`'"'"']*' commands/ skills/ | sort -u |
  while read -r ref; do
    p="${ref/\$\{CLAUDE_PLUGIN_ROOT\}/.}"
    [ -e "$p" ] || echo "DEAD REF: $ref"
  done
  ```
- **Hook scripts exist and are executable** — parse the script paths out of `hooks/hooks.json`:
  ```bash
  jq -r '.. | .command? // empty' hooks/hooks.json |
  while read -r ref; do
    p="${ref/\$\{CLAUDE_PLUGIN_ROOT\}/.}"
    [ -e "$p" ] || { echo "HOOK MISSING: $ref"; continue; }
    [ -x "$p" ] || echo "HOOK NOT EXECUTABLE: $ref"
  done
  ```

## 3. Docs drift  (severity: warning)

- **README skill table matches `skills/`** — diff the actual skill folders against the skills
  named in the README table, both directions (nothing missing, nothing stale). Compare
  `ls -1 skills/` to the skill names you find in `README.md`'s table and report each asymmetry.
- **Manifests agree** — `plugin.json` and `marketplace.json` name the same plugin (and agree on
  `version` where both carry it):
  ```bash
  jq -r '.name' .claude-plugin/plugin.json
  jq -r '.plugins[].name' .claude-plugin/marketplace.json
  ```

## 4. Content quality  (severity: advisory — report-only)

Read each `skills/*/SKILL.md` and judge:

- **One job** — is the skill focused on a single clear purpose (per `CLAUDE.md`), or has it grown
  past that and should be split?
- **No duplication** — does it duplicate a skill already provided by `superpowers`,
  `code-simplifier`, `security-guidance`, or `claude-md-management`? It should complement, not
  restate them.
- **Description matches body** — does the `description` frontmatter accurately describe what the
  skill actually does?

These are always report-only. Do not auto-fix content.

## 5. Report

Emit **one** report, grouped and ordered by severity:

1. 🔴 **Errors** — structural integrity (§1), dead references (§2).
2. 🟡 **Warnings** — docs drift (§3).
3. 🔵 **Advisories** — content quality (§4).

Each finding names the file and the specific problem. If everything passes, print a short
all-pass summary and stop — there is nothing to fix.

## 6. Offer fixes  ⏸ GATE

If any **safe/mechanical** issues were found, list them and ask the user once whether to fix
them. Fix nothing before they approve.

- **Safe to fix (offer these):**
  - `chmod +x` a hook script that lost its executable bit;
  - sync the README skill table to match `skills/` (add missing rows, remove stale rows);
  - correct a plainly-wrong `${CLAUDE_PLUGIN_ROOT}` path where the intended target is unambiguous.
- **Report-only (never auto-fix):**
  - all content-quality advisories (§4);
  - any structural issue with more than one plausible fix — e.g. a missing `SKILL.md`, or a
    frontmatter `name` that disagrees with its folder (fixing either side is a judgment call).
    Surface these for the user to resolve.

On approval, apply only the safe set, then **re-run the affected probes** to confirm the issues
are resolved. Report what was fixed and what remains for the user to decide.
