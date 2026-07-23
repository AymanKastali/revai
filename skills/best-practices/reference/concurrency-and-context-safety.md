# Concurrency & context safety

Backends fail inside the service, not just at the network edge: a goroutine leaks because nothing
ever signals it to stop, two handlers race on the same map, a fan-out spawns one goroutine per
request with no bound. These rules keep concurrent code correct and bounded, not just fast.

## Rules

- **No shared mutable state without a guard.** A `mutex`, a channel, or an actor-style single owner
  goroutine — pick one, but never let two goroutines read-modify-write the same value unguarded.
  Prefer passing ownership (channels) or immutable data over sharing state that needs a lock.
- **Every goroutine/task has a clear exit path.** Before spawning one, know what makes it stop:
  the work finishing, its context being cancelled, or its parent shutting down. A goroutine with
  none of these is a leak, even if it's cheap today.
- **Propagate cancellation through every call chain.** Pass the caller's `context.Context` (or the
  Python equivalent — a cancellable `asyncio.Task`) into everything spawned on its behalf; check
  `ctx.Err()` / `task.cancelled()` before starting expensive work, not only at the end.
- **Bound concurrency to a fixed pool, never per-request unbounded spawning.** `go func()` (or
  `asyncio.create_task`) once per incoming request, with no cap, means load determines your
  goroutine count instead of you. Use a worker pool, a semaphore, or an `errgroup` with
  `SetLimit`.
- **One goroutine per fan-out step waits for all its children before returning.** Spawning workers
  and returning without joining them (`sync.WaitGroup`, `errgroup.Wait`, gathering the tasks) loses
  both their errors and their completion — the caller moves on with work still in flight.
- **Cancel siblings on first failure in a fan-out.** If one branch of concurrent work fails and the
  rest is now pointless, cancel the shared context so the others stop promptly instead of running
  to completion for nothing (`errgroup.WithContext` gives you this for free).
- **Timeouts and retries are `resilience-and-timeouts`'s job, not this skill's** — this skill owns
  *in-process* concurrency safety; that one owns calling *out* to a dependency.

## Checklist

- [ ] Every piece of shared mutable state has a named guard (mutex, channel ownership, or single
      owning goroutine) — never bare concurrent read-modify-write
- [ ] Every spawned goroutine/task has a stated exit condition (done, cancelled, or parent exit)
- [ ] The caller's context/cancellation is propagated into everything spawned on its behalf
- [ ] Concurrency to a fan-out or worker pool is capped, not one-per-request unbounded
- [ ] Every fan-out joins/waits on its children before the function returns
- [ ] A fan-out cancels its siblings on first failure when the rest would be wasted work

## Examples

### Go

**Bad** — unbounded per-item goroutines, no join, a shared map written without a guard:

```go
func enrichAll(items []Item) map[string]Result {
    results := map[string]Result{} // shared, unguarded
    for _, item := range items {
        go func(it Item) { // one goroutine per item, no cap, no join
            results[it.ID] = enrich(it) // concurrent write to a plain map: a data race
        }(item)
    }
    return results // returns before any goroutine has necessarily run
}
```

**Good** — bounded fan-out via `errgroup`, each result written by its own owner, cancels on first
failure, propagates the caller's context:

```go
func enrichAll(ctx context.Context, items []Item) (map[string]Result, error) {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(8) // bounded concurrency, not one goroutine per item

    results := make([]Result, len(items))
    for i, item := range items {
        i, item := i, item
        g.Go(func() error {
            if ctx.Err() != nil { // caller cancelled or a sibling already failed
                return ctx.Err()
            }
            r, err := enrich(ctx, item)
            if err != nil {
                return err // cancels the group's context for the remaining goroutines
            }
            results[i] = r // each goroutine owns a distinct slice index — no shared write
            return nil
        })
    }
    if err := g.Wait(); err != nil { // joins every goroutine before returning
        return nil, err
    }
    out := make(map[string]Result, len(items))
    for i, item := range items {
        out[item.ID] = results[i]
    }
    return out, nil
}
```

### Python

**Bad** — unbounded task creation, no cancellation on failure, shared dict mutated from every task:

```python
async def enrich_all(items: list[Item]) -> dict[str, Result]:
    results = {}  # shared, unguarded
    tasks = [asyncio.create_task(enrich(it)) for it in items]  # unbounded, one per item
    for it, task in zip(items, tasks):
        results[it.id] = await task  # sequential await defeats the concurrency anyway
    return results
```

**Good** — bounded concurrency via a semaphore, gathered together so one failure cancels the rest:

```python
async def enrich_all(items: list[Item], limit: int = 8) -> dict[str, Result]:
    sem = asyncio.Semaphore(limit)  # bounded concurrency, not one task per item

    async def bounded_enrich(item: Item) -> tuple[str, Result]:
        async with sem:
            return item.id, await enrich(item)

    tasks = [asyncio.create_task(bounded_enrich(it)) for it in items]
    try:
        pairs = await asyncio.gather(*tasks)  # joins every task; raises on first failure
    except BaseException:
        for t in tasks:
            t.cancel()  # cancel the siblings instead of letting them run to completion
        raise
    return dict(pairs)
```
