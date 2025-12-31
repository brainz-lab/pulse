class CreateNotificationChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_channels, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      t.string :name, null: false
      t.string :kind, null: false  # webhook, email, slack, pagerduty
      t.boolean :enabled, default: true

      # Configuration stored as JSONB for flexibility
      # webhook: { url, headers, method }
      # email: { addresses }
      # slack: { webhook_url, channel }
      # pagerduty: { integration_key, severity }
      t.jsonb :config, default: {}, null: false

      t.datetime :last_used_at
      t.integer :success_count, default: 0
      t.integer :failure_count, default: 0

      t.timestamps

      t.index [ :project_id, :name ], unique: true
      t.index [ :project_id, :kind ]
      t.index [ :project_id, :enabled ]
    end
  end
end
