# Observability & feature flags, per module

## Contents
Module-tagged structured logging · why distributed tracing isn't needed in-process · what's verified
vs. stated as convention · feature-flag namespacing.

## Module-tagged structured logging

Add a `module` field to every log line, plus a correlation/request ID threaded through the call chain.
Because every cross-module call in this pattern is in-process (see
`reference/in-process-communication.md`), a coherently module-tagged, correlation-ID-threaded log
stream **is** the full request trace — there is no network hop to lose visibility across, so no
distributed tracing infrastructure is needed for calls that never leave the process. Cross-reference
`system-design/reference/observability-strategy.md` for the moment a request *does* cross into another
service — that's a different problem this file doesn't solve.

## What's verified vs. stated as convention

No confirmed OpenTelemetry semantic-convention standard for module-scoped attributes exists in the
research behind this skill — a specific claim to that effect could not be confirmed against Spring
Boot's actual observability documentation. Treat the `module` log field above as **this skill's own
recommended convention**, not an OpenTelemetry or industry standard.

## Feature-flag namespacing

Prefix a feature flag with its owning module's name (e.g. `billing.new_invoice_flow`) rather than a
flat, unnamespaced flag name — this avoids a global flag junk drawer where it's unclear which module a
flag even belongs to, or whether two modules have accidentally claimed the same name. Real-world
precedent for the *pattern* of module-scoped flags exists (module-registration-time flags that
conditionally wire a module's routes/dependencies at all; GitLab's combination of code ownership,
feature flags, and internal APIs as its modularity enforcement mechanism) — but the specific
`module.flag_name` namespacing convention itself has no verified industry-standard citation beyond
"prefix by module name" being the obvious move. State it as this skill's recommended convention.

## Checklist

- [ ] Every log line carries a `module` field and a correlation/request ID
- [ ] No claim is made that module-tagged logging satisfies a specific OTel semantic-convention
      standard — it's stated as this skill's own convention
- [ ] Every feature flag controlling module-specific behavior is namespaced by module name
- [ ] Distributed tracing is reserved for requests that actually cross into another service
      (`system-design/reference/observability-strategy.md`), not added by default in-process
