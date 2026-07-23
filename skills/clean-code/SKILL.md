---
name: clean-code
description: Enforces strict clean-code discipline on every piece of code — intention-revealing names, small single-responsibility functions and classes, minimal comments, honest error handling, and no leaked abstractions. Use when writing or reviewing any function, variable, type, class, file, or module, in any language.
---

# Clean code

This standard is absolute, not aspirational. It applies to every line you write — the throwaway
script, the one-off migration, the internal tool nobody will "really" see — not just the parts that
feel important. Code is read far more than it is written, and the reader is usually you, later, with
no memory of the context you have right now.

**The four rules of simple design, in priority order, are the whole standard compressed:** the code
passes its tests, reveals its intent, contains no duplication, and has no more elements than it
needs. Everything below is what each of those means in practice.

## Quick reference

| Concern | Reference |
|---|---|
| Names for functions, variables, types, files | `reference/naming.md` |
| Function size, arguments, side effects, DRY | `reference/functions.md` |
| Comments and code formatting | `reference/comments-and-formatting.md` |
| Objects vs. data structures, Law of Demeter | `reference/objects-and-data-structures.md` |
| Exceptions vs. error codes, null handling | `reference/error-handling.md` |
| Class responsibility, cohesion, organizing for change | `reference/classes-and-cohesion.md` |
| Recognizing a smell before it spreads | `reference/smells-and-heuristics.md` |

## Rationalizations

Every one of these shows up in the moment you're tempted to skip a cleanup. None survive contact
with the next reader.

| Excuse | Reality |
|---|---|
| "It's just a quick script." | It gets read again — by someone, maybe you — the moment it breaks or needs a tweak. Quick scripts have the longest half-life of anything. |
| "I'll clean it up in review." | `/revai:implement`'s Refine stage exists for exactly this, and it isn't a license to write it messy first. Reviewers review logic, not a first draft's shape. |
| "This is a one-off, doesn't need it." | One-offs become permanent constantly. Nothing in a codebase is reliably temporary. |
| "Splitting/renaming this is overkill for now." | It's cheapest today, before anything else depends on the tangled version. |
| "The tests pass, so it's done." | Passing is rule one of four, not all four. Intent, duplication, and size still need a pass. |

## Red flags

Stop and fix these immediately — don't defer them:

- A name, function, or comment that needs re-reading twice to understand.
- Any unit (function, class, file) you can't describe in one sentence without "and" / "or".
- Nesting past 2-3 levels — branching *and* the actual work tangled together.
- Copy-pasted code with only names changed — it's the same responsibility, extract it.
- A file where you can't summarize "what lives here" in one line.

## Checklist

- [ ] Every applicable reference above has been consulted for the code just written
- [ ] The four rules hold, in order: tests pass, intent is clear, no duplication, nothing extra
