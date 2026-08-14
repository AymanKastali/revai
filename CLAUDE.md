# revai — developing the harness itself

This repo IS a Claude Code plugin (and its own marketplace). It carries engineering standards — four
stack-agnostic and injected into every session, two procedure standards invoked as skills
(`system-design`, `implementation-planning`), plus three stack-specific (`golang`,
`go-project-layout`, `postgres`) —
and the machinery that makes an AI follow them. See `README.md` for the user-facing overview.

## The one rule that matters here

Each standard's `skills/<name>/SKILL.md` is the **single source of truth** for that standard. The
rules live inside its `HARD-RULES` comment fence, and `hooks/inject-hard-rules.sh` extracts every
fence at runtime with `sed`.

Never copy rules out of a fence into another file. If you find yourself restating a rule anywhere
else — in a hook, an agent, the README — you have introduced drift. Read it out of `SKILL.md`
instead, or point at the skill.

Editing a fence changes what every session sees. Keep the markers intact and in order:

```text
<!-- HARD-RULES:START -->
<!-- HARD-RULES:END -->
```

## Structure rules

- `plugin.json` and `marketplace.json` live **only** inside `.claude-plugin/`. Nothing else goes
  there.
- Component dirs live at the repo **root**: `skills/`, `agents/`, `hooks/`.
- There is deliberately **no `reference/` directory**. Splitting rules into reference files that
  nothing opens is the exact failure this rewrite exists to remove — keep `SKILL.md` self-contained.
  This is a **considered deviation** from Anthropic's progressive-disclosure guidance, which says to
  split as a file approaches 500 lines. It holds here for two reasons: Layer 1 injects the rules
  regardless of whether any file is opened, and the depth below each fence is precisely what a caller
  invoked the skill to get, so putting it one hop further away buys nothing at the point of use. The
  `## Contents` section is the mitigation the same guidance prescribes for long files. Do not
  "fix" this by reintroducing reference files; if a `SKILL.md` genuinely cannot fit in 500 lines,
  raise it with the repo owner instead of splitting it — `system-design`, `implementation-planning`
  and `go-project-layout` did exactly that, and are named in `LARGE_SKILLS` in
  `.github/workflows/ci.yml`, which grants them `LARGE_SKILL_MAX_LINES` (650) instead of the default.
  `LARGE_SKILLS` is deliberately not `PROCEDURE_SKILLS`: needing room and carrying a procedure are
  two different questions, and while the first two skills answer yes to both, `go-project-layout`
  answers yes only to the first — its reference tree is the deliverable, not an example to cut.
- **There is deliberately no `commands/` directory.** A standard whose value is a **procedure**
  rather than a set of constraints on code being written (`system-design`, `implementation-planning`)
  does not get a separate entry point that sequences a rules-only skill from outside it — the
  procedure is a `## Procedure` section inside that same `SKILL.md`, below its `HARD-RULES` fence, so
  there is exactly one file per standard and the fence stays the single source of truth for the rules
  half of it. There is still deliberately no `templates/`, and still no per-repo setup step. If you
  think a standard needs either of those, the design slipped.
- Reference bundled files from a skill, agent, or hook with `${CLAUDE_PLUGIN_ROOT}`.

## Adding a standard

First decide which layers it gets. An **agnostic** standard that governs code as it is written is
injected by Layer 1, so it is in context whether or not anything invokes it. A **stack-specific**
standard — one that governs a single language or a single datastore — is not, and neither is a
**procedure** standard that governs a deliberate act rather than the code being typed; see § Layers.

For an agnostic standard, four edits, in this order, or the layers fall out of sync:

1. `skills/<name>/SKILL.md` — spec-conformant frontmatter (see Conventions), a `## Contents` section
   stating the scan list's row count, then the fence.
2. `hooks/inject-hard-rules.sh` — add `'<name>:<xml-tag>'` to the `STANDARDS` array. Nothing else in
   the hook needs to change; it loops.
3. `.github/workflows/ci.yml` — raise `EXPECTED_RULES` to the new total across all fences.
4. `README.md` — add a row to the matching table with the standard's rule count and scan-list row
   count. CI requires one README row per directory in `skills/`, so a new skill fails the build until
   this exists.

For a stack-specific standard, steps 1 and 4 only. `EXPECTED_RULES` counts the injected card, so it
does not move, and CI derives the list of skills that must appear in the card from the hook's
`STANDARDS` array rather than from `skills/*/` — which is what lets a skill exist without being
injected.

For a procedure standard, steps 1 and 4 plus a `## Procedure` section in that same `SKILL.md`, after
the fence, sequencing the standard end to end. `EXPECTED_RULES` does not move either way. If the
merged file won't fit the default 500-line budget, add its skill name to `LARGE_SKILLS` in
`.github/workflows/ci.yml` rather than splitting it into a second file. `PROCEDURE_SKILLS` is a
separate list and is what makes the `## Procedure` section mandatory; a skill only needing room goes
in `LARGE_SKILLS` alone.

Then decide whether the standard needs its own review agent. If it does, the gate must demand it by
name in `hooks/review-gate.sh`, and CI asserts that every agent the gate names actually exists.

## Layers

Layer 1 costs tokens in every session, in every repo, including plain chat. That is the right trade
for a standard that applies to every line of code in any stack, and the wrong one for a standard that
applies to one: Go rules injected into a Python repo, or Postgres rules into a repo with no database,
are pure noise, and the card is already ~12k tokens.

So **stack-specific skills are Layer 2 only**. They carry no entry in `STANDARDS` and are reached
the way any skill is reached — by their `description`, which is why that description must name its
triggers concretely. Layer 3 can still demand a stack reviewer, gated on the changed paths, the way
it already gates `ddd-review` on domain-looking paths.

They keep the fence anyway. It separates the hard rules from the depth below for a human reader, it is
what CI's numbering check keys off, and it means injecting one later is a one-line array edit rather
than a restructure.

`system-design` and `implementation-planning` are Layer 2 for a different reason, and they are the
only standards of this kind here. Both are stack-agnostic, so the rule above would put them in the
card — but their rules constrain **a design act and the document or plan it produces**, not the lines
of code being typed. 123 design rules injected into a session that is fixing a typo are the same
noise as Go rules in a Python repo, and the trigger is not "you are writing code" but "you are
deciding a system's shape" or "you are turning an approved design into a plan". A card cannot sequence
a standard as a procedure, so each carries its own `## Procedure` section below its fence instead —
reached the way any skill is reached, by its `description`'s `Use when …` clause, or by the user
invoking it directly by name. Both still self-gate in their fence regardless (`system-design` rule 1
on the change deciding a shape, `implementation-planning` rule 1 on there being an approved design to
plan from; rule 2 in each on the group or stage in play).

Neither case is a licence to scope-limit an agnostic standard by leaving it out of Layer 1. That was
the old plugin's failure and the Conventions rule below still forbids it: an agnostic standard that
governs code as it is written and does not always apply says so inside its own fence, as its first
rules. The exemptions are exactly two and both are structural — the standard governs one technology, or
it governs a deliberate act that produces its own artifact rather than lines of code.

## Conventions

- Frontmatter stays inside the **six fields of the Agent Skills spec** (`name`, `description`,
  `allowed-tools`, `compatibility`, `license`, `metadata`). We use only the first two. Claude Code
  extensions like `when_to_use` are rejected by CI: they would make these skills fail to load on
  claude.ai and through the API, and the description has room for what they would carry.
- `name` equals its directory, is `[a-z0-9-]` within 64 characters, and contains no reserved word.
  `description` is one line, ≤ 1024 characters, leads with a verb saying what the standard does, and
  ends with a `Use when …` clause naming concrete triggers — that clause is what drives discovery, and
  CI requires it.
- Every `SKILL.md` over 100 lines carries a `## Contents` section above the fence, so a partial read
  still shows the file's full scope. Keep it outside the fence: it must never enter the injected card.
- Section names are parallel across skills — `## Contents`, the rules group, decision tables,
  `## Depth`, then `## Anti-pattern scan list`. Same for the review agents. A procedure standard adds
  exactly one more, `## Procedure`, below its fence and above `## Depth`; CI checks that it is there,
  that it is listed in `## Contents`, and that no rules-only skill has grown one.
- Every `SKILL.md` has a hard budget of **500 lines**, or **650** for a skill listed in CI's
  `LARGE_SKILLS`. Past that, cut examples — never move rules out.
- Rules inside a fence are numbered `1..N` with no gaps or duplicates; CI enforces it. Renumber the
  whole group rather than inserting `12a`.
- Every rule in the fence is one line. Depth, examples, decision tables and scan lists go below it.
- Anti-pattern scan-list codes restart at `1` for each group prefix and run `1..N` within it, with no
  gaps or duplicates — the codes get cited (`G12`, `R7`), so a gap makes a citation ambiguous. CI
  enforces this the same way it enforces rule numbering.
- Every count stated about a standard has to be true, because nothing regenerates it: each
  `## Contents` states its scan list's row count as `N rows`, and README's tables carry each
  standard's rule count and scan-list row count in a `Scan list` column keyed to the skill name. CI
  checks both against the files, so **changing a scan list means updating two numbers** — that
  skill's `## Contents` and its README row.
- **A reference to a numbered section of a design document always carries that section's title** —
  `section 18 (Delivery & Rollout)`, never a bare `section 18`. The numbers belong to
  `system-design`'s document outline, which has been renumbered once already, silently breaking every
  reference in `implementation-planning`. CI now resolves each `section N (Title)` pair against that
  outline and rejects a numeric reference with no title, so a renumber fails the build instead of
  sending the planner to the wrong section of a real design.
- A standard that is not universally applicable must say so **inside its own fence**, as its first
  rules — not by being left out of Layer 1. Two shapes exist: `domain-driven-design` rules 1–3 gate
  the whole standard on one up-front classification; `best-practices` rule 1 gates each group on the
  concern named in its heading. Pick whichever matches how the standard actually varies, or both where
  both are true — `modular-monolith` rule 1 gates the whole standard on the system being one deployable
  with more than one capability, and rule 2 then gates each group on its heading's concern. A
  stack-specific or procedure standard is the exception to the "not by being left out" half (see
  § Layers), and it still gates itself in its own fence: `golang` rule 1 on the change containing Go,
  `go-project-layout` rule 1 on the codebase being a Go binary with more than one bounded context,
  `postgres` rule 1 on it containing schema, SQL or a migration, `system-design` rule 1 on the change
  deciding a system's shape, and rule 2 in each on the group's concern.
- Standards divide by **question**, not by topic, so a finding belongs to exactly one of them:
  `clean-code` owns how the code reads, `best-practices` owns what it is built with,
  `domain-driven-design` owns how the domain is modelled, `modular-monolith` owns how one deployable is
  partitioned, `system-design` owns what is being built and whether its shape meets requirements
  someone can check, and a stack standard owns how that one technology is used — `golang` how Go itself
  is written, `go-project-layout` where a Go file goes once the binary holds more than one bounded
  context, `postgres` how Postgres itself is used. `go-project-layout` is the one stack standard whose
  question is physical rather than syntactic, and its edge is drawn the same way as the rest: it never
  restates why a boundary exists (`domain-driven-design`, `modular-monolith`), only which directory,
  package name and filename make that boundary true in Go — and where the compiler enforces it for
  free. `system-design` is the newest edge and the one
  most at risk of absorbing the others: it owns requirements, sizing, failure enumeration, trust
  boundaries, cost, the decision record and the design document, and it cites the others for boundaries
  (`domain-driven-design`), what crosses them (`modular-monolith`) and which library, protocol or
  resilience pattern implements a choice (`best-practices`).
  Before adding a rule, check that no other fence already answers its question — the outbox, for
  example, is DDD rule 61, so `best-practices` rule 82 states the general dual-write hazard instead of
  restating it, and `modular-monolith` rule 58 points at both rather than describing an outbox again.
  The DDD edge is the one most easily blurred: DDD owns how a bounded context is found and what lives
  inside it, `modular-monolith` owns what crosses the boundary once it exists — the graph, the surface,
  storage ownership, in-process integration, wiring and the extraction seam.
- A stack standard names its technology's **form** of a property another standard mandates; it never
  restates the property. `best-practices` rule 46 requires a timeout on every outbound call; `golang`
  rule 61 says the Go form is a `context.Context` first parameter, and `postgres` rule 77 says the
  Postgres form is `statement_timeout` and `lock_timeout` set on the role. If a rule would read the
  same for another language or another database, it belongs in an agnostic fence instead.
- Pseudocode in the agnostic standards stays technology-neutral. Concrete idioms belong in that
  language's or datastore's skill.
- A stack standard cites the release that introduced each modern form — `any` (1.18), `wg.Go` (1.25),
  `uuidv7()` (18) — so a reader can tell a rule they cannot yet apply from one they are ignoring.
- No rationalization tables and no "this standard is absolute" preamble. That was the old plugin's
  entire top level and it changed nothing; the `Stop` gate is the enforcement mechanism now.
- Markdown: table delimiter rows are spaced (`| --- | --- |`) and every fenced block declares a
  language. The repo lints clean under `npx markdownlint-cli2`, configured by
  `.markdownlint-cli2.jsonc` — which disables exactly two rules, each with the reason written down.
- Hook scripts are `bash`, `set -uo pipefail`, executable, and **never fail a session** — every
  error path warns on stderr and exits 0. The one exception is the gate's deliberate `exit 2`.
- A hook that reads several skills degrades per-skill: one unreadable fence warns and is skipped, the
  rest still inject.
- Validate JSON before committing: `jq . .claude-plugin/*.json hooks/hooks.json`.
- Design docs live under `docs/` and are **gitignored** — local only, never shipped with the plugin.

## Versioning

`plugin.json` carries no `version` field on purpose, so consumers track commits and
`/plugin update revai@revai` always fetches the tip of `main`. Add one only for a tagged release.

## How to verify your work

There is no build or test suite. Verification means:

| Purpose | Command |
| --- | --- |
| Manifests parse | `jq . .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json` |
| Fences intact | `grep -n 'HARD-RULES:\(START\|END\)' skills/*/SKILL.md` |
| Cards extract | `./hooks/inject-hard-rules.sh` — one tagged block per **injected** skill, exit 0 |
| Rule count | `./hooks/inject-hard-rules.sh \| grep -cE '^[0-9]+\. '` — must equal `EXPECTED_RULES` (324) |
| Layer 2 only | no `<golang>`, `<go-project-layout>`, `<postgres>`, `<system-design>` or `<implementation-planning>` block in the card, and all five absent from the hook's `STANDARDS` array |
| No `commands/` | `[ ! -d commands ]` — the directory must not exist; CI's "Plugin structure rules" step asserts the same |
| Procedure skills load | `/reload-plugins`, then confirm `system-design` and `implementation-planning` are both listed with their descriptions, and that `/revai:system-design <an idea>` still reaches the procedure with its argument — that slash form is the explicit entry point the README documents now that `commands/` is gone |
| Procedure sections exist | `grep -nx '## Procedure' skills/*/SKILL.md` — exactly the two `PROCEDURE_SKILLS`, each below its fence; CI's "Procedure standards carry their own procedure" step asserts that, plus the `## Contents` entry and that neither is injected |
| Numbering | rules in each fence run `1..N` — CI's awk check, or eyeball the tail of each group |
| Scan lists sequential | CI's "Scan lists are sequential and state their own row count" step — codes run `1..N` per group prefix, and each `## Contents` states the true row count |
| Counts true | same step, plus CI's "README's rule and scan-list counts match the skills" — README's `Rules` and `Scan list` columns are checked per skill, and the step fails if it does not match one row per `skills/*/` |
| Section refs resolve | CI's "References to a design section resolve against system-design's outline" step — every `section N (Title)` in `implementation-planning` and README is row `N` of the outline, and no bare `section N` exists |
| Spec conformance | CI's "Skills conform to the Agent Skills spec" step — name/description limits, spec-only frontmatter, `## Contents` present, agent name equals filename |
| Card unaffected | `./hooks/inject-hard-rules.sh \| sha1sum` before and after editing anything outside a fence — it must not change |
| Budgets held | `wc -l skills/*/SKILL.md` — each must be ≤ 500, except the three in `LARGE_SKILLS` (`system-design`, `implementation-planning`, `go-project-layout`), which get ≤ 650 (`LARGE_SKILL_MAX_LINES`) |
| Hooks parse | `bash -n hooks/*.sh` |
| Hook paths resolve | `jq -r '.hooks[][].hooks[].command' hooks/hooks.json` — each file exists |
| Gate is quiet | run `hooks/review-gate.sh` with only docs or config changed — exit 0, no output. Config means an extension in the filter *and* any dotfile basename: `.gitignore` has no extension and `.jsonc` is not `.json`, so both once demanded four reviews of a file holding no code |
| Gate blocks | touch any source file, run it — exit 2, demand text names all four review agents |
| Gate escalates | touch `x/domain/y.go`, run it — demand hard-requires `ddd-review` and lists the path |
| Components load | `/reload-plugins`, then confirm every skill and every review agent appears |

Run the gate only in a throwaway repo, or clean up after: it writes `.revai/` bookkeeping into
whatever tree it runs in.

CI (`.github/workflows/ci.yml`) runs the non-interactive subset of the above on every PR and push to
`main`. Because the repo is its own marketplace, merging to `main` publishes instantly — CI's job is
to guard what gets published.
