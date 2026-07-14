# revai — developing the harness itself

This repo IS a Claude Code plugin (and its own marketplace). It carries reusable AI knowledge that
gets attached to other codebases. See `README.md` for the user-facing overview.

## Plugin structure rules

- `plugin.json` and `marketplace.json` live **only** inside `.claude-plugin/`. Nothing else goes there.
- All component dirs live at the repo **root**: `commands/`, `skills/`, `agents/`, `hooks/`,
  `templates/`.
- A skill is a folder `skills/<name>/SKILL.md` (kebab-case name), optionally with supporting files.
- A command is `commands/<name>.md` and surfaces as `/revai:<name>`.
- Reference bundled files from a command/skill with `${CLAUDE_PLUGIN_ROOT}` (the plugin's install path).

## Conventions

- Keep each skill/command focused on one job. Split when it grows past a single clear purpose.
- **Do not duplicate** skills already provided by `superpowers`, `code-simplifier`,
  `security-guidance`, or `claude-md-management`. Add what complements them.
- Validate JSON before committing: `jq . .claude-plugin/*.json`.
- Bump `version` in `.claude-plugin/plugin.json` for stable releases.
- After changing components, remember consumers pull updates via `/plugin update revai@revai`
  (they don't auto-sync).
- Design docs from brainstorming/planning live under `docs/` and are **gitignored** — local only,
  never shipped with the plugin. `docs/` is deliberately not a plugin component dir.

## How to verify your work

There's no build/test suite. Verification for changes here means:

| Purpose | Command |
|---|---|
| Manifests parse | `jq . .claude-plugin/plugin.json .claude-plugin/marketplace.json` |
| Component loads  | `/reload-plugins`, then confirm the skill/command appears |
| Full self-audit  | `/revai:doctor` — structure, dead refs, README/skill-table drift, skill quality |
