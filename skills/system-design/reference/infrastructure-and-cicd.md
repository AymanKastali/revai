# Infrastructure & CI/CD

## Contents
Infrastructure as code · containerization/orchestration · CI/CD strategy · examples.

Owns how the design gets from a document to a running, repeatedly-deployable system. Nothing else in
this harness covers this ground — treat it as a real design decision, not a detail left for
whoever sets up the pipeline later, proportional to the stakes: a small internal tool may genuinely
need nothing beyond "deploys via the platform's existing pipeline," and that's a valid, stated
answer rather than an invented Kubernetes cluster for a two-user tool.

## Infrastructure as code

State the tool (Terraform, OpenTofu, or the platform's native IaC) only where new infrastructure is
actually being provisioned — servers, databases, networks, queues. Reusing existing, already-
provisioned infrastructure is a valid answer; say so rather than describing IaC for infrastructure
that already exists.

## Containerization & orchestration

- **Containerize** with Docker (or equivalent) when the system needs environment consistency across
  local/staging/production — the default for anything beyond a trivial script.
- **Orchestration** — Kubernetes when the system already needs (or clearly will need) multi-service
  scheduling, autoscaling, and self-healing across many instances; a managed service (ECS, Cloud
  Run, or the platform's equivalent) when it doesn't need Kubernetes' full feature set but still
  wants managed scaling and deploys. Reaching for Kubernetes because it's the default reflex, for a
  system that a managed service would serve just as well, is the same over-engineering mistake this
  harness flags everywhere else — name the actual need it serves here.

## CI/CD strategy

- **Pipeline stages** — automated tests, lint, and security scans gating the deploy, matching
  whatever this project's `/revai:attach`-recorded verify commands already are; this reference
  doesn't invent a new verification step, just places CI in the topology.
- **Deployment strategy** — blue/green (two full environments, swap traffic) or canary (shift a
  small percentage of traffic, watch, then ramp) for zero-downtime releases. State which one, and
  why — canary suits a system where a partial-traffic failure is detectable and tolerable; blue/
  green suits one where an instant, clean rollback matters more than gradual exposure. A low-stakes
  internal tool may reasonably skip either and deploy directly, stated as such.

## Checklist

- [ ] New infrastructure that's actually being provisioned names its IaC tool; reused existing
      infrastructure is stated as such rather than re-described
- [ ] Containerization is stated as in-scope or explicitly not needed, with the reason
- [ ] Orchestration choice (Kubernetes vs. a managed service vs. none) is justified by an actual
      scheduling/scaling need, not defaulted to the most complex option
- [ ] A deployment strategy (blue/green, canary, or direct) is named with the reason it fits this
      system's risk tolerance
- [ ] CI/CD stages reference this project's actual recorded verify commands, not an invented generic
      pipeline
