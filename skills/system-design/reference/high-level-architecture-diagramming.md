# High-level architecture diagramming

## Contents
The diagram convention · the ingress layer · monolith vs. microservices (pointer, not a rule owned
here) · examples.

The design doc's **Recommended architecture** section needs a picture, not just prose — a reader
should see the request path in five seconds. This reference owns the *diagramming convention* and
the *ingress-layer pieces*; it does not re-decide the module/service boundary — that's
`domain-driven-design`'s call (bounded contexts, hexagonal layering, the modular-monolith default),
made before this diagram gets drawn.

## The convention

Plain ASCII/indented block diagram, terminal-renderable — no renderer-only syntax (matches
`architecture-fit.md`'s rule for the rest of the design doc). Draw the request path top-to-bottom,
client to datastore:

```
[ Client / Mobile ]
        │
        ▼
  [ CDN / Edge ]
        │
        ▼
 [ API Gateway / Load Balancer ]
        │
 ┌──────┴────────────────┐
 ▼                       ▼
[ Module A ]          [ Module B ]
 │                       │
 ▼                       ▼
[ Cache / Redis ]    [ DB ]
```

Label each box with the real name from the design (module names, not generic placeholders), and
annotate an arrow only where the protocol matters and isn't obvious (see
`reference/api-contract-design.md`) — e.g. `──gRPC──▶` between two internal modules, `──REST──▶` at
the client-facing edge.

## The ingress layer

Everything above the service layer, in order:

- **DNS** — routes the domain to the edge/load balancer. Rarely a design decision worth a line
  unless multi-region failover is genuinely in play.
- **CDN** — caches and serves static/media assets close to the client. Worth a box whenever the
  system serves meaningfully large or geographically distributed static content; skip it (state why
  in one line) for a purely API-driven backend with no static payload.
- **Load balancer / API gateway** — SSL termination, rate-limiting, and routing to the service
  layer. This is also where authn is typically resolved once, at the edge (see
  `reference/security-and-compliance.md` and `best-practices/authn-and-authorization.md`).

## Monolith vs. microservices — pointer, not owned here

`domain-driven-design`'s modular-monolith default already answers this: one deployable, partitioned
by bounded context, until a module genuinely needs to be its own service. This diagram draws
whatever that decision produced — modules inside one box for a monolith, separate boxes with a
network edge between them once a module has actually been extracted. Don't re-litigate the
boundary decision here; just draw it accurately.

## Checklist

- [ ] The design doc's "Recommended architecture" section includes a diagram, not prose alone
- [ ] The diagram is plain ASCII/indented text — no renderer-only diagram syntax
- [ ] Boxes are labelled with real module/component names, not generic placeholders
- [ ] Protocol is annotated only where it isn't obvious from context
- [ ] The diagram reflects the module/service boundary DDD already decided — it doesn't introduce a
      new one
