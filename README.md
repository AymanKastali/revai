# revai — Personal AI Agent Harness

**revai** (revolution of AI) is a reusable **agent harness**: a bundle of AI knowledge — skills,
slash commands, workflows, subagents, and conventions — authored *once* and attached to *any*
codebase to make AI-driven development more reliable.

The **agent** is Claude Code doing the work. The **harness** is everything built around it —
context, capabilities, guardrails, and feedback loops — so it produces work that actually holds up
instead of just looking right. revai is that harness, delivered as a Claude Code **plugin** so one
central source of truth can be strapped onto every project you work in.

## How it's delivered

revai is a Claude Code plugin that also acts as its own marketplace. You author here; each codebase
enables the plugin. Improvements live in one place and propagate on demand.

## Attaching revai to a codebase

```bash
# once per machine — register revai as a marketplace
/plugin marketplace add AymanKastali/revai          # from GitHub
# (during local development: /plugin marketplace add ~/Documents/me/revai)

/plugin install revai@revai                   # install the harness
```

Then, inside the target repo:

```bash
/revai:attach
```

`/revai:attach` enables the plugin for that repo (`.claude/settings.json`), detects its stack,
records the verify commands (install/run/test/lint/format), and writes a project `CLAUDE.md` so the
AI knows how to check its own work. It never overwrites files you already have.

New repo or existing one — the steps are identical.

## Keeping projects in sync

Plugins are copied into a local cache, so changes here don't propagate automatically. After you
push an improvement, pull it into a project with:

```bash
/plugin update revai@revai      # then start a fresh session, or /reload-plugins
```

One central brain, synced with one command.

## Bundled backend skills

Once revai is installed, these skills surface automatically when their subject comes up — no setup
per repo. They complement the other plugins rather than duplicate them, and each is a tight rule set
+ checklist + a concrete example (Go and Python where code is shown; SQL/HTTP where that's clearer).

| Skill | Fires when you're… |
|---|---|
| `api-design` | Designing or adding an HTTP endpoint or resource |
| `config-and-secrets` | Loading config/secrets or wiring startup |
| `data-access-patterns` | Writing queries, repositories, or transactions |
| `safe-schema-changes` | Writing a migration or altering a schema |
| `error-handling-and-logging` | Writing error paths, `try`/`catch`, or logging |
| `resilience-and-timeouts` | Calling a network dependency, retrying, or handling startup/shutdown |
| `backend-testing` | Writing tests for APIs, services, or data access |
| `naming-and-structure` | Naming anything, or shaping units/layers (any code, not only backend) |
| `bounded-contexts` | Drawing a domain boundary, naming a module/service, or integrating two subsystems (strategic DDD) |
| `domain-modeling` | Modelling a domain type, adding an invariant, or deciding where a rule lives (tactical DDD) |
| `hexagonal-architecture` | Structuring a module, placing code in a layer, or wiring ports/adapters (modular monolith + logical CQRS) |

## Feature workflow (`/revai:feature`)

One gated pipeline that takes a feature from a description to an open PR:
**plan → implement → verify → review → PR**. Invoke it in a repo that has revai attached:

```bash
/revai:feature "add idempotent refund endpoint to the billing module"
```

It **orchestrates** — it doesn't reinvent. The heavy lifting is done by the `superpowers` skills
(`brainstorming`, `writing-plans`, `executing-plans`, `test-driven-development`,
`verification-before-completion`, `finishing-a-development-branch`); the command sequences them and
injects revai's own layer — your project `CLAUDE.md` rules, the backend skills, the `backend-review`
agent, and the verify-on-Stop hook.

It stops for your approval at **two gates** and runs automatically between them:

1. **Gate 1 — plan.** Produces a written plan that names the module/bounded context, the layers
   touched, the skills in scope, and the tests to write first — then waits for your OK before any
   code is written.
2. Implement (TDD by default) → verify (`.revai/verify.json`) → review (`backend-review` agent,
   looping fix→verify→review until clean) all run on their own.
3. **Gate 2 — PR.** Presents a completion summary and proposed PR title/body, then waits for your OK
   before it branches-safe, pushes, and opens the PR with `gh`.

## Review agent & guardrail

Skills are advisory — these make them stick:

- **`backend-review` agent** — dispatch it (e.g. "review the backend changes") to audit the current
  diff against all the skills at once and report findings by severity. Read-only; it reports, it
  doesn't edit.
- **Secrets guardrail (hook)** — a `PreToolUse` hook blocks any `git commit` whose staged changes
  add a private key, cloud/API token, or inline credential. Deterministic and unskippable by the
  agent — it runs in every repo that enables revai.
- **Verify-on-Stop (hook)** — a `Stop` hook runs the project's recorded verify commands (from
  `.revai/verify.json`, written by `/revai:attach`) when the agent tries to finish, and **blocks
  completion if a blocking check fails** — turning "evidence before assertions" into enforcement.
  Tiered (test/lint block; build/format advisory), scoped to turns that changed code, and it relents
  after a few attempts so a stuck build can't loop forever.

## Extending revai

Add a capability, commit, push, then `/plugin update` where you want it:

- **Skill** → `skills/<name>/SKILL.md` (plus optional supporting files in that folder).
- **Slash command** → `commands/<name>.md` (becomes `/revai:<name>`).
- **Subagent** → `agents/<name>.md`.
- **Hook** → `hooks/hooks.json`.

Bump `version` in `.claude-plugin/plugin.json` for stable releases.

> Scope note: revai does **not** duplicate skills already provided by the `superpowers`,
> `code-simplifier`, `security-guidance`, or `claude-md-management` plugins. It adds the personal,
> project-attach, and verification layer on top of them.

## Layout

```
revai/
├── .claude-plugin/
│   ├── plugin.json          # declares the "revai" plugin
│   └── marketplace.json     # lists revai as installable (source ".")
├── commands/                # /revai:attach (setup) and /revai:feature (workflow)
├── templates/               # files /revai:attach instantiates into a project
├── skills/                  # reusable skills (api-design, safe-schema-changes, …)
├── CLAUDE.md                # conventions for developing revai itself
└── README.md
```
