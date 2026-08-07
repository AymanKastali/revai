# Security & compliance architecture

## Contents
Defense in depth · authn/authz at the system level · data protection · network isolation · pointer
to `best-practices` · examples.

Owns the *system-level* security architecture — where authn/authz is resolved, how data is
protected in transit and at rest, and how the network is isolated. The code-level check
(`best-practices/authn-and-authorization.md`) and secrets handling
(`best-practices/config-and-secrets.md`) apply once this shape is chosen.

## Defense in depth

Security is layered, not a single gate at the edge: the ingress layer (rate limiting, WAF), the
authn/authz check, network isolation, and encryption each catch what the layer before them misses.
State each layer that applies to this design rather than relying on one of them to carry all the
weight.

## Authn/authz, at the system level

- **Authentication model** — OpenID Connect (OIDC), or session tokens; state which, and where it's
  issued/validated (typically the ingress layer — see
  `reference/high-level-architecture-diagramming.md`). OIDC, not bare OAuth2, is what actually
  supplies authentication (the ID token) — OAuth2 alone is a delegated-*authorization* framework, it
  doesn't verify who the user is. Don't reach for "OAuth2" as a stand-in for "the user is
  authenticated"; if the design needs an identity claim, that's OIDC's ID token, with the access
  token (OAuth2 proper, usually a JWT) covering delegated access to a resource.
- **Authorization model** — RBAC (or finer-grained, if a role genuinely doesn't capture the access
  rule) resolved once, at the edge, not re-derived deep in each module — this is the same rule
  `best-practices/authn-and-authorization.md` enforces in code; state the model here, let that
  reference own the implementation.
- **Tenant/data isolation** — for a multi-tenant system, state the isolation boundary (separate
  schema/database per tenant, or row-level tenant ID with enforced filtering) — this is a design
  decision with real blast-radius consequences if wrong, not an implementation detail to defer.

## Data protection

- **In transit** — TLS everywhere, stated as a baseline, not a design decision to weigh.
- **At rest** — encryption for the datastore and object storage holding sensitive data (AES-256 or
  the platform's equivalent managed encryption). State which data classes require this rather than
  encrypting everything by default without knowing why.
- **Compliance drivers** — name any that apply (GDPR, HIPAA, PCI-DSS) and what each concretely
  requires of this design (data residency, retention limits, audit logging) — a compliance
  requirement that isn't named tends to get discovered late, during an audit instead of a design
  review.

## Network isolation

Internal services and datastores sit in a private subnet/VPC, reachable only from the ingress layer
and other services that need them — not exposed directly to the internet. State the security-group/
firewall boundary for anything in the diagram that shouldn't be publicly reachable, and where a WAF
sits if the system is a plausible target for common web attacks.

## Checklist

- [ ] Authentication model and where it's resolved are both stated
- [ ] Authorization is resolved once, at the edge — not re-derived per module (matches
      `best-practices/authn-and-authorization.md`'s code-level rule)
- [ ] A multi-tenant system states its isolation boundary explicitly
- [ ] TLS in transit is assumed; at-rest encryption is stated for the data classes that need it
- [ ] Any compliance driver (GDPR/HIPAA/PCI-DSS/etc.) is named with what it concretely requires
- [ ] Internal services/datastores are stated as network-isolated, not publicly reachable by default
