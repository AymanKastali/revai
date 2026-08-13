---
description: Turn a high-level idea into a full, documented system design
argument-hint: <the idea, in a sentence or two>
---

# /revai:design

The idea: **$ARGUMENTS**

Produce a complete high-level system design for it, documented, against the `system-design` standard.

**Read `${CLAUDE_PLUGIN_ROOT}/skills/system-design/SKILL.md` in full before anything else.** Its 110
rules, its document outline, its three tables and its scan list are the specification for what you
produce here. Nothing below repeats them; this file is only the procedure.

Terminal state: **a design document on disk and a short summary in chat.** Write no implementation
code, scaffold nothing, install nothing.

## 1. Is a design warranted?

Apply rules 1 and 97. If the idea is a well-understood change inside a shape that already exists, say
so in one paragraph — the answer, and why it needed no document — and stop. Otherwise continue.

## 2. Context before questions

Do not ask what you can find. Before the question round, establish from the repository: whether one
exists at all, its language and frameworks, its datastore, its deployment shape, its existing modules
or services, and any design docs, ADRs or `CLAUDE.md` already present. If there is no repository, the
design is greenfield — say so and move on.

## 3. One bounded question round

Ask only what changes the design. A question whose every plausible answer leads to the same document
is a question you already answered yourself.

Use `AskUserQuestion`, up to four questions per call, **at most three calls**. Every question carries
a concrete recommended option first, so the user can accept your default rather than compose an
answer. If they skip, answer "you decide", or stop responding, proceed — the design is still due, with
the gap recorded as an assumption and an open question.

Ask in this order of value, stopping when the remaining answers would not move a decision:

1. **What it must do** — the two or three journeys that define the system, and what is explicitly out.
2. **Scale and shape of load** — how many users or events, how fast that grows, how bursty. Ask for
   users and actions, never for a request rate: derive the rate yourself (rules 23–24).
3. **What must never fail or be lost**, and what may (rule 19). This decides more of the design than
   anything else on this list.
4. **Consistency and freshness** — where a stale or eventually-consistent read is unacceptable
   (rule 48).
5. **Hard constraints** — deadline, team size, budget, regulation, residency, systems that already
   exist and must be integrated or migrated (rules 9, 75).
6. **Where it runs and what it may depend on** — cloud, on-premise, existing managed services,
   vendors already paid for (rule 38).

## 4. Defaults you apply without asking

Each is the standard's own answer; each is overridden only by a stated requirement, and the override
is recorded as a decision.

- One deployable with modules inside it (rule 36, `modular-monolith` rules 4–6). A design with
  several deployables must name the driver in the document.
- The boring, well-understood technology, and a managed service before self-hosting before building
  (rules 37, 38). If the repository already has a stack, that stack is the boring option.
- A single region, synchronous request/response, one relational store as the source of truth, until a
  requirement forces otherwise (rules 34, 40).
- No queue, cache, replica, gateway or tier without the requirement named beside it (rule 39).

## 5. Write the document

Path: `docs/design/<kebab-slug>.md` in the working repository, unless the user names another. Create
the directory if needed. Follow the skill's **design document** outline exactly, in order, all fifteen
sections; a section with nothing in it says "not applicable" and why (rule 96).

Specifically:

- Do the arithmetic in the document, visible, with its assumptions (rules 31, 32) — not in your head.
- One component-level diagram as a fenced `mermaid` block: every box labelled with responsibility and
  technology, every edge labelled with what flows and by what mechanism (rule 42).
- Mark every assumption you made for the user as `Assumption:` inline, and mirror each one in section
  15 with an owner and a date needed by (rule 104).
- Cite the sibling standard rather than re-deciding what it owns: boundaries and the domain model to
  `domain-driven-design`, what crosses a boundary to `modular-monolith`, libraries, protocols,
  resilience mechanics and migration mechanics to `best-practices`. If the design names Go or
  Postgres, the `golang` and `postgres` skills carry that technology's form of these decisions.
- Section 12 carries a record per consequential decision with real alternatives, the consequence
  accepted, its reversibility and its revisit trigger (rules 90–95).

## 6. Check it before showing it

Work the scan list and the validation group over what you just wrote, and **fix what fails rather
than reporting it**. The design does not leave this step until all of the following hold:

- Every quality attribute has a measure, a window and a measurement point (rules 13, 16, 76).
- Every number shows where it came from (rules 21, 31).
- Every dependency has a row in the failure table with detection, blast radius, degraded behaviour and
  recovery, and the availability target survives the arithmetic in rule 60.
- Every component traces to a requirement (rule 39), and every primary journey traces through the
  components (rule 98).
- Trust boundaries are on the diagram and every crossing flow has been walked (rules 68, 69).
- There is a cost model (rule 80), a transition plan if a system already exists (rule 108), and a
  first increment that ships on its own (rules 105, 106).
- Non-goals, what is not being optimised for, and open questions are all non-empty (rules 6, 20, 104).

## 7. Report

In chat, briefly — the document holds the detail:

- The shape, in a few lines.
- The sizing headline, and what saturates first.
- The three decisions that matter most, each with the alternative rejected.
- The open questions, and the riskiest assumption you made on the user's behalf.
- The path to the document.

Then stop and offer the next step: refine a section, or turn a delivery slice (section 14) into
an implementation plan. Do not start building.

If the user picks the plan: when section 14 names more than one slice, ask which one — recommend
the first, thinnest end-to-end slice (rule 106) as the default. Then invoke
`superpowers:writing-plans`, handing it this design document's path as the spec and the chosen
slice's scope — what it ships, what stays deferred to a later slice, and any constraint from
sections 8–12 that bounds it — as the requirement to plan against. Writing-plans writes a plan
document only; it does not touch code, and neither does this handoff.
