# Data layer architecture

## Contents
Storage-engine selection by access pattern · ER-diagram convention · sharding/partitioning shape ·
pointer to `best-practices` and the existing caching dimension · examples.

This reference owns *which kind of datastore fits this access pattern*, at the system level, and
the *shape* of partitioning across nodes. It doesn't own query/repository code
(`best-practices/data-access-patterns.md`), migrations (`best-practices/safe-schema-changes.md`),
or caching strategy (the existing "Caching" dimension in `/revai:decide`'s checklist, plus
`best-practices/caching.md`) — those apply once a storage engine is chosen here.

## Storage-engine selection

| Access pattern | Engine type | Examples |
|---|---|---|
| Structured data, complex joins, strong consistency (ACID) | Relational (RDBMS) | PostgreSQL, MySQL |
| Semi-structured/unstructured, schema varies per record or evolves often | Document | MongoDB, DynamoDB |
| Simple key→value lookups, session/cache-shaped data | Key-value | Redis, Memcached |
| Full-text search, fuzzy matching, faceted filtering | Search engine | Elasticsearch, OpenSearch |
| High-volume timestamped metrics/events | Time-series | TimescaleDB |
| Data whose value is in the connections (social graphs, recommendations) | Graph | Neo4j |

Pick by the *actual* read/write and query shape from `reference/capacity-estimation.md` and the
domain's aggregates (`domain-driven-design/reference/tactical-patterns.md`) — not by familiarity or
what's already running elsewhere in the org. A system can legitimately use more than one engine for
different modules/aggregates; state which module uses which and why, rather than forcing one engine
to serve every access pattern.

## ER diagrams and indexing

Sketch entities and relationships as simple ASCII/indented text, matching the diagram convention in
`reference/high-level-architecture-diagramming.md` — no renderer-only ER diagram syntax. Name the
indexes that the system's known high-frequency queries need; an index list with no query behind it
is speculative, and a high-frequency query with no supporting index is a latency bug waiting to be
found in production.

## Sharding and partitioning

Only a live decision once `reference/capacity-estimation.md`'s storage/bandwidth numbers actually
warrant it — a dataset that fits comfortably on one instance doesn't need a partitioning scheme
"for later." Where it is warranted, state the partition key and why it distributes load evenly
(avoid a key that concentrates traffic on one shard — a single high-traffic tenant ID, for example).
Read replicas and connection pooling (PgBouncer or equivalent) are the usual first scaling move
before sharding — see `reference/scalability-and-resilience.md`.

## Checklist

- [ ] The storage engine is chosen from the access-pattern table above, with the reason stated —
      not defaulted to a familiar engine
- [ ] Different modules/aggregates using different engines are named explicitly, if that's the case
- [ ] High-frequency queries each have a named supporting index
- [ ] Sharding/partitioning is proposed only where the capacity numbers actually warrant it, with a
      partition key that distributes load evenly
- [ ] Caching strategy is left to the existing "Caching" checklist dimension and
      `best-practices/caching.md`, not re-decided here
