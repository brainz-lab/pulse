# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2024_12_21_000006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "aggregated_metrics", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.float "avg"
    t.datetime "bucket", null: false
    t.float "count"
    t.jsonb "dimensions", default: {}
    t.string "granularity", null: false
    t.float "max"
    t.float "min"
    t.string "name", null: false
    t.float "p50"
    t.float "p95"
    t.float "p99"
    t.uuid "project_id", null: false
    t.float "sum"
    t.index ["project_id", "name", "bucket", "granularity"], name: "idx_agg_metrics_lookup"
    t.index ["project_id"], name: "index_aggregated_metrics_on_project_id"
  end

  create_table "metric_points", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "metric_id", null: false
    t.uuid "project_id", null: false
    t.jsonb "tags", default: {}
    t.datetime "timestamp", null: false
    t.float "value", null: false
    t.index ["metric_id"], name: "index_metric_points_on_metric_id"
    t.index ["project_id", "metric_id", "timestamp"], name: "index_metric_points_on_project_id_and_metric_id_and_timestamp"
    t.index ["project_id"], name: "index_metric_points_on_project_id"
  end

  create_table "metrics", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "kind", default: "gauge", null: false
    t.string "name", null: false
    t.uuid "project_id", null: false
    t.jsonb "tags", default: {}
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_metrics_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_metrics_on_project_id"
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.float "apdex_t", default: 0.5
    t.datetime "created_at", null: false
    t.string "environment", default: "live"
    t.string "name"
    t.string "platform_project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_project_id"], name: "index_projects_on_platform_project_id", unique: true
  end

  create_table "spans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "data", default: {}
    t.float "duration_ms"
    t.datetime "ended_at"
    t.boolean "error", default: false
    t.string "error_class"
    t.text "error_message"
    t.string "kind", null: false
    t.string "name", null: false
    t.string "parent_span_id"
    t.uuid "project_id", null: false
    t.string "span_id", null: false
    t.datetime "started_at", null: false
    t.uuid "trace_id", null: false
    t.index ["project_id"], name: "index_spans_on_project_id"
    t.index ["span_id"], name: "index_spans_on_span_id"
    t.index ["trace_id", "started_at"], name: "index_spans_on_trace_id_and_started_at"
    t.index ["trace_id"], name: "index_spans_on_trace_id"
  end

  create_table "traces", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action"
    t.string "commit"
    t.string "controller"
    t.float "db_duration_ms", default: 0.0
    t.float "duration_ms"
    t.datetime "ended_at"
    t.string "environment"
    t.boolean "error", default: false
    t.string "error_class"
    t.text "error_message"
    t.float "external_duration_ms", default: 0.0
    t.string "host"
    t.string "job_class"
    t.string "job_id"
    t.string "kind", default: "request", null: false
    t.string "name", null: false
    t.uuid "project_id", null: false
    t.string "queue"
    t.string "request_id"
    t.string "request_method"
    t.string "request_path"
    t.integer "span_count", default: 0
    t.datetime "started_at", null: false
    t.integer "status"
    t.string "trace_id", null: false
    t.string "user_id"
    t.float "view_duration_ms", default: 0.0
    t.index ["project_id", "name", "started_at"], name: "index_traces_on_project_id_and_name_and_started_at"
    t.index ["project_id", "started_at"], name: "index_traces_on_project_id_and_started_at"
    t.index ["project_id"], name: "index_traces_on_project_id"
    t.index ["request_id"], name: "index_traces_on_request_id"
    t.index ["trace_id"], name: "index_traces_on_trace_id", unique: true
  end

  add_foreign_key "metrics", "projects"
  add_foreign_key "spans", "projects"
  add_foreign_key "spans", "traces"
  add_foreign_key "traces", "projects"
end
