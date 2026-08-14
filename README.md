# revai

Help, support, and guidance for writing backend software solutions — packaged as a
[Claude Code](https://claude.com/claude-code) plugin.

`revai` bundles a set of skills that Claude reaches for while you design and refactor
backend systems: modelling the domain, hunting down shallow abstractions, and pressure
testing a plan before you commit to it.

## Install

```
/plugin marketplace add AymanKastali/revai
/plugin install revai@revai
```

Or from your shell, without an interactive session:

```sh
claude plugin marketplace add AymanKastali/revai
claude plugin install revai@revai
```

This repository is both the plugin and its marketplace, which is why the marketplace and
the plugin share the name `revai`.

To update later:

```
/plugin marketplace update revai
```

## Skills

| Skill | What it does |
| --- | --- |
| `domain-driven-design` | Model software around the business domain: ubiquitous language, bounded contexts, aggregates, domain events, repositories, and strategic design. Triggers on domain modelling questions and on splitting a monolith into services. |
| `improve-codebase-architecture` | Scans a codebase for *deepening opportunities* — refactors that turn shallow modules into deep ones — presents them as a visual HTML report, then grills through whichever one you pick. Manual invocation only. |
| `grilling` | A relentless, round-based interview that stress-tests a plan, decision, or idea by mapping it as a design tree. |
| `find-skills` | Discovers and installs skills from the open agent skills ecosystem when you ask "is there a skill for X?" |

Most skills activate on their own when the conversation matches their description. Invoke
any of them explicitly with `/revai:<skill-name>`.

## Credits

The skills here are vendored from other MIT-licensed collections, with each skill keeping
its upstream `LICENSE` alongside it:

- `domain-driven-design` — [wondelai/skills](https://github.com/wondelai/skills)
- `improve-codebase-architecture`, `grilling` — [mattpocock/skills](https://github.com/mattpocock/skills)
- `find-skills` — [vercel-labs/skills](https://github.com/vercel-labs/skills)

See [CHANGELOG.md](CHANGELOG.md) for what changed relative to upstream.

## License

MIT © Ayman Kastali. See [LICENSE](LICENSE).
