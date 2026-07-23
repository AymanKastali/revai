# Authentication & authorization

Identity and permission checks are easy to scatter — a role check copy-pasted into every handler,
a token half-verified deep in a service call. These rules keep "who is this" resolved once at the
edge and "what can they do" centralized as an explicit policy, so both stay auditable and correct.

## Rules

- **Authenticate once, at the edge.** The inbound adapter — HTTP middleware, gRPC interceptor,
  message consumer — verifies the credential and resolves a principal exactly once. Pass that
  principal down explicitly (request context, function argument); never re-derive identity by
  re-parsing a token deep in domain code.
- **Authorization is an app/domain-layer concern, not scattered conditionals.** Model it as an
  explicit policy or rule set — a function or table the app layer consults — never ad hoc
  `if user.Role == "admin"` checks copy-pasted across handlers. One place decides "who can do X".
- **Prefer an established mechanism over inventing one.** OAuth2/OIDC for delegated third-party
  auth; signed JWTs or opaque session tokens for first-party sessions. Rolling a custom token format
  or a bespoke handshake is the kind of problem `best-practices` says to search for a standard
  solution to first.
- **Model permissions explicitly: RBAC roles or ABAC attributes.** Pick one model and keep the
  mapping from role/attribute to allowed action in one reviewable place, not implied by scattered
  code paths.
- **401 vs 403 are never conflated.** 401 (Unauthorized) means not authenticated at all — no
  principal, missing/invalid credential. 403 (Forbidden) means authenticated but not permitted.
  Returning the wrong one either leaks that a resource exists to an anonymous caller or hides a real
  auth failure as a permission problem.
- **Every authorization failure is a distinct, expected error.** Map it to `403 Forbidden` through
  the same expected-error path as any domain error (see `error-handling-and-logging`) — never let it
  surface as a generic `500`. The response must not leak enough detail (which specific permission,
  which other users have it) to help an attacker enumerate the policy.
- **Authorization is always enforced server-side.** A client-side or UI-only check (hiding a button)
  is UX, not security — the server re-checks on every request regardless of what the client claims.
- **Tokens are secrets-adjacent.** Never log a raw token, session ID, or credential — log a hash or
  the principal ID instead (see `error-handling-and-logging`'s secrets rule).
- **Tokens are short-lived with a revocation path.** A long-lived token that can't be revoked turns
  any leak into a standing compromise; prefer short expiry plus refresh, and a real way to invalidate
  a session (blocklist, session store, or bump a token version) before natural expiry.

## Checklist

- [ ] Identity is resolved once at the edge and passed down explicitly — no re-deriving it deep in
      domain code
- [ ] Authorization logic lives in one explicit policy/rule set, not scattered `if role ==` checks
- [ ] Auth uses an established mechanism (OAuth2/OIDC, signed JWT, opaque session) not a custom one
- [ ] Permissions are modeled explicitly (RBAC or ABAC) in one place
- [ ] 401 (not authenticated) and 403 (not permitted) are distinct and never conflated
- [ ] Every authorization failure returns 403 through the expected-error path, never a generic 500
- [ ] The failure response doesn't leak enough detail to enumerate the permission model
- [ ] Every authorization check is enforced server-side, regardless of any client-side check
- [ ] Tokens/credentials are never logged raw
- [ ] Tokens are short-lived and have a real revocation path

## Examples

### Go

**Bad** — role check duplicated ad hoc inside the handler, re-parses the token instead of using the
resolved principal, and returns a generic error that conflates "not logged in" with "not allowed":

```go
func DeleteInvoiceHandler(w http.ResponseWriter, r *http.Request) {
    token := r.Header.Get("Authorization")
    claims, err := parseJWT(token) // re-derives identity here, not from the edge
    if err != nil || claims.Role != "admin" { // ad hoc role check, copy-pasted per handler
        http.Error(w, "error", http.StatusInternalServerError) // wrong status, no distinction
        return
    }
    deleteInvoice(r.Context(), r.PathValue("id"))
}
```

**Good** — the principal is resolved once by middleware and carried on the context; authorization
is a single named policy call; 401 vs 403 are distinct:

```go
// middleware: runs once at the edge, resolves the principal, rejects unauthenticated requests
func WithPrincipal(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        principal, err := authenticator.Verify(r.Header.Get("Authorization"))
        if err != nil {
            http.Error(w, "unauthorized", http.StatusUnauthorized) // 401: no valid credential
            return
        }
        next.ServeHTTP(w, r.WithContext(withPrincipal(r.Context(), principal)))
    })
}

// app layer: one policy function decides "who can do X"
func (p Policy) CanDeleteInvoice(principal Principal, inv Invoice) bool {
    return principal.HasRole(RoleAdmin) || principal.OwnsAccount(inv.AccountID)
}

func DeleteInvoiceHandler(w http.ResponseWriter, r *http.Request) {
    principal := principalFrom(r.Context()) // resolved once, upstream
    inv, err := invoices.Get(r.Context(), r.PathValue("id"))
    if err != nil {
        writeDomainError(w, err)
        return
    }
    if !policy.CanDeleteInvoice(principal, inv) {
        http.Error(w, "forbidden", http.StatusForbidden) // 403: authenticated, not permitted
        return
    }
    invoices.Delete(r.Context(), inv.ID)
}
```

### Python

**Bad** — the handler re-parses the token itself and hardcodes the role check, mixing authentication
and authorization together with no single policy to audit:

```python
def delete_invoice(request):
    payload = jwt.decode(request.headers["Authorization"], SECRET, algorithms=["HS256"])
    if payload.get("role") != "admin":       # ad hoc, repeated per endpoint
        return Response(status=500)          # wrong status, leaks nothing useful either way
    invoices.delete(request.path_params["id"])
```

**Good** — an auth middleware resolves the principal once; a dedicated policy object is the single
place permissions are decided; 401/403 map to the right expected-error path:

```python
# middleware: resolves the principal once, rejects invalid/missing credentials with 401
async def auth_middleware(request: Request, call_next):
    try:
        principal = authenticator.verify(request.headers.get("Authorization", ""))
    except InvalidCredential:
        return JSONResponse({"error": "unauthorized"}, status_code=401)
    request.state.principal = principal
    return await call_next(request)

# app layer: one policy class, one place to change "who can do X"
class InvoicePolicy:
    def can_delete(self, principal: Principal, invoice: Invoice) -> bool:
        return principal.has_role("admin") or principal.owns_account(invoice.account_id)

async def delete_invoice(request: Request):
    principal = request.state.principal  # resolved once, upstream — never re-derived here
    invoice = await invoices.get(request.path_params["id"])
    if not policy.can_delete(principal, invoice):
        return JSONResponse({"error": "forbidden"}, status_code=403)  # authenticated, not permitted
    await invoices.delete(invoice.id)
```
