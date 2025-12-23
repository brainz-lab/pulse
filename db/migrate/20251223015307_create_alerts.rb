class CreateAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :alerts, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.references :alert_rule, type: :uuid, null: false, foreign_key: true

      t.string :status, null: false, default: 'firing'  # firing, resolved
      t.string :severity, null: false

      # Snapshot of rule condition
      t.string :metric_type, null: false
      t.string :operator, null: false
      t.float :threshold, null: false
      t.float :value, null: false       # The actual value that triggered

      # Timing
      t.datetime :triggered_at, null: false
      t.datetime :resolved_at

      # Context
      t.string :endpoint
      t.string :environment
      t.text :message

      t.timestamps

      t.index [:project_id, :status]
      t.index [:project_id, :triggered_at]
      t.index [:alert_rule_id, :triggered_at]
    end

    # Track notification delivery
    create_table :alert_notifications, id: :uuid do |t|
      t.references :alert, type: :uuid, null: false, foreign_key: true
      t.references :notification_channel, type: :uuid, null: false, foreign_key: true

      t.string :status, null: false, default: 'pending'  # pending, sent, failed
      t.text :error_message
      t.datetime :sent_at

      t.timestamps

      t.index [:alert_id, :notification_channel_id], unique: true, name: 'idx_alert_notifications_unique'
      t.index [:status]
    end
  end
end
