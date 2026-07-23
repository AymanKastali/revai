# revai — Personal AI Agent Harness

**revai** (revolution of AI) is a reusable **agent harness**: a bundle of AI knowledge — skills,
slash commands, workflows, subagents, and conventions — authored *once* and attached to *any*
codebase to make AI-driven development more reliable.

The **agent** is Claude Code doing the work; the **harness** is the context, capabilities,
guardrails, and feedback loops built around it so the work actually holds up instead of just
looking right. revai packages that harness as a Claude Code **plugin** — see "How it's delivered"
below.

## How it's delivered

revai is a Claude Code plugin that also acts as its own marketplace: you author skills, commands,
and conventions once, here, and every attached codebase enables the plugin and pulls from that
single source of truth. Improvements live in one place and propagate on demand — see "Keeping
projects in sync".

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

This is how every project stays on the single source of truth described above.

## Bundled skills

Once revai is installed, exactly **3 skills** surface automatically when their subject comes up —
no setup per repo. Each is a concise index (`SKILL.md`) pointing to focused `reference/*.md` files —
progressive disclosure, so only the concern actually in play gets read into context. They complement
the other plugins rather than duplicate them — rules, a checklist, and (except for pure recognition
catalogs) concrete Go/Python examples in every reference file.

| Skill | Fires when you're… | What's inside |
|---|---|---|
| `best-practices` | Writing any code, or making any implementation choice, in `/revai:implement` or `/revai:decide` | Standard-solution-first meta-principle, plus a reference for each cross-cutting concern: `api-design`, `data-access-patterns`, `safe-schema-changes`, `config-and-secrets`, `error-handling-and-logging`, `resilience-and-timeouts`, `concurrency-and-context-safety`, `tdd`, `backend-testing`, `pr-sizing`, `event-driven-messaging`, `authn-and-authorization`, `observability`, `caching` |
| `clean-code` | Naming or structuring anything — any function, variable, type, class, file, or module | A reference for each concern: `naming`, `functions` (size, arguments, side effects), `comments-and-formatting`, `objects-and-data-structures` (Law of Demeter), `error-handling` (code shape, not operations), `classes-and-cohesion`, `smells-and-heuristics` (a recognition catalog) — all strictly enforced (rationalization tables + red flags) |
| `domain-driven-design` | Modelling a domain, drawing a service/module boundary, or designing a new system's/bounded context's architecture | A reference for each layer: `strategic-design` (bounded contexts, ubiquitous language), `tactical-patterns` (aggregates, value objects, invariants, domain events), `architecture-and-layering` (hexagonal, modular monolith, CQRS), `architecture-fit` (how much of this a system actually needs) |

## Deciding, then implementing (`decide` · `implement`)

Every change this harness drives runs through exactly two commands, split along one axis: **is this
a judgment call, or is it execution?**

```bash
/revai:decide "a URL shortener with per-user quotas and analytics"
/revai:decide "add idempotent refund endpoint to the billing module"
/revai:decide "refunds over the daily cap are silently accepted"
/revai:decide "extract the payout fee calc out of the order handler"
```

`/revai:decide` covers **every** judgment call before code changes — a brand-new system's
architecture, a feature's implementation plan, a bug's root cause, a refactor's bounded scope — and
classifies which one it's looking at from how you describe it (asking exactly one clarifying
question if it's genuinely ambiguous). It scales its own depth to the stakes: an architecture
decision gets `superpowers:brainstorming` and `domain-driven-design`'s neutral fit judgment; a
plan gets `writing-plans` and `best-practices`' pr-sizing check; a defect gets
`systematic-debugging` and a named root cause; a reshape gets a bounded scope and a
characterization-safety-net check. **It never touches the repo** — no code, no branch, ever, under
any classification — so it works on a bare idea with no repo at all, and its one written artifact
(`docs/design/<slug>.md`, a `writing-plans` doc, or `docs/decisions/<slug>.md`) can be handed to
`/revai:implement` in a later session, even by someone else.

```bash
/revai:implement docs/decisions/refund-cap-bug.md
/revai:implement "bump the retry cap in the payments client from 3 to 5"
```

`/revai:implement` takes that artifact — or an inline description trivial enough not to need one —
and drives it to an open PR: branch (only after you approve, so declining leaves the repo
untouched) → build/fix/reshape (TDD by default, `code-simplifier`-driven for a reshape) → self-review
→ verify → `backend-review` → a final approval gate before the PR goes up. This is the **only**
command in the harness that mutates the repo.

Two gates, always: **Approve & branch** (before any repo mutation) and **Ship** (before the PR).
Everything between runs automatically.

## Everyday command (`review`)

| Command | What it does |
|---|---|
| `/revai:review [target]` | Broadly reviews the code you generated (bugs, security, backend design, quality), reports ranked findings, **auto-fixes** what it's confident about, re-verifies, and shows the diff. Defaults to your uncommitted changes. |

## Review agent & guardrails

Skills are advisory — these make them stick:

- **`backend-review` agent** — dispatch it (e.g. "review the backend changes") to audit the current
  diff against all the skills at once and report findings by severity. Read-only; it reports, it
  doesn't edit.
- **Secrets guardrail (hook)** — a `PreToolUse` hook blocks any `git commit` whose staged changes
  add a private key, cloud/API token, or inline credential. Deterministic and unskippable by the
  agent — it runs in every repo that enables revai.
- **Branch-protection guardrail (hook)** — a `PreToolUse` hook blocks any `git commit`/`git push`
  made directly on `main`/`master`, so a feature branch is unskippable even if `/revai:implement`'s
  own Approve & branch gate is somehow bypassed.
- **Verify-on-Stop (hook)** — a `Stop` hook runs the project's recorded verify commands (from
  `.revai/verify.json`, written by `/revai:attach`) when the agent tries to finish, and **blocks
  completion if a blocking check fails** — turning "evidence before assertions" into enforcement.
  Tiered (test/lint block; build/format advisory), scoped to turns that changed code, and it relents
  after a few attempts so a stuck build can't loop forever.

## Maintaining the plugin (`/revai:doctor`)

`/revai:doctor` audits the plugin repo itself — manifest integrity, malformed skills, dead
`${CLAUDE_PLUGIN_ROOT}` references, README/skill-table drift, and skill content quality — then
offers to fix the safe, mechanical issues behind a single gate. Run it after changing components.

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
├── commands/                # attach (setup); decide (any judgment call); implement (plan → PR); review; doctor (self-audit)
├── agents/                  # backend-review subagent
├── hooks/                   # secrets guardrail + branch-protection guardrail + verify-on-Stop
├── templates/               # files /revai:attach instantiates into a project
├── skills/                  # best-practices, clean-code, domain-driven-design (each with reference/)
├── CLAUDE.md                # conventions for developing revai itself
└── README.md
```
