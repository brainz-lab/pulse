class CreateTraces < ActiveRecord::Migration[8.0]
  def change
    create_table :traces, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      # Identification
      t.string :trace_id, null: false
      t.string :name, null: false
      t.string :kind, null: false, default: 'request'

      # Timing
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.float :duration_ms

      # Request context
      t.string :request_id
      t.string :request_method
      t.string :request_path
      t.string :controller
      t.string :action
      t.integer :status

      # Job context
      t.string :job_class
      t.string :job_id
      t.string :queue

      # Environment
      t.string :environment
      t.string :commit
      t.string :host

      # User
      t.string :user_id

      # Status
      t.boolean :error, default: false
      t.string :error_class
      t.text :error_message

      # Metrics
      t.integer :span_count, default: 0
      t.float :db_duration_ms, default: 0
      t.float :view_duration_ms, default: 0
      t.float :external_duration_ms, default: 0

      t.index [:project_id, :started_at]
      t.index [:project_id, :name, :started_at]
      t.index :trace_id, unique: true
      t.index :request_id
    end
  end
end
