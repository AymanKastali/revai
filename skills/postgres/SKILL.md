---
name: postgres
description: Applies the Postgres standard — design schemas, write SQL and ship migrations the way the PostgreSQL manual, the project wiki and the release notes say to, using the current major version's answers rather than folklore inherited from a MySQL tutorial. Use when writing or reviewing SQL, designing or changing a schema, picking a column type or a key, adding an index or a constraint, writing a migration, diagnosing a slow query, choosing an isolation level or a lock, sizing a connection pool, or granting database access.
---

# Postgres

Postgres punishes guesses quietly. The schema that looked fine holds `varchar(50)` and `timestamp`, the
query that returns the right rows takes the lock queue down with it, and the migration that passed in
staging holds `ACCESS EXCLUSIVE` on forty million rows. Almost every one of those has a documented
single answer — in the manual, in the project wiki's *Don't Do This* page, and in the release notes
that retired the workarounds most SQL still carries.

Scope: this standard governs **how Postgres itself is used** — the physical schema, the SQL, the locks,
the mechanics of changing a schema in use. What to build a thing out of belongs to `best-practices`;
how the code reads belongs to `clean-code`; which aggregate owns which invariant belongs to
`domain-driven-design`. Where those mandate a property, the rules here name Postgres's form of it:
`best-practices` requires a parameterised query, this standard says the form is `$1` and, where an
identifier must be dynamic, `format()` with `%I` and `%L`.

## Contents

- **Postgres rules** — 123 rules in thirteen groups: identifiers and schema, types, constraints,
  queries, indexes, transactions and locking, migrations, MVCC and vacuum, diagnosis, access control,
  server-side code, and connections. Rules 1–2 gate the standard on the change touching Postgres and
  each group on the concern in its heading. Parenthesised numbers name the major release that made
  that form available.
- **Legacy Postgres and its modern replacement** — 30 forms that were correct once, each with the
  current answer and the release that introduced it. Read this before copying a pattern out of an
  older schema.
- **Depth** — worked bad/good pairs for the rules that get misread without one: a table that states
  its own rules, a query the index can serve, two workers competing for one row, and a migration that
  cannot take the table down.
- **Anti-pattern scan list** — 79 rows, coded by group (`S` schema, `Y` types, `K` constraints,
  `Q` queries, `I` indexes, `T` transactions, `M` migrations, `V` vacuum, `P` performance, `A` access,
  `F` functions and triggers, `C` connections), to work down while reviewing.

<!-- HARD-RULES:START -->
## Postgres rules

These are not aspirations. A schema, query or migration that violates one is not finished.

Rule 1 gates the standard: it governs Postgres schema, SQL and migrations. Rule 2 gates each group on
the concern named in its heading. A version in parentheses is the Postgres major release that made
that form available — if the deployed server is older, the rule is advisory until it is upgraded.

### Rules 1-2 — what applies

1. This standard governs Postgres schema, SQL and migrations, including SQL embedded in application code and schema expressed through an ORM or query builder. On a change with none of those, say so in one line and skip the rest.
2. Each group below names its concern in its heading; only groups whose concern the change touches are in play. Identifiers, types and constraints always apply to a schema change; the query rules always apply to SQL the application issues.

### Identifiers and schema layout — always applies to a schema change

3. Every identifier is `lower_snake_case` and needs no quoting. Postgres folds unquoted names to lowercase, so a `"userId"` created once must be quoted forever, by every tool, migration and hand-typed query.
4. No identifier is a reserved word — never a column named `user`, `order`, `default`, `end` or `type`.
5. Table names are consistent across the schema in number, unabbreviated, named for what a row is; a join table names both sides (`order_items`), and a column referencing another table's key is `<table_singular>_id`.
6. Constraints and indexes are named explicitly, in one documented pattern, so a later migration can validate or drop them by name without querying the catalog.
7. The cluster encoding is `UTF8`. `SQL_ASCII` is not an encoding but the absence of one, and it is unrecoverable once mixed data is in.
8. Objects live in a schema chosen deliberately; application queries are schema-qualified or run under a `search_path` set explicitly for the role, never whatever resolves first.
9. `search_path` never includes a schema an untrusted role can write to — that is how an object gets shadowed.
10. Every table, and every column whose meaning is not obvious from its name, carries a `COMMENT ON`. The schema is the one piece of documentation that cannot go out of date.
11. A view exists to serve callers, not to hide a query nobody wants to read. A materialized view records who refreshes it and how often, next to its definition.
12. Every table has a primary key. Without one a row cannot be updated safely, deduplicated, or replicated logically without configuring a replica identity.
13. Partitioning is a decision about size and lifecycle, with the partition key inside the primary key, and it is declarative (10) — never table inheritance, never rules.

### Types — always applies to a schema change

14. `text` is the default string type. `varchar(n)` costs the same, buys no speed, and turns a product decision into a migration; where a limit is a real rule, `text` with `CHECK (length(col) <= n)` states it as one.
15. Never `char(n)`. It pads with spaces to the declared width, and the padding leaks into comparisons and output.
16. Every timestamp is `timestamptz`. `timestamp` records a picture of a clock with no idea which clock, so arithmetic across zones is wrong; "we store UTC" hides that intent from the database rather than telling it. Never `timetz`, never `CURRENT_TIME`, and never `timestamp(0)` — it rounds rather than truncates, so it can store a time that has not happened. Use `date_trunc('second', …)`.
17. Money is `numeric` with an explicit scale, beside a currency column wherever more than one currency exists. Never the `money` type — locale-dependent and unable to hold a fractional cent — and never a float.
18. A surrogate key is `bigint GENERATED ALWAYS AS IDENTITY` (10). Never `serial`, whose ownership and permissions behave surprisingly, and never `integer` on a table that can grow.
19. A key generated outside the database is `uuid` from `uuidv7()` (18): time-ordered, so inserts stay at the right edge of the index. `gen_random_uuid()` (13) is random — it scatters writes across the whole index and bloats it. Store it as `uuid`, never `text` or `char(36)`.
20. Data with a known shape is columns. `jsonb` is for genuinely variable or caller-defined payloads, never a way to avoid writing a migration — and never `json`, which has no equality operator and cannot be indexed usefully.
21. An enumerated set is a lookup table with a foreign key unless the set is tiny and fixed forever: a native `enum` cannot have a value removed or reordered without rewriting the type.
22. A boolean is `boolean` — not `char(1)`, not `smallint` — and is not nullable to smuggle in a third state.
23. Arrays hold a small, ordered, wholly-owned list. Anything needing a foreign key, a unique constraint or its own lifecycle is a table. Addresses use `inet`/`cidr`/`macaddr`, spans use range types, binary uses `bytea` — never `text` holding an encoded copy.
24. Derived data is a generated column rather than a value the application must remember to maintain: `STORED` (12) when it is indexed, `VIRTUAL` (18, and now the default) when it is only read.
25. Numeric types come from the domain, not from habit: `numeric(p,s)` for exact decimals, `integer`/`bigint` for counts, `real`/`double precision` only for measurements where approximation is the correct semantics.
26. When the same constraint follows a value onto every table it appears in, it becomes a `DOMAIN` or a composite type, so the next table cannot forget it.

### Constraints are the schema's contract — always applies to a schema change

27. `NOT NULL` is the default. A nullable column is a deliberate, documented decision that the value may be genuinely unknown — never that a writer has not got round to it.
28. Every rule the data must satisfy that SQL can express is a `CHECK`. A rule enforced only in application code is a rule the next backfill, script or service will break.
29. Every foreign key names its `ON DELETE` action explicitly. Omitting it means `NO ACTION`, which is a decision nobody made.
30. Every foreign key's referencing columns are indexed. The referenced side is already unique by definition; the referencing side gets no index automatically, which turns a parent delete into a child table scan.
31. Uniqueness is a `UNIQUE` constraint. A `SELECT` that checks first does not prevent the race that follows it. Where NULLs must collide instead of being distinct, `UNIQUE NULLS NOT DISTINCT` (15) says so.
32. Uniqueness that holds only for some rows is a partial unique index — `… WHERE deleted_at IS NULL` — not a trigger.
33. "These two things may not overlap" is `EXCLUDE USING gist`, or a temporal `PRIMARY KEY`/`UNIQUE … WITHOUT OVERLAPS` (18); it is never a read followed by an insert.
34. `DEFERRABLE` is set only where a transaction genuinely must break the constraint mid-way, because a deferred failure surfaces at `COMMIT`, far from the statement that caused it. A `NOT ENFORCED` constraint (18) guarantees nothing at all — never add one to make a migration pass.
35. An invariant spanning tables that no constraint can express is enforced inside one transaction with the rows locked, never by a read followed by a hopeful write.

### Writing queries — always applies to SQL the application issues

36. Every value from outside the process is a bound parameter (`$1`). Where an identifier or literal must be assembled, `format()` with `%I` and `%L` — never `%s`, never concatenation.
37. `SELECT *` never appears in application code: it breaks on a column added, ships columns nobody reads, and forecloses an index-only scan. Name the columns, and name an `INSERT`'s target columns too.
38. Any query with `LIMIT` has a total `ORDER BY` — tie-broken on a unique column — or which rows come back is arbitrary between runs.
39. Pagination is keyset — `WHERE (created_at, id) < ($1, $2) ORDER BY created_at DESC, id DESC LIMIT n` — not `OFFSET`, which reads and discards every skipped row and shifts under concurrent writes.
40. A time range is half-open, `>= $1 AND < $2`. Never `BETWEEN` on a timestamp: its closed upper bound double-counts the boundary instant.
41. `NOT IN (SELECT …)` is banned — one NULL in the subquery makes the whole predicate return nothing, and it optimises badly. Use `NOT EXISTS`.
42. An existence test is `EXISTS`, not `COUNT(*) > 0`, which counts every match before answering a yes/no question.
43. A predicate leaves its indexed column bare — `created_at >= $1`, not `date(created_at) = $1` — unless an expression index was built for exactly that expression.
44. Types match on both sides of every comparison and join. An implicit cast between a `bigint` column and a `text` parameter silently discards the index.
45. Joins are explicit `JOIN … ON`. No comma joins, and no join predicate hidden among the filters in `WHERE`.
46. "The latest row per group" is `DISTINCT ON` or a window function — not a correlated subquery evaluated per row, and not a self-join against `max()`.
47. A lookup that needs a value from the outer row is `LATERAL`, not a subquery in the select list repeated once per column.
48. A CTE is for readability and recursion. Since 12 it is inlined, so `MATERIALIZED` is written explicitly when the fence is the point — and never written out of habit.
49. An upsert is `INSERT … ON CONFLICT (…) DO UPDATE`, whose conflict target names a real unique constraint. `MERGE` (15) is for multi-action set logic, with `merge_action()` and `RETURNING` (17) when the caller must know what happened to each row.
50. A write returns what the caller needs through `RETURNING` — including `old.*` and `new.*` (18) — rather than a second query that may see a different state.
51. Bulk work is set-based: one statement over `unnest($1::bigint[])`, a multi-row `VALUES`, or `COPY`. Never a row-at-a-time loop driven from the application.
52. A statement that could touch an unbounded number of rows is bounded — by a key range, a `LIMIT`ed sub-select, or explicit batching — so one call cannot lock the whole table.
53. `count(*)` on a large table is a sequential scan: use it knowing that, and use `pg_class.reltuples` or a maintained counter where an estimate will do. `ORDER BY random()` sorts the entire table; sample with `TABLESAMPLE` or a probe into the key space.
54. Deleting or updating "everything older than X" runs in bounded batches, each committing, never as one statement across months of data.
55. Nothing relies on row order without `ORDER BY`, on the locale's collation for a comparison that must be stable, or on `now()` as the wall clock — it is the transaction's start time, and `clock_timestamp()` is the clock.

### Indexes — the concern is read performance and the writes that pay for it

56. Indexes come from the plans the workload actually produces, not from intuition and not from indexing every column in case. Each one is paid for on every insert, update and delete of its columns.
57. A composite index puts equality columns first, then the range or sort column. Skip scan (18) makes the wrong order less catastrophic; it does not make it right.
58. An index on a prefix of an existing composite index is redundant — `(a)` is served by `(a, b)`. Drop it.
59. `INCLUDE` (11) carries the columns a query returns but never filters on, buying an index-only scan without widening the key.
60. An index serving only some rows is partial — `WHERE status = 'active'` — which is smaller, cheaper to maintain, and likelier to be chosen.
61. Match the index type to the access: `GIN` for `jsonb` containment and array membership, `pg_trgm` for substring and fuzzy matching, a stored-and-indexed `tsvector` for full text rather than one computed per query, `BRIN` for naturally ordered append-only columns on a huge table.
62. On a table already in use, an index is built with `CREATE INDEX CONCURRENTLY`, which cannot run inside a transaction block and therefore lives in its own migration.
63. A failed `CONCURRENTLY` build leaves an `INVALID` index that answers no query and still taxes every write; the migration checks for one and drops it or runs `REINDEX … CONCURRENTLY` (12). Rebuilds are `REINDEX … CONCURRENTLY` too, never `DROP` then `CREATE`.
64. Unused indexes are found in `pg_stat_user_indexes` — `idx_scan` still zero across a full business cycle — and dropped. Duplicate and unused indexes are pure write tax.
65. To add uniqueness to a live table, build the unique index `CONCURRENTLY` and then attach it with `ALTER TABLE … ADD CONSTRAINT … USING INDEX`.
66. After a bulk load or a large migration, `ANALYZE` the table. The planner cannot choose well from statistics describing the table as it used to be.
67. Correlated predicates the planner misestimates get `CREATE STATISTICS` (10; on expressions, 14). Postgres has no query hints, and a plan is not argued with — it is informed.

### Transactions and locking — the concern is concurrency and contention

68. A transaction opens as late as it can, contains no HTTP call, no queue publish, no user interaction and no sleep, and commits as soon as its invariant is safe.
69. The isolation level is chosen deliberately. `READ COMMITTED`, the default, gives no stable snapshot across statements; `REPEATABLE READ` gives one; `SERIALIZABLE` is the only level that makes a concurrent read-modify-write correct without explicit locks.
70. Every transaction at `REPEATABLE READ` or `SERIALIZABLE` sits inside a retry loop for SQLSTATE `40001`, re-running the whole transaction from the beginning with backoff. The manual requires it: without the loop, raising the isolation level manufactures failures instead of preventing them.
71. A transaction that only reads is declared `READ ONLY` — under `SERIALIZABLE` it can often take no predicate locks at all, and it can never need retrying.
72. A read-modify-write at `READ COMMITTED` either locks the row it will write with `SELECT … FOR UPDATE`, or carries a version predicate (`WHERE … AND version = $2`) and checks the affected row count. A bare read then write is a lost update.
73. Rows are locked in one consistent order — primary key ascending — everywhere in the system. Two transactions taking the same pair in opposite orders is a deadlock waiting for load.
74. A queue in a table claims work with `SELECT … FOR UPDATE SKIP LOCKED LIMIT n`, so concurrent workers neither block each other nor take the same row.
75. `LISTEN`/`NOTIFY` is a wake-up hint, never delivery: it is not durable, not replayed on reconnect, and dropped when nothing is listening. The durable record is the row.
76. Advisory locks are declared in one documented place with their scope, and the transaction-scoped form (`pg_advisory_xact_lock`) is preferred because a session lock can outlive the work on a pooled connection.
77. Every role has `statement_timeout`, `lock_timeout` and `idle_in_transaction_session_timeout` configured, plus `transaction_timeout` (17) where a whole transaction must be bounded. These are role settings, not something each query remembers.
78. Inside a transaction, settings are changed with `SET LOCAL`, so a timeout or a `search_path` cannot leak to the next transaction that borrows the connection.
79. Long-running reads and long-idle transactions are hunted down: the oldest snapshot in the cluster bounds what vacuum can reclaim in every database, so one forgotten session bloats everything.
80. A `SAVEPOINT` per row inside a loop is not error handling. Each one is a subtransaction, and enough of them degrade the whole cluster; handle the failure in the application and retry the statement.

### Migrations — the concern is changing a schema that is in use

81. Every schema change is a checked-in migration, applied by the same tool in every environment. Nothing is changed by hand in a console, ever.
82. A migration is written so the currently deployed application survives it — expand then contract, which `best-practices` mandates. What follows is Postgres's part: which lock each step takes, and how not to hold it.
83. Any migration taking a table-level lock sets a short `lock_timeout` and is retried on timeout. A queued `ACCESS EXCLUSIVE` request blocks every later query on that table, including the ones it would not have conflicted with, so waiting indefinitely for it takes the table down.
84. One lock-heavy operation per migration, and `ALTER TABLE` subcommands needing the same lock are combined into a single statement so the table is locked once.
85. `CREATE INDEX CONCURRENTLY`, `DROP INDEX CONCURRENTLY` and `REINDEX CONCURRENTLY` cannot run in a transaction block, so their migration disables the automatic wrapper — and is therefore written to be safely re-runnable.
86. A foreign key or `CHECK` is added `NOT VALID`, then validated by a separate `VALIDATE CONSTRAINT`, which takes a weaker lock and lets writes continue while it scans.
87. `SET NOT NULL` scans the whole table under `ACCESS EXCLUSIVE`. Add `CHECK (col IS NOT NULL) NOT VALID`, validate it, then `SET NOT NULL`, which skips the scan (12); or add the constraint as `NOT NULL … NOT VALID` and validate that (18).
88. Adding a column with a constant default is metadata-only (11), but a volatile default such as `now()` or `gen_random_uuid()` still rewrites the table. Add the column, set the default, then backfill.
89. Never rename or drop a column, table or enum value the deployed application still refers to. Add the new one, move reads then writes, then remove the old one in a later release.
90. Changing a column's type rewrites the table and blocks reads and writes. Add a new column, dual-write, backfill, move reads, then drop the old column.
91. Adding a `STORED` generated column rewrites the table; a `VIRTUAL` one (18) does not.
92. Backfills run in bounded batches, each in its own transaction, driven by a key-range cursor and under a `statement_timeout` — never one `UPDATE` over the whole table.
93. `VACUUM FULL` and `CLUSTER` take `ACCESS EXCLUSIVE` and rewrite the table; neither belongs in a migration against a live system. Use `pg_repack`, or rotate partitions.
94. Old data is removed by dropping a partition, not by a mass `DELETE`; a partition is detached with `DETACH PARTITION … CONCURRENTLY` (14).
95. Every migration is rehearsed against a copy with production-like volume, and how to get back is written down before it runs.

### MVCC, vacuum and bloat — the concern is a table that is updated or deleted from

96. An `UPDATE` writes a new row version and leaves the old one dead, and a `DELETE` frees nothing until vacuum runs. A hot table is one whose vacuum must keep pace with its write rate.
97. Autovacuum is never turned off. Where the defaults cannot keep up, it is tuned per table — `autovacuum_vacuum_scale_factor`, the cost limits — and that setting is committed with the schema.
98. An update touching no indexed column can be a HOT update and skip the index writes entirely. That is bought by keeping volatile counters out of indexes and lowering `fillfactor` on hot tables.
99. Wide, rarely-read values live in TOAST and cost an extra read; putting a large `jsonb` or `text` beside hot columns is a decision to make deliberately, not to discover.
100. Bloat and transaction-ID age are monitored rather than discovered: `n_dead_tup` and `last_autovacuum` in `pg_stat_user_tables`, and `age(datfrozenxid)` against the wraparound horizon.

### Diagnosis and performance — the concern is a slow or heavy query

101. A performance claim is an `EXPLAIN (ANALYZE, BUFFERS)` against production-like volume — buffers are included by default from 18 — never a guess, and never a plan from an empty table.
102. The plan is read for the gap between estimated and actual rows first. A bad row estimate is usually the cause; the strange-looking node is usually the symptom.
103. `pg_stat_statements` is installed and the query to fix is chosen by total time, not by whoever complained. `log_min_duration_statement` and `auto_explain` are configured so a slow statement leaves evidence instead of a memory.
104. Measurement uses real parameter values. The plan for a generic parameter can differ from the plan for the value that actually hurts.
105. Server settings and indexes are exhausted before SQL is contorted, and any rewrite keeps a test proving it still returns the same rows.

### Access control — the concern is who can reach the data

106. The application connects as a role that owns nothing and is not a superuser, holding only the privileges it uses. Migrations run as a separate, more privileged role.
107. Privileges are granted to roles and roles are granted to users, never privileges to individuals. `ALTER DEFAULT PRIVILEGES` is set so the next table created is not accidentally world-readable.
108. `CREATE` on the `public` schema is revoked — the default since 15 — and no application role can create objects in a schema another role trusts.
109. Where row-level security is used it is enabled with `FORCE ROW LEVEL SECURITY` as well, or the table's owner quietly bypasses the policy protecting it.
110. A view over restricted data is created `WITH (security_invoker = true)` (15) unless lending the owner's privileges is precisely its purpose.
111. A `SECURITY DEFINER` function pins `SET search_path` with `pg_temp` last, and has `EXECUTE` revoked from `PUBLIC` and granted explicitly. Without both, a temporary object can hijack it.
112. Authentication is `scram-sha-256` — `md5` is deprecated and warns from 18 — `trust` is never configured over TCP/IP, and connections require TLS.
113. Data classified as sensitive is not selectable by the general application role: column privileges, a separate schema and role, or encryption whose key lives outside the database.

### Server-side code — the concern is functions, triggers and extensions

114. Business rules live in the application. A trigger does the data-integrity job the database is uniquely placed to do — an audit row, a `tsvector`, an `updated_at` — and is documented where the table is defined, because it is a side effect no caller can see.
115. A trigger performs no external IO and never depends on the order in which other triggers fire.
116. Never `RULE`, whose rewrite semantics defeat everyone, and never table inheritance: a trigger and declarative partitioning are the supported answers.
117. Every function declares its true volatility. A wrong `IMMUTABLE` returns wrong answers from an index built on it; a lazy `VOLATILE` blocks inlining and index use.
118. Extensions come from the distribution, are created `IF NOT EXISTS` into a named schema by a migration, and are version-pinned like any other dependency. `uuid-ossp` and `hstore` are legacy — `uuidv7()` and `jsonb` replace them.
119. Tests run against a real Postgres of the major version that is deployed. Not SQLite, not an in-memory double: the constraints, types, collations and locks under test are Postgres's.

### Connections — the concern is how the application reaches the server

120. Connections come from a pool sized to what the server can hold, not to the application's concurrency. `max_connections` is a hard limit and every backend costs memory.
121. Under transaction-mode pooling, nothing may depend on session state: no `SET` (use `SET LOCAL`), no session-scoped advisory lock, no `LISTEN`, no `WITH HOLD` cursor, no session temporary table. Protocol-level prepared statements work only with the pooler configured for them (`max_prepared_statements`).
122. Every connection sets `application_name`, so `pg_stat_activity` names the culprit instead of showing an anonymous backend.
123. A retry after a connection error re-runs only work that is idempotent or keyed, because a lost connection does not prove the transaction did not commit.
<!-- HARD-RULES:END -->

## Legacy Postgres and its modern replacement

Every left-hand column was correct once, or is still repeated in tutorials. Each is now a signal that
the schema — or the habit that wrote it — predates the release in the third column.

| Concern | Legacy form | Modern Postgres |
| --- | --- | --- |
| Auto-increment key | `serial`, `bigserial` | `bigint GENERATED ALWAYS AS IDENTITY` (10) |
| Externally generated key | `uuid_generate_v4()`, `gen_random_uuid()` | `uuidv7()` (18) — time-ordered, index-friendly |
| UUID support | the `uuid-ossp` extension | core `gen_random_uuid()` (13), `uuidv7()` (18) |
| Bounded string | `varchar(255)` | `text` with `CHECK (length(col) <= n)` |
| Fixed-width code | `char(n)` | `text` with a length `CHECK` |
| Point in time | `timestamp`, UTC by convention | `timestamptz` |
| Money | `money`, `double precision` | `numeric(p,s)` plus a currency column |
| Semi-structured data | `json`, `hstore`, an EAV table | `jsonb` |
| Derived value | a column the application maintains | generated column: `STORED` (12), `VIRTUAL` (18) |
| Upsert | `SELECT` then `INSERT` or `UPDATE` | `INSERT … ON CONFLICT DO UPDATE` |
| Set-shaped write | a PL/pgSQL loop of `INSERT`/`UPDATE`/`DELETE` | `MERGE` (15), with `merge_action()` and `RETURNING` (17) |
| Claiming queue work | `FOR UPDATE` and contend, or `NOTIFY` as delivery | `FOR UPDATE SKIP LOCKED` |
| Pagination | `LIMIT n OFFSET m` | a keyset predicate on the sort key |
| Anti-join | `NOT IN (SELECT …)` | `NOT EXISTS (SELECT …)` |
| Latest row per group | self-join against `max()` | `DISTINCT ON`, or a window function |
| Optimisation fence | a `WITH` relied on to materialise | explicit `MATERIALIZED` (12) |
| Covering a query | widening the index key | `INCLUDE` non-key columns (11) |
| Index rebuild | `DROP INDEX` then `CREATE INDEX` | `REINDEX … CONCURRENTLY` (12) |
| Adding `NOT NULL` | `ALTER COLUMN … SET NOT NULL` | validated `CHECK` then `SET NOT NULL` (12); or `NOT NULL … NOT VALID` then `VALIDATE` (18) |
| Adding a column with a default | add the column, then `UPDATE` every row | a constant default is metadata-only (11) |
| Overlap rule | check in the application, then insert | `EXCLUDE USING gist`; `… WITHOUT OVERLAPS` (18) |
| Unique where NULLs must collide | a sentinel value, or a second partial index | `UNIQUE NULLS NOT DISTINCT` (15) |
| Partitioning | table inheritance plus rules or triggers | declarative partitioning (10); `DETACH … CONCURRENTLY` (14) |
| Case-insensitive text | `lower(col)` at every call site, `citext` | a nondeterministic ICU collation (12); `casefold()` (18) |
| Restricting a view's reach | a `SECURITY DEFINER` wrapper function | `security_invoker` view (15) |
| Password authentication | `md5` | `scram-sha-256` (10); `md5` deprecated (18) |
| Random integer in a range | `floor(random() * (hi - lo + 1)) + lo` | `random(lo, hi)` (17) |
| JSON into rows | nested `jsonb_each` and lateral gymnastics | `JSON_TABLE` (17) |
| Bulk insert | one `INSERT` per row from the application | multi-row `VALUES`, `unnest($1::type[])`, or `COPY` |
| Plan IO accounting | `EXPLAIN (ANALYZE, BUFFERS)` | buffers included by default (18) |

## Depth

### Rules 14-24, 27-33 — a table that states its own rules

```text
Bad
  CREATE TABLE orders (
      id           serial PRIMARY KEY,                  -- serial, and 32-bit (18)
      customer_id  integer,                             -- nullable, no foreign key, no index (29, 30)
      email        varchar(255),                        -- an arbitrary limit, now a migration (14)
      status       varchar(20),                         -- any string whatsoever is accepted (28)
      total        float,                                -- an amount as a float (17)
      currency     char(3),                             -- space-padded (15)
      meta         json,                                -- no equality operator, no index (20)
      created_at   timestamp DEFAULT now()              -- a clock picture, and nullable (16, 27)
  );

Good
  CREATE TABLE orders (
      id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,             -- (18)
      customer_id  bigint NOT NULL REFERENCES customers (id) ON DELETE RESTRICT, -- (29)
      email        text   NOT NULL CHECK (length(email) <= 320),                -- (14, 27)
      status       text   NOT NULL REFERENCES order_statuses (status),          -- a lookup table (21)
      total        numeric(12,2) NOT NULL CHECK (total >= 0),                   -- (17)
      currency     text   NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),             -- (15, 17)
      meta         jsonb  NOT NULL DEFAULT '{}',                                -- (20)
      created_at   timestamptz NOT NULL DEFAULT now(),                          -- (16)
      shipped_at   timestamptz,                                                 -- nullable by decision (27)
      CONSTRAINT orders_shipped_after_created
          CHECK (shipped_at IS NULL OR shipped_at >= created_at)                -- (28)
  );
  CREATE INDEX orders_customer_id_idx ON orders (customer_id);   -- a foreign key gets none for free (30)
  COMMENT ON COLUMN orders.total IS 'Order total, in the currency named by orders.currency.';   -- (10)
```

Every rule in the good column is enforced by the server, so no script, backfill or second service can
break it. In the bad column the same rules exist only in whichever code happens to write the row, and
each one is a defect waiting for a second writer.

### Rules 38-44, 57-59 — a query the index can serve

```text
Bad
  SELECT * FROM events                                 -- every column, so no index-only scan (37)
   WHERE date(created_at) = $1                         -- the index on created_at cannot be used (43)
     AND tenant_id = $2::text                          -- bigint column, text parameter (44)
   ORDER BY created_at DESC
   LIMIT 20 OFFSET 40000;                              -- reads 40 020 rows to return 20 (39)

Good
  -- CREATE INDEX CONCURRENTLY ON events (tenant_id, created_at DESC, id DESC) INCLUDE (kind);
  SELECT id, created_at, kind FROM events              -- named columns, covered by INCLUDE (37, 59)
   WHERE tenant_id = $1                                -- equality column first (57)
     AND created_at >= $2 AND created_at < $3          -- half-open and sargable (40, 43)
     AND (created_at, id) < ($4, $5)                   -- the cursor from the previous page (39)
   ORDER BY created_at DESC, id DESC                   -- total order, and the index's order (38)
   LIMIT 20;
```

Page two thousand costs what page one costs: the index descends straight to the cursor and reads
twenty entries. The `OFFSET` version also skips rows inserted since the first page was served.

### Rules 68-74 — two workers, one row

```text
Bad
  ids = SELECT id FROM jobs WHERE state = 'ready' LIMIT 10;   -- nothing is locked (72)
  UPDATE jobs SET state = 'running' WHERE id = ANY(ids);      -- two workers claim the same job

Good
  BEGIN;
    SELECT id, payload FROM jobs
     WHERE state = 'ready' AND run_after <= now()
     ORDER BY run_after, id                                   -- one consistent lock order (73)
     FOR UPDATE SKIP LOCKED                                   -- contenders take other rows (74)
     LIMIT 10;
    UPDATE jobs SET state = 'running', attempts = attempts + 1
     WHERE id = ANY($1);
  COMMIT;
  -- the job itself runs here, outside the transaction (68)
```

`SKIP LOCKED` is what makes the claim scale: contending workers neither block nor collide. The work
runs after `COMMIT`, so no HTTP call is ever inside the transaction. At `SERIALIZABLE` the row lock
would be unnecessary — but then every caller needs the `40001` retry loop (70).

### Rules 83-88 — a migration that cannot take the table down

```text
Bad
  ALTER TABLE orders ADD CONSTRAINT orders_customer_fk
      FOREIGN KEY (customer_id) REFERENCES customers (id);          -- scans and blocks writes (86)
  CREATE INDEX idx_orders_status ON orders (status);                -- blocks writes for the build (62)
  ALTER TABLE orders ALTER COLUMN shipped_at SET NOT NULL;          -- full scan under ACCESS EXCLUSIVE (87)

Good
  -- migration 1: metadata only, one lock, held for milliseconds
  SET lock_timeout = '3s';                                          -- the runner retries on timeout (83)
  ALTER TABLE orders
      ADD COLUMN status text NOT NULL DEFAULT 'new',                -- constant default, no rewrite (88)
      ADD CONSTRAINT orders_customer_fk FOREIGN KEY (customer_id)
          REFERENCES customers (id) NOT VALID,                      -- validated later (86)
      ADD CONSTRAINT orders_shipped_at_nn
          CHECK (shipped_at IS NOT NULL) NOT VALID;                 -- one statement, one lock (84)

  -- migration 2: no transaction wrapper, individually re-runnable (85)
  CREATE INDEX CONCURRENTLY idx_orders_status ON orders (status);

  -- migration 3: the scans, under a lock writes tolerate
  ALTER TABLE orders VALIDATE CONSTRAINT orders_customer_fk;        -- SHARE UPDATE EXCLUSIVE (86)
  ALTER TABLE orders VALIDATE CONSTRAINT orders_shipped_at_nn;
  ALTER TABLE orders ALTER COLUMN shipped_at SET NOT NULL;          -- 12 skips the scan (87)
```

Both columns do the same work. The difference is that every scan in the good one runs under
`SHARE UPDATE EXCLUSIVE`, which concurrent writes tolerate, and no statement holds a strong lock long
enough for a queue to form behind it.

## Anti-pattern scan list

Work down this list while reviewing Postgres. Each row cites the rule that settles it.

| Code | Anti-pattern | Rule |
| --- | --- | --- |
| S1 | A quoted mixed-case identifier, or one that is a reserved word | 3, 4 |
| S2 | Abbreviated or inconsistently pluralised table names, or a reference column not named `<table>_id` | 5 |
| S3 | A constraint or index left with no deliberate name | 6 |
| S4 | `SQL_ASCII` encoding, or objects landing in whatever `search_path` resolves first | 7, 8 |
| S5 | `search_path` including a schema an untrusted role can write to | 9 |
| S6 | A table or non-obvious column with no `COMMENT ON`, or a materialized view with no stated refresh owner | 10, 11 |
| S7 | A table with no primary key, or partitioning by inheritance | 12, 13 |
| Y1 | `varchar(n)` as the default string type, or `char(n)` at all | 14, 15 |
| Y2 | `timestamp`, `timetz`, `CURRENT_TIME`, or `timestamp(0)` | 16 |
| Y3 | `money` or a float for an amount, or an amount with no currency beside it | 17 |
| Y4 | `serial`, or an `integer` surrogate key on a growing table | 18 |
| Y5 | `gen_random_uuid()` for a new primary key, or a UUID stored as `text` | 19 |
| Y6 | `json` rather than `jsonb`, or `jsonb` holding a shape the schema already knows | 20 |
| Y7 | A native `enum` for a set that will change, a boolean as `char(1)`, or a nullable boolean meaning three things | 21, 22 |
| Y8 | An array where a table belongs, an address or span kept as `text`, or a derived value the application maintains | 23, 24 |
| K1 | A column nullable by default rather than by decision | 27 |
| K2 | A rule enforced only in application code that SQL could express as a `CHECK` | 28 |
| K3 | A foreign key with no explicit `ON DELETE`, or with no index on the referencing columns | 29, 30 |
| K4 | Uniqueness checked by a `SELECT` first, or a conditional uniqueness enforced by a trigger | 31, 32 |
| K5 | An overlap rule checked in the application | 33 |
| K6 | `DEFERRABLE` used casually, a `NOT ENFORCED` constraint, or a cross-table invariant with no locking | 34, 35 |
| Q1 | A value interpolated into SQL, or dynamic SQL built with `%s` instead of `%I`/`%L` | 36 |
| Q2 | `SELECT *` in application code, or an `INSERT` with no column list | 37 |
| Q3 | `LIMIT` with no total `ORDER BY`, or `OFFSET` pagination | 38, 39 |
| Q4 | `BETWEEN` on timestamps, or `NOT IN (SELECT …)` | 40, 41 |
| Q5 | `COUNT(*) > 0` as an existence test | 42 |
| Q6 | A function wrapped round an indexed column, or a cast between the column's type and the parameter's | 43, 44 |
| Q7 | A comma join, a join predicate hidden in `WHERE`, or a correlated subquery where `DISTINCT ON` or `LATERAL` belongs | 45, 46, 47 |
| Q8 | A CTE relied on as an optimisation fence with no `MATERIALIZED` | 48 |
| Q9 | A read-then-write upsert, or a second query where `RETURNING` would do | 49, 50 |
| Q10 | Row-at-a-time writes from the application, or a statement with no bound on the rows it can touch | 51, 52 |
| Q11 | `count(*)` on a large table where an estimate would do, `ORDER BY random()`, or an unbatched bulk delete | 53, 54 |
| Q12 | Reliance on row order with no `ORDER BY`, or on `now()` as the wall clock | 55 |
| I1 | Indexes added speculatively, or a composite index ordered range-column-first | 56, 57 |
| I2 | An index that is a prefix of another, or a duplicate | 58, 64 |
| I3 | A widened index key where `INCLUDE` would serve, or a full index where a partial one would | 59, 60 |
| I4 | A btree for `jsonb` containment or substring search, or a `tsvector` computed per query | 61 |
| I5 | `CREATE INDEX` without `CONCURRENTLY` on a live table | 62 |
| I6 | An `INVALID` index left behind, or a rebuild done by `DROP` and `CREATE` | 63 |
| I7 | Uniqueness added to a live table without building the index first, no `ANALYZE` after a bulk load, or a misestimate met with query contortion instead of `CREATE STATISTICS` | 65, 66, 67 |
| T1 | An HTTP call, a publish, a sleep or user interaction inside a transaction | 68 |
| T2 | An isolation level inherited by accident, or `REPEATABLE READ`/`SERIALIZABLE` with no `40001` retry loop | 69, 70 |
| T3 | A read-only transaction not declared `READ ONLY` | 71 |
| T4 | A read-modify-write with no row lock and no version predicate | 72 |
| T5 | Rows locked in different orders in different code paths | 73 |
| T6 | A queue claim without `SKIP LOCKED`, or `NOTIFY` treated as delivery | 74, 75 |
| T7 | A session-scoped advisory lock on a pooled connection, or a role with no `statement_timeout`, `lock_timeout` or `idle_in_transaction_session_timeout` | 76, 77 |
| T8 | `SET` where `SET LOCAL` belongs, a long-idle transaction, or a `SAVEPOINT` per row | 78, 79, 80 |
| M1 | A schema change made by hand, or one the deployed application cannot survive | 81, 82 |
| M2 | A lock-taking migration with no `lock_timeout` and no retry | 83 |
| M3 | Several lock-heavy operations in one migration, or separate `ALTER TABLE` statements that could share a lock | 84 |
| M4 | A `CONCURRENTLY` statement inside a transaction block, or such a migration that cannot be re-run | 85 |
| M5 | A foreign key or `CHECK` added and validated in one step | 86 |
| M6 | A bare `SET NOT NULL`, or a volatile default added to an existing column | 87, 88 |
| M7 | A column, table or enum value renamed or dropped while in use, or a type changed in place | 89, 90 |
| M8 | A `STORED` generated column added to a large table, or a backfill as one unbounded `UPDATE` | 91, 92 |
| M9 | `VACUUM FULL` or `CLUSTER` in a migration, or old data removed by mass `DELETE` instead of dropping a partition | 93, 94 |
| M10 | A migration never rehearsed at production volume, or with no written way back | 95 |
| V1 | A hot-updated table whose vacuum cannot keep up, or autovacuum disabled | 96, 97 |
| V2 | A frequently updated column carried in an index, or a hot table left at the default `fillfactor` | 98 |
| V3 | Large `jsonb` or `text` sitting beside hot columns with no thought given to TOAST | 99 |
| V4 | Bloat or transaction-ID age discovered from an incident rather than monitoring | 100 |
| P1 | A performance claim with no `EXPLAIN (ANALYZE, BUFFERS)`, or a plan taken from an empty table | 101 |
| P2 | A plan read node-by-node without checking estimated against actual rows | 102 |
| P3 | No `pg_stat_statements`, or the query to optimise chosen by anecdote | 103 |
| P4 | A plan measured with an unrepresentative parameter, or SQL contorted before settings and indexes were tried | 104, 105 |
| A1 | The application connecting as superuser or as the schema owner, or migrations sharing that role | 106 |
| A2 | Privileges granted to individuals, or no `ALTER DEFAULT PRIVILEGES` | 107 |
| A3 | `CREATE` still granted on `public` | 108 |
| A4 | Row-level security without `FORCE`, or a view over restricted data with no `security_invoker` | 109, 110 |
| A5 | `SECURITY DEFINER` with no pinned `search_path`, or still executable by `PUBLIC` | 111 |
| A6 | `md5` or `trust` authentication, no TLS, or sensitive columns readable by the general role | 112, 113 |
| F1 | A business rule implemented in a trigger, or a trigger undocumented at its table | 114 |
| F2 | A trigger doing external IO or depending on firing order | 115 |
| F3 | A `RULE`, table inheritance, or a function whose declared volatility is wrong | 116, 117 |
| F4 | An unpinned extension, `uuid-ossp` or `hstore` in new work, or tests run against anything but real Postgres | 118, 119 |
| C1 | A pool sized to application concurrency, or no pool at all | 120 |
| C2 | Session state relied on under transaction pooling, or prepared statements with the pooler unconfigured | 121 |
| C3 | Connections with no `application_name`, or a non-idempotent statement retried after a connection error | 122, 123 |
