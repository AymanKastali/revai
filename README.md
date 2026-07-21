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

Once revai is installed, these skills surface automatically when their subject comes up — no setup
per repo. They complement the other plugins rather than duplicate them — each a focused set of
rules, a checklist, and concrete examples (Go and Python where code is shown; SQL/HTTP where that's
clearer).

| Skill | Fires when you're… |
|---|---|
| `api-design` | Designing or adding an HTTP endpoint or resource |
| `config-and-secrets` | Loading config/secrets or wiring startup |
| `data-access-patterns` | Writing queries, repositories, or transactions |
| `safe-schema-changes` | Writing a migration or altering a schema |
| `error-handling-and-logging` | Writing error paths, `try`/`catch`, or logging |
| `resilience-and-timeouts` | Calling a network dependency, retrying, or handling startup/shutdown |
| `tdd` | Implementing a feature or bugfix — how to drive it with TDD and what to test per layer |
| `backend-testing` | Writing tests for APIs, services, or data access |
| `naming-and-structure` | Naming anything, or shaping units/layers (any code, not only backend) |
| `best-practices` | Writing any code, or weighing an implementation approach — prefer the standard/established solution over inventing one |
| `bounded-contexts` | Drawing a domain boundary, naming a module/service, or integrating two subsystems (strategic DDD) |
| `domain-modeling` | Modelling a domain type, adding an invariant, or deciding where a rule lives (tactical DDD) |
| `hexagonal-architecture` | Structuring a module, placing code in a layer, or wiring ports/adapters (modular monolith + logical CQRS) |
| `designing-architecture` | Designing a project's (or a new area's) architecture before code — choosing the fitting weight (DDD+hex vs. layered vs. script) and shaping it; drives `/revai:design` |
| `divide-and-conquer` | Deciding a plan/diff is too big for one PR — inside `feature`/`bugfix`/`refactor`'s Decide gate, or `designing-architecture`'s build order |
| `shipping-a-change` | Running a change workflow — the shared spine (set up → understand → refine → verify → review → ship) behind `feature`/`bugfix`/`refactor` |
| `writing-learning-docs` | Drives `/revai:learn` — owns the progressive learning-doc template (TL;DR + mental model first, then depth) and its authoring rules, so the doc becomes your source of truth on a topic |
| `explaining-code` | Drives `/revai:explain` — turns a survey of the codebase into a clean mental-model map a newcomer can grasp fast |

## Designing the architecture (`design`)

Before you change code, `design` lays the grounds. Give it an idea — or point it at a new area of an
existing repo — and it interrogates you one question at a time until it understands the problem, then
**neutrally recommends the architecture that fits** (a modular-monolith DDD + hexagonal design, a
simple layered app, or a plain script/library — whichever the problem warrants, never forced) and
writes it to `docs/design/<slug>.md`.

```bash
/revai:design "a URL shortener with per-user quotas and analytics"
```

It **orchestrates** — `superpowers:brainstorming` runs the question-asking, the
`designing-architecture` skill owns the fit judgment and the doc shape, and revai's architecture skills
(`bounded-contexts`, `domain-modeling`, `hexagonal-architecture`, …) fill it in. It is **read-only plus
one doc** — no code, no branch, no PR — and ends by handing the design's build order to
`/revai:prepare` (or straight to `/revai:feature` if the slice is simple enough to plan inline),
slice by slice.

## Preparing an implementation plan (`prepare`)

Between a design and a PR sits one more step: turning already-decided intent — a design doc, a
rough spec, or several plan files — into a concrete, step-by-step implementation plan.

```bash
/revai:prepare docs/design/url-shortener.md
```

It **orchestrates** — `superpowers:writing-plans` drafts the actual task/step breakdown,
`divide-and-conquer` decides if the input is too big for one PR-sized plan and slices it down to
one, and `best-practices` biases any remaining option-picking toward the standard/established
choice. It is **read-only plus one plan doc** — no code, no branch, no PR — and ends by handing
the prepared plan to `/revai:feature` to execute.

## Change workflows (`feature` · `bugfix` · `refactor`)

Three gated pipelines — one for each way you change code — that take a change from a description to
an open PR. Invoke any of them in a repo that has revai attached:

```bash
/revai:feature  "add idempotent refund endpoint to the billing module"
/revai:bugfix   "refunds over the daily cap are silently accepted"
/revai:refactor "extract the payout fee calc out of the order handler"
```

They **orchestrate** — they don't reinvent. The heavy lifting is done by the `superpowers` skills
(`brainstorming`, `writing-plans`, `executing-plans`, `systematic-debugging`,
`test-driven-development`, `verification-before-completion`, `receiving-code-review`,
`finishing-a-development-branch`) plus the `code-simplifier` agent; each command sequences them and
injects revai's own layer — your project `CLAUDE.md` rules, the backend skills, the `explaining-code`
survey, the `backend-review` agent, and the verify-on-Stop hook.

Each runs the same **eight explicit stages** and stops for your approval at **two gates**, running
automatically between them. They differ only in the **middle** (stages 3–4) — how the change is
Decided and Built — and share the same spine everywhere else:

```
Set up → Understand → Decide ⏸ → Build → Refine → Verify → Review → Ship ⏸
└──────── spine ────┘ └──── command ───┘ └─────────── spine ───────────┘
```

Each Decide gate also reaches for `divide-and-conquer` when the plan, diagnosis, or scope turns out
too big for one PR — splitting it into a sequence of small, independently shippable PRs instead of
one sprawling change.

| | Decide ⏸ (Gate 1, before any code) | Build | 
|---|---|---|
| **`feature`** | approved written plan | implement, TDD by default |
| **`bugfix`** | reproduction + failing test + root cause | minimal fix, no scope creep |
| **`refactor`** | bounded scope + characterization safety net | behaviour-preserving transform, tests stay green |

**The shared spine** lives once in the **`shipping-a-change`** skill, so all three stay identical
where they should and can't drift. It owns six of the eight stages — including two quality levers the
commands used to skip:

- **Understand** *(before deciding)* — actively survey the code the change will touch (via the
  `explaining-code` move, off your main context) so the change fits the repo instead of fighting it.
- **Refine** *(before review)* — self-review your own diff and run the `code-simplifier` agent over
  it, so external review spends its budget on real issues, not mess you could have caught.
- plus **Set up** (attach check → safe branch), the **clean-code + consistency bar** held throughout
  (`naming-and-structure` and `best-practices` as always-on absolute standards *and* consistency
  with the surrounding code), and the **Verify → Review → Ship** finish (`.revai/verify.json`;
  `backend-review` looping fix→verify→review until clean; Gate 2 summary → push → `gh` PR).

## Everyday commands (`explain` · `learn` · `review`)

Three commands outside the change-workflow spine, for day-to-day work.

| Command | What it does |
|---|---|
| `/revai:explain [area]` | **Read-only.** Surveys the codebase and prints a clean, human-friendly mental-model map — what it does, its architecture, one real flow end-to-end, how to run it — then offers to save it. Whole repo by default; give it an area (e.g. `"the domain layer"`) to scope it. |
| `/revai:learn <topic>` | Generates a learning doc to `docs/learning/<topic>.md` (topic kebab-cased), **calibrated to you** (level · goal · depth), progressively structured (grasp it in 60s or study it in depth), grounded by **real web research**, and self-reviewed as the learner — then offers to keep tutoring. Your source of truth for a topic. |
| `/revai:review [target]` | Broadly reviews the code you generated (bugs, security, backend design, quality), reports ranked findings, **auto-fixes** what it's confident about, re-verifies, and shows the diff. Defaults to your uncommitted changes. |

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
├── commands/                # /revai:attach (setup); design (architecture); feature·bugfix·refactor (workflows); explain·learn·review (everyday); /revai:doctor (self-audit)
├── agents/                  # backend-review subagent
├── hooks/                   # secrets guardrail + verify-on-Stop
├── templates/               # files /revai:attach instantiates into a project
├── skills/                  # reusable skills (api-design, safe-schema-changes, …)
├── CLAUDE.md                # conventions for developing revai itself
└── README.md
```
