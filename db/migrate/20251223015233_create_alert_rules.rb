class CreateAlertRules < ActiveRecord::Migration[8.1]
  def change
    create_table :alert_rules, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      t.string :name, null: false
      t.text :description
      t.boolean :enabled, default: true

      # What to monitor
      t.string :metric_type, null: false  # apdex, error_rate, throughput, response_time, custom
      t.string :metric_name                # For custom metrics

      # Condition
      t.string :operator, null: false      # gt, gte, lt, lte, eq
      t.float :threshold, null: false      # The value to compare against
      t.string :aggregation, default: 'avg' # avg, max, min, sum, count, p95, p99

      # Time window
      t.integer :window_minutes, default: 5  # Evaluate over last N minutes

      # Filtering (optional)
      t.string :endpoint                    # Filter by endpoint path
      t.string :environment                 # Filter by environment

      # Notification settings
      t.integer :cooldown_minutes, default: 60  # Don't re-alert within this period
      t.string :severity, default: 'warning'    # info, warning, critical

      # Status tracking
      t.string :status, default: 'ok'       # ok, alerting, recovering
      t.datetime :last_triggered_at
      t.datetime :last_checked_at

      t.timestamps

      t.index [ :project_id, :enabled ]
      t.index [ :project_id, :status ]
      t.index [ :project_id, :metric_type ]
    end

    # Join table for alert_rules -> notification_channels
    create_table :alert_rule_channels, id: :uuid do |t|
      t.references :alert_rule, type: :uuid, null: false, foreign_key: true
      t.references :notification_channel, type: :uuid, null: false, foreign_key: true

      t.timestamps

      t.index [ :alert_rule_id, :notification_channel_id ], unique: true, name: 'idx_alert_rule_channels_unique'
    end
  end
end
