# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `.claude-plugin/marketplace.json`, making this repository its own single-plugin
  marketplace so the plugin can be installed with
  `/plugin marketplace add AymanKastali/revai`.
- `README.md` with install instructions and a skill index.
- `find-skills` skill, vendored from [vercel-labs/skills](https://github.com/vercel-labs/skills)
  under MIT. Discovers and installs skills from the open agent skills ecosystem
  via the `npx skills` CLI.
- `grilling` skill, vendored from [mattpocock/skills](https://github.com/mattpocock/skills)
  under MIT. Relentless round-based interviewing to stress-test a plan or design.
  Upstream splits this across `grill-me` (a one-line manual trigger) and
  `grilling` (the method); merged here into a single skill.
- `improve-codebase-architecture` skill, vendored from [mattpocock/skills](https://github.com/mattpocock/skills)
  under MIT. Scans for shallow modules, presents deepening candidates as an HTML
  report, then grills through the chosen one.
- `domain-driven-design` skill, vendored from [wondelai/skills](https://github.com/wondelai/skills)
  under MIT. Ubiquitous language, bounded contexts, aggregates, domain events,
  repositories, and strategic design, with six reference documents.

### Removed

- The empty `.mcp.json` and the inert `hooks/hooks.json`. Both were placeholders
  with no entries; Claude Code discovers them by convention, so an empty file is
  only a chance to fail validation. They come back when there is something to put
  in them.
- The `version` field from the plugin manifest. Releases are tracked here and by
  git tags rather than in the manifest.

## [0.1.0] - 2026-08-14

### Added

- Initial plugin scaffold: manifest, empty `skills/`, `agents/`, and `bin/`
  directories, an inert `hooks/hooks.json`, and an empty `.mcp.json`.
