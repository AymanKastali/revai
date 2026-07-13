---
name: safe-schema-changes
description: Use when writing a database migration or altering a schema — enforces backward-compatible expand→contract changes, reversible migrations, and avoiding destructive operations or long table locks in the same deploy as the code that depends on them.
---

# Safe schema changes

A migration runs against a live database while old and new code may both be running. A change that
looks fine locally can drop data or lock a busy table in production. Follow expand→contract so every
deploy is safe to roll back.

## The core rule: expand, then contract

Never change a column's meaning in one step. Split any rename, type change, or removal across
separate deploys so that at every moment the running code matches the schema.

**Renaming `full_name` → `name`:**
1. **Expand** — add the new `name` column (nullable). Deploy.
2. **Backfill** — copy `full_name` → `name` in batches. Start writing both columns.
3. **Migrate reads** — deploy code that reads `name`.
4. **Contract** — once nothing reads `full_name`, drop it. Deploy.

Each step is independently deployable and reversible. Collapsing them risks the old code hitting a
column that no longer exists.

## Rules

- **Additions are safe; removals and renames are not.** Adding a nullable or defaulted column, a new
  table, or a new index is backward-compatible. Dropping or renaming a column/table is a contract
  step — do it only after all code that referenced it is gone.
- **New non-null column needs a default or a backfill** — otherwise the insert of existing rows
  fails. Add nullable → backfill → add the NOT NULL constraint in a later step.
- **Every migration is reversible.** Write the `down`/rollback, or explicitly document why it's
  irreversible and get sign-off. A deploy you can't roll back is a deploy you can't trust.
- **Don't lock large tables.** Adding a column with a volatile default, or an index without a
  concurrent/online option, can hold a write lock for the whole table. Use the engine's online/
  concurrent index build; backfill in bounded batches with pauses, not one giant `UPDATE`.
- **Separate schema change from data change from code change** across deploys when a table is large
  or hot. Small, low-traffic tables can combine steps — use judgment, but default to splitting.
- **Guard destructive ops.** A `DROP`/`TRUNCATE`/type-narrowing migration should be reviewed as
  deliberately destructive, never bundled silently into a feature migration.

## Checklist

- [ ] Change is additive, OR it's the final contract step after readers are gone
- [ ] New NOT NULL column has a default or a backfill-then-constrain sequence
- [ ] Migration has a working rollback (or a documented, approved reason it can't)
- [ ] Index built online/concurrently; backfills run in bounded batches
- [ ] No rename/drop in the same deploy as the code that stops using it
- [ ] Destructive statements are called out explicitly for review

## Example

**Bad** — one migration renames and the old code breaks the instant it deploys:
```sql
ALTER TABLE users RENAME COLUMN full_name TO name;   -- old pods still SELECT full_name → errors
```

**Good** — expand now, contract in a later deploy:
```sql
-- deploy 1 (expand)
ALTER TABLE users ADD COLUMN name text;               -- nullable, backward-compatible
-- deploy 1 background job: UPDATE ... SET name = full_name WHERE name IS NULL  (batched)
-- deploy 2 (after code reads `name`): ALTER TABLE users DROP COLUMN full_name;
```
