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

ActiveRecord::Schema[8.1].define(version: 2025_12_23_020446) do
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

  create_table "alert_notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "alert_id", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.uuid "notification_channel_id", null: false
    t.datetime "sent_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_id", "notification_channel_id"], name: "idx_alert_notifications_unique", unique: true
    t.index ["alert_id"], name: "index_alert_notifications_on_alert_id"
    t.index ["notification_channel_id"], name: "index_alert_notifications_on_notification_channel_id"
    t.index ["status"], name: "index_alert_notifications_on_status"
  end

  create_table "alert_rule_channels", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "alert_rule_id", null: false
    t.datetime "created_at", null: false
    t.uuid "notification_channel_id", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_rule_id", "notification_channel_id"], name: "idx_alert_rule_channels_unique", unique: true
    t.index ["alert_rule_id"], name: "index_alert_rule_channels_on_alert_rule_id"
    t.index ["notification_channel_id"], name: "index_alert_rule_channels_on_notification_channel_id"
  end

  create_table "alert_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "aggregation", default: "avg"
    t.integer "cooldown_minutes", default: 60
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "enabled", default: true
    t.string "endpoint"
    t.string "environment"
    t.datetime "last_checked_at"
    t.datetime "last_triggered_at"
    t.string "metric_name"
    t.string "metric_type", null: false
    t.string "name", null: false
    t.string "operator", null: false
    t.uuid "project_id", null: false
    t.string "severity", default: "warning"
    t.string "status", default: "ok"
    t.float "threshold", null: false
    t.datetime "updated_at", null: false
    t.integer "window_minutes", default: 5
    t.index ["project_id", "enabled"], name: "index_alert_rules_on_project_id_and_enabled"
    t.index ["project_id", "metric_type"], name: "index_alert_rules_on_project_id_and_metric_type"
    t.index ["project_id", "status"], name: "index_alert_rules_on_project_id_and_status"
    t.index ["project_id"], name: "index_alert_rules_on_project_id"
  end

  create_table "alerts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "alert_rule_id", null: false
    t.datetime "created_at", null: false
    t.string "endpoint"
    t.string "environment"
    t.text "message"
    t.string "metric_type", null: false
    t.string "operator", null: false
    t.uuid "project_id", null: false
    t.datetime "resolved_at"
    t.string "severity", null: false
    t.string "status", default: "firing", null: false
    t.float "threshold", null: false
    t.datetime "triggered_at", null: false
    t.datetime "updated_at", null: false
    t.float "value", null: false
    t.index ["alert_rule_id", "triggered_at"], name: "index_alerts_on_alert_rule_id_and_triggered_at"
    t.index ["alert_rule_id"], name: "index_alerts_on_alert_rule_id"
    t.index ["project_id", "status"], name: "index_alerts_on_project_id_and_status"
    t.index ["project_id", "triggered_at"], name: "index_alerts_on_project_id_and_triggered_at"
    t.index ["project_id"], name: "index_alerts_on_project_id"
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

  create_table "notification_channels", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true
    t.integer "failure_count", default: 0
    t.string "kind", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.uuid "project_id", null: false
    t.integer "success_count", default: 0
    t.datetime "updated_at", null: false
    t.index ["project_id", "enabled"], name: "index_notification_channels_on_project_id_and_enabled"
    t.index ["project_id", "kind"], name: "index_notification_channels_on_project_id_and_kind"
    t.index ["project_id", "name"], name: "index_notification_channels_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_notification_channels_on_project_id"
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.float "apdex_t", default: 0.5
    t.datetime "created_at", null: false
    t.string "environment", default: "live"
    t.string "name"
    t.string "platform_project_id", null: false
    t.jsonb "settings", default: {}, null: false
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
    t.jsonb "data", default: {}, null: false
    t.float "db_duration_ms", default: 0.0
    t.float "duration_ms"
    t.datetime "ended_at"
    t.string "environment"
    t.boolean "error", default: false
    t.string "error_class"
    t.text "error_message"
    t.integer "executions", default: 1
    t.float "external_duration_ms", default: 0.0
    t.string "host"
    t.string "job_class"
    t.string "job_id"
    t.string "kind", default: "request", null: false
    t.string "name", null: false
    t.uuid "project_id", null: false
    t.string "queue"
    t.float "queue_wait_ms"
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
    t.index ["project_id", "queue", "started_at"], name: "idx_traces_job_queue"
    t.index ["project_id", "started_at"], name: "index_traces_on_project_id_and_started_at"
    t.index ["project_id"], name: "index_traces_on_project_id"
    t.index ["request_id"], name: "index_traces_on_request_id"
    t.index ["trace_id"], name: "index_traces_on_trace_id", unique: true
  end

  add_foreign_key "alert_notifications", "alerts"
  add_foreign_key "alert_notifications", "notification_channels"
  add_foreign_key "alert_rule_channels", "alert_rules"
  add_foreign_key "alert_rule_channels", "notification_channels"
  add_foreign_key "alert_rules", "projects"
  add_foreign_key "alerts", "alert_rules"
  add_foreign_key "alerts", "projects"
  add_foreign_key "metrics", "projects"
  add_foreign_key "notification_channels", "projects"
  add_foreign_key "spans", "projects"
  add_foreign_key "spans", "traces"
  add_foreign_key "traces", "projects"
end
