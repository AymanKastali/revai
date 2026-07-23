# Resilience & timeouts

## Contents
Rules · Checklist · Examples

Backends fail at the network edge: a dependency hangs, a retry storm amplifies an outage, a deploy
kills a pod mid-request. These rules stop one slow dependency from taking down the whole service.

## Rules

- **Every outbound call has a deadline.** Pass a `context.Context` with a timeout to every DB query,
  HTTP call, and RPC. Never call a network dependency with `context.Background()` and no deadline.
  **Propagate the incoming request's context** so a client disconnect cancels the downstream work.
- **Explicit HTTP client timeouts.** Go's default `http.Client` has *no* timeout and can hang
  forever — always set `Timeout` (or drive it entirely from a per-request context deadline).
- **Retry only idempotent + transient failures.** Retry on timeouts, connection errors, and `5xx`
  for idempotent operations; never blindly retry a non-idempotent `POST` — gate it on an idempotency
  key (see `reference/api-design.md`). Always cap the attempt count.
- **Backoff with jitter.** Exponential backoff plus random jitter, so simultaneous clients don't
  retry in lockstep and stampede a recovering dependency. Never tight-loop retry.
- **Bound concurrency; fail fast.** Put a pool, semaphore, or circuit breaker in front of a
  dependency so a dead one doesn't pile up goroutines/connections. Shed load rather than queue
  unbounded.
- **Budgets shrink with depth.** A handler's total time budget must exceed the sum of what it allows
  downstream. Deriving each downstream deadline from the request context (`context.WithTimeout`)
  enforces this automatically — the remaining budget only ever decreases.
- **Graceful shutdown.** On `SIGTERM`: stop accepting new work, let in-flight requests finish within
  a bounded drain window, then close resources. Never hard-exit mid-request.
- **Name the failure.** Distinguish a timeout/cancellation from a genuine error in logs and metrics
  (see `reference/error-handling-and-logging.md`) — they have different causes and fixes.

## Checklist

- [ ] Every outbound call gets a context deadline; the request context is propagated
- [ ] HTTP clients set an explicit timeout (no default zero-timeout client)
- [ ] Retries only on idempotent + transient errors, with a capped attempt count
- [ ] Backoff is exponential with jitter, not a tight loop
- [ ] Concurrency to each dependency is bounded (pool / semaphore / breaker)
- [ ] Downstream deadlines derive from the handler's budget, not fresh unbounded ones
- [ ] `SIGTERM` triggers a bounded graceful drain, not an abrupt exit

## Examples

### Go

**Bad** — no timeout, default client, blind unbounded retry that hammers a down dependency:

```go
func fetch(url string) (*Resp, error) {
    for { // retries forever
        resp, err := http.Get(url) // default client: no timeout, can hang indefinitely
        if err == nil {
            return parse(resp)
        }
    }
}
```

**Good** — deadline propagated from the caller's context, bounded retries with backoff + jitter:

```go
var client = &http.Client{Timeout: 3 * time.Second}

func fetch(ctx context.Context, url string) (*Resp, error) {
    const maxAttempts = 3
    for attempt := 0; attempt < maxAttempts; attempt++ {
        req, _ := http.NewRequestWithContext(ctx, http.MethodGet, url, nil) // caller's deadline propagates
        resp, err := client.Do(req)
        if err == nil {
            return parse(resp)
        }
        if !isRetryable(err) || ctx.Err() != nil { // don't retry a fatal error or a cancelled ctx
            return nil, err
        }
        backoff := time.Duration(1<<attempt)*100*time.Millisecond + jitter()
        select {
        case <-time.After(backoff):
        case <-ctx.Done():
            return nil, ctx.Err()
        }
    }
    return nil, fmt.Errorf("fetch %s: retries exhausted", url)
}
```

### Python

**Bad** — no timeout, unbounded retry loop with no backoff:

```python
def fetch(url):
    while True:                              # retries forever
        try:
            return parse(requests.get(url))  # default: no timeout, can hang indefinitely
        except Exception:
            pass                             # blind retry, no backoff
```

**Good** — explicit client timeout; propagate a monotonic deadline (Python's stand-in for a context):

```python
_client = httpx.Client(timeout=3.0)  # explicit timeout, not the unbounded default

def fetch(url: str, deadline: float) -> Resp:
    for attempt in range(3):
        try:
            return parse(_client.get(url))
        except httpx.HTTPError as e:
            backoff = 0.1 * 2 ** attempt + jitter()
            if not is_retryable(e) or time.monotonic() + backoff >= deadline:
                raise  # don't retry a fatal error or past the caller's deadline
            time.sleep(backoff)
    raise RuntimeError(f"fetch {url}: retries exhausted")
```
