# Incident Diagnosis — `ActiveRecord::RecordNotUnique` on `traces`

> **STATUS: UNVERIFIED — needs DB/deploy confirmation.**
> This is a **diagnosis-only** document. No code or schema change is shipped in this PR.
> The Observability/Pulse production database has **no read-only credential available**
> to the incident agent (`vault_db_query` reports *"no database credential named
> `observability-db-ro`"*, and there is no `pulse-db-ro` either), and the reflex/recall
> MCP tools are scoped to a different project and surface no Pulse logs. The live runtime
> state therefore **could not be inspected**. The root cause below is inferred from the
> committed schema + source and must be confirmed with the commands in §4 before a fix is merged.

## 1. Incident

| Field | Value |
|-------|-------|
| Source | reflex (Observability) |
| Product | Observability → **Pulse** (APM) |
| Error class | `ActiveRecord::RecordNotUnique` |
| Message | `PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint "index_traces_on_trac…"` |
| Fingerprint | `3f313587264f9c56` |
| Occurred | 2026-06-16 17:09:50 UTC |
| Project | `6e130615-079b-440a-b7f9-c4c48b42f52f` |
| Reflex group | https://reflex.brainzlab.ai/error_groups/beb37608-d491-4050-ac52-0e1bc0b6e637 |

## 2. What was verified

1. **The violated constraint exists and is correct.** `db/schema.rb:217` defines
   `t.index ["trace_id"], name: "index_traces_on_trace_id", unique: true` on the `traces`
   table (also present in `db/structure.sql`). The truncated name `index_traces_on_trac…`
   in the alert matches `index_traces_on_trace_id`.
   → **A `UniqueViolation` here means the table and index already exist and a row with a
   duplicate `trace_id` was inserted.** This is **not** a missing-table / unloaded-schema /
   pending-migration problem, so **adding or altering a migration is the wrong fix.**

2. **Trace ingestion is not idempotent / not race-safe.** Every insert path can attempt to
   write a `trace_id` that already exists (or appears twice in the same request):

   | Path | Location | Problem |
   |------|----------|---------|
   | Batch bulk insert | `app/services/trace_processor.rb:99-113` (`bulk_insert_traces`) | Builds one raw multi-row `INSERT INTO traces … VALUES …` with **no `ON CONFLICT`**. |
   | Batch dedup | `app/services/trace_processor.rb:27-39` (`process_batch!`) | Pre-fetches existing traces once (line 17), then appends every not-yet-existing payload to `new_trace_records` **without de-duplicating `trace_id` within the batch**. A single `/traces/batch` payload containing the same new `trace_id` twice → the multi-row `INSERT` itself violates the unique index (deterministic, not even a race). |
   | Batch insert validation skipped | `app/services/trace_processor.rb:157-174` → `create_trace!(skip_uniqueness: true)` (line 165, 209-239) | `skip_uniqueness_validation` is set (`app/models/trace.rb:11-18`), so AR does not guard, and there is no DB-level conflict handling. A concurrent insert between the pre-fetch and this insert → `RecordNotUnique`. |
   | Single trace | `app/services/trace_processor.rb:169-173` | `find_by(trace_id:)` then `create_trace!` — classic check-then-create (TOCTOU). The AR uniqueness validation (`trace.rb:12`) narrows but does **not** close the window; two concurrent requests both pass validation, both insert, second fails. |
   | Span auto-create | `app/controllers/api/v1/spans_controller.rb:67-101` (`find_or_create_trace_for`) | `find_by(trace_id:)` then `current_project.traces.create!(…)` — same check-then-create race. |

## 3. Most likely root cause

Pulse receives traces from many SDK clients over HTTP. The same `trace_id` legitimately
arrives **concurrently or more than once**:

- parallel spans of one request POSTed by the SDK at roughly the same time
  (`spans_controller` auto-creates the parent trace on first span seen);
- at-least-once / retried deliveries from the SDK or a proxy resending a payload;
- the same new `trace_id` appearing twice inside a single `POST /api/v1/traces/batch` body.

Because none of the insert paths use a database-level idempotent insert
(`INSERT … ON CONFLICT (trace_id) DO NOTHING`) and the batch path does not de-duplicate
`trace_id`s, the duplicate reaches PostgreSQL and trips `index_traces_on_trace_id`, raising
`ActiveRecord::RecordNotUnique`. The single-occurrence event count (`event_count: 1`) is
consistent with an intermittent concurrency race rather than a steady, structural failure.

**This is an application-level idempotency bug, not a schema/infra problem.**

## 4. How a human with production access should CONFIRM (before fixing)

Run from the Pulse service dir (see `CLAUDE.md` → "Kamal Production Access"):

```bash
# (a) Recent occurrences of the violation in the app logs — confirms it is still firing
kamal app logs --since 24h | grep -i "index_traces_on_trace_id\|RecordNotUnique"

# (b) Is it the batch path, the single path, or span auto-create? Look at the surrounding
#     stack frames in the same log lines (trace_processor#bulk_insert_traces vs
#     #create_trace! vs spans_controller#find_or_create_trace_for).
kamal app logs --since 24h --grep "RecordNotUnique" -n 50

# (c) Confirm duplicate trace_ids are actually arriving (read-only SQL):
kamal app exec -p --reuse -e SECRET_KEY_BASE:<master_key> \
  'bin/rails runner "puts Trace.group(:trace_id).having(\"COUNT(*) > 1\").count.size"'   # expect 0 (unique index blocks dupes; >0 would be surprising)

# (d) Confirm the index really is unique in production (rules out a drifted prod schema):
kamal app exec -p --reuse -e SECRET_KEY_BASE:<master_key> \
  'bin/rails runner "puts ActiveRecord::Base.connection.indexes(:traces).find { |i| i.name == \"index_traces_on_trace_id\" }.inspect"'
```

Expected if this diagnosis is correct: (a)/(b) show the violation originating in
`TraceProcessor`/`SpansController` insert paths; (d) shows `unique: true`.

## 5. Recommended fix (apply only after §4 confirms — NOT shipped here)

Make every trace insert idempotent at the database level, keyed on `trace_id`:

1. **Batch (`bulk_insert_traces`, `trace_processor.rb:99-113`)** — de-duplicate
   `new_trace_records` by `trace_id` before building the statement, and append
   `ON CONFLICT (trace_id) DO NOTHING` to the `INSERT`. Then re-fetch by `trace_id`
   (already done at line 48) so rows inserted by a concurrent request are still returned.
   Equivalent Rails-native option: `project.traces.insert_all(records, unique_by: :index_traces_on_trace_id)`.

2. **Single trace (`create_trace!`, `trace_processor.rb:209-239` and
   `spans_controller.rb` `find_or_create_trace_for`)** — wrap `save!`/`create!` in
   `rescue ActiveRecord::RecordNotUnique` and re-`find_by(trace_id:)` to return the
   winner of the race (read-then-create-then-reselect is the standard idempotent pattern).

3. Keep the existing unique index — it is doing its job. **Do not add a migration.**

These changes are correct regardless of which sub-path fired, but they touch the
production ingest hot path and were **not validated against live data or a reproduction**,
so they are left as a recommendation pending §4 confirmation.
