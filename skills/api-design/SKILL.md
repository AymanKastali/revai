---
name: api-design
description: Use when designing or adding an HTTP API endpoint, route, or resource — enforces resource-oriented URLs, correct status codes, one consistent error envelope, pagination/filtering conventions, versioning, and idempotency on writes.
---

# Designing HTTP APIs

Apply these when adding or changing any endpoint. The goal is that every endpoint in the codebase
behaves the same way, so a client that has integrated one can predict the next.

**First, match what already exists.** If the codebase has an established error shape, pagination
style, or versioning scheme, follow it — consistency beats these defaults. Use the rules below when
there is no precedent.

## Rules

- **Resource-oriented URLs.** Nouns, plural, no verbs: `POST /orders`, `GET /orders/{id}`,
  `GET /orders/{id}/items`. The HTTP method is the verb. No `/getOrder`, `/createOrder`.
- **Right status codes** — do not return `200` for everything:

  | Situation | Status |
  |---|---|
  | Read / update succeeded | `200` |
  | Resource created | `201` (+ `Location` header) |
  | Accepted for async work | `202` |
  | Success, no body | `204` |
  | Client sent bad input | `400` |
  | Not authenticated | `401` |
  | Authenticated but forbidden | `403` |
  | Resource missing | `404` |
  | Conflict / duplicate / version mismatch | `409` |
  | Validation failed | `422` |
  | Rate limited | `429` |
  | Unexpected server fault | `500` |

- **One error envelope** for every non-2xx, everywhere:
  ```json
  { "error": { "code": "order_not_found", "message": "Order 123 does not exist", "details": [] } }
  ```
  `code` is a stable machine string clients can branch on; `message` is human-facing; `details` is
  an optional array (e.g. per-field validation errors). Never leak stack traces or internal messages.
- **Pagination** on any collection that can grow unbounded. Pick one style and use it everywhere —
  prefer cursor-based (`?limit=50&cursor=…`, response returns `next_cursor`) for large or live data;
  offset/limit is acceptable for small, stable sets. Always cap `limit`.
- **Filtering & sorting** via query params, documented and allow-listed: `?status=open&sort=-created_at`.
  Never build queries from arbitrary client-supplied field names.
- **Versioning.** Choose one scheme up front — URL prefix (`/v1/…`) is simplest and most visible.
  Add a new version rather than breaking an existing one; additive changes (new optional field) need
  no version bump.
- **Idempotency on writes.** Non-idempotent creates (`POST`) should accept an `Idempotency-Key`
  header and return the original result on retry, so a client retry never double-charges or
  double-creates. `PUT`/`DELETE` must be naturally idempotent.
- **Validate at the boundary.** Reject unknown/extra fields or coerce explicitly; never trust the
  client's content-type or field types.

## Checklist

- [ ] URL is a plural noun; method carries the verb
- [ ] Status code matches the outcome (not blanket `200`)
- [ ] Errors use the shared envelope with a stable `code`
- [ ] Collection endpoints paginate with a capped `limit`
- [ ] Filter/sort params are allow-listed, not free-form
- [ ] Breaking change → new version, not a mutated existing one
- [ ] `POST` creates accept an idempotency key
- [ ] No stack traces / internal details in responses

## Example

**Bad** — verb URL, blanket 200, ad-hoc error, unbounded list:
```
GET /fetchAllOrders        → 200 { "orders": [ ...every row... ] }
POST /createOrder (dupe)   → 200 { "ok": false, "msg": "already exists" }
```

**Good:**
```
GET  /orders?status=open&limit=50   → 200 { "data": [...], "next_cursor": "eyJ…" }
POST /orders  (Idempotency-Key: abc)
     first call  → 201 Location: /orders/789   { "data": {...} }
     retry       → 201 same body (not a second order)
     conflict    → 409 { "error": { "code": "order_exists", "message": "…" } }
```
