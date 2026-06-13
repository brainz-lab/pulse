# Incident Diagnosis: `ActiveRecord::RecordNotUnique` on trace ingestion

> **STATUS: UNVERIFIED — needs DB/deploy confirmation.**
> This is a **diagnosis-only** document. No code change is shipped, because the
> Observability/Pulse production database has **no read-only credential available**
> to the incident responder (vault exposes `*-db-ro` creds only for the customer
> apps — `amplifica, bite, browq, doiteveryday, nexus, propi, sinfiltro, sondea,
> synapse` — there is no `pulse-db-ro` / `observability-db-ro`). The exact fix
> depends on the *live* unique-index definition, which the repo cannot tell us
> unambiguously (see "Schema divergence" below). A human with DB/console access
> must confirm before the fix is applied.

## Incident

- **Source:** reflex (Observability) — error group
  `98d2be48-8538-4088-8dd5-876ceaacd1f4`, fingerprint `542c58c0657e45be`
- **Error:** `ActiveRecord::RecordNotUnique`
- **Message:** `PG::UniqueViolation: ERROR: duplicate key value violates unique
  constraint "index_traces_on_trac..."` (truncated — the index is
  `index_traces_on_trace_id` on the `traces` table)
- **Occurred:** 2026-06-13 08:13:28 UTC, environment `production`
- **Owning service:** `brainz-lab/pulse` (APM). The `traces` table and the
  `index_traces_on_trace_id` unique index live here.

## Most likely root cause (high confidence): non-idempotent trace ingestion

Pulse ingests traces through two paths, and **neither handles a duplicate
`trace_id` at the database level**:

### 1. Batch path — `POST /api/v1/traces/batch`
`TraceProcessor.process_batch!` (`app/services/trace_processor.rb`):

- Pre-fetches existing traces with `project.traces.where(trace_id: trace_ids)`
  and indexes them **by `trace_id` only** (line 17).
- Builds records for the not-yet-seen `trace_id`s and inserts them with a
  **raw SQL `INSERT INTO traces (...) VALUES (...)` that has no `ON CONFLICT`
  clause** (`bulk_insert_traces`, lines 99-113).

This raises `PG::UniqueViolation` whenever the same trace key is inserted twice:

- **Concurrent batches** carrying the same trace (SDK at-least-once delivery /
  retry, or two web workers) both read "not present", both `INSERT` → the second
  violates the unique index. Classic check-then-insert (TOCTOU) race.
- **Duplicates within a single batch payload:** the dedup map is keyed by DB
  rows only, so two payloads with the same key in one request both land in
  `new_trace_records` and the single multi-row `INSERT` fails outright.

### 2. Single path — `POST /api/v1/traces`
`TraceProcessor#find_or_create_trace` does `find_by(trace_id:)` then
`create_trace!` (lines 169-173). The model's `validates :trace_id, uniqueness`
(`app/models/trace.rb:12`) is an application-level check with the same race
window, and it cannot prevent a true concurrent insert — under load the loser
still raises `RecordNotUnique`.

There is **no `rescue ActiveRecord::RecordNotUnique`, no `ON CONFLICT`, no
`upsert`/`insert_all`, and no in-batch dedup** anywhere in the ingestion code
(verified by grep).

## Schema divergence — why this is diagnosis-only, not a blind fix

The correct `ON CONFLICT` target for an idempotent insert **must match the real
unique index**, and the repo gives two contradictory answers:

| Source | Definition of `index_traces_on_trace_id` |
|---|---|
| `db/schema.rb:217` | `t.index ["trace_id"], unique: true` → **on `(trace_id)`** |
| `db/structure.sql:1456` | `CREATE UNIQUE INDEX ... ON public.traces USING btree (trace_id, started_at)` → **on `(trace_id, started_at)`** |
| migration `20251223200000_convert_tables_to_hypertables.rb:13-15` | drops the old index and recreates it as **`(trace_id, started_at)`** |

The migration history and `structure.sql` agree the live index is the
**composite `(trace_id, started_at)`** — TimescaleDB requires the partitioning
column (`started_at`) in any unique index on a hypertable. `schema.rb` appears
**stale/misleading** (the Rails dumper can't faithfully represent the raw-SQL
composite index).

**This is exactly why DB confirmation is required before fixing.** A natural-
looking fix —

```ruby
INSERT INTO traces (...) VALUES (...) ON CONFLICT (trace_id) DO NOTHING
```

— would itself raise `PG 42P10: there is no unique or exclusion constraint
matching the ON CONFLICT specification` against the live composite index, i.e. a
plausible-but-wrong fix. The conflict target is `(trace_id, started_at)` **iff**
the live index is the composite one.

## Commands a human should run to confirm (needs DB / Kamal access)

```sql
-- 1. The authoritative live index definition (settles the divergence):
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'traces' AND indexname = 'index_traces_on_trace_id';
-- Expect: CREATE UNIQUE INDEX ... ON traces USING btree (trace_id, started_at)

-- 2. Confirm duplicate keys are actually being attempted (recent window):
SELECT trace_id, started_at, count(*)
FROM traces
GROUP BY trace_id, started_at
HAVING count(*) > 1
LIMIT 20;   -- should be empty (index blocks them); the INSERTs that *would*
            -- create these are what raise the error.
```

Or via console (see CLAUDE.md → "Kamal Production Access"):

```bash
kamal app exec -p --reuse -e SECRET_KEY_BASE:<master_key> \
  'bin/rails runner "puts ActiveRecord::Base.connection.execute(%q{SELECT indexdef FROM pg_indexes WHERE indexname=\\'index_traces_on_trace_id\\'}).to_a.inspect"'
```

## Proposed fix (apply only after the index is confirmed) — UNVERIFIED

Make both ingestion paths idempotent, using the **confirmed** conflict target.
Assuming the composite index `(trace_id, started_at)` is confirmed:

1. **Batch raw insert** (`bulk_insert_traces`): append
   `ON CONFLICT (trace_id, started_at) DO NOTHING` to the generated `INSERT`.
2. **De-duplicate within a batch** before building records: collapse payloads on
   `[trace_id, started_at]` so one request never inserts the same key twice.
3. **Single path** (`create_trace!` / `find_or_create_trace`): wrap in
   `rescue ActiveRecord::RecordNotUnique` and re-fetch the existing row (treat a
   duplicate ingest as success — return the existing trace), since trace ingest
   is meant to be idempotent.
4. **Re-sync `schema.rb`** with the live composite index (or switch the app to
   `schema_format = :sql`) so the source of truth stops lying about the index.

If step 1's SQL confirms the index is on `(trace_id)` alone, the conflict target
is `(trace_id)` instead — but then the hypertable migration would have to have
failed/not run in production, which should also be investigated.

## What was verified vs. not

- **Verified (from repo + the error itself):** the live DB enforces a UNIQUE
  index named `index_traces_on_trace_id` on `traces` (the error fired because of
  it); the ingestion code has no conflict/dedup handling on either path.
- **NOT verified (no DB credential for this product):** the exact column tuple of
  the live unique index, and whether the offending duplicates come from
  concurrent retries vs. duplicate batch payloads. These require the SQL above.
