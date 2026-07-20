---
description: Generate a canonical, self-contained learning document on a topic — your source of truth — grounded by verification, then keep tutoring interactively.
argument-hint: <topic to learn, e.g. "SSE (server-sent events)">
---

# /revai:learn

Turn a topic into **the one document you need to understand it** — self-contained, straightforward,
with runnable Python examples — then stay available to tutor you further. You **orchestrate**; the
`writing-learning-docs` skill owns the shape, and `deep-research` grounds the facts.

The argument (`$ARGUMENTS`) is the topic to learn. If it's empty, ask what to learn and stop.

## 1. Set up the doc

- Invoke the **`writing-learning-docs`** skill and follow its template + rules for everything below.
- Derive a kebab-case slug from the topic (e.g. `SSE (server-sent events)` → `sse`). The target
  file is `docs/learning/<slug>.md` in the current repo. Create `docs/learning/` if it's missing.
- If the file already exists, tell the user and ask whether to **refresh** it (regenerate) or
  **extend** it (add to what's there). Don't silently overwrite.

## 2. Draft

- Write the full doc from your own knowledge against the skill's template. Get the mental model and
  the "how it works" right first — that's the spine.
- Put runnable Python where code clarifies. Don't add code for its own sake.

## 3. Verify (hybrid grounding)

- Invoke the **`deep-research`** skill to check the load-bearing claims — anything version-specific,
  anything a reader would act on, anything you're less than sure of.
- Correct the draft against what research finds. Fill the **Sources** section with the links it
  surfaces. If research contradicts a claim you can't resolve, cut the claim rather than ship it.

## 4. Write

- Save the finished doc to `docs/learning/<slug>.md`.
- Report the path and give the user a 3–5 line summary of what the doc covers.

## 5. Offer to go deeper

- Offer to tutor further: answer questions, expand a section, or add more examples — applying each
  update to the **same file** so it stays the single source of truth.
- Keep going until the user is done. Re-run the verification pass for any new load-bearing claim.
