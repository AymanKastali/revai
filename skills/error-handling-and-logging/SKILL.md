---
name: error-handling-and-logging
description: Use when writing error paths, try/catch blocks, or logging in backend code — fail loud instead of swallowing errors, distinguish expected domain errors from unexpected faults, emit structured logs with context, and never log secrets or PII.
---

# Error handling & logging

The default failure mode in backends is the *silent* one: an exception caught and ignored, a log
line with no context, a secret printed to stdout. These rules keep failures visible, diagnosable,
and safe.

## Two kinds of errors — handle them differently

- **Expected / domain errors** (validation failed, not found, conflict, forbidden): part of normal
  operation. Represent them as typed results or specific exception types, map them to the right API
  response (see `api-design`), and log at `info`/`warn`. Do not alert on these.
- **Unexpected faults** (bug, dependency down, out of memory): the code cannot recover. Let them
  propagate to a top-level handler that logs at `error` with full context and returns a generic
  `500` envelope. These are what monitoring should alert on.

Don't blur the two — catching a genuine bug and returning `200`, or turning a "not found" into a
`500`, both hide the truth.

## Rules

- **Never swallow.** No empty `catch`, no `catch` that only logs and continues as if nothing
  happened when the operation actually failed. If you catch, you must handle: recover, translate, or
  re-raise. Catching to add context then re-raising is fine.
- **Catch narrow.** Catch the specific error you can handle, not a blanket "any error" — a broad
  catch hides the faults you didn't anticipate.
- **Preserve the cause.** When wrapping an error, chain the original (cause/`from`) so the stack
  trace survives. Never replace a real error with a vague new one.
- **Fail fast on bad state.** Validate inputs and invariants at the boundary and stop early, rather
  than propagating corrupt state deeper where the eventual failure is unrelatable to the cause.
- **Structured logs.** Log key-value fields (`order_id=…`, `user_id=…`, `duration_ms=…`), not
  interpolated prose. Structured logs are queryable; prose is not.
- **Carry a correlation/request ID** through the request lifecycle and include it on every log line,
  so one request's logs can be reassembled across services.
- **Right level.** `debug` for dev detail, `info` for lifecycle events, `warn` for handled-but-
  notable, `error` for faults needing attention. Don't log at `error` for expected domain outcomes.
- **Never log secrets or PII.** No passwords, tokens, API keys, full card numbers, or personal data.
  Redact or omit. Assume logs are readable by more people than the data itself should be.

## Checklist

- [ ] Expected errors are typed and mapped to correct responses; faults propagate to a top handler
- [ ] No empty/continue-anyway catch blocks; catches are narrow
- [ ] Wrapped errors preserve the original cause/stack
- [ ] Logs are structured key-values with a correlation ID
- [ ] Log level matches severity (domain outcome ≠ `error`)
- [ ] No secrets or PII in any log line or error message

## Example

**Bad** — swallows the fault, logs prose, leaks a secret, wrong outcome:
```go
if err := charge(order, apiKey); err != nil {
    slog.Info("charge failed for " + apiKey) // secret in logs; fault hidden as info
    return nil                               // lies to the caller
}
```

**Good:**
```go
if err := charge(order, apiKey); err != nil {
    var declined *CardDeclined
    if errors.As(err, &declined) { // expected domain error
        slog.Warn("charge declined",
            "order_id", order.ID, "reason", declined.Code, "request_id", reqID)
        return apiError(422, "card_declined", declined.Message)
    }
    return fmt.Errorf("charging order %s: %w", order.ID, err) // fault → top handler → 500
}
```
