# Observability: metrics & tracing

Metrics and traces exist to answer "is it broken, and where" faster than reading logs one line at a
time. This file covers metrics and distributed tracing; **structured logging is
`error-handling-and-logging`'s job and isn't duplicated here** — that file owns what a log line
contains and when to emit one.

## Rules

- **Emit metrics for signals that actually drive an alert or a dashboard.** Follow **RED** for a
  request-serving component (rate, errors, duration per endpoint) or **USE** for a resource
  (utilization, saturation, errors per pool/queue/disk). A metric nobody looks at or alerts on is
  noise — cut it rather than let it accumulate.
- **Every metric has a stated consumer.** Before adding one, name the dashboard panel or alert rule
  it feeds. If there isn't one yet, that's fine as a deliberate short-term choice, but a metric that
  never gets a consumer should be removed, not left emitting forever.
- **Bounded cardinality on every label.** A label value must come from a small, known set (endpoint
  name, status class, region). Never label with a raw user ID, request ID, or anything with
  unbounded distinct values — each unique combination is a new time series, and an unbounded label
  is a cardinality explosion that inflates cost and can take down the metrics backend.
- **Propagate trace context across every network hop.** Pass the W3C `traceparent` header (or your
  stack's equivalent) through every outbound call so a single request's spans link up across
  services. A trace that stops at the first hop is a trace of one component, not the request.
- **Correlate logs to traces.** The correlation/request ID already in structured logs should tie
  back to the trace ID (ideally, be the trace ID) — so "found it in the logs" and "found it in the
  trace" land on the same request.
- **Wrap outbound calls in a span, named by operation not implementation.** Name a span
  `db.get_user` or `payment.charge`, not `pq.Query` or `POST /internal/v3/x` — the name should
  survive a driver or endpoint change.
- **Sampling is a deliberate, stated choice.** Decide head-based (sample at the start, cheap, may
  miss rare errors) or tail-based (decide after seeing the outcome, catches errors, costs more) on
  purpose. Never silently drop error traces from the sample — an elevated error rate with no traces
  to explain it is a debugging dead end.

## Checklist

- [ ] Metrics cover RED (request path) or USE (resource) signals, not arbitrary internals
- [ ] Every metric has a named dashboard panel or alert consuming it, or it's cut
- [ ] No label carries an unbounded value (user ID, request ID, raw free text)
- [ ] Trace context propagates across every outbound network hop
- [ ] The log correlation ID ties back to the trace ID
- [ ] Outbound-call spans are named by operation, not driver/transport detail
- [ ] Sampling strategy (head vs tail) is a stated decision, and errors are never silently dropped
      from it
- [ ] Structured log *content* rules live in `error-handling-and-logging`, not duplicated here

## Examples

### Go

**Bad** — unbounded label blows up cardinality, no span around the outbound call, no propagated
trace context:

```go
func GetUser(ctx context.Context, id string) (*User, error) {
    requestsTotal.WithLabelValues(id).Inc() // raw user ID as a label: unbounded cardinality
    resp, err := http.Get(userServiceURL + "/users/" + id) // no span, no trace header propagated
    if err != nil {
        return nil, err
    }
    return parseUser(resp)
}
```

**Good** — bounded labels (endpoint + outcome class only), a named span, trace context carried onto
the outbound request:

```go
var requestsTotal = prometheus.NewCounterVec(
    prometheus.CounterOpts{Name: "user_service_requests_total"},
    []string{"endpoint", "outcome"}, // bounded set: known endpoints, known outcomes
)

func GetUser(ctx context.Context, id string) (*User, error) {
    ctx, span := tracer.Start(ctx, "user_service.get_user") // named by operation, not transport
    defer span.End()

    req, _ := http.NewRequestWithContext(ctx, http.MethodGet, userServiceURL+"/users/"+id, nil)
    otel.GetTextMapPropagator().Inject(ctx, propagation.HeaderCarrier(req.Header)) // W3C traceparent

    resp, err := client.Do(req)
    outcome := "ok"
    if err != nil {
        outcome = "error"
    }
    requestsTotal.WithLabelValues("get_user", outcome).Inc() // bounded: 2 labels, small value sets
    if err != nil {
        span.RecordError(err)
        return nil, err
    }
    return parseUser(resp)
}
```

### Python

**Bad** — request ID as a metric label, and the outbound call carries no trace context so the span
tree stops at this service:

```python
def get_user(request_id: str, user_id: str) -> User:
    requests_total.labels(request_id).inc()  # unbounded label: one series per request, forever
    resp = httpx.get(f"{USER_SERVICE_URL}/users/{user_id}")  # no span, no propagated trace context
    return parse_user(resp)
```

**Good** — bounded labels, a named span, propagated trace headers, and the log's correlation ID is
the trace ID:

```python
requests_total = Counter(
    "user_service_requests_total", "requests to user-service", ["endpoint", "outcome"]
)  # bounded: known endpoint names, "ok"/"error" only

def get_user(user_id: str) -> User:
    with tracer.start_as_current_span("user_service.get_user") as span:  # named by operation
        headers = {}
        inject(headers)  # W3C traceparent injected onto the outbound request
        trace_id = format(span.get_span_context().trace_id, "032x")
        try:
            resp = httpx.get(f"{USER_SERVICE_URL}/users/{user_id}", headers=headers)
            requests_total.labels("get_user", "ok").inc()
        except httpx.HTTPError as e:
            requests_total.labels("get_user", "error").inc()
            span.record_exception(e)  # tail-sampled traces keep errors; never dropped silently
            raise
        # error-handling-and-logging owns the log call itself; here we just ensure
        # the correlation ID passed to it is this trace_id, so log and trace tie together
        logger.info("fetched user", extra={"correlation_id": trace_id})
        return parse_user(resp)
```
