# Observability strategy

## Contents
The three pillars, at a topology level · health checks and alerting · pointer to `best-practices` ·
examples.

Owns *what must be visible to operate this system safely* — which pillar covers which concern, and
where a health check or alert belongs in the topology. The actual metric/trace implementation
(`best-practices/observability.md`) and structured error logging
(`best-practices/error-handling-and-logging.md`) apply once this strategy is stated.

## The three pillars

The default this reference builds around, and still the right one for the large majority of systems
it'll be applied to. There's a live, credible industry critique arguing wide structured events serve
better than three siloed pillars that discard relational context at write time — worth knowing about,
but it doesn't change what to build here unless this system's own observability need has already
outgrown metrics/logs/traces.

- **Metrics** — numeric time series (latency, error rate, throughput, resource usage) per service
  in the diagram. State which metrics matter for *this* system's failure modes, not a generic list
  — a queue-backed worker cares about queue depth and consumer lag; a request/response API cares
  about p99 latency and error rate.
- **Logs** — structured, centralized. State what a log line must carry to debug a real incident
  (request/trace ID, tenant/user context where relevant) — the format itself is
  `best-practices/error-handling-and-logging.md`'s territory.
- **Traces** — for any request path crossing more than one service, a distributed trace is what
  makes "which hop was slow" answerable at all. State which paths need this — usually every
  cross-service call in the diagram; a single-service system may not need distributed tracing at
  all, and should say so rather than adding it by default.

## Health checks and alerting

- Every service the load balancer routes to exposes a `/healthz`-equivalent the LB uses to route
  around a bad instance — state this as a baseline, not a design decision to weigh per service.
- Name the conditions that page someone: sustained high error rate, resource exhaustion, queue depth
  past a threshold, a dependency's circuit breaker open for too long. An alert with no stated
  consumer or threshold is noise waiting to be muted — this mirrors
  `best-practices/observability.md`'s "a metric with no stated consumer" rule, applied to alerts.

## SLOs

Where the system has a real availability/latency target from the NFRs
(`/revai:decide`'s "Functional scope & NFRs" dimension), restate it here as the number observability
is built to detect a breach of — an SLO with no corresponding alert is a target nobody is actually
watching.

## Checklist

- [ ] Metrics, logs, and traces are each addressed for this system's actual failure modes, not a
      generic template
- [ ] Every load-balanced service has a stated health-check endpoint
- [ ] Alert conditions are named with a threshold and an implied consumer (who gets paged, for what)
- [ ] A stated NFR target (availability/latency) has a corresponding alert that would detect its
      breach
- [ ] Distributed tracing is scoped to paths that actually cross more than one service — not added
      by default to a single-service system
