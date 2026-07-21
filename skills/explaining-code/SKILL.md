---
name: explaining-code
description: Use when explaining an existing codebase to a human — owns the output shape and the writing rules for /revai:explain. Produces a clean mental-model map (whole repo or a scoped area) that a newcomer can grasp fast, grounded in real files and inventing nothing.
---

# Explaining code (the mental-model map)

The goal is the picture you'd want on your first day in a codebase: enough to know **what it is, how
it's built, how it actually works, and where to look next** — and no more. Not a file-by-file
catalogue, not a summary that skips the mechanism. This skill owns the shape and the standards so
every explanation reads the same way.

Lead broad, then narrow, then get concrete, then point forward. Ground every claim in real files —
if you can't confirm it in the code, leave it out.

## The template

Write these sections, in this order. Scale each to the codebase; **omit a section if it doesn't
apply and say nothing rather than pad**. In focused mode (a named area), scope every section to that
area and drop the global ones that don't fit.

1. **At a glance** — one paragraph: what the system does, and for whom. The reader should grasp the
   shape before any detail.
2. **Stack & entry points** — the languages and frameworks, and where execution starts: `main`, the
   server bootstrap, the CLI, the job runner. Name the files.
3. **Architecture** — the layers/modules and how they relate, as a **simple ASCII / indented
   structure**. Output is terminal markdown — do **not** use mermaid or other renderer-only
   diagrams. Show the dependency direction where it matters.
4. **Key modules** — a compact table of only the significant ones:

   | Module | Responsibility | Key dependencies |
   |---|---|---|
   | `path/to/module` | what it owns, in one line | what it leans on |

5. **How it works** — trace **one representative flow** end-to-end (a request, a job, a command)
   from entry point through each layer to the result. This is the load-bearing "aha" section — the
   fastest way to make the rest click. Reference the real files it passes through.
6. **Data & external dependencies** — datastores, external services, config/secrets, and the
   integration points. Only what's actually there.
7. **Run & test** — the handful of commands that actually matter: run it, test it, lint it. Pull
   these from the real scripts/manifests, not from convention.
8. **Where to look next** — a few pointers of the form "to change X, start in `file Y`." Turn the
   map into next actions.

## The rules

- **Correct over comprehensive.** Omit what you cannot verify in the code rather than guess. A
  shorter true explanation beats a longer doubtful one. Never invent architecture, a flow, or a file
  that isn't there.
- **Ground it in files.** Name real paths; cite `path:line` sparingly — only where it helps the
  reader jump there — not on every sentence.
- **Straightforward prose.** Short sentences, plain words, no filler. Cut anything that doesn't help
  the reader understand. No "as we can see", no restating the heading.
- **Show, then name.** Introduce a piece with what it concretely does before the abstract label.
- **No noise, no repetition.** Say each thing once. Don't preface, don't recap, don't hedge.
- **No silent truncation.** On a large codebase, hold the mental-model altitude rather than dumping
  everything — and say what you summarised or left out, then offer to drill into any area. Never let
  a bounded view read as if it covered everything.
