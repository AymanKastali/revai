---
description: Turn a high-level idea into a full, documented system design
argument-hint: <the idea, in a sentence or two>
---

# /revai:design

The idea: **$ARGUMENTS**

Produce a complete high-level system design for it, documented, against the `system-design` standard.

**Read `${CLAUDE_PLUGIN_ROOT}/skills/system-design/SKILL.md` in full before anything else.** Its 123
rules, its document outline, its three tables and its scan list are the specification for what you
produce here. Nothing below repeats them; this file is only the procedure.

Terminal state: **a design document on disk and a short summary in chat.** Write no implementation
code, scaffold nothing, install nothing.

## 1. Is a design warranted?

Apply rules 1 and 109. If the idea is a well-understood change inside a shape that already exists, say
so in one paragraph — the answer, and why it needed no document — and stop. Otherwise continue.

## 2. Classify the complexity, out loud

Before anything else, state in one line: how many distinct actor journeys the idea implies, how many
integrations and stores, and whether multi-region, regulated data or a genuinely hard mechanism is in
play. Tag the idea **narrow** or **complex** — this governs how hard steps 4 and 7 push, not decoration:

- **Narrow**: one or two journeys, a well-trodden shape, no hard sub-problem. The question round in
  step 4 can close as soon as the shape, store and loss tolerance are settled. Detailed Design may be
  "not applicable" if nothing in the design is actually hard (rule 64's own gate).
- **Complex**: several journeys, more than one integration or store, or a mechanism that isn't
  off-the-shelf composition. The question round does not close on a fixed number of calls — it closes
  when doubt runs out (step 4). Detailed Design covers 2-3 mechanisms, not fewer, unless the design
  genuinely doesn't need one.

## 3. Context before questions

Do not ask what you can find. Before the question round, establish from the repository: whether one
exists at all, its language and frameworks, its datastore, its deployment shape, its existing modules
or services, and any design docs, ADRs or `CLAUDE.md` already present. If there is no repository, the
design is greenfield — say so and move on.

## 4. Question rounds — keep going as long as there is doubt

Ask only what changes the design. A question whose every plausible answer leads to the same document
is a question you already answered yourself. Use `AskUserQuestion`, up to four questions per call —
**there is no cap on the number of calls.** Every question carries a concrete recommended option first,
so the user can accept your default rather than compose an answer.

A decision-critical unknown is any of: the shape, the store, the consistency model, what may be lost
versus what must never be lost, the contract each interface needs, and — for a **complex** design —
which sub-problem earns the Detailed Design deep dive. Keep issuing rounds until every one of these is
either answered or explicitly defaulted with a recorded rationale (step 5). Only stop early once the
user has actually skipped a round or answered "you decide" — not before a first real attempt, and never
just because a fixed number of calls was reached.

When an answer is vague, numberless, or contradicts an earlier one, the next call's first question is
a clarifying follow-up on that same point — do not carry an unresolved one into a new category.

Ask in this order of value, adding another round rather than dropping a category while doubt remains:

1. **What it must do** — the journeys that define the system as functional requirements, each with an
   actor and what "done" looks like, and what is explicitly out.
2. **Scale and shape of load** — how many users or events, how fast that grows, how bursty. Ask for
   users and actions, never for a request rate: derive the rate yourself (rules 25–26).
3. **What must never fail or be lost**, and what may (rule 21). This decides more of the design than
   anything else on this list.
4. **Consistency and freshness** — where a stale or eventually-consistent read is unacceptable
   (rule 50).
5. **Who consumes each interface, and what they expect from it** — another service, another team, an
   external caller, an existing client whose contract can't change (rules 59–62).
6. **Hard constraints** — deadline, team size, budget, regulation, residency, systems that already
   exist and must be integrated or migrated (rules 9, 87).
7. **Where it runs and what it may depend on** — cloud, on-premise, existing managed services, vendors
   already paid for (rule 40).
8. **For a complex design, what's actually hard** — the one or two sub-problems, if any are already
   visible, that need a mechanism walk rather than a box on the diagram (rule 64).

## 5. Defaults you apply without asking

Each is the standard's own answer; each is overridden only by a stated requirement, and the override
is recorded as a decision.

- One deployable with modules inside it (rule 38, `modular-monolith` rules 4–6). A design with several
  deployables must name the driver in the document.
- The boring, well-understood technology, and a managed service before self-hosting before building
  (rules 39, 40). If the repository already has a stack, that stack is the boring option.
- A single region, synchronous request/response, one relational store as the source of truth, until a
  requirement forces otherwise (rules 36, 42).
- No queue, cache, replica, gateway or tier without the requirement named beside it (rule 41).
- Every requirement the user skipped or waved off is recorded as an assumption in the document and as
  an open question with an owner and a "needed by" date (rule 116) — never silently guessed.

## 6. Write the document

Path: `docs/design/<kebab-slug>.md` in the working repository, unless the user names another. Create
the directory if needed. Follow the skill's **design document** outline exactly, in order, all
nineteen sections; a section with nothing in it says "not applicable" and why (rule 108).

Specifically:

- Do the arithmetic in the document, visible, with its assumptions (rules 33, 34) — not in your head.
- Split Requirements into the two sections the standard names: Functional Requirements, each with an
  actor, a priority and an acceptance criterion (rules 13–14); Non-Functional Requirements, each as a
  scenario with a measure (rules 15–24).
- Give every interface that crosses a boundary a real contract in API & Interface Design — types, an
  error taxonomy, sync/async and delivery semantics, versioning (rules 59–63) — not a named endpoint
  with no shape.
- Walk the 1-3 hardest mechanisms in Detailed Design: the naive approach and why it fails, the chosen
  one step by step, its cost, and the requirement it serves (rules 64–68). A narrow design with nothing
  hard says "not applicable" here and why.
- One component-level diagram as a fenced `mermaid` block: every box labelled with responsibility and
  technology, every edge labelled with what flows and by what mechanism (rule 44).
- Mark every assumption you made for the user as `Assumption:` inline, and mirror each one in Open
  Questions with an owner and a date needed by (rule 116).
- Cite the sibling standard rather than re-deciding what it owns: boundaries and the domain model to
  `domain-driven-design`, what crosses a boundary to `modular-monolith`, libraries, protocols,
  resilience mechanics and migration mechanics to `best-practices`. If the design names Go or
  Postgres, the `golang` and `postgres` skills carry that technology's form of these decisions.
- Decisions carries a record per consequential decision with real alternatives, the consequence
  accepted, its reversibility and its revisit trigger (rules 102–107).
- **Before writing a sentence in Architecture, API & Interface Design or Detailed Design, check it:**
  would it be equally true of a different system? If yes, delete it and write the version that is only
  true of this one — a name, a number or a mechanism specific to what you were actually asked to build.

## 7. Check it before showing it

Work the scan list and the validation group over what you just wrote, and **fix what fails rather
than reporting it**. The design does not leave this step until all of the following hold:

- Every functional requirement has an actor, a priority and an acceptance criterion (rules 13–14); no
  requirement reads as an adjective with no number attached.
- Every non-functional requirement has a measure, a window and a measurement point (rules 15, 18, 88).
- Every number shows where it came from and ties to the scale actually stated for this system, not a
  generic round figure (rules 23, 33).
- Every interface that crosses a boundary has a concrete contract — types, errors, delivery semantics
  — not a name (rule 59).
- The 1-3 hardest mechanisms are walked to the edge case that breaks the naive version, not restated as
  a box on the diagram (rules 64–66).
- Every dependency has a row in the failure table with detection, blast radius, degraded behaviour and
  recovery, and the availability target survives the arithmetic in rule 72.
- Every component traces to a requirement (rule 41), and every primary journey traces through the
  components (rule 110).
- Trust boundaries are on the diagram and every crossing flow has been walked (rules 80, 81).
- There is a cost model (rule 92), a transition plan if a system already exists (rule 121), and a
  first increment that ships on its own (rules 118, 119).
- Non-goals, what is not being optimised for, and open questions are all non-empty (rules 6, 22, 116).
- **One final genericness pass**: read the Architecture, API & Interface Design and Detailed Design
  sections back. Any sentence that would survive word-for-word in a design for a different system gets
  rewritten or cut.

## 8. Report

In chat, briefly — the document holds the detail:

- The complexity tag from step 2, and why.
- The shape, in a few lines.
- The sizing headline, and what saturates first.
- The hardest mechanism covered in Detailed Design, and the naive approach it beat.
- The three decisions that matter most, each with the alternative rejected.
- The open questions, and the riskiest assumption you made on the user's behalf.
- The path to the document.

Then stop. Do not start building, and do not offer to plan the implementation — that is
`/revai:plan`'s job, run separately once this design is approved.
