---
description: Attach the revai harness to the current repo — enable the plugin, detect the stack, and record how the AI should verify its work.
---

# /revai:attach

Set up the **current repository** with the revai harness. Work through these steps in order.
Be concise with the user; confirm before writing files. Never overwrite content you did not create.

## 1. Enable the revai plugin for this project

- Look for `.claude/settings.json` in the repo root. Create it (and the `.claude/` dir) if absent.
- Merge `"revai@revai": true` into the `enabledPlugins` object. **Preserve every existing key** —
  read the current JSON, add the one entry, write it back. Do not clobber other settings.
- If the file already has `"revai@revai": true`, say so and move on.

## 2. Detect the stack

Probe the repo root for stack markers and infer the language/framework:

| Marker | Stack |
|---|---|
| `package.json` | Node / TypeScript / JavaScript |
| `pyproject.toml`, `requirements.txt`, `setup.py` | Python |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `pom.xml`, `build.gradle` | Java / Kotlin (JVM) |
| `Gemfile` | Ruby |
| `composer.json` | PHP |

- If several match, pick the primary and note the others.
- If **nothing** matches (brand-new empty repo) or it is ambiguous, **ASK** the user what stack this
  project is (or will be).

## 3. Derive the verify commands

Determine the commands that let the AI check its own work — **install, run, test, lint, format**.
Read them from the project itself; do NOT invent them:

- Node: `package.json` `scripts` (`test`, `lint`, `build`, `dev`/`start`), package manager from
  the lockfile (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, else npm).
- Python: `pyproject.toml` / `Makefile` / `tox.ini`; detect `pytest`, `ruff`/`flake8`, `black`.
- Go: `go test ./...`, `go build ./...`, `go vet ./...`, `gofmt`.
- Rust: `cargo test`, `cargo build`, `cargo clippy`, `cargo fmt`.
- Otherwise inspect a `Makefile` / `Justfile` / CI config, or ask.

Show the user the commands you found and let them correct any before writing. Leave a field blank
(with a `TODO` note) rather than guessing.

## 4. Write the project files

### 4a. The project CLAUDE.md

Instantiate the template at `${CLAUDE_PLUGIN_ROOT}/templates/project-CLAUDE.md`, filling in the
stack and verify commands.

- **No `CLAUDE.md` yet:** write the filled-in template to `CLAUDE.md`.
- **`CLAUDE.md` already exists:** do **not** overwrite it. Instead, append a clearly delimited
  section titled `## revai harness` containing the stack + verify commands, or show the user the
  proposed block and let them merge it. Preserve everything already in the file.

### 4b. The machine-readable verify config (`.revai/verify.json`)

This is what the **verify-on-Stop hook** reads to gate task completion. Write the *check* commands
(test, lint, build, format — **not** install or run-the-app) as JSON. Mark the ones whose failure
should block the agent from finishing: **`test` and `lint` are blocking; `build` and `format` are
advisory** (reported, never blocking). Omit any command you left blank/TODO.

```json
{
  "commands": [
    { "name": "test",   "cmd": "<TEST command>",   "blocking": true },
    { "name": "lint",   "cmd": "<LINT command>",   "blocking": true },
    { "name": "build",  "cmd": "<BUILD command>",  "blocking": false },
    { "name": "format", "cmd": "<FORMAT check>",   "blocking": false }
  ]
}
```

- Create the `.revai/` dir if absent. If `.revai/verify.json` already exists, show the user the
  proposed content and let them confirm before overwriting — don't clobber their tuning.
- For the format entry, prefer a **check** form that fails on unformatted code (e.g. `gofmt -l .`,
  `black --check .`, `prettier --check .`) over one that rewrites files.
- Keep the commands identical to the ones in `CLAUDE.md` so the two never drift.

## 5. Summarize

Tell the user what you set up:
- plugin enabled in `.claude/settings.json`
- detected stack + verify commands recorded in `CLAUDE.md`
- verify commands mirrored to `.revai/verify.json` so the **verify-on-Stop hook** runs them
  automatically and blocks completion when a blocking check (test/lint) fails
- for backend projects: revai's backend skills (listed in the project `CLAUDE.md` you just wrote) are
  now available and surface automatically when relevant
- next step: for anything that needs a judgment call first — a new architecture, a feature's plan,
  a bug's root cause, a refactor's scope — start with **`/revai:decide`**, which ends in one written,
  approved decision doc with zero repo changes; once you have one (or the change is trivial enough
  not to need one), **`/revai:implement`** drives it to an open PR — build/fix/reshape → verify →
  review → PR — following the rules you just recorded
- reminder: pull future harness improvements with `/plugin update revai@revai`, and start a fresh
  session (or `/reload-plugins`) to pick up newly enabled components.
